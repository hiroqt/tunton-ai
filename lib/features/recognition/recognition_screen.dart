import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../shared/models/landmark.dart';

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({
    super.key,
    required this.photoBytes,
    this.recognize,
    this.onConfirm,
  });
  final Uint8List photoBytes;
  final Future<List<Landmark>> Function()? recognize;
  final ValueChanged<Landmark>? onConfirm;

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  Future<List<Landmark>>? _matches;

  // Guards the automatic advance so onConfirm fires exactly once even as the
  // FutureBuilder rebuilds.
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    if (widget.recognize != null) _matches = Future.sync(widget.recognize!);
  }

  void _retry() => Navigator.of(context).pop();

  Widget _unavailable({bool unknown = false}) => JourneyMessage(
    icon: unknown
        ? Icons.image_not_supported_outlined
        : Icons.travel_explore_rounded,
    title: unknown ? 'Not recognized' : 'Recognition unavailable',
    message: unknown
        ? 'This photo did not match a supported landmark. Try a clearer view or another photo.'
        : 'Landmark recognition is not available on this build. You can go back and choose another photo.',
    action: FilledButton.icon(
      onPressed: _retry,
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('Try another photo'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TuntonScaffold(
      step: 1,
      backLabel: 'Your photo',
      onBack: _retry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Look familiar?', style: theme.textTheme.headlineLarge),
          ),
          const SizedBox(height: 12),
          Text(
            'Matching your photo on this device, then continuing automatically.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(
                widget.photoBytes,
                fit: BoxFit.cover,
                cacheWidth: 1024,
                semanticLabel: 'Photo being matched',
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Photo preview unavailable')),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_matches == null)
            _unavailable()
          else
            FutureBuilder<List<Landmark>>(
              future: _matches,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return JourneyMessage(
                    icon: Icons.travel_explore_rounded,
                    title: 'Finding the landmark…',
                    message: 'Matching your photo on this device.',
                    action: const LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError) return _unavailable();
                final matches = snapshot.data ?? const <Landmark>[];
                // The screen consumes ONLY the single accepted best match. An
                // empty list is a first-class "Not recognized" result; never
                // fabricate a match when there is no top candidate.
                if (matches.isEmpty) return _unavailable(unknown: true);
                final best = matches.first;
                // Automatically proceed with the single best match once the
                // frame settles — no candidate list, no manual Confirm.
                if (!_advanced && widget.onConfirm != null) {
                  _advanced = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) widget.onConfirm!(best);
                  });
                }
                return _AutoMatchCard(landmark: best, onRetry: _retry);
              },
            ),
        ],
      ),
    );
  }
}

/// Non-blocking card naming the landmark that was auto-selected. It does NOT
/// gate the flow (the automatic advance has already fired); it keeps the user
/// informed and keeps the honesty disclaimer visible, with a retry affordance.
class _AutoMatchCard extends StatelessWidget {
  const _AutoMatchCard({required this.landmark, required this.onRetry});
  final Landmark landmark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final area =
        landmark.areaId[0].toUpperCase() + landmark.areaId.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Match found', style: theme.textTheme.labelMedium),
        ),
        const SizedBox(height: 12),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.primary, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(landmark.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        area,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Try another photo'),
        ),
        const SizedBox(height: 16),
        Text(
          'Suggestions are visual matches. Please verify the place before continuing.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
