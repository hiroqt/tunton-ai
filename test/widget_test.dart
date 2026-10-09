import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tuntun/app/app.dart';
import 'package:tuntun/features/camera/photo_screen.dart';
import 'package:tuntun/features/map/offline_map_screen.dart';
import 'package:tuntun/features/navigation/navigation_screen.dart';
import 'package:tuntun/features/recognition/recognition_screen.dart';
import 'package:tuntun/shared/models/landmark.dart';
import 'package:tuntun/shared/models/route_result.dart';

final photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAI0lEQVR4nGO8dOkSAymAiSTVDKMaiANMRKqDg1ENxACSQwkAuO0Clv+ckegAAAAASUVORK5CYII=',
);
// Presentation fixtures only; none of these catalog records ship in the app.
const destination = Landmark(
  id: 'fixture-a',
  name: 'Fixture destination',
  latitude: 14.59,
  longitude: 120.975,
  routeNodeId: 'fixture-node-a',
);
const origin = Landmark(
  id: 'fixture-b',
  name: 'Fixture start',
  latitude: 14.591,
  longitude: 120.974,
  routeNodeId: 'fixture-node-b',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('a selected photo opens recognition and retry preserves it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      TuntonApp(
        home: PhotoScreen(
          pickPhoto: (source) async =>
              source == ImageSource.camera ? photo : null,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Take a photo'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Take a photo'));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('Find the landmark').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Find the landmark'));
    await tester.tap(find.text('Find the landmark'));
    await tester.pumpAndSettle();
    expect(find.text('Recognition unavailable'), findsOneWidget);
    await tester.ensureVisible(find.text('Try another photo'));
    await tester.tap(find.text('Try another photo'));
    await tester.pumpAndSettle();
    expect(find.text('Find the landmark'), findsOneWidget);
    await tester.ensureVisible(find.text('Choose another photo'));
    await tester.tap(find.text('Choose another photo'));
    await tester.pumpAndSettle();
    expect(find.text('Find the landmark'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screens remain readable in narrow, wide and dark layouts', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final home in <Widget>[
        const PhotoScreen(),
        RecognitionScreen(photoBytes: photo),
        OfflineMapScreen(destination: destination, onStartConfirmed: (_) {}),
        const NavigationScreen(destination: destination, origin: origin),
      ]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(2),
            ),
            child: TuntonApp(home: home),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$home at $width with enlarged text',
        );
      }
    }
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const TuntonApp(home: PhotoScreen()));
    final theme = Theme.of(tester.element(find.text('Take a photo')));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF17191B));
  });

  testWidgets('mobile screens render without accessibility target errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundaryKey = GlobalKey();
    final semantics = tester.ensureSemantics();
    final screens = <String, Widget>{
      'photo': const PhotoScreen(),
      'recognition': RecognitionScreen(
        photoBytes: photo,
        recognize: () async => [destination, origin],
        onConfirm: (_) {},
      ),
      'map': OfflineMapScreen(
        destination: destination,
        startPoints: const [origin],
        onStartConfirmed: (_) {},
      ),
      'route-unavailable': const NavigationScreen(
        destination: destination,
        origin: origin,
      ),
    };
    try {
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: TuntonApp(home: entry.value),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        final screenshotDirectory =
            Platform.environment['TUNTON_UI_SCREENSHOTS'];
        if (screenshotDirectory != null) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory(screenshotDirectory)
              ..createSync(recursive: true);
            await File(
              '${directory.path}/${entry.key}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('unreadable photo shows a recoverable error', (tester) async {
    await tester.pumpWidget(
      TuntonApp(
        home: PhotoScreen(
          pickPhoto: (_) async => Uint8List.fromList([1, 2, 3]),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Choose from gallery'));
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(
      find.text('That photo could not be opened. Choose another image.'),
      findsOneWidget,
    );
    expect(find.text('Find the landmark'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling photo selection leaves the input screen usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      TuntonApp(home: PhotoScreen(pickPhoto: (_) async => null)),
    );
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Find the landmark'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one best match is ready for explicit destination confirmation', (
    tester,
  ) async {
    Landmark? confirmed;
    await tester.pumpWidget(
      TuntonApp(
        home: RecognitionScreen(
          photoBytes: photo,
          recognize: () async => [destination, destination, origin],
          onConfirm: (value) => confirmed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fixture destination'), findsOneWidget);
    expect(find.text('Fixture start'), findsNothing);
    expect(find.text('Ranked suggestions'), findsNothing);
    final button = find.widgetWithText(FilledButton, 'Use this destination');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(confirmed, isNull);
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(confirmed, destination);
  });

  testWidgets('unknown input stays unknown and offers retry', (tester) async {
    await tester.pumpWidget(
      TuntonApp(
        home: RecognitionScreen(photoBytes: photo, recognize: () async => []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not recognized'), findsOneWidget);
    expect(find.text('Try another photo'), findsOneWidget);
    expect(find.text('Use this destination'), findsNothing);
  });

  testWidgets('missing inference does not produce sample predictions', (
    tester,
  ) async {
    await tester.pumpWidget(
      TuntonApp(home: RecognitionScreen(photoBytes: photo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recognition unavailable'), findsOneWidget);
    expect(find.text('Ranked suggestions'), findsNothing);
  });

  testWidgets('missing map and start assets stay unavailable', (tester) async {
    await tester.pumpWidget(
      TuntonApp(
        home: OfflineMapScreen(
          destination: destination,
          onStartConfirmed: (_) {},
          loadZooms: () async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline map unavailable'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Preview walking route'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual start is chosen from supported points before preview', (
    tester,
  ) async {
    Landmark? confirmed;
    await tester.pumpWidget(
      TuntonApp(
        home: OfflineMapScreen(
          destination: destination,
          startPoints: const [origin],
          onStartConfirmed: (value) => confirmed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose starting point'));
    await tester.tap(find.text('Choose starting point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture start'));
    await tester.pumpAndSettle();
    expect(confirmed, isNull);
    await tester.ensureVisible(find.text('Preview walking route'));
    await tester.tap(find.text('Preview walking route'));
    expect(confirmed, origin);
  });

  testWidgets('unavailable route never displays fabricated distance or ETA', (
    tester,
  ) async {
    await tester.pumpWidget(
      TuntonApp(
        home: NavigationScreen(
          destination: destination,
          origin: origin,
          calculateRoute: () async => const RouteResult.unavailable(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Route unavailable'), findsOneWidget);
    expect(find.text('Choose another start'), findsOneWidget);
    expect(find.text('Walking distance'), findsNothing);
    expect(find.text('Estimated time'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'photo entry offers camera and gallery on a neutral Inter theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(const TuntonApp(home: PhotoScreen()));
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Manila · Makati · Pasay'), findsOneWidget);
      final theme = Theme.of(tester.element(find.text('Take a photo')));
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9F6));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('photo entry stays usable at 320px with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 780),
          textScaler: TextScaler.linear(2),
        ),
        child: const TuntonApp(home: PhotoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Choose from gallery'));
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets('current GPS location can be chosen as start point', (
    tester,
  ) async {
    Landmark? confirmed;
    await tester.pumpWidget(
      TuntonApp(
        home: OfflineMapScreen(
          destination: destination,
          startPoints: const [origin],
          findNearestNode: (lat, lon) =>
              ('snapped-gps-node', (14.5905, 120.9745)),
          getCurrentPosition: () async => Position(
            latitude: 14.5902,
            longitude: 120.9741,
            timestamp: DateTime.now(),
            accuracy: 5.0,
            altitude: 10.0,
            altitudeAccuracy: 1.0,
            heading: 0.0,
            headingAccuracy: 1.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          ),
          onStartConfirmed: (value) => confirmed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Use current location (GPS)'), findsOneWidget);
    await tester.ensureVisible(find.text('Use current location (GPS)'));
    await tester.tap(find.text('Use current location (GPS)'));
    await tester.pumpAndSettle();
    expect(find.text('Location set: Your Location'), findsOneWidget);

    await tester.ensureVisible(find.text('Preview walking route'));
    await tester.tap(find.text('Preview walking route'));
    expect(confirmed, isNotNull);
    expect(confirmed!.id, 'user-current-location');
    expect(confirmed!.routeNodeId, 'snapped-gps-node');
  });

  testWidgets(
    'navigation screen displays live GPS streaming status when stream emits',
    (tester) async {
      final controller = StreamController<Position>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        TuntonApp(
          home: NavigationScreen(
            destination: destination,
            origin: origin,
            calculateRoute: () async => const RouteResult.available(
              geometry: [(14.591, 120.974), (14.59, 120.975)],
              distanceMeters: 150.0,
            ),
            positionStream: controller.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('150 m'), findsOneWidget);
      expect(find.text('Live GPS position streaming'), findsNothing);

      controller.add(
        Position(
          latitude: 14.591,
          longitude: 120.974,
          timestamp: DateTime.now(),
          accuracy: 3.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 1.2,
          speedAccuracy: 0.2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live GPS position streaming'), findsOneWidget);
    },
  );
}
