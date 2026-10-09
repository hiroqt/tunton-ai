import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart';

/// One CPU interpreter for the approved MobileNetV3 Small image embedder.
class EmbeddingService {
  EmbeddingService._(this._interpreter);

  static const modelAsset = 'assets/models/landmark_embedder.tflite';
  static const inputSize = 224;
  static const dimension = 1024;
  final Interpreter _interpreter;
  bool _disposed = false;

  static Future<EmbeddingService> load() async {
    final interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: InterpreterOptions()..threads = 1,
    );
    try {
      final inputs = interpreter.getInputTensors();
      final outputs = interpreter.getOutputTensors();
      if (inputs.length != 1 ||
          outputs.length != 1 ||
          inputs.single.type != TensorType.float32 ||
          outputs.single.type != TensorType.float32 ||
          inputs.single.shape.join(',') != '1,224,224,3' ||
          outputs.single.shape.join(',') != '1,1024') {
        throw StateError('The bundled model has incompatible tensors.');
      }
      return EmbeddingService._(interpreter);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  /// Synchronous inference serializes calls on the owning Dart isolate.
  List<double> embed(Uint8List encodedImage) {
    if (_disposed) {
      throw StateError('Embedding service is disposed.');
    }
    final pixels = prepareImage(encodedImage);
    final output = [List<double>.filled(dimension, 0)];
    _interpreter.run(pixels.buffer.asUint8List(), output);
    return normalizeEmbedding(output.single);
  }

  /// Matches Python preparation: EXIF orientation, RGB, floor-index resize,
  /// and pixel / 255 (the approved checkpoint's mean 0 and std 255).
  static Float32List prepareImage(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Photo is empty or exceeds 20 MiB.');
    }
    late final image.Image decoded;
    try {
      final decoder = image.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        throw const FormatException('Photo cannot be decoded.');
      }
      if (info.width * info.height > 16 * 1000 * 1000) {
        throw const FormatException('Photo exceeds 16 megapixels.');
      }
      final frame = decoder!.decodeFrame(0);
      if (frame == null) {
        throw const FormatException('Photo cannot be decoded.');
      }
      decoded = frame;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Photo cannot be decoded.');
    }
    final rgb = image
        .bakeOrientation(decoded)
        .convert(format: image.Format.uint8, numChannels: 3);
    final pixels = Float32List(inputSize * inputSize * 3);
    var offset = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = rgb.getPixel(
          x * rgb.width ~/ inputSize,
          y * rgb.height ~/ inputSize,
        );
        pixels[offset++] = pixel.r / 255;
        pixels[offset++] = pixel.g / 255;
        pixels[offset++] = pixel.b / 255;
      }
    }
    return pixels;
  }

  static List<double> normalizeEmbedding(List<double> vector) {
    if (vector.length != dimension || vector.any((value) => !value.isFinite)) {
      throw const FormatException('Model returned an invalid embedding.');
    }
    final norm = math.sqrt(
      vector.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (!norm.isFinite || norm == 0) {
      throw const FormatException(
        'Model returned a zero or invalid embedding.',
      );
    }
    return vector.map((value) => value / norm).toList(growable: false);
  }

  void dispose() {
    if (!_disposed) {
      _interpreter.close();
      _disposed = true;
    }
  }
}
