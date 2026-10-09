import 'dart:convert';

/// One verified Intramuros landmark from the bundled catalog.
///
/// Coordinates are read-only and never invented at runtime: they originate from
/// the packaged `assets/landmarks/landmarks.json`. `routeNodeId` ties the
/// landmark to a real node in the walk graph.
class Landmark {
  const Landmark({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.routeNodeId,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String routeNodeId;

  /// Validates one catalog entry. JSON keys: id, name, lat, lon, route_node_id.
  /// Throws [FormatException] when id/name/route_node_id are missing or blank
  /// (after trim), lat is not in [-90, 90], lon is not in [-180, 180], or
  /// lat/lon are non-finite or not numbers.
  factory Landmark.fromJson(Map<String, dynamic> json) {
    final id = _requireNonBlank(json['id'], 'id');
    final name = _requireNonBlank(json['name'], 'name');
    final routeNodeId = _requireNonBlank(json['route_node_id'], 'route_node_id');
    final lat = _requireCoordinate(json['lat'], 'lat', 90);
    final lon = _requireCoordinate(json['lon'], 'lon', 180);
    return Landmark(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      routeNodeId: routeNodeId,
    );
  }

  /// Parses the whole catalog string (a JSON array). Throws [FormatException]
  /// if the top-level JSON is not a List, any element is not a Map, any element
  /// fails [Landmark.fromJson], or two entries share the same id.
  /// Returns a non-growable list in file order.
  static List<Landmark> listFromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Landmark catalog must be a JSON array.');
    }
    final landmarks = <Landmark>[];
    final seenIds = <String>{};
    for (final element in decoded) {
      if (element is! Map<String, dynamic>) {
        throw const FormatException('Each catalog entry must be a JSON object.');
      }
      final landmark = Landmark.fromJson(element);
      if (!seenIds.add(landmark.id)) {
        throw FormatException('Duplicate landmark id: ${landmark.id}.');
      }
      landmarks.add(landmark);
    }
    return List<Landmark>.of(landmarks, growable: false);
  }

  static String _requireNonBlank(Object? value, String key) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Landmark $key must be a non-blank string.');
    }
    return value;
  }

  static double _requireCoordinate(Object? value, String key, num bound) {
    if (value is! num) {
      throw FormatException('Landmark $key must be a number.');
    }
    final coordinate = value.toDouble();
    if (!coordinate.isFinite || coordinate < -bound || coordinate > bound) {
      throw FormatException('Landmark $key is out of range: $value.');
    }
    return coordinate;
  }
}
