import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tuntun/features/recognition/landmark_matcher.dart';

/// Builds a decoded-JSON map for a small synthetic dimension so the ranking
/// logic can be exercised without the 512-dimension real asset.
Map<String, dynamic> _decoded(
  int dimension,
  List<(String landmarkId, List<double> vector)> references,
) {
  return <String, dynamic>{
    'model_id': 'synthetic',
    'dimension': dimension,
    'references': [
      for (final (landmarkId, vector) in references)
        <String, dynamic>{
          'landmark_id': landmarkId,
          'image_asset': 'assets/images/$landmarkId/x.png',
          'vector': vector,
        },
    ],
  };
}

void main() {
  test('best-match mode returns one clear landmark and its reference photo', () {
    final matcher = LandmarkMatcher.fromDecodedJson(_decoded(2, [
      ('alpha', [1.0, 0.0]),
      ('beta', [0.0, 1.0]),
    ]));
    final result = matcher.matchBest([1.0, 0.0]);
    expect(result.candidates, hasLength(1));
    expect(result.top!.landmarkId, 'alpha');
    expect(matcher.referencePhotos['alpha'], 'assets/images/alpha/x.png');
  });

  test('best-match mode rejects a weak top result', () {
    final matcher = LandmarkMatcher.fromDecodedJson(_decoded(2, [
      ('alpha', [0.7, math.sqrt(1 - 0.7 * 0.7)]),
    ]));
    expect(matcher.match([1.0, 0.0]).isRecognized, isTrue);
    expect(matcher.matchBest([1.0, 0.0]).isRecognized, isFalse);
  });

  test('best-match mode rejects two similar but distinct landmarks', () {
    final matcher = LandmarkMatcher.fromDecodedJson(_decoded(2, [
      ('alpha', [0.91, math.sqrt(1 - 0.91 * 0.91)]),
      ('beta', [0.90, math.sqrt(1 - 0.90 * 0.90)]),
    ]));
    expect(matcher.matchBest([1.0, 0.0]).candidates, isEmpty);
  });

  test('a runner-up below the ranking threshold still counts for ambiguity', () {
    final matcher = LandmarkMatcher.fromDecodedJson(_decoded(2, [
      ('alpha', [0.91, math.sqrt(1 - 0.91 * 0.91)]),
      ('beta', [0.89, math.sqrt(1 - 0.89 * 0.89)]),
    ]), scoreThreshold: 0.9);
    expect(matcher.match([1.0, 0.0]).candidates, hasLength(1));
    expect(matcher.matchBest([1.0, 0.0]).candidates, isEmpty);
  });

  test('multiple reference photos of the same place do not cause ambiguity', () {
    final matcher = LandmarkMatcher.fromDecodedJson(_decoded(2, [
      ('alpha', [1.0, 0.0]),
      ('alpha', [0.99, math.sqrt(1 - 0.99 * 0.99)]),
      ('beta', [0.0, 1.0]),
    ]));
    expect(matcher.matchBest([1.0, 0.0]).top!.landmarkId, 'alpha');
  });

  test('takes the MAX similarity across a landmark reference vectors', () {
    // alpha has a weak and a strong reference; the strong one must win.
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [0.6, 0.8]),
        ('alpha', [1.0, 0.0]),
      ]),
      scoreThreshold: 0.0,
    );
    final result = matcher.match([1.0, 0.0]);
    expect(result.isRecognized, isTrue);
    expect(result.top!.landmarkId, 'alpha');
    expect(result.top!.score, closeTo(1.0, 1e-12));
  });

  test('sorts distinct landmarks by best score descending', () {
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
        ('beta', [0.0, 1.0]),
        ('gamma', [0.70710678, 0.70710678]),
      ]),
      scoreThreshold: 0.0,
    );
    final result = matcher.match([1.0, 0.0]);
    expect(result.candidates.map((c) => c.landmarkId).toList(), [
      'alpha',
      'gamma',
      'beta',
    ]);
    expect(result.candidates[0].score, greaterThan(result.candidates[1].score));
    expect(result.candidates[1].score, greaterThan(result.candidates[2].score));
  });

  test('caps the result at 3 distinct ids when 4+ landmarks pass', () {
    // alpha is a clear winner (margin to beta well above the default), and the
    // other three stay above threshold so the 3-candidate cap is exercised.
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]), // cosine 1.0 vs query
        ('beta', [0.70710678, 0.70710678]), // cosine ~0.707
        ('gamma', [0.6, 0.8]), // cosine 0.6
        ('delta', [0.55, 0.83516]), // cosine ~0.55
      ]),
      scoreThreshold: 0.0,
    );
    final result = matcher.match([1.0, 0.0]);
    expect(result.candidates.length, 3);
    final ids = result.candidates.map((c) => c.landmarkId).toSet();
    expect(ids.length, 3);
    expect(ids.contains('alpha'), isTrue);
  });

  test(
    'ambiguity gate: two near-equal top scores within the margin => Not recognized',
    () {
      // alpha and beta are both ~0.707 to the query (a diagonal), a near-tie
      // well inside the default margin, so the result must be rejected.
      final matcher = LandmarkMatcher.fromDecodedJson(
        _decoded(2, [
          ('alpha', [1.0, 0.0]),
          ('beta', [0.0, 1.0]),
        ]),
        // Above the absolute threshold so only the MARGIN gate can reject.
        scoreThreshold: 0.4,
        minTopMargin: 0.05,
      );
      final result = matcher.match([0.70710678, 0.70710678]);
      expect(result.isRecognized, isFalse);
      expect(result.candidates, isEmpty);
      expect(result.top, isNull);
    },
  );

  test(
    'ambiguity gate: a clear dominant winner beyond the margin is recognized',
    () {
      final matcher = LandmarkMatcher.fromDecodedJson(
        _decoded(2, [
          ('alpha', [1.0, 0.0]), // cosine 1.0 vs query
          ('beta', [0.6, 0.8]), // cosine 0.6 vs query (margin 0.4 >> 0.05)
        ]),
        scoreThreshold: 0.4,
        minTopMargin: 0.05,
      );
      final result = matcher.match([1.0, 0.0]);
      expect(result.isRecognized, isTrue);
      expect(result.top!.landmarkId, 'alpha');
      expect(result.candidates.length, 2);
    },
  );

  test(
    'below the absolute threshold stays Not recognized even without a tie',
    () {
      final matcher = LandmarkMatcher.fromDecodedJson(
        _decoded(2, [
          ('alpha', [1.0, 0.0]),
        ]),
        scoreThreshold: 0.4,
        minTopMargin: 0.05,
      );
      // cosine ~0.30 < 0.40 absolute threshold.
      final result = matcher.match([0.3, 0.95393920]);
      expect(result.isRecognized, isFalse);
      expect(result.candidates, isEmpty);
    },
  );

  test('a lone candidate at or above the strong gate is accepted', () {
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
      ]),
      scoreThreshold: 0.4,
      minTopMargin: 0.07,
      strongMatchThreshold: 0.55,
    );
    // cosine 1.0 >= 0.55 strong gate.
    final result = matcher.match([1.0, 0.0]);
    expect(result.isRecognized, isTrue);
    expect(result.top!.landmarkId, 'alpha');
    expect(result.candidates.length, 1);
  });

  test(
    'lone weak match between floor and strong gate is rejected (0.40-0.55 hole)',
    () {
      final matcher = LandmarkMatcher.fromDecodedJson(
        _decoded(2, [
          ('alpha', [1.0, 0.0]),
        ]),
        scoreThreshold: 0.4,
        minTopMargin: 0.07,
        strongMatchThreshold: 0.55,
      );
      // Query chosen so cosine with [1,0] is ~0.4951 (the observed lone false
      // hit): above the 0.40 floor but below the 0.55 strong gate.
      const cos = 0.4951;
      final result = matcher.match([cos, 0.868819]);
      expect(result.top, isNull);
      expect(result.isRecognized, isFalse);
      expect(result.candidates, isEmpty);
    },
  );

  test('lone strong match in the real-photo band is accepted', () {
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
      ]),
      scoreThreshold: 0.4,
      minTopMargin: 0.07,
      strongMatchThreshold: 0.55,
    );
    // cosine ~0.60 with [1,0] — a dominant mid-band real-photo match.
    final result = matcher.match([0.60, 0.8]);
    expect(result.isRecognized, isTrue);
    expect(result.top!.landmarkId, 'alpha');
    expect(result.candidates.length, 1);
  });

  test('defaults use the measured threshold, margin and strong gate', () {
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
      ]),
    );
    expect(matcher.scoreThreshold, LandmarkMatcher.defaultScoreThreshold);
    expect(matcher.minTopMargin, LandmarkMatcher.defaultMinTopMargin);
    expect(
      matcher.strongMatchThreshold,
      LandmarkMatcher.defaultStrongMatchThreshold,
    );
    expect(LandmarkMatcher.defaultScoreThreshold, 0.40);
    expect(LandmarkMatcher.defaultMinTopMargin, 0.07);
    expect(LandmarkMatcher.defaultStrongMatchThreshold, 0.55);
  });

  test('returns a first-class Not-recognized result below threshold', () {
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
      ]),
      scoreThreshold: 0.55,
    );
    // Orthogonal query => cosine 0.0, below 0.55.
    final result = matcher.match([0.0, 1.0]);
    expect(result.isRecognized, isFalse);
    expect(result.candidates, isEmpty);
    expect(result.top, isNull);
  });

  test('throws FormatException when the query has the wrong length', () {
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
      ]),
    );
    expect(() => matcher.match([1.0]), throwsFormatException);
    expect(() => matcher.match([1.0, 0.0, 0.0]), throwsFormatException);
  });

  test('throws FormatException when the query has a non-finite value', () {
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
      ]),
    );
    expect(() => matcher.match([double.nan, 0.0]), throwsFormatException);
    expect(() => matcher.match([double.infinity, 0.0]), throwsFormatException);
  });

  test('rejects malformed decoded JSON', () {
    expect(
      () => LandmarkMatcher.fromDecodedJson(_decoded(0, [])),
      throwsFormatException,
    );
    expect(
      () => LandmarkMatcher.fromDecodedJson(<String, dynamic>{
        'dimension': 2,
        'references': <dynamic>[],
      }),
      throwsFormatException,
    );
    expect(
      () => LandmarkMatcher.fromDecodedJson(
        _decoded(2, [
          ('', [1.0, 0.0]),
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => LandmarkMatcher.fromDecodedJson(
        _decoded(2, [
          ('alpha', [1.0]),
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => LandmarkMatcher.fromDecodedJson(
        _decoded(2, [
          ('alpha', [double.nan, 0.0]),
        ]),
      ),
      throwsFormatException,
    );
  });

  test('fromJsonString parses a valid synthetic payload', () {
    final matcher = LandmarkMatcher.fromJsonString(
      jsonEncode(
        _decoded(2, [
          ('alpha', [1.0, 0.0]),
        ]),
      ),
      scoreThreshold: 0.0,
    );
    expect(matcher.dimension, 2);
    expect(matcher.match([1.0, 0.0]).top!.landmarkId, 'alpha');
  });

  test(
    'real asset: a stored reference vector self-matches its own landmark',
    () {
      final jsonString = File(
        'assets/landmarks/reference_embeddings.json',
      ).readAsStringSync();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final matcher = LandmarkMatcher.fromDecodedJson(decoded);

      expect(matcher.dimension, 512);

      final references = decoded['references'] as List<dynamic>;
      final firstReference = references.first as Map<String, dynamic>;
      final expectedLandmarkId = firstReference['landmark_id'] as String;
      final query = (firstReference['vector'] as List<dynamic>)
          .map((value) => (value as num).toDouble())
          .toList(growable: false);

      final result = matcher.match(query);
      expect(result.isRecognized, isTrue);
      expect(result.top!.landmarkId, expectedLandmarkId);
      // A unit vector dotted with itself is 1.0 (vectors are L2-normalized).
      expect(result.top!.score, closeTo(1.0, 1e-6));
    },
  );
}
