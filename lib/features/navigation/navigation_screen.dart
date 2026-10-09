import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
    this.positionStream,
  });
  final Landmark destination;
  final Landmark origin;
  final Future<RouteResult> Function()? calculateRoute;
  final Stream<Position>? positionStream;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Future<RouteResult>? _route;
  StreamSubscription<Position>? _positionSub;
  LatLng? _liveUserLocation;

  @override
  void initState() {
    super.initState();
    if (widget.calculateRoute != null) {
      _route = Future.sync(widget.calculateRoute!);
    }
    _startLiveTracking();
  }

  void _startLiveTracking() {
    if (widget.origin.id == 'user-current-location') {
      _liveUserLocation = LatLng(widget.origin.lat, widget.origin.lon);
    }
    if (widget.positionStream != null) {
      _positionSub = widget.positionStream!.listen(
        (pos) {
          if (mounted) {
            setState(() {
              _liveUserLocation = LatLng(pos.latitude, pos.longitude);
            });
          }
        },
        onError: (_) {},
      );
      return;
    }
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _positionSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2,
          ),
        ).listen(
          (pos) {
            if (mounted) {
              setState(() {
                _liveUserLocation = LatLng(pos.latitude, pos.longitude);
              });
            }
          },
          onError: (_) {},
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _changeStart() => Navigator.of(context).pop();

  Widget _unavailable([RouteResult? result]) => JourneyMessage(
    icon: Icons.route_outlined,
    title: 'ROUTE UNAVAILABLE',
    message: result?.unavailableReason?.toUpperCase() ?? 'WALKING ROUTES ARE NOT AVAILABLE ON THIS BUILD. GO BACK AND CHOOSE ANOTHER START.',
    action: FilledButton.icon(
      onPressed: _changeStart,
      icon: const Icon(Icons.place_outlined),
      label: const Text('CHOOSE ANOTHER START'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TuntonScaffold(
      step: 3,
      backLabel: 'CHANGE START',
      onBack: _changeStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'YOUR WALKING ROUTE',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A WALKING PREVIEW THROUGH INTRAMUROS.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
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
                    title: 'FINDING A WALKING PATH…',
                    message: 'CHECKING THE PATHS STORED ON THIS DEVICE.',
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
                    ? '${distance.round()} M'
                    : '${(distance / 1000).toStringAsFixed(1)} KM';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OfflineLandmarkMap(
                      destination: widget.destination,
                      origin: widget.origin,
                      route: result,
                      userLocation: _liveUserLocation,
                    ),
                    const SizedBox(height: 24),
                    _Endpoint(
                      label: widget.origin.id == 'user-current-location'
                          ? 'Starting location'
                          : 'Manual start',
                      place: widget.origin.name,
                      icon: widget.origin.id == 'user-current-location'
                          ? Icons.my_location_rounded
                          : Icons.trip_origin_rounded,
                    ),
                    const SizedBox(height: 16),
                    _Endpoint(
                      label: 'DESTINATION',
                      place: widget.destination.name.toUpperCase(),
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
                            color: theme.colorScheme.onSurface,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.onSurface,
                              offset: const Offset(6, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
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
                            if (_liveUserLocation != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.gps_fixed_rounded,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Live GPS position streaming',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'WALKING ESTIMATE AT 4.5 KM/H. GATES AND ACCESS MAY CHANGE.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _changeStart,
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('CHOOSE ANOTHER START'),
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
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              place,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
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
      Text(
        value,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    ],
  );
}
