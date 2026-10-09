/// A single ordered geographic point in [latitude, longitude] order, matching
/// the walk graph coordinate convention. Dependency-free local record type.
typedef GeoPoint = (double lat, double lon);

/// Outcome of a walking-route request between two graph-backed points.
///
/// Has two first-class states: an [RouteResult.available] route carrying the
/// reconstructed polyline and total distance, and an [RouteResult.unavailable]
/// "no connected path" state (P0-12) — never a zero-length route and never a
/// straight line.
class RouteResult {
  /// Available route. [geometry] is the ordered polyline reconstructed by
  /// concatenating edge geometries in traversal order; [distanceMeters] is the
  /// summed `length_m` along the path. Both finite; distance >= 0.
  const RouteResult.available({
    required this.geometry,
    required this.distanceMeters,
  }) : isAvailable = true;

  /// First-class "no connected path" state (P0-12). Not a zero-length route and
  /// not a straight line: geometry is empty and distanceMeters is 0.
  const RouteResult.unavailable()
      : geometry = const <GeoPoint>[],
        distanceMeters = 0,
        isAvailable = false;

  final List<GeoPoint> geometry;
  final double distanceMeters;
  final bool isAvailable;

  /// ETA rule (ARD §7.7, PRD §10): walking speed 4.5 km/h = 75 m/min.
  static const double metersPerMinute = 75.0;

  /// Estimated walking time in minutes. Returns 0 for an unavailable route.
  double get etaMinutes =>
      isAvailable ? distanceMeters / metersPerMinute : 0.0;
}
