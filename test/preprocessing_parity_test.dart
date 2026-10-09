import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuntun/features/recognition/embedding_service.dart';

void main() {
  test('Dart tensor stays close to the tagged OpenCLIP transform', () {
    final parity =
        jsonDecode(File('test/datasets/parity.json').readAsStringSync())
            as Map<String, dynamic>;
    final pixels = EmbeddingService.prepareImage(
      File(parity['image_path'] as String).readAsBytesSync(),
    );
    final expectedBytes = File(
      'test/datasets/parity_input.bin',
    ).readAsBytesSync();
    final expected = Float32List.view(
      expectedBytes.buffer,
      expectedBytes.offsetInBytes,
      expectedBytes.lengthInBytes ~/ 4,
    );
    expect(pixels.length, 3 * 224 * 224);
    expect(expected.length, pixels.length);
    var maximumDifference = 0.0;
    var squaredError = 0.0;
    for (var i = 0; i < pixels.length; i++) {
      final difference = (pixels[i] - expected[i]).abs();
      if (difference > maximumDifference) maximumDifference = difference;
      squaredError += difference * difference;
    }
    final rmse = math.sqrt(squaredError / pixels.length);
    // Integer RGB resize may differ by at most one 8-bit level from Pillow.
    expect(maximumDifference, lessThan(3.8));
    expect(rmse, lessThan(0.2));
  });
}
