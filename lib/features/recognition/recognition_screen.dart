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
    title: unknown ? 'NOT RECOGNIZED' : 'RECOGNITION UNAVAILABLE',
    message: unknown
        ? 'THIS PHOTO DID NOT MATCH A SUPPORTED LANDMARK. TRY A CLEARER VIEW OR ANOTHER PHOTO.'
        : 'LANDMARK RECOGNITION IS NOT AVAILABLE ON THIS BUILD. YOU CAN GO BACK AND CHOOSE ANOTHER PHOTO.',
    action: FilledButton.icon(
      onPressed: _retry,
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('TRY ANOTHER PHOTO'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TuntonScaffold(
      step: 1,
      backLabel: 'YOUR PHOTO',
      onBack: _retry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'LOOK FAMILIAR?',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CHOOSE THE LANDMARK IN YOUR PHOTO, THEN CONFIRM YOUR DESTINATION.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.onSurface, width: 4),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.onSurface,
                  offset: const Offset(6, 6),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(
                widget.photoBytes,
                fit: BoxFit.cover,
                cacheWidth: 1024,
                semanticLabel: 'Photo being matched',
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('PHOTO PREVIEW UNAVAILABLE')),
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
                    title: 'FINDING THE LANDMARK…',
                    message: 'MATCHING YOUR PHOTO ON THIS DEVICE.',
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
                      'RANKED SUGGESTIONS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
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
                      label: const Text('CONFIRM DESTINATION'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('TRY ANOTHER PHOTO'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SUGGESTIONS ARE VISUAL MATCHES. PLEASE CONFIRM THE PLACE BEFORE CONTINUING.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
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
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: selected ? colors.primary : colors.onSurface,
            width: selected ? 4 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? colors.primary : colors.onSurface,
              offset: const Offset(4, 4),
            ),
          ],
        ),
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
                      color: selected ? colors.primary : colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        landmark.name.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'INTRAMUROS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
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
