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

/// End-to-end flow test. The native `com.tunton/vision` MethodChannel is stubbed
/// via TestDefaultBinaryMessengerBinding so the REAL EmbeddingService,
/// LandmarkMatcher, RecognitionScreen and PhotoScreen navigation all run; only
/// the on-device ONNX inference is replaced by a controlled 512-d embedding.
///
/// Asserts:
///  (a) a stubbed KNOWN reference vector → the app AUTOMATICALLY advances to that
///      landmark with NO manual candidate tap and NO "Confirm destination" press.
///  (b) a stubbed noise vector below the gates → the app shows "Not recognized".
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tunton/vision');

  // A tiny valid 16x16 PNG so prepareImage() can decode a real image headlessly.
  final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAI0lEQVR4nGO8dOkSAymAiSTVDKMaiANMRKqDg1ENxACSQwkAuO0Clv+ckegAAAAASUVORK5CYII=',
  );

  // Filled in setUpAll from the bundled reference asset.
  late List<double> knownReferenceVector;
  late String knownLandmarkId;
  late List<Landmark> landmarks;

  // The embedding the stub should return for the next embed() call.
  late List<num> stubbedEmbedding;

  setUpAll(() async {
    final refsString = await rootBundle.loadString(
      LandmarkMatcher.referenceAsset,
    );
    final refs = jsonDecode(refsString) as Map<String, dynamic>;
    final references = refs['references'] as List<dynamic>;
    // Use fort-santiago (Intramuros, routable) if present, else the first ref.
    final chosen =
        references.cast<Map<String, dynamic>>().firstWhere(
          (r) => r['landmark_id'] == 'fort-santiago',
          orElse: () => references.first as Map<String, dynamic>,
        );
    knownLandmarkId = chosen['landmark_id'] as String;
    knownReferenceVector = (chosen['vector'] as List<dynamic>)
        .map((v) => (v as num).toDouble())
        .toList(growable: false);

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
    // Recognition runs the real embed + matcher; let it settle.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'known reference vector automatically advances with no manual confirm',
    (tester) async {
      stubbedEmbedding = knownReferenceVector;
      await captureAndRecognize(tester);

      // No manual selection UI: no per-candidate Confirm button exists.
      expect(find.text('Confirm destination'), findsNothing);
      expect(find.text('Ranked suggestions'), findsNothing);

      // The chosen known landmark is Intramuros + routable, so the automatic
      // onConfirm advances into the offline map / start-selection flow.
      final chosen = landmarks.firstWhere((l) => l.id == knownLandmarkId);
      if (chosen.isRoutable) {
        // Reached the map step (start selection) — not the recognition screen.
        expect(find.text('Choose starting point'), findsOneWidget);
      } else {
        // Non-routable: the confirmed-non-routable dialog is shown automatically.
        expect(find.text(chosen.name), findsWidgets);
      }
    },
  );

  testWidgets('noise vector below the gates shows Not recognized', (
    tester,
  ) async {
    // A near-uniform 512-vector: after L2 normalization it is diffuse, so it
    // lands below the recognition gates for every landmark.
    stubbedEmbedding = List<num>.filled(EmbeddingService.dimension, 1.0);
    await captureAndRecognize(tester);

    expect(find.text('Not recognized'), findsOneWidget);
    expect(find.text('Try another photo'), findsOneWidget);
    expect(find.text('Confirm destination'), findsNothing);
  });
}
