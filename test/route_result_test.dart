import 'package:flutter_test/flutter_test.dart';
import 'package:tuntun/shared/models/route_result.dart';

void main() {
  test('available holds geometry and distance', () {
    const geometry = <GeoPoint>[(14.0, 120.0), (14.1, 120.1)];
    const result =
        RouteResult.available(geometry: geometry, distanceMeters: 150);
    expect(result.isAvailable, isTrue);
    expect(result.geometry, geometry);
    expect(result.distanceMeters, 150);
  });

  test('etaMinutes uses 75 m/min', () {
    const twoMinutes = RouteResult.available(
      geometry: <GeoPoint>[(0, 0), (0, 1)],
      distanceMeters: 150,
    );
    const oneMinute = RouteResult.available(
      geometry: <GeoPoint>[(0, 0), (0, 1)],
      distanceMeters: 75,
    );
    expect(twoMinutes.etaMinutes, 2.0);
    expect(oneMinute.etaMinutes, 1.0);
  });

  test('unavailable is a first-class no-path state', () {
    const result = RouteResult.unavailable();
    expect(result.isAvailable, isFalse);
    expect(result.geometry, isEmpty);
    expect(result.distanceMeters, 0);
    expect(result.etaMinutes, 0.0);
  });

  test('unavailable is distinct from a zero-length available route', () {
    const zeroLength = RouteResult.available(
      geometry: <GeoPoint>[(14.0, 120.0)],
      distanceMeters: 0,
    );
    const unavailable = RouteResult.unavailable();
    expect(zeroLength.isAvailable, isTrue);
    expect(unavailable.isAvailable, isFalse);
    expect(zeroLength.geometry, isNotEmpty);
    expect(unavailable.geometry, isEmpty);
  });
}
