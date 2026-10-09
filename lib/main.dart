import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
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
      if (matcher.dimension != EmbeddingService.dimension ||
          matcher.modelId != EmbeddingService.modelId ||
          matcher.modelSha256 != embedding.modelSha256 ||
          matcher.preprocessingVersion !=
              EmbeddingService.preprocessingVersion) {
        throw StateError(
          'The packaged model and reference index do not match.',
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
            (landmark.routeNodeId != null &&
                !routing.hasNode(landmark.routeNodeId!)),
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

  Future<List<Landmark>> recognize(Uint8List photo) async {
    final timer = Stopwatch()..start();
    try {
      final byId = {for (final landmark in landmarks) landmark.id: landmark};
      final result = matcher.match(await embedding.embed(photo));
      final matches = result.candidates
          .map((candidate) => byId[candidate.landmarkId]!)
          .toList(growable: false);
      timer.stop();
      if (kDebugMode) {
        debugPrint(
          '[TUNTON_RECOG] result=${matches.isEmpty ? 'not_recognized' : 'matched'} '
          'count=${matches.length} total_ms=${timer.elapsedMilliseconds}',
        );
      }
      return matches;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[TUNTON_RECOG] failure=${error.runtimeType}: $error\n$stackTrace',
        );
      }
      rethrow;
    }
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
          .where(
            (landmark) =>
                landmark.isRoutable &&
                landmark.routeNodeId != null &&
                services.routing.hasNode(landmark.routeNodeId!),
          )
          .toList(growable: false);
      return PhotoScreen(
        recognizePhoto: (photo) async => services.recognize(photo),
        startPoints: starts,
        findNearestNode: services.routing.findNearestNode,
        calculateRoute: (origin, destination) async {
          final originNodeId = origin.routeNodeId;
          final destinationNodeId = destination.routeNodeId;
          if (originNodeId == null ||
              destinationNodeId == null ||
              !services.routing.hasNode(originNodeId) ||
              !services.routing.hasNode(destinationNodeId)) {
            return const RouteResult.unavailable();
          }
          final route = services.routing.findRoute(
            originNodeId,
            destinationNodeId,
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
      );
    },
  );
}
