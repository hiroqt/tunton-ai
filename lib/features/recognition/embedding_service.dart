import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;

/// Prepares one OpenCLIP ViT-B/32 input and calls native Android ONNX Runtime.
class EmbeddingService {
  EmbeddingService._(this._dimension, this.modelSha256);

  static const manifestAsset =
      'assets/models/openclip_vit_b32_laion2b_int8.manifest.json';
  static const modelId = 'openclip-vit-b32-laion2b-s34b-b79k-int8-dynamic';
  static const preprocessingVersion = 'openclip-vit-b32-v1';
  static const dimension = 512;
  static const inputSize = 224;
  static const _area = inputSize * inputSize;
  static const _mean = [0.48145466, 0.4578275, 0.40821073];
  static const _std = [0.26862954, 0.26130258, 0.27577711];
  static const _channel = MethodChannel('com.tunton/vision');

  final int _dimension;
  final String modelSha256;
  bool _disposed = false;

  static Future<EmbeddingService> load() async {
    final decoded = jsonDecode(await rootBundle.loadString(manifestAsset));
    if (decoded is! Map<String, dynamic> ||
        decoded['model_id'] != modelId ||
        decoded['input_shape'] is! List ||
        (decoded['input_shape'] as List).join(',') != '1,3,224,224' ||
        decoded['dimension'] != dimension ||
        decoded['preprocessing_version'] != preprocessingVersion ||
        decoded['model_sha256'] is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(decoded['model_sha256'] as String)) {
      throw const FormatException('The OpenCLIP model manifest is invalid.');
    }
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'initialize',
      {'sha256': decoded['model_sha256'], 'dimension': dimension},
    );
    if (result?['dimension'] != dimension) {
      throw StateError('The Android model output dimension is incompatible.');
    }
    return EmbeddingService._(dimension, decoded['model_sha256'] as String);
  }

  Future<List<double>> embed(Uint8List encodedImage) async {
    if (_disposed) throw StateError('Embedding service is disposed.');
    final preprocessing = Stopwatch()..start();
    final tensor = prepareImage(encodedImage);
    preprocessing.stop();
    final inference = Stopwatch()..start();
    final raw = await _channel.invokeListMethod<num>('embed', {
      'tensor': tensor,
    });
    inference.stop();
    if (raw == null) {
      throw const FormatException('Android returned no image embedding.');
    }
    final embedding = normalizeEmbedding(raw, _dimension);
    if (kDebugMode) {
      debugPrint(
        '[TUNTON_RECOG] preprocess_ms=${preprocessing.elapsedMilliseconds} '
        'inference_ms=${inference.elapsedMilliseconds} '
        'embedding_dim=${embedding.length}',
      );
    }
    return embedding;
  }

  /// OpenCLIP resize-shortest-edge, bicubic, center-crop, RGB and normalization.
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
      decoded = image
          .bakeOrientation(frame)
          .convert(format: image.Format.uint8, numChannels: 3);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Photo cannot be decoded.');
    }

    final width = decoded.width < decoded.height
        ? inputSize
        : (decoded.width * inputSize / decoded.height).floor();
    final height = decoded.height < decoded.width
        ? inputSize
        : (decoded.height * inputSize / decoded.width).floor();
    final resized = _resizeBicubic(decoded, width, height);
    final cropped = image.copyCrop(
      resized,
      x: ((width - inputSize) / 2).round(),
      y: ((height - inputSize) / 2).round(),
      width: inputSize,
      height: inputSize,
    );
    final tensor = Float32List(3 * _area);
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = cropped.getPixel(x, y);
        final offset = y * inputSize + x;
        tensor[offset] = (pixel.r / 255 - _mean[0]) / _std[0];
        tensor[_area + offset] = (pixel.g / 255 - _mean[1]) / _std[1];
        tensor[2 * _area + offset] = (pixel.b / 255 - _mean[2]) / _std[2];
      }
    }
    return tensor;
  }

  static image.Image _resizeBicubic(image.Image source, int width, int height) {
    final xWeights = _bicubicWeights(source.width, width);
    final yWeights = _bicubicWeights(source.height, height);
    final horizontal = Uint8List(width * source.height * 3);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < width; x++) {
        final weights = xWeights[x];
        var red = 0.0, green = 0.0, blue = 0.0;
        for (var i = 0; i < weights.length; i++) {
          final pixel = source.getPixel(weights[i].$1, y);
          red += pixel.r * weights[i].$2;
          green += pixel.g * weights[i].$2;
          blue += pixel.b * weights[i].$2;
        }
        final index = (y * width + x) * 3;
        horizontal[index] = red.round().clamp(0, 255).toInt();
        horizontal[index + 1] = green.round().clamp(0, 255).toInt();
        horizontal[index + 2] = blue.round().clamp(0, 255).toInt();
      }
    }
    final resized = image.Image(width: width, height: height, numChannels: 3);
    for (var y = 0; y < height; y++) {
      final weights = yWeights[y];
      for (var x = 0; x < width; x++) {
        var red = 0.0, green = 0.0, blue = 0.0;
        for (var i = 0; i < weights.length; i++) {
          final index = (weights[i].$1 * width + x) * 3;
          red += horizontal[index] * weights[i].$2;
          green += horizontal[index + 1] * weights[i].$2;
          blue += horizontal[index + 2] * weights[i].$2;
        }
        resized.setPixelRgb(x, y, red.round(), green.round(), blue.round());
      }
    }
    return resized;
  }

  static List<List<(int, double)>> _bicubicWeights(int input, int output) {
    final scale = input / output;
    final filterScale = math.max(1.0, scale);
    final support = 2 * filterScale;
    return List.generate(output, (position) {
      final center = (position + 0.5) * scale;
      final first = math.max(0, (center - support + 0.5).floor()).toInt();
      final end = math.min(input, (center + support + 0.5).floor()).toInt();
      final samples = <(int, double)>[];
      var sum = 0.0;
      for (var index = first; index < end; index++) {
        final distance = ((index + 0.5 - center) / filterScale).abs();
        final weight = distance < 1
            ? ((1.5 * distance - 2.5) * distance * distance) + 1
            : distance < 2
            ? (((-0.5 * distance + 2.5) * distance - 4) * distance) + 2
            : 0.0;
        samples.add((index, weight));
        sum += weight;
      }
      return samples.map((sample) => (sample.$1, sample.$2 / sum)).toList();
    });
  }

  static List<double> normalizeEmbedding(List<num> vector, int expectedSize) {
    if (vector.length != expectedSize || vector.any((v) => !v.isFinite)) {
      throw const FormatException('Model returned an invalid embedding.');
    }
    final values = vector.map((v) => v.toDouble()).toList(growable: false);
    final scale = values.fold<double>(
      0,
      (max, value) => math.max(max, value.abs()),
    );
    if (!scale.isFinite || scale == 0) {
      throw const FormatException(
        'Model returned a zero or invalid embedding.',
      );
    }
    final norm = math.sqrt(
      values.fold<double>(0, (sum, value) {
        final scaled = value / scale;
        return sum + scaled * scaled;
      }),
    );
    if (!norm.isFinite || norm == 0) {
      throw const FormatException(
        'Model returned a zero or invalid embedding.',
      );
    }
    return values
        .map((value) => (value / scale) / norm)
        .toList(growable: false);
  }

  void dispose() => _disposed = true;
}
