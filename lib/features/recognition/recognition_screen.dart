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
  Landmark? _selected;

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
            'Choose the landmark in your photo, then confirm your destination.',
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
                final ids = <String>{};
                final candidates = (snapshot.data ?? [])
                    .where((place) => ids.add(place.id))
                    .take(3)
                    .toList();
                if (candidates.isEmpty) return _unavailable(unknown: true);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ranked suggestions',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < candidates.length; index++) ...[
                      _CandidateTile(
                        landmark: candidates[index],
                        rank: index + 1,
                        selected: _selected?.id == candidates[index].id,
                        onTap: () =>
                            setState(() => _selected = candidates[index]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _selected == null || widget.onConfirm == null
                          ? null
                          : () => widget.onConfirm!(_selected!),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Confirm destination'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Try another photo'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Suggestions are visual matches. Please confirm the place before continuing.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.landmark,
    required this.rank,
    required this.selected,
    required this.onTap,
  });
  final Landmark landmark;
  final int rank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rank',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(landmark.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Intramuros',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
