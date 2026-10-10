import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tuntun/app/app.dart';
import 'package:tuntun/features/map/landmark_markers.dart';
import 'package:tuntun/features/map/offline_map_screen.dart';
import 'package:tuntun/shared/models/landmark.dart';

/// Device-free coverage for the two newly registered recognition-only POIs:
///   - sm-makati  (SM Makati, area_id makati)
///   - mrt-edsa   (MRT EDSA Station (Taft Avenue), area_id pasay)
///
/// These tests assert ONLY what is genuinely true today: both landmarks are
/// registered in the bundled catalog, parse without error, carry a valid
/// location, are NOT routable, and ARE produced as map markers at their exact
/// catalog coordinates. They deliberately do NOT assert that either landmark
/// can be recognized from a photo — there are no reference embeddings or
/// licensed images for them yet (see docs/KNOWN_LANDMARK_GAPS.md). The honest
/// "Not recognized" behavior is covered in integration_test/new_landmarks_e2e_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const smMakatiId = 'sm-makati';
  const mrtEdsaId = 'mrt-edsa';

  List<Landmark> loadCatalog() => Landmark.listFromJsonString(
    File('assets/landmarks/landmarks.json').readAsStringSync(),
  );

  group('catalog registration (device-free)', () {
    test('the bundled catalog parses with 17 unique ids and no duplicates', () {
      // listFromJsonString throws on a duplicate id, so a successful parse of
      // the real file already proves uniqueness; the count anchors the two
      // new additions on top of the prior 15 entries.
      final landmarks = loadCatalog();
      expect(landmarks.length, 17);
      final ids = landmarks.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    });

    test('SM Makati is registered as a recognition-only Makati POI', () {
      final landmarks = loadCatalog();
      final sm = landmarks.firstWhere(
        (l) => l.id == smMakatiId,
        orElse: () => throw StateError('sm-makati missing from catalog'),
      );
      expect(sm.name, 'SM Makati');
      expect(sm.areaId, 'makati');
      expect(sm.hasValidLocation, isTrue);
      // Recognition-only: no walking-route node outside Intramuros/Manila.
      expect(sm.isRoutable, isFalse);
      expect(sm.routeNodeId, isNull);
      // Coordinates are read from the catalog, never invented.
      expect(sm.latitude, closeTo(14.5497868, 1e-9));
      expect(sm.longitude, closeTo(121.0267042, 1e-9));
    });

    test('MRT EDSA Station is registered as a recognition-only Pasay POI', () {
      final landmarks = loadCatalog();
      final mrt = landmarks.firstWhere(
        (l) => l.id == mrtEdsaId,
        orElse: () => throw StateError('mrt-edsa missing from catalog'),
      );
      expect(mrt.name, 'MRT EDSA Station (Taft Avenue)');
      expect(mrt.areaId, 'pasay');
      expect(mrt.hasValidLocation, isTrue);
      expect(mrt.isRoutable, isFalse);
      expect(mrt.routeNodeId, isNull);
      expect(mrt.latitude, closeTo(14.5375167, 1e-9));
      expect(mrt.longitude, closeTo(121.0014056, 1e-9));
    });
  });

  group('map marker creation (device-free)', () {
    const colors = ColorScheme.light();

    test('landmarkMarkers() emits a destination marker at the SM Makati '
        'position', () {
      final sm = loadCatalog().firstWhere((l) => l.id == smMakatiId);
      final markers = landmarkMarkers(
        landmarks: [sm],
        destinationId: sm.id,
        colors: colors,
      );
      expect(markers, hasLength(1));
      // Proves the landmark IS rendered as a marker at its catalog coordinates
      // (even though the basemap tiles under it may be blank — see gap doc).
      expect(markers.single.point, sm.position);
      expect(markers.single.point, LatLng(sm.latitude, sm.longitude));
    });

    test('landmarkMarkers() emits a destination marker at the MRT EDSA '
        'position', () {
      final mrt = loadCatalog().firstWhere((l) => l.id == mrtEdsaId);
      final markers = landmarkMarkers(
        landmarks: [mrt],
        destinationId: mrt.id,
        colors: colors,
      );
      expect(markers, hasLength(1));
      expect(markers.single.point, mrt.position);
      expect(markers.single.point, LatLng(mrt.latitude, mrt.longitude));
    });
  });

  group('offline map rendering for the new POIs (device-free)', () {
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

    for (final id in [smMakatiId, mrtEdsaId]) {
      testWidgets('OfflineMapScreen builds with $id as destination and renders '
          'its marker', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final destination = loadCatalog().firstWhere((l) => l.id == id);
        await tester.pumpWidget(
          TuntonApp(
            home: OfflineMapScreen(
              destination: destination,
              onStartConfirmed: (_) {},
              // Provide at least one zoom so the map body renders instead of
              // the "unavailable" state; the tile pixels themselves are not
              // asserted here (they may be blank for Makati/Pasay).
              loadZooms: () async => const [17],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The screen builds cleanly with the new POI as the destination.
        expect(tester.takeException(), isNull);
        expect(find.text(destination.name), findsWidgets);

        // The destination marker is present in the live widget tree.
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(
          find.bySemanticsLabel('Destination: ${destination.name}'),
          findsOneWidget,
        );
      });
    }
  });
}
