import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A single ordered geographic point in [latitude, longitude] order, matching
/// the walk graph coordinate convention. Dependency-free local record type.
typedef GeoPoint = (double lat, double lon);

/// Outcome of a walking-route request between two graph-backed points.
///
/// Has two first-class states: an [RouteResult.available] route carrying the
/// reconstructed polyline and total distance, and an [RouteResult.unavailable]
/// "no connected path" state (P0-12) — never a zero-length route and never a
/// straight line.
@immutable
class RouteResult {
  /// Available route. [geometry] is the ordered polyline reconstructed by
  /// concatenating edge geometries in traversal order; [distanceMeters] is the
  /// summed `length_m` along the path. Both finite; distance >= 0.
  const RouteResult.available({
    required this.geometry,
    required this.distanceMeters,
  })  : isAvailable = true,
        unavailableReason = null;

  RouteResult({
    required List<LatLng> points,
    required this.distanceMeters,
  })  : geometry = points.map((p) => (p.latitude, p.longitude)).toList(growable: false),
        isAvailable = true,
        unavailableReason = null {
    if (!distanceMeters.isFinite ||
        distanceMeters < 0 ||
        points.isEmpty ||
        (distanceMeters > 0 && points.length < 2) ||
        points.any(
          (point) => !point.latitude.isFinite || !point.longitude.isFinite,
        )) {
      throw ArgumentError(
        'Route geometry and distance must be finite and nonnegative.',
      );
    }
  }

  /// First-class "no connected path" state (P0-12). Not a zero-length route and
  /// not a straight line: geometry is empty and distanceMeters is 0.
  const RouteResult.unavailable([
    this.unavailableReason =
        'No connected walking path was found. Choose another supported start.',
  ])  : geometry = const <GeoPoint>[],
        distanceMeters = 0.0,
        isAvailable = false;

  final List<GeoPoint> geometry;
  final double distanceMeters;
  final bool isAvailable;
  final String? unavailableReason;

  List<LatLng> get points =>
      geometry.map((p) => LatLng(p.$1, p.$2)).toList(growable: false);

  /// ETA rule (ARD §7.7, PRD §10): walking speed 4.5 km/h = 75 m/min.
  static const double metersPerMinute = 75.0;

  /// Estimated walking time in minutes. Returns 0 for an unavailable route.
  double get etaMinutes =>
      isAvailable ? distanceMeters / metersPerMinute : 0.0;

  double? get estimatedMinutes =>
      isAvailable ? distanceMeters / metersPerMinute : null;
}
