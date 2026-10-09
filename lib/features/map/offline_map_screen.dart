import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app.dart';
import '../../shared/models/landmark.dart';
import '../../shared/models/route_result.dart';
import 'landmark_markers.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({
    super.key,
    required this.destination,
    this.startPoints = const [],
    required this.onStartConfirmed,
    this.loadZooms,
    this.findNearestNode,
    this.getCurrentPosition,
  });
  final Landmark destination;

  /// Only catalog points whose route nodes have been verified by the data layer.
  final List<Landmark> startPoints;
  final ValueChanged<Landmark> onStartConfirmed;
  final Future<List<int>> Function()? loadZooms;
  final (String, (double, double)) Function(double lat, double lon)?
  findNearestNode;
  final Future<Position?> Function()? getCurrentPosition;

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  Landmark? _start;
  LatLng? _userLocation;
  bool _locatingGps = false;

  @override
  void initState() {
    super.initState();
    _checkInitialLocation();
  }

  Future<void> _checkInitialLocation() async {
    try {
      if (widget.getCurrentPosition != null) {
        final pos = await widget.getCurrentPosition!();
        if (pos != null && mounted) {
          setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
        }
        return;
      }
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null && mounted) {
          setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
        }
      }
    } catch (_) {}
  }

  Future<void> _useCurrentLocation() async {
    if (_locatingGps) return;
    setState(() => _locatingGps = true);
    try {
      Position? position;
      if (widget.getCurrentPosition != null) {
        position = await widget.getCurrentPosition!();
      } else {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location services are turned off. Please turn on GPS in phone settings.',
                ),
              ),
            );
          }
          return;
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Location permission was denied. You can select a start landmark manually.',
                  ),
                ),
              );
            }
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission is permanently denied. You can select a start landmark manually.',
                ),
              ),
            );
          }
          return;
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      }

      if (position != null && mounted) {
        final lat = position.latitude;
        final lon = position.longitude;
        final latLng = LatLng(lat, lon);

        String? snappedNodeId;
        if (widget.findNearestNode != null) {
          final (nodeId, _) = widget.findNearestNode!(lat, lon);
          snappedNodeId = nodeId;
        } else {
          for (final point in widget.startPoints) {
            final routeNodeId = point.routeNodeId;
            if (routeNodeId != null && routeNodeId.isNotEmpty) {
              snappedNodeId = routeNodeId;
              break;
            }
          }
        }

        if (snappedNodeId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No graph-backed walking path is available. Choose a mapped start manually.',
              ),
            ),
          );
          return;
        }

        final userStart = Landmark(
          id: 'user-current-location',
          name: 'Your Location (GPS)',
          latitude: lat,
          longitude: lon,
          routeNodeId: snappedNodeId,
        );

        setState(() {
          _userLocation = latLng;
          _start = userStart;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GPS start snapped to the nearest graph node.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not obtain GPS fix. You can select a start landmark manually.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  Future<void> _chooseStart(List<Landmark> places) async {
    final selected = await showModalBottomSheet<Landmark>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose your start',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                title: const Text('Use current location (GPS)'),
                subtitle: const Text(
                  'Snaps to a graph node; connector may not be walkable.',
                ),
                leading: Icon(
                  Icons.my_location_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _useCurrentLocation();
                },
              ),
              const Divider(indent: 24, endIndent: 24),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final place in places)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        title: Text(place.name),
                        leading: Icon(
                          _start?.id == place.id
                              ? Icons.check_circle_rounded
                              : Icons.place_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onTap: () => Navigator.of(context).pop(place),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _start = selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ids = <String>{};
    final starts = widget.startPoints
        .where((place) => place.hasValidLocation && ids.add(place.id))
        .toList();
    return TuntonScaffold(
      step: 2,
      backLabel: 'Your destination',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Where will you start?',
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose where your walk begins using GPS or a landmark.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          OfflineLandmarkMap(
            destination: widget.destination,
            origin: _start,
            userLocation: _userLocation,
            loadZooms: widget.loadZooms,
          ),
          const SizedBox(height: 24),
          Text(
            'DESTINATION',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.destination.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          Text('Starting point', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _locatingGps ? null : _useCurrentLocation,
            icon: _locatingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(
              _locatingGps
                  ? 'Finding GPS location…'
                  : _start?.id == 'user-current-location'
                  ? 'Location set: Your Location'
                  : 'Use current location (GPS)',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: starts.isEmpty ? null : () => _chooseStart(starts),
            icon: const Icon(Icons.place_outlined),
            label: Text(
              _start != null && _start!.id != 'user-current-location'
                  ? _start!.name
                  : 'Choose starting point',
            ),
          ),
          const SizedBox(height: 12),
          if (starts.isEmpty) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'Start points unavailable. Go back and try another destination.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: _start == null
                ? null
                : () => widget.onStartConfirmed(_start!),
            icon: const Icon(Icons.directions_walk_rounded),
            label: const Text('Preview walking route'),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a supported start to continue.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays only bundled raster tiles and supplied catalog/graph geometry.
class OfflineLandmarkMap extends StatefulWidget {
  const OfflineLandmarkMap({
    super.key,
    required this.destination,
    this.origin,
    this.route,
    this.userLocation,
    this.loadZooms,
  });
  final Landmark destination;
  final Landmark? origin;
  final RouteResult? route;
  final LatLng? userLocation;
  final Future<List<int>> Function()? loadZooms;

  @override
  State<OfflineLandmarkMap> createState() => _OfflineLandmarkMapState();
}

class _OfflineLandmarkMapState extends State<OfflineLandmarkMap> {
  late final Future<List<int>> _zooms = widget.loadZooms != null
      ? widget.loadZooms!()
      : _loadZooms();
  bool _tileError = false;

  Future<List<int>> _loadZooms() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final zooms =
        manifest
            .listAssets()
            .where(
              (path) =>
                  RegExp(r'^assets/tiles/\d+/\d+/\d+\.png$').hasMatch(path),
            )
            .map((path) => int.parse(path.split('/')[2]))
            .toSet()
            .toList()
          ..sort();
    return zooms;
  }

  void _onTileError(TileImage _, Object _, StackTrace? _) {
    if (_tileError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.destination.hasValidLocation ||
        (widget.origin != null && !widget.origin!.hasValidLocation)) {
      return const JourneyMessage(
        icon: Icons.place_outlined,
        title: 'Location unavailable',
        message:
            'This location could not be loaded. Go back and choose another destination.',
      );
    }
    return FutureBuilder<List<int>>(
      future: _zooms,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const JourneyMessage(
            icon: Icons.map_outlined,
            title: 'Opening the offline map…',
            message: 'Loading map data from this device.',
            action: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError ||
            (snapshot.data?.isEmpty ?? true) ||
            _tileError) {
          return const JourneyMessage(
            icon: Icons.map_outlined,
            title: 'Offline map unavailable',
            message:
                'The map for this area could not be loaded. Go back and try another destination.',
          );
        }
        final zooms = snapshot.data!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 300,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: widget.destination.position,
                    initialZoom: zooms.contains(17)
                        ? 17
                        : zooms.first.toDouble(),
                    minZoom: zooms.first.toDouble(),
                    maxZoom: zooms.last.toDouble(),
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'assets/tiles/{z}/{x}/{y}.png',
                      tileProvider: AssetTileProvider(),
                      errorTileCallback: _onTileError,
                      minZoom: zooms.first.toDouble(),
                      maxZoom: zooms.last.toDouble(),
                      maxNativeZoom: zooms.last,
                    ),
                    if ((widget.route?.points.length ?? 0) >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: widget.route!.points,
                            color: theme.colorScheme.primary,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        ...landmarkMarkers(
                          landmarks: [
                            widget.destination,
                            if (widget.origin != null &&
                                widget.origin!.id != widget.destination.id)
                              widget.origin!,
                          ],
                          destinationId: widget.destination.id,
                          startId: widget.origin?.id,
                          colors: theme.colorScheme,
                        ),
                        if (widget.userLocation != null)
                          userLocationMarker(
                            point: widget.userLocation!,
                            colors: theme.colorScheme,
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  left: 8,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      color: theme.colorScheme.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
