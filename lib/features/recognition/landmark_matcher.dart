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
    this.modelId,
    this.modelSha256,
    this.preprocessingVersion,
  );

  static const String referenceAsset =
      'assets/landmarks/reference_embeddings.json';

  /// Conservative default rejection THRESHOLD (a ranking signal, not a
  /// probability). A true held-out match of these L2-normalized MobileNetV3
  /// embeddings scores well above this, while unrelated photos fall below.
  /// Tunable against held-out evidence.
  static const double defaultScoreThreshold = 0.55;

  final int _dimension;

  /// landmark_id -> list of that landmark's reference vectors
  /// (each of length _dimension).
  final Map<String, List<List<double>>> _refsByLandmark;

  final double scoreThreshold;
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
      modelId,
      modelSha256 as String?,
      preprocessingVersion as String?,
    );
  }

  /// Parse a JSON string then delegate to [fromDecodedJson].
  factory LandmarkMatcher.fromJsonString(
    String jsonString, {
    double scoreThreshold = defaultScoreThreshold,
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
    );
  }

  /// Convenience loader reading the bundled asset via rootBundle
  /// (package:flutter/services.dart is Flutter itself, not a new package).
  static Future<LandmarkMatcher> load({
    double scoreThreshold = defaultScoreThreshold,
  }) async {
    final jsonString = await rootBundle.loadString(referenceAsset);
    return LandmarkMatcher.fromJsonString(
      jsonString,
      scoreThreshold: scoreThreshold,
    );
  }

  /// Rank [query] against the reference embeddings (ARD §6 steps 5-7).
  ///
  /// [query] must have length == [dimension] and all finite values, else a
  /// [FormatException] is thrown. For each landmark the MAX cosine similarity
  /// across its reference vectors is computed (no re-normalization — both sides
  /// are already L2-normalized); landmarks are sorted by that best score
  /// descending; any below [scoreThreshold] are dropped; at most [maxCandidates]
  /// DISTINCT ids are kept. Returns a [MatchResult] (empty == Not recognized).
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
    final kept = candidates.length > maxCandidates
        ? candidates.sublist(0, maxCandidates)
        : candidates;
    if (kDebugMode) {
      debugPrint(
        '[TUNTON_RECOG] candidates=${kept.map((candidate) => candidate.landmarkId).join(',')}',
      );
    }
    return MatchResult(List<LandmarkCandidate>.unmodifiable(kept));
  }
}
