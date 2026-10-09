import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:tuntun/features/recognition/embedding_service.dart';

void main() {
  test('RGB values and floor-index resize match preparation contract', () {
    final photo = image.Image(width: 3, height: 2);
    photo.setPixelRgb(0, 0, 255, 0, 0);
    photo.setPixelRgb(1, 0, 0, 255, 0);
    photo.setPixelRgb(2, 0, 0, 0, 255);
    photo.setPixelRgb(0, 1, 0, 127, 255);
    photo.setPixelRgb(1, 1, 255, 255, 0);
    photo.setPixelRgb(2, 1, 255, 0, 255);
    final pixels = EmbeddingService.prepareImage(image.encodePng(photo));
    expect(pixels.length, 224 * 224 * 3);
    expect(pixels.sublist(0, 3), [1, 0, 0]);
    expect(pixels.sublist(74 * 3, 74 * 3 + 3), [1, 0, 0]);
    expect(pixels.sublist(75 * 3, 75 * 3 + 3), [0, 1, 0]);
    final secondRow = 112 * 224 * 3;
    expect(pixels[secondRow], 0);
    expect(pixels[secondRow + 1], closeTo(127 / 255, 1e-7));
    expect(pixels[secondRow + 2], 1);
    expect(pixels.sublist(pixels.length - 3), [1, 0, 1]);
  });

  test('bakes JPEG EXIF orientation before resizing', () {
    final photo = image.Image(width: 32, height: 16);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 32; x++) {
        photo.setPixelRgb(x, y, x < 16 ? 255 : 0, 0, x < 16 ? 0 : 255);
      }
    }
    photo.exif.imageIfd.orientation = 6;
    final pixels = EmbeddingService.prepareImage(
      image.encodeJpg(photo, quality: 100),
    );
    final top = (20 * 224 + 112) * 3;
    final bottom = (200 * 224 + 112) * 3;
    expect(pixels[top], greaterThan(0.95));
    expect(pixels[top + 2], lessThan(0.05));
    expect(pixels[bottom], lessThan(0.05));
    expect(pixels[bottom + 2], greaterThan(0.95));
  });

  test('rejects empty, corrupt, oversized and excessive dimension inputs', () {
    expect(
      () => EmbeddingService.prepareImage(Uint8List(0)),
      throwsFormatException,
    );
    expect(
      () => EmbeddingService.prepareImage(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => EmbeddingService.prepareImage(Uint8List(20 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    final photo = image.Image(width: 1, height: 1);
    final encoded = image.encodeBmp(photo);
    // BMP dimensions are available before allocating the decoded pixel array.
    ByteData.sublistView(encoded).setInt32(18, 16000001, Endian.little);
    expect(() => EmbeddingService.prepareImage(encoded), throwsFormatException);
  });

  test('normalizes finite output and rejects malformed model outputs', () {
    final vector = List<double>.filled(1024, 0)
      ..[0] = 3
      ..[1] = 4;
    final normalized = EmbeddingService.normalizeEmbedding(vector);
    expect(normalized[0], closeTo(0.6, 1e-12));
    expect(normalized[1], closeTo(0.8, 1e-12));
    expect(vector[0], 3);
    for (final invalid in [
      <double>[1],
      List<double>.filled(1024, 0),
      List<double>.filled(1024, double.nan),
      List<double>.filled(1024, double.infinity),
      List<double>.filled(1024, 1e308),
    ]) {
      expect(
        () => EmbeddingService.normalizeEmbedding(invalid),
        throwsFormatException,
      );
    }
  });
}
