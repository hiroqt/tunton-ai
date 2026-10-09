import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One ranked candidate: a distinct landmark id and its RAW best cosine
/// similarity (dot product of two L2-normalized vectors). NOT a calibrated
/// probability — never present this as a percentage.
class LandmarkCandidate {
  const LandmarkCandidate(this.landmarkId, this.score);

  /// Matches an id in landmarks.json.
  final String landmarkId;

  /// Raw cosine similarity in roughly [-1, 1].
  final double score;
}

/// Result of matching one query embedding. `candidates` is 0..maxCandidates
/// distinct landmark ids sorted by score descending. `isRecognized` is true iff
/// at least one candidate passed the threshold (P0-04 "Not recognized" is a
/// first-class empty result).
class MatchResult {
  const MatchResult(this.candidates);

  /// Growable:false, length 0..maxCandidates, sorted by score descending.
  final List<LandmarkCandidate> candidates;

  bool get isRecognized => candidates.isNotEmpty;

  LandmarkCandidate? get top => candidates.isEmpty ? null : candidates.first;
}

/// Ranks a query embedding against packaged reference embeddings grouped by
/// landmark (P0-03, P0-04). Dependency-free math: cosine similarity is a plain
/// dot product because both the query (from EmbeddingService.normalizeEmbedding)
/// and every stored reference vector are already L2-normalized.
class LandmarkMatcher {
  LandmarkMatcher._(
    this._dimension,
    this._refsByLandmark,
    this.scoreThreshold,
    this.minTopMargin,
    this.strongMatchThreshold,
    this.modelId,
    this.modelSha256,
    this.preprocessingVersion,
  );

  static const String referenceAsset =
      'assets/landmarks/reference_embeddings.json';

  /// Absolute rejection THRESHOLD on raw cosine similarity (a ranking signal,
  /// NOT a calibrated probability — never present as a percentage).
  ///
  /// Chosen from measured data, not guessed: see
  /// `.agents/tasks/recognition-threshold/analysis.md`. The reference-vs-
  /// reference INTRA (correct) and INTER (wrong-landmark) cosine distributions
  /// overlap heavily (INTER median ~0.66, INTRA p25 ~0.69), so no absolute
  /// cutoff alone separates correct from wrong. Real on-device held-out photos
  /// were observed at raw cosine 0.36–0.68, far below reference-to-reference
  /// scores, so a high absolute gate would reject genuine matches. 0.40 sits
  /// just above the noise floor while keeping the real-photo band; the
  /// [defaultMinTopMargin] gate — not this threshold — is the primary
  /// ambiguity filter.
  static const double defaultScoreThreshold = 0.40;

  /// Minimum required gap between the top-1 and top-2 landmark scores for a
  /// result to be accepted (a ranking signal, NOT a probability).
  ///
  /// Chosen from measured data, not guessed: see
  /// `.agents/tasks/recognition-threshold/analysis.md`. A genuine match has a
  /// landmark score that clearly beats the runner-up; an ambiguous photo sits
  /// near-equally close to two landmarks (small margin). The measured margin
  /// distribution (median ~0.10, p25 ~0.044) shows 0.05 rejects the bottom
  /// ~31% near-tie cases as "Not recognized" while keeping the ~69% with a
  /// clear winner — stricter than the old single-gate behavior for exactly the
  /// cases that confused users.
  ///
  /// Widened from 0.05 to 0.07 on 2026-10-10 for the "more aggressive"
  /// rejection the user requested: from the measured margin trade-off, m=0.07
  /// keeps the ~58.8% of refs with a clear winner (the genuine median margin
  /// 0.10 still clears 0.07) while rejecting the extra ~10% near-tie band that
  /// 0.05 still admitted. See analysis.md.
  static const double defaultMinTopMargin = 0.07;

  /// Higher absolute THRESHOLD a LONE top candidate must clear when it is the
  /// SOLE landmark above [defaultScoreThreshold] (a ranking signal, NOT a
  /// calibrated probability — never present as a percentage).
  ///
  /// Chosen from measured data, not guessed: see
  /// `.agents/tasks/recognition-threshold/analysis.md`. The ≥2-candidate path
  /// relies on the [defaultMinTopMargin] gate to reject ambiguity, but a photo
  /// that weakly matches EXACTLY ONE landmark above the 0.40 floor has no
  /// runner-up to trip the margin — an observed synthetic image leaked through
  /// at cosine 0.4951 as a lone confident #1. This stronger gate closes that
  /// hole: a lone candidate is accepted only when its score ≥ 0.55.
  ///
  /// 0.55 is the most defensible aggressive setting: strictly above the
  /// measured 0.4951 lone false hit, below the 0.36–0.68 real on-device
  /// photo band so a genuine dominant real match in ~0.55–0.68 still passes,
  /// and just below INTRA p10 (0.5362) so it keeps the bulk of correct
  /// reference-grade matches (INTRA kept at 0.55 ≈ 84.3%). It stays an
  /// accept/reject ranking decision, never a probability.
  static const double defaultStrongMatchThreshold = 0.55;

  final int _dimension;

  /// landmark_id -> list of that landmark's reference vectors
  /// (each of length _dimension).
  final Map<String, List<List<double>>> _refsByLandmark;

  final double scoreThreshold;
  final double minTopMargin;
  final double strongMatchThreshold;
  final String modelId;
  final String? modelSha256;
  final String? preprocessingVersion;

  int get dimension => _dimension;

  Iterable<String> get landmarkIds => _refsByLandmark.keys;

  /// Build from already-parsed JSON (preferred for tests — no IO).
  ///
  /// Validates: `dimension` is a positive int; `references` is a non-empty list;
  /// each entry has a non-blank `landmark_id`; each `vector` has length ==
  /// dimension and all finite values. Throws [FormatException] on any violation.
  factory LandmarkMatcher.fromDecodedJson(
    Map<String, dynamic> json, {
    double scoreThreshold = defaultScoreThreshold,
    double minTopMargin = defaultMinTopMargin,
    double strongMatchThreshold = defaultStrongMatchThreshold,
  }) {
    final rawDimension = json['dimension'];
    if (rawDimension is! int || rawDimension <= 0) {
      throw const FormatException(
        'Reference embeddings must declare a positive integer dimension.',
      );
    }
    final dimension = rawDimension;
    final modelId = json['model_id'];
    if (modelId is! String || modelId.trim().isEmpty) {
      throw const FormatException('Reference embeddings require a model_id.');
    }
    final modelSha256 = json['model_sha256'];
    if (modelSha256 != null &&
        (modelSha256 is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(modelSha256))) {
      throw const FormatException(
        'Reference embeddings have an invalid model checksum.',
      );
    }
    final preprocessingVersion = json['preprocessing_version'];
    if (preprocessingVersion != null &&
        (preprocessingVersion is! String || preprocessingVersion.isEmpty)) {
      throw const FormatException(
        'Reference embeddings have an invalid preprocessing version.',
      );
    }

    final rawReferences = json['references'];
    if (rawReferences is! List || rawReferences.isEmpty) {
      throw const FormatException(
        'Reference embeddings must contain a non-empty references list.',
      );
    }

    final refsByLandmark = <String, List<List<double>>>{};
    for (final rawReference in rawReferences) {
      if (rawReference is! Map<String, dynamic>) {
        throw const FormatException('Each reference must be a JSON object.');
      }
      final rawLandmarkId = rawReference['landmark_id'];
      if (rawLandmarkId is! String || rawLandmarkId.trim().isEmpty) {
        throw const FormatException(
          'Each reference must have a non-blank landmark_id.',
        );
      }
      final rawVector = rawReference['vector'];
      if (rawVector is! List || rawVector.length != dimension) {
        throw FormatException(
          'Reference vector for "$rawLandmarkId" must have length $dimension.',
        );
      }
      final vector = List<double>.filled(dimension, 0, growable: false);
      for (var i = 0; i < dimension; i++) {
        final value = rawVector[i];
        if (value is! num || !value.isFinite) {
          throw FormatException(
            'Reference vector for "$rawLandmarkId" has a non-finite value.',
          );
        }
        vector[i] = value.toDouble();
      }
      final norm = math.sqrt(
        vector.fold<double>(0, (sum, value) => sum + value * value),
      );
      if (!norm.isFinite || (norm - 1).abs() > 0.001) {
        throw FormatException(
          'Reference vector for "$rawLandmarkId" must be L2-normalized.',
        );
      }
      refsByLandmark
          .putIfAbsent(rawLandmarkId, () => <List<double>>[])
          .add(vector);
    }

    return LandmarkMatcher._(
      dimension,
      refsByLandmark,
      scoreThreshold,
      minTopMargin,
      strongMatchThreshold,
      modelId,
      modelSha256 as String?,
      preprocessingVersion as String?,
    );
  }

  /// Parse a JSON string then delegate to [fromDecodedJson].
  factory LandmarkMatcher.fromJsonString(
    String jsonString, {
    double scoreThreshold = defaultScoreThreshold,
    double minTopMargin = defaultMinTopMargin,
    double strongMatchThreshold = defaultStrongMatchThreshold,
  }) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Reference embeddings JSON must be an object.',
      );
    }
    return LandmarkMatcher.fromDecodedJson(
      decoded,
      scoreThreshold: scoreThreshold,
      minTopMargin: minTopMargin,
      strongMatchThreshold: strongMatchThreshold,
    );
  }

  /// Convenience loader reading the bundled asset via rootBundle
  /// (package:flutter/services.dart is Flutter itself, not a new package).
  static Future<LandmarkMatcher> load({
    double scoreThreshold = defaultScoreThreshold,
    double minTopMargin = defaultMinTopMargin,
    double strongMatchThreshold = defaultStrongMatchThreshold,
  }) async {
    final jsonString = await rootBundle.loadString(referenceAsset);
    return LandmarkMatcher.fromJsonString(
      jsonString,
      scoreThreshold: scoreThreshold,
      minTopMargin: minTopMargin,
      strongMatchThreshold: strongMatchThreshold,
    );
  }

  /// Rank [query] against the reference embeddings (ARD §6 steps 5-7).
  ///
  /// [query] must have length == [dimension] and all finite values, else a
  /// [FormatException] is thrown. For each landmark the MAX cosine similarity
  /// across its reference vectors is computed (no re-normalization — both sides
  /// are already L2-normalized); landmarks are sorted by that best score
  /// descending; any below [scoreThreshold] are dropped; at most [maxCandidates]
  /// DISTINCT ids are kept.
  ///
  /// NET ACCEPT RULE (P0-04): a result is RECOGNIZED only if the best landmark
  /// clears the appropriate absolute threshold AND is unambiguous:
  /// - **Sole above-floor candidate:** accept only if its score ≥
  ///   [strongMatchThreshold] (the stronger lone-match gate). A single
  ///   0.40–0.55 match is rejected → *Not recognized*. This closes the
  ///   lone-candidate hole where a weak one-landmark hit (observed at 0.4951)
  ///   leaked through as a confident #1 with no runner-up to trip the margin.
  /// - **≥2 above-floor candidates:** accept the top only if top1 − top2 ≥
  ///   [minTopMargin]; otherwise reject the whole result.
  /// Everything else (nothing clears [scoreThreshold], a lone candidate below
  /// the strong gate, or a near-tie) → empty [MatchResult] = *Not recognized*.
  ///
  /// The measured reference distributions overlap too much for the absolute
  /// threshold alone to reject wrong-landmark matches, so the margin gate (for
  /// the ≥2 case) and the strong-match gate (for the lone case) — not
  /// [scoreThreshold] — are the real ambiguity filters (see analysis.md). This
  /// stays an accept/reject ranking decision, never a calibrated probability.
  ///
  /// Returns a [MatchResult] (empty == Not recognized).
  MatchResult match(List<double> query, {int maxCandidates = 3}) {
    if (query.length != _dimension) {
      throw FormatException(
        'Query embedding must have length $_dimension, got ${query.length}.',
      );
    }
    for (final value in query) {
      if (!value.isFinite) {
        throw const FormatException('Query embedding has a non-finite value.');
      }
    }

    final candidates = <LandmarkCandidate>[];
    for (final entry in _refsByLandmark.entries) {
      var bestScore = double.negativeInfinity;
      for (final reference in entry.value) {
        var dot = 0.0;
        for (var i = 0; i < _dimension; i++) {
          dot += query[i] * reference[i];
        }
        if (dot > bestScore) {
          bestScore = dot;
        }
      }
      if (kDebugMode) {
        debugPrint(
          '[TUNTON_RECOG] landmark=${entry.key} '
          'best_cosine=${bestScore.toStringAsFixed(4)} '
          'accepted=${bestScore >= scoreThreshold} '
          'threshold=${scoreThreshold.toStringAsFixed(2)}',
        );
      }
      if (bestScore >= scoreThreshold) {
        candidates.add(LandmarkCandidate(entry.key, bestScore));
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    // Nothing cleared the absolute floor → Not recognized.
    if (candidates.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[TUNTON_RECOG] REJECT gate=below_threshold '
          'threshold=${scoreThreshold.toStringAsFixed(2)} => Not recognized',
        );
      }
      return const MatchResult(<LandmarkCandidate>[]);
    }

    // LONE-CANDIDATE GATE (P0-04): with exactly one landmark above the floor
    // there is no runner-up for the margin gate to catch, so a weak lone hit
    // (observed at 0.4951) would otherwise leak through as a confident #1.
    // Require the stronger [strongMatchThreshold] in that case.
    if (candidates.length == 1) {
      if (candidates[0].score < strongMatchThreshold) {
        if (kDebugMode) {
          debugPrint(
            '[TUNTON_RECOG] REJECT gate=lone_below_strong '
            'top1=${candidates[0].landmarkId}(${candidates[0].score.toStringAsFixed(4)}) '
            '< strongMatchThreshold=${strongMatchThreshold.toStringAsFixed(2)} '
            '=> Not recognized',
          );
        }
        return const MatchResult(<LandmarkCandidate>[]);
      }
      if (kDebugMode) {
        debugPrint(
          '[TUNTON_RECOG] ACCEPT gate=accept_strong_single '
          'candidate=${candidates[0].landmarkId} '
          'score=${candidates[0].score.toStringAsFixed(4)} '
          '>= strongMatchThreshold=${strongMatchThreshold.toStringAsFixed(2)}',
        );
      }
      return MatchResult(List<LandmarkCandidate>.unmodifiable(candidates));
    }

    // AMBIGUITY GATE (P0-04): a near-tie between the top two landmarks means the
    // photo does not clearly depict one landmark. Reject the whole result to
    // "Not recognized" rather than present a misleading confident #1.
    final margin = candidates[0].score - candidates[1].score;
    if (margin < minTopMargin) {
      if (kDebugMode) {
        debugPrint(
          '[TUNTON_RECOG] REJECT gate=ambiguous_margin '
          'top1=${candidates[0].landmarkId}(${candidates[0].score.toStringAsFixed(4)}) '
          'top2=${candidates[1].landmarkId}(${candidates[1].score.toStringAsFixed(4)}) '
          'margin=${margin.toStringAsFixed(4)} < minTopMargin=${minTopMargin.toStringAsFixed(2)} '
          '=> Not recognized',
        );
      }
      return const MatchResult(<LandmarkCandidate>[]);
    }

    final kept = candidates.length > maxCandidates
        ? candidates.sublist(0, maxCandidates)
        : candidates;
    if (kDebugMode) {
      debugPrint(
        '[TUNTON_RECOG] ACCEPT gate=accept_margin_ok '
        'candidates=${kept.map((candidate) => candidate.landmarkId).join(',')} '
        'margin=${margin.toStringAsFixed(4)}>=${minTopMargin.toStringAsFixed(2)} '
        'threshold=${scoreThreshold.toStringAsFixed(2)}',
      );
    }
    return MatchResult(List<LandmarkCandidate>.unmodifiable(kept));
  }
}
