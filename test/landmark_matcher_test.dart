import 'dart:convert';
import 'dart:io';

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
    final matcher = LandmarkMatcher.fromDecodedJson(
      _decoded(2, [
        ('alpha', [1.0, 0.0]),
        ('beta', [0.9999, 0.0141]),
        ('gamma', [0.9998, 0.02]),
        ('delta', [0.9997, 0.0245]),
      ]),
      scoreThreshold: 0.0,
    );
    final result = matcher.match([1.0, 0.0]);
    expect(result.candidates.length, 3);
    final ids = result.candidates.map((c) => c.landmarkId).toSet();
    expect(ids.length, 3);
    expect(ids.contains('alpha'), isTrue);
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
