import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:tuntun/features/recognition/embedding_service.dart';

void main() {
  test('prepares normalized NCHW OpenCLIP input from RGB pixels', () {
    final photo = image.Image(width: 12, height: 8);
    for (var y = 0; y < photo.height; y++) {
      for (var x = 0; x < photo.width; x++) {
        photo.setPixelRgb(x, y, 128, 64, 255);
      }
    }
    final tensor = EmbeddingService.prepareImage(image.encodePng(photo));
    expect(tensor.length, 3 * 224 * 224);
    expect(tensor[0], closeTo((128 / 255 - 0.48145466) / 0.26862954, 1e-5));
    expect(
      tensor[224 * 224],
      closeTo((64 / 255 - 0.4578275) / 0.26130258, 1e-5),
    );
    expect(tensor[2 * 224 * 224], closeTo((1 - 0.40821073) / 0.27577711, 1e-5));
  });

  test('bakes JPEG EXIF orientation before OpenCLIP resize and crop', () {
    final photo = image.Image(width: 32, height: 16);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 32; x++) {
        photo.setPixelRgb(x, y, x < 16 ? 255 : 0, 0, x < 16 ? 0 : 255);
      }
    }
    photo.exif.imageIfd.orientation = 6;
    final tensor = EmbeddingService.prepareImage(
      image.encodeJpg(photo, quality: 100),
    );
    final red = tensor[50 * 224 + 112];
    final lowerRed = tensor[170 * 224 + 112];
    expect(red, greaterThan(lowerRed));
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
    ByteData.sublistView(encoded).setInt32(18, 16000001, Endian.little);
    expect(() => EmbeddingService.prepareImage(encoded), throwsFormatException);
  });

  test('normalizes finite output and rejects malformed model outputs', () {
    final vector = List<double>.filled(EmbeddingService.dimension, 0)
      ..[0] = 3
      ..[1] = 4;
    final normalized = EmbeddingService.normalizeEmbedding(
      vector,
      EmbeddingService.dimension,
    );
    expect(normalized[0], closeTo(0.6, 1e-12));
    expect(normalized[1], closeTo(0.8, 1e-12));
    expect(vector[0], 3);
    for (final invalid in [
      <double>[1],
      List<double>.filled(EmbeddingService.dimension, 0),
      List<double>.filled(EmbeddingService.dimension, double.nan),
      List<double>.filled(EmbeddingService.dimension, double.infinity),
    ]) {
      expect(
        () => EmbeddingService.normalizeEmbedding(
          invalid,
          EmbeddingService.dimension,
        ),
        throwsFormatException,
      );
    }
    final large = EmbeddingService.normalizeEmbedding(
      List<double>.filled(EmbeddingService.dimension, 1e308),
      EmbeddingService.dimension,
    );
    expect(large.first, closeTo(1 / 22.627416998, 1e-10));
  });
}
