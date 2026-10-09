import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuntun/features/navigation/routing_service.dart';
import 'package:tuntun/shared/models/landmark.dart';
import 'package:tuntun/shared/models/route_result.dart';

/// Builds a tiny hand-made graph. Nodes A,B,C,D with:
///   A -> B (10m), B -> C (10m), A -> C (30m)  [so A->B->C (20m) is shortest]
///   C -> D is ONE-WAY (D has no edge back to C), D isolated otherwise.
///   E is a lone node with no edges (disconnected).
Map<String, dynamic> _tinyGraph() => <String, dynamic>{
      'nodes': <Map<String, dynamic>>[
        {'id': 'A', 'lat': 14.0, 'lon': 120.0},
        {'id': 'B', 'lat': 14.1, 'lon': 120.1},
        {'id': 'C', 'lat': 14.2, 'lon': 120.2},
        {'id': 'D', 'lat': 14.3, 'lon': 120.3},
        {'id': 'E', 'lat': 14.9, 'lon': 120.9},
      ],
      'edges': <Map<String, dynamic>>[
        {
          'from': 'A',
          'to': 'B',
          'length_m': 10.0,
          'geometry': [
            [14.0, 120.0],
            [14.1, 120.1],
          ],
        },
        {
          'from': 'B',
          'to': 'C',
          'length_m': 10.0,
          'geometry': [
            [14.1, 120.1],
            [14.2, 120.2],
          ],
        },
        {
          'from': 'A',
          'to': 'C',
          'length_m': 30.0,
          'geometry': [
            [14.0, 120.0],
            [14.2, 120.2],
          ],
        },
        {
          'from': 'C',
          'to': 'D',
          'length_m': 5.0,
          'geometry': [
            [14.2, 120.2],
            [14.3, 120.3],
          ],
        },
      ],
    };

void main() {
  group('RoutingService synthetic graph', () {
    test('picks the shortest directed path and sums its length', () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      final result = service.findRoute('A', 'C');

      expect(result.isAvailable, isTrue);
      // A->B->C (20m) beats the direct A->C (30m).
      expect(result.distanceMeters, closeTo(20.0, 1e-9));
      expect(result.etaMinutes, greaterThan(0));
    });

    test('concatenates edge geometry in traversal order with shared-vertex de-dup',
        () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      final result = service.findRoute('A', 'C');

      // A->B geometry [A,B] then B->C geometry [B,C]; shared B de-duplicated.
      expect(result.geometry, <GeoPoint>[
        (14.0, 120.0),
        (14.1, 120.1),
        (14.2, 120.2),
      ]);
    });

    test('one-way edge is not traversable backward', () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      // C -> D exists, but there is no D -> C edge.
      final forward = service.findRoute('C', 'D');
      expect(forward.isAvailable, isTrue);

      final backward = service.findRoute('D', 'C');
      expect(backward.isAvailable, isFalse);
      expect(backward.geometry, isEmpty);
      expect(backward.distanceMeters, 0);
    });

    test('disconnected valid pair returns unavailable, never a straight line',
        () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      final result = service.findRoute('A', 'E');
      expect(result.isAvailable, isFalse);
      expect(result.geometry, isEmpty);
      expect(result.distanceMeters, 0);
    });

    test('start == destination yields an available single-point zero-distance route',
        () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      final result = service.findRoute('B', 'B');
      expect(result.isAvailable, isTrue);
      expect(result.geometry, <GeoPoint>[(14.1, 120.1)]);
      expect(result.distanceMeters, 0.0);
      expect(result.etaMinutes, 0.0);
    });

    test('unknown node id throws FormatException', () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      expect(() => service.findRoute('A', 'ZZZ'), throwsFormatException);
      expect(() => service.findRoute('ZZZ', 'A'), throwsFormatException);
    });

    test('hasNode reflects the parsed node set', () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      expect(service.hasNode('A'), isTrue);
      expect(service.hasNode('ZZZ'), isFalse);
    });

    test('rejects malformed graph data', () {
      expect(
        () => RoutingService.fromDecodedJson(<String, dynamic>{
          'nodes': 'not-a-list',
          'edges': <dynamic>[],
        }),
        throwsFormatException,
      );
      // Non-positive length_m.
      expect(
        () => RoutingService.fromDecodedJson(<String, dynamic>{
          'nodes': [
            {'id': 'A', 'lat': 14.0, 'lon': 120.0},
            {'id': 'B', 'lat': 14.1, 'lon': 120.1},
          ],
          'edges': [
            {
              'from': 'A',
              'to': 'B',
              'length_m': 0,
              'geometry': [
                [14.0, 120.0],
                [14.1, 120.1],
              ],
            },
          ],
        }),
        throwsFormatException,
      );
      // Edge referencing an unknown node.
      expect(
        () => RoutingService.fromDecodedJson(<String, dynamic>{
          'nodes': [
            {'id': 'A', 'lat': 14.0, 'lon': 120.0},
          ],
          'edges': [
            {
              'from': 'A',
              'to': 'B',
              'length_m': 10.0,
              'geometry': [
                [14.0, 120.0],
                [14.1, 120.1],
              ],
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('RoutingService real bundled graph', () {
    test('routes fort-santiago -> puerta-real with an ordered geometry', () {
      final service = RoutingService.fromJsonString(
        File('assets/maps/intramuros_graph.json').readAsStringSync(),
      );
      final landmarks = Landmark.listFromJsonString(
        File('assets/landmarks/landmarks.json').readAsStringSync(),
      );
      final fortSantiago =
          landmarks.firstWhere((l) => l.id == 'fort-santiago');
      final puertaReal = landmarks.firstWhere((l) => l.id == 'puerta-real');

      expect(fortSantiago.routeNodeId, '1034882636');
      expect(puertaReal.routeNodeId, '9834302082');
      expect(service.hasNode(fortSantiago.routeNodeId!), isTrue);
      expect(service.hasNode(puertaReal.routeNodeId!), isTrue);

      final result = service.findRoute(
        fortSantiago.routeNodeId!,
        puertaReal.routeNodeId!,
      );

      expect(result.isAvailable, isTrue);
      expect(result.distanceMeters, greaterThan(0));
      expect(result.geometry.length, greaterThanOrEqualTo(2));
      expect(result.etaMinutes, greaterThan(0));
    });

    test('findNearestNode snaps to the closest graph node', () {
      final service = RoutingService.fromDecodedJson(_tinyGraph());
      // A is at (14.0, 120.0), B is at (14.1, 120.1)
      final (nodeA, coordA) = service.findNearestNode(14.01, 120.01);
      expect(nodeA, 'A');
      expect(coordA, (14.0, 120.0));

      // E is at (14.9, 120.9)
      final (nodeE, coordE) = service.findNearestNode(14.88, 120.89);
      expect(nodeE, 'E');
      expect(coordE, (14.9, 120.9));
    });

    test('distanceMeters returns expected great-circle distance', () {
      final d0 = RoutingService.distanceMeters((14.0, 120.0), (14.0, 120.0));
      expect(d0, 0.0);

      // (14.0, 120.0) to (14.001, 120.0) is approx ~111 meters
      final d1 = RoutingService.distanceMeters((14.0, 120.0), (14.001, 120.0));
      expect(d1, closeTo(111.0, 5.0));
    });

    test('findNearestNode on real bundled graph snaps landmark position', () {
      final service = RoutingService.fromJsonString(
        File('assets/maps/intramuros_graph.json').readAsStringSync(),
      );
      final landmarks = Landmark.listFromJsonString(
        File('assets/landmarks/landmarks.json').readAsStringSync(),
      );
      final fortSantiago =
          landmarks.firstWhere((l) => l.id == 'fort-santiago');

      final (nodeId, _) = service.findNearestNode(
        fortSantiago.lat,
        fortSantiago.lon,
      );
      expect(nodeId, fortSantiago.routeNodeId);
    });
  });
}
