import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'app/app.dart';
import 'features/map/offline_map_screen.dart';
import 'features/navigation/navigation_screen.dart';
import 'features/navigation/routing_service.dart';
import 'features/camera/photo_screen.dart';
import 'features/recognition/embedding_service.dart';
import 'features/recognition/landmark_matcher.dart';
import 'shared/models/landmark.dart';
import 'shared/models/route_result.dart';

const _landmarksAsset = 'assets/landmarks/landmarks.json';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/Inter-LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });
  runApp(TuntonApp(home: _BackendGate(backend: _LocalBackend.load())));
}

class _LocalBackend {
  _LocalBackend(this.embedding, this.matcher, this.landmarks, this.routing);

  final EmbeddingService embedding;
  final LandmarkMatcher matcher;
  final List<Landmark> landmarks;
  final RoutingService routing;

  static Future<_LocalBackend> load() async {
    final embedding = await EmbeddingService.load();
    try {
      final matcher = await LandmarkMatcher.load();
      if (matcher.dimension != EmbeddingService.dimension) {
        throw StateError(
          'The model and reference embedding sizes do not match.',
        );
      }
      final landmarks = Landmark.listFromJsonString(
        await rootBundle.loadString(_landmarksAsset),
      );
      final routing = await RoutingService.load();
      final landmarksById = {
        for (final landmark in landmarks) landmark.id: landmark,
      };
      final missingReferences = matcher.landmarkIds
          .where((id) => !landmarksById.containsKey(id))
          .toList(growable: false);
      final unrouteableLandmarks = landmarks.where(
        (landmark) =>
            !landmark.hasValidLocation ||
            !routing.hasNode(landmark.routeNodeId),
      );
      if (missingReferences.isNotEmpty || unrouteableLandmarks.isNotEmpty) {
        throw FormatException(
          'The landmark catalog, embeddings, and walking graph do not match.',
        );
      }
      return _LocalBackend(embedding, matcher, landmarks, routing);
    } catch (_) {
      embedding.dispose();
      rethrow;
    }
  }

  List<Landmark> recognize(Uint8List photo) {
    final byId = {for (final landmark in landmarks) landmark.id: landmark};
    return matcher
        .match(embedding.embed(photo))
        .candidates
        .map((candidate) => byId[candidate.landmarkId]!)
        .toList(growable: false);
  }
}

class _BackendGate extends StatelessWidget {
  const _BackendGate({required this.backend});
  final Future<_LocalBackend> backend;

  @override
  Widget build(BuildContext context) => FutureBuilder<_LocalBackend>(
    future: backend,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Local landmark recognition is unavailable. Check the bundled model and landmark data, then restart the app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final services = snapshot.data!;
      final starts = services.landmarks
          .where((landmark) => services.routing.hasNode(landmark.routeNodeId))
          .toList(growable: false);
      return _DashboardScreen(services: services, starts: starts);
    },
  );
}

class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen({
    required this.services,
    required this.starts,
  });

  final _LocalBackend services;
  final List<Landmark> starts;

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  int _currentIndex = 0;


  void _startTour(BuildContext context) async {
    final destination = await Navigator.of(context).push<Landmark>(
      MaterialPageRoute<Landmark>(
        builder: (context) => PhotoScreen(
          recognizePhoto: (photo) async => widget.services.recognize(photo),
          startPoints: widget.starts,
        ),
      ),
    );
    if (destination != null) {
      _showDestinationSheet(destination);
    }
  }

  void _showDestinationSheet(Landmark destination) {
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _DestinationSheet(
        destination: destination,
        onDirectionsTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => OfflineMapScreen(
                destination: destination,
                startPoints: widget.starts,
                findNearestNode: widget.services.routing.findNearestNode,
                onStartConfirmed: (origin) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => NavigationScreen(
                      destination: destination,
                      origin: origin,
                      calculateRoute: () async {
                        final route = widget.services.routing.findRoute(
                          origin.routeNodeId,
                          destination.routeNodeId,
                        );
                        if (!route.isAvailable) return route;
                        if (origin.id == 'user-current-location') {
                          final originPoint = (origin.lat, origin.lon);
                          final targetPoint = route.geometry.isNotEmpty
                              ? route.geometry.first
                              : originPoint;
                          final extraDist = RoutingService.distanceMeters(
                            originPoint,
                            targetPoint,
                          );
                          return RouteResult.available(
                            geometry: [originPoint, ...route.geometry],
                            distanceMeters: route.distanceMeters + extraDist,
                          );
                        }
                        return route;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _ExploreTab(
            starts: widget.starts,
            onCameraTap: () => _startTour(context),
            onMarkerTap: _showDestinationSheet,
          ),
          _SavedTab(starts: widget.starts),
          const _LocalStorageTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colorScheme.onSurface, width: 4)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surface,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'EXPLORE',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_outline),
              activeIcon: Icon(Icons.bookmark),
              label: 'SAVED',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sd_storage_outlined),
              activeIcon: Icon(Icons.sd_storage),
              label: 'STORAGE',
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreTab extends StatelessWidget {
  const _ExploreTab({required this.starts, required this.onCameraTap, required this.onMarkerTap});
  final List<Landmark> starts;
  final VoidCallback onCameraTap;
  final void Function(Landmark) onMarkerTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = starts.isNotEmpty ? starts.first.position : const LatLng(14.5896, 120.9734);

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            minZoom: 15,
            maxZoom: 18,
            backgroundColor: theme.colorScheme.surfaceContainerLow,
          ),
          children: [
            TileLayer(
              urlTemplate: 'assets/tiles/{z}/{x}/{y}.png',
              tileProvider: AssetTileProvider(),
              minZoom: 15,
              maxZoom: 18,
              maxNativeZoom: 18,
            ),
            MarkerLayer(
              markers: starts.map((landmark) => Marker(
                point: landmark.position,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => onMarkerTap(landmark),
                  child: Icon(Icons.place, color: theme.colorScheme.primary, size: 32),
                ),
              )).toList(),
            ),
          ],
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: theme.colorScheme.onSurface, width: 4),
              boxShadow: [
                BoxShadow(color: theme.colorScheme.onSurface, offset: const Offset(4, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: theme.colorScheme.onSurface),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search Intramuros...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(Icons.mic, color: theme.colorScheme.onSurface),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: GestureDetector(
            onTap: onCameraTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                border: Border.all(color: theme.colorScheme.onSurface, width: 4),
                boxShadow: [
                  BoxShadow(color: theme.colorScheme.onSurface, offset: const Offset(6, 6)),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                color: theme.colorScheme.onSurface,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedTab extends StatelessWidget {
  const _SavedTab({required this.starts});
  final List<Landmark> starts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = starts.take(3).toList();
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'SAVED LOCATIONS',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: saved.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final place = saved[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.onSurface, width: 4),
                    boxShadow: [
                      BoxShadow(color: theme.colorScheme.onSurface, offset: const Offset(4, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark, color: theme.colorScheme.primary, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          place.name.toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalStorageTab extends StatelessWidget {
  const _LocalStorageTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LOCAL STORAGE',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            const _StorageItem(
              icon: Icons.map,
              title: 'OFFLINE MAP TILES',
              subtitle: 'INTRAMUROS REGION',
              status: 'READY',
            ),
            const SizedBox(height: 16),
            const _StorageItem(
              icon: Icons.memory,
              title: 'AI MODEL',
              subtitle: 'MOBILENET V3 TFLITE',
              status: 'READY',
            ),
            const SizedBox(height: 16),
            const _StorageItem(
              icon: Icons.route,
              title: 'ROUTING GRAPH',
              subtitle: 'PEDESTRIAN WAYS',
              status: 'READY',
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageItem extends StatelessWidget {
  const _StorageItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.onSurface, width: 4),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.onSurface, offset: const Offset(4, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              border: Border.all(color: theme.colorScheme.onSurface, width: 2),
            ),
            child: Text(
              status,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationSheet extends StatelessWidget {
  const _DestinationSheet({required this.destination, required this.onDirectionsTap});
  final Landmark destination;
  final VoidCallback onDirectionsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.onSurface, width: 4),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.onSurface, offset: const Offset(6, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            destination.name.toUpperCase(),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'INTRAMUROS, MANILA',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onDirectionsTap,
            icon: const Icon(Icons.directions_walk),
            label: const Text('DIRECTIONS'),
          ),
        ],
      ),
    );
  }
}
