import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app.dart';
import '../../shared/models/landmark.dart';
import '../../shared/models/route_result.dart';
import '../recognition/recognition_screen.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({
    super.key,
    this.pickPhoto,
    this.recognizePhoto,
    this.startPoints = const [],
    this.calculateRoute,
    this.findNearestNode,
  });

  final Future<Uint8List?> Function(ImageSource source)? pickPhoto;
  final Future<List<Landmark>> Function(Uint8List photo)? recognizePhoto;
  final List<Landmark> startPoints;
  final Future<RouteResult> Function(Landmark origin, Landmark destination)?
  calculateRoute;
  final (String, (double, double)) Function(double lat, double lon)?
  findNearestNode;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final _picker = ImagePicker();
  Uint8List? _photo;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.pickPhoto == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _recoverPhoto();
    }
  }

  Future<void> _recoverPhoto() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.files?.isNotEmpty ?? false) {
        await _accept(await response.files!.first.readAsBytes());
      } else if (response.exception != null && mounted) {
        setState(
          () => _error = 'Your previous photo could not be recovered. Please choose it again.',
        );
      }
    } on MissingPluginException {
      // There is no native picker in widget tests; selection errors stay visible.
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your previous photo could not be opened. Choose another photo.',
        );
      }
    }
  }

  Future<void> _accept(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1024,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    if (mounted) {
      setState(() {
        _photo = bytes;
        _error = null;
      });
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Uint8List? bytes;
      if (widget.pickPhoto != null) {
        bytes = await widget.pickPhoto!(source);
      } else {
        final file = await _picker.pickImage(source: source);
        bytes = await file?.readAsBytes();
      }
      if (bytes != null) await _accept(bytes);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code.contains('denied')
              ? 'Photo access is turned off. Allow access in your phone settings, or try the other photo option.'
              : 'We could not open ${source == ImageSource.camera ? 'the camera' : 'your gallery'}. Try the other photo option.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'That photo could not be opened. Choose another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _recognize() {
    final photo = _photo!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RecognitionScreen(
          photoBytes: photo,
          recognize: widget.recognizePhoto == null
              ? null
              : () => widget.recognizePhoto!(photo),
          onConfirm: _confirmDestination,
        ),
      ),
    );
  }

  void _confirmDestination(Landmark destination) {
    Navigator.of(context).pop();
    Navigator.of(context).pop(destination);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return TuntonScaffold(
      step: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, color: colors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'Intramuros',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              _photo == null
                  ? 'YOUR NEXT STOP,\nONE PHOTO AWAY.'
                  : 'A PICTURE BECOMES\nA PLACE.',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _photo == null
                ? 'SNAP A LANDMARK. FIND YOUR WAY THROUGH THE WALLED CITY.'
                : 'CHECK THAT THE LANDMARK IS CLEAR BEFORE FINDING A MATCH.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 24),
          _PhotoPreview(photo: _photo),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _error!.toUpperCase(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_busy) ...[
            Semantics(
              liveRegion: true,
              child: const Text('OPENING YOUR PHOTO…'),
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (_photo != null) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _recognize,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('FIND THE LANDMARK'),
            ),
            const SizedBox(height: 12),
          ],
          if (_photo == null) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('TAKE A PHOTO'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _photo == null ? 'CHOOSE FROM GALLERY' : 'CHOOSE ANOTHER PHOTO',
            ),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('TAKE A NEW PHOTO'),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Photos stay on your device',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo});
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.onSurface, width: 4),
        boxShadow: [
          BoxShadow(color: colors.onSurface, offset: const Offset(6, 6)),
        ],
      ),
      child: photo != null
          ? AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(
                photo!,
                fit: BoxFit.cover,
                cacheWidth: 1024,
                semanticLabel: 'Selected landmark photo',
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('PHOTO PREVIEW UNAVAILABLE')),
              ),
            )
          : Container(
              constraints: const BoxConstraints(minHeight: 220),
              color: colors.surfaceContainerLow,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.crop_free_rounded,
                      size: 64,
                      color: colors.onSurface,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FRAME A LANDMARK',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'USE A CLEAR VIEW OF THE BUILDING.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
