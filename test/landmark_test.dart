import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuntun/shared/models/landmark.dart';

void main() {
  Map<String, dynamic> validJson() => <String, dynamic>{
        'id': 'fort-santiago',
        'name': 'Fort Santiago',
        'lat': 14.592877,
        'lon': 120.9718867,
        'route_node_id': '1034882636',
      };

  test('fromJson reads a valid entry', () {
    final landmark = Landmark.fromJson(validJson());
    expect(landmark.id, 'fort-santiago');
    expect(landmark.name, 'Fort Santiago');
    expect(landmark.lat, closeTo(14.592877, 1e-9));
    expect(landmark.lon, closeTo(120.9718867, 1e-9));
    expect(landmark.routeNodeId, '1034882636');
  });

  test('fromJson accepts integer lat/lon', () {
    final landmark = Landmark.fromJson(validJson()
      ..['lat'] = 0
      ..['lon'] = 120);
    expect(landmark.lat, 0.0);
    expect(landmark.lon, 120.0);
  });

  test('fromJson rejects blank id/name/route_node_id', () {
    for (final key in ['id', 'name', 'route_node_id']) {
      expect(
        () => Landmark.fromJson(validJson()..[key] = '   '),
        throwsFormatException,
        reason: '$key blank should throw',
      );
      expect(
        () => Landmark.fromJson(validJson()..[key] = null),
        throwsFormatException,
        reason: '$key missing should throw',
      );
    }
  });

  test('fromJson rejects out-of-range latitude and longitude', () {
    expect(
      () => Landmark.fromJson(validJson()..['lat'] = 90.1),
      throwsFormatException,
    );
    expect(
      () => Landmark.fromJson(validJson()..['lon'] = 180.1),
      throwsFormatException,
    );
  });

  test('fromJson rejects NaN and Infinity coordinates', () {
    expect(
      () => Landmark.fromJson(validJson()..['lat'] = double.nan),
      throwsFormatException,
    );
    expect(
      () => Landmark.fromJson(validJson()..['lon'] = double.infinity),
      throwsFormatException,
    );
  });

  test('listFromJsonString parses and preserves file order', () {
    const jsonString = '''
    [
      {"id":"a","name":"Alpha","lat":1.0,"lon":2.0,"route_node_id":"n1"},
      {"id":"b","name":"Beta","lat":3.0,"lon":4.0,"route_node_id":"n2"}
    ]''';
    final landmarks = Landmark.listFromJsonString(jsonString);
    expect(landmarks.length, 2);
    expect(landmarks.map((l) => l.id).toList(), ['a', 'b']);
  });

  test('listFromJsonString rejects duplicate ids', () {
    const jsonString = '''
    [
      {"id":"a","name":"Alpha","lat":1.0,"lon":2.0,"route_node_id":"n1"},
      {"id":"a","name":"Again","lat":3.0,"lon":4.0,"route_node_id":"n2"}
    ]''';
    expect(
      () => Landmark.listFromJsonString(jsonString),
      throwsFormatException,
    );
  });

  test('listFromJsonString rejects non-array top-level JSON', () {
    expect(
      () => Landmark.listFromJsonString('{"id":"a"}'),
      throwsFormatException,
    );
  });

  test('parses the real bundled catalog', () {
    final jsonString =
        File('assets/landmarks/landmarks.json').readAsStringSync();
    final landmarks = Landmark.listFromJsonString(jsonString);
    expect(landmarks.length, 6);
    expect(landmarks.first.id, 'fort-santiago');
    expect(landmarks.first.routeNodeId, '1034882636');
  });
}
