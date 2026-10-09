import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuntun/features/recognition/embedding_service.dart';

void main() {
  test('Dart preprocessing matches real PNG Python tensor bytes', () {
    final parity =
        jsonDecode(File('test/datasets/parity.json').readAsStringSync())
            as Map<String, dynamic>;
    final imagePath = parity['image_path'] as String;
    expect(imagePath.endsWith('.png'), isTrue);
    final pixels = EmbeddingService.prepareImage(
      File(imagePath).readAsBytesSync(),
    );
    final expected = File('test/datasets/parity_input.bin').readAsBytesSync();
    final actual = pixels.buffer.asUint8List();
    expect(actual.length, 224 * 224 * 3 * 4);
    expect(expected.length, actual.length);
    expect(
      listEquals(actual, expected),
      isTrue,
      reason:
          'Python and Dart RGB/resize/scale must produce identical float32 bytes. '
          'This comparison does not run Android inference.',
    );
  });
}
