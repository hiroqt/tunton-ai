import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tuntun/app/app.dart';
import 'package:tuntun/features/camera/photo_screen.dart';
import 'package:tuntun/features/navigation/routing_service.dart';
import 'package:tuntun/features/recognition/embedding_service.dart';
import 'package:tuntun/features/recognition/landmark_matcher.dart';
import 'package:tuntun/shared/models/landmark.dart';
import 'package:tuntun/shared/models/route_result.dart';

/// End-to-end honesty test for the two newly registered recognition-only POIs
/// (sm-makati, mrt-edsa). It follows the SAME harness as app_test.dart: the
/// native `com.tunton/vision` MethodChannel is stubbed via
/// TestDefaultBinaryMessengerBinding so the REAL EmbeddingService,
/// LandmarkMatcher, RecognitionScreen and PhotoScreen navigation all run; only
/// the on-device ONNX inference is replaced by a controlled 512-d embedding.
///
/// WHY THIS TEST ASSERTS "Not recognized" AND NOT A POSITIVE RECOGNITION:
/// sm-makati and mrt-edsa have NO reference embeddings in
/// assets/landmarks/reference_embeddings.json and NO licensed images under
/// assets/images/. Recognition for them is NON-FUNCTIONAL until licensed
/// photos are added and tools/prepare_dataset.py is rerun to produce real
/// 512-d OpenCLIP embeddings (see docs/KNOWN_LANDMARK_GAPS.md). Fabricating a
/// vector that "recognizes" either landmark would violate AGENTS.md §8. The
/// honest, verifiable fact is that WITHOUT reference embeddings a diffuse noise
/// query is correctly rejected to "Not recognized" rather than being falsely
/// matched to any landmark.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tunton/vision');

  // A tiny valid 16x16 PNG so prepareImage() can decode a real image headlessly.
  final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAI0lEQVR4nGO8dOkSAymAiSTVDKMaiANMRKqDg1ENxACSQwkAuO0Clv+ckegAAAAASUVORK5CYII=',
  );

  late List<Landmark> landmarks;

  // The embedding the stub should return for the next embed() call.
  late List<num> stubbedEmbedding;

  setUpAll(() async {
    landmarks = Landmark.listFromJsonString(
      await rootBundle.loadString('assets/landmarks/landmarks.json'),
    );

    final fonts = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'initialize':
              return <String, dynamic>{'dimension': EmbeddingService.dimension};
            case 'embed':
              return stubbedEmbedding;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<Widget> buildApp() async {
    final embedding = await EmbeddingService.load();
    final matcher = await LandmarkMatcher.load();
    final routing = await RoutingService.load();
    final byId = {for (final l in landmarks) l.id: l};

    Future<List<Landmark>> recognize(Uint8List bytes) async {
      final result = matcher.match(await embedding.embed(bytes));
      return result.candidates
          .map((c) => byId[c.landmarkId]!)
          .toList(growable: false);
    }

    final starts = landmarks
        .where(
          (l) =>
              l.isRoutable &&
              l.routeNodeId != null &&
              routing.hasNode(l.routeNodeId!),
        )
        .toList(growable: false);

    return TuntonApp(
      home: PhotoScreen(
        pickPhoto: (source) async =>
            source == ImageSource.camera ? photo : null,
        recognizePhoto: recognize,
        startPoints: starts,
        findNearestNode: routing.findNearestNode,
        calculateRoute: (origin, destination) async {
          final o = origin.routeNodeId;
          final d = destination.routeNodeId;
          if (o == null ||
              d == null ||
              !routing.hasNode(o) ||
              !routing.hasNode(d)) {
            return const RouteResult.unavailable();
          }
          return routing.findRoute(o, d);
        },
      ),
    );
  }

  Future<void> captureAndRecognize(WidgetTester tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('Find the landmark').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find the landmark'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'new recognition-only POIs are registered but cannot be falsely recognized',
    (tester) async {
      // Precondition: both new POIs ARE in the catalog the app loads.
      final ids = landmarks.map((l) => l.id).toSet();
      expect(ids.contains('sm-makati'), isTrue);
      expect(ids.contains('mrt-edsa'), isTrue);
      // ...and neither is routable (recognition-only).
      expect(
        landmarks.firstWhere((l) => l.id == 'sm-makati').isRoutable,
        isFalse,
      );
      expect(
        landmarks.firstWhere((l) => l.id == 'mrt-edsa').isRoutable,
        isFalse,
      );

      // A near-uniform 512-vector: after L2 normalization it is diffuse, so it
      // lands below the recognition gates for every landmark. Because
      // sm-makati/mrt-edsa have no reference embeddings at all, there is no
      // vector that could match them here — the correct, honest outcome is
      // "Not recognized" (never a fabricated positive match).
      stubbedEmbedding = List<num>.filled(EmbeddingService.dimension, 1.0);
      await captureAndRecognize(tester);

      expect(find.text('Not recognized'), findsOneWidget);
      expect(find.text('Try another photo'), findsOneWidget);
      expect(find.text('Confirm destination'), findsNothing);
      // The new POIs must not appear as a falsely confident destination.
      expect(find.text('SM Makati'), findsNothing);
      expect(find.text('MRT EDSA Station (Taft Avenue)'), findsNothing);
    },
  );
}
