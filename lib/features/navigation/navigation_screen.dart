import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../shared/models/landmark.dart';
import '../../shared/models/route_result.dart';
import '../map/offline_map_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.destination,
    required this.origin,
    this.calculateRoute,
  });
  final Landmark destination;
  final Landmark origin;
  final Future<RouteResult> Function()? calculateRoute;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Future<RouteResult>? _route;

  @override
  void initState() {
    super.initState();
    if (widget.calculateRoute != null) {
      _route = Future.sync(widget.calculateRoute!);
    }
  }

  void _changeStart() => Navigator.of(context).pop();

  Widget _unavailable([RouteResult? result]) => JourneyMessage(
    icon: Icons.route_outlined,
    title: 'Route unavailable',
    message: result?.unavailableReason ?? 'Walking routes are not available on this build. Go back and choose another start.',
    action: FilledButton.icon(
      onPressed: _changeStart,
      icon: const Icon(Icons.place_outlined),
      label: const Text('Choose another start'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TuntonScaffold(
      step: 3,
      backLabel: 'Change start',
      onBack: _changeStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Your walking route',
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A walking preview through Intramuros.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_route == null)
            _unavailable()
          else
            FutureBuilder<RouteResult>(
              future: _route,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const JourneyMessage(
                    icon: Icons.route_outlined,
                    title: 'Finding a walking path…',
                    message: 'Checking the paths stored on this device.',
                    action: LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return _unavailable();
                }
                final result = snapshot.data!;
                if (!result.isAvailable) return _unavailable(result);
                final distance = result.distanceMeters;
                final distanceLabel = distance < 1000
                    ? '${distance.round()} m'
                    : '${(distance / 1000).toStringAsFixed(1)} km';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OfflineLandmarkMap(
                      destination: widget.destination,
                      origin: widget.origin,
                      route: result,
                    ),
                    const SizedBox(height: 24),
                    _Endpoint(
                      label: 'Manual start',
                      place: widget.origin.name,
                      icon: Icons.trip_origin_rounded,
                    ),
                    const SizedBox(height: 16),
                    _Endpoint(
                      label: 'Destination',
                      place: widget.destination.name,
                      icon: Icons.flag_outlined,
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Wrap(
                          spacing: 32,
                          runSpacing: 20,
                          children: [
                            _RouteMetric(
                              value: distanceLabel,
                              label: 'Walking distance',
                            ),
                            _RouteMetric(
                              value: '${result.estimatedMinutes!.ceil()} min',
                              label: 'Estimated time',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Walking estimate at 4.5 km/h. Gates and access may change.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _changeStart,
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('Choose another start'),
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

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.place,
    required this.icon,
  });
  final String label;
  final String place;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(place, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ],
  );
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}
