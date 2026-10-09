import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:tuntun/shared/models/route_result.dart';

/// One directed outgoing edge in the walk graph: its destination node, its
/// weight (`length_m`), and its ordered geometry in traversal order (from -> to).
class _Edge {
  const _Edge(this.to, this.lengthM, this.geometry);

  final String to;
  final double lengthM;
  final List<GeoPoint> geometry;
}

/// Minimal array-based binary min-heap keyed by tentative distance.
///
/// `dart:collection` has no priority queue, so Dijkstra uses this. Entries are
/// never removed on decrease-key; instead stale entries are pushed and the
/// caller skips any popped entry whose distance exceeds the best recorded one
/// (lazy deletion).
class _MinHeap {
  final List<String> _nodes = <String>[];
  final List<double> _dists = <double>[];

  bool get isEmpty => _nodes.isEmpty;

  void push(String node, double dist) {
    _nodes.add(node);
    _dists.add(dist);
    var i = _nodes.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_dists[parent] <= _dists[i]) {
        break;
      }
      _swap(i, parent);
      i = parent;
    }
  }

  /// Removes and returns the (node, distance) with the smallest distance.
  (String, double) pop() {
    final node = _nodes.first;
    final dist = _dists.first;
    final last = _nodes.length - 1;
    _nodes[0] = _nodes[last];
    _dists[0] = _dists[last];
    _nodes.removeLast();
    _dists.removeLast();
    if (_nodes.isNotEmpty) {
      _siftDown(0);
    }
    return (node, dist);
  }

  void _siftDown(int i) {
    final length = _nodes.length;
    while (true) {
      final left = 2 * i + 1;
      final right = 2 * i + 2;
      var smallest = i;
      if (left < length && _dists[left] < _dists[smallest]) {
        smallest = left;
      }
      if (right < length && _dists[right] < _dists[smallest]) {
        smallest = right;
      }
      if (smallest == i) {
        break;
      }
      _swap(i, smallest);
      i = smallest;
    }
  }

  void _swap(int a, int b) {
    final tmpNode = _nodes[a];
    _nodes[a] = _nodes[b];
    _nodes[b] = tmpNode;
    final tmpDist = _dists[a];
    _dists[a] = _dists[b];
    _dists[b] = tmpDist;
  }
}

/// Pure-Dart pedestrian routing over the bundled Intramuros walk graph.
///
/// Runs Dijkstra over DIRECTED edges weighted by `length_m` (P0-09, P0-10).
/// The graph is read-only bundled data; no network, no database, no GPS.
class RoutingService {
  RoutingService._(this._nodes, this._adjacency);

  static const String graphAsset = 'assets/maps/intramuros_graph.json';

  /// node id -> (lat, lon)
  final Map<String, GeoPoint> _nodes;

  /// from-node id -> outgoing directed edges (from -> to only, never reversed)
  final Map<String, List<_Edge>> _adjacency;

  /// Builds from already-parsed graph JSON (preferred for tests — no IO).
  ///
  /// Validates: `nodes` is a list of `{id, lat, lon}` with unique non-blank ids
  /// and finite coordinates; `edges` is a list of `{from, to, length_m,
  /// geometry}` with `length_m` finite and > 0, `from`/`to` referencing known
  /// node ids, and `geometry` a non-empty list of `[lat, lon]` pairs. Throws
  /// [FormatException] on any violation. Builds DIRECTED adjacency: each edge is
  /// added to `_adjacency[from]` only — never the reverse.
  factory RoutingService.fromDecodedJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'];
    final rawEdges = json['edges'];
    if (rawNodes is! List) {
      throw const FormatException('Graph "nodes" must be a JSON array.');
    }
    if (rawEdges is! List) {
      throw const FormatException('Graph "edges" must be a JSON array.');
    }

    final nodes = <String, GeoPoint>{};
    for (final entry in rawNodes) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Each graph node must be a JSON object.');
      }
      final id = entry['id'];
      if (id is! String || id.trim().isEmpty) {
        throw const FormatException('Graph node id must be a non-blank string.');
      }
      if (nodes.containsKey(id)) {
        throw FormatException('Duplicate graph node id: $id.');
      }
      final lat = _finiteCoord(entry['lat'], 'node $id lat');
      final lon = _finiteCoord(entry['lon'], 'node $id lon');
      nodes[id] = (lat, lon);
    }

    final adjacency = <String, List<_Edge>>{};
    for (final entry in rawEdges) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Each graph edge must be a JSON object.');
      }
      final from = entry['from'];
      final to = entry['to'];
      if (from is! String || from.trim().isEmpty) {
        throw const FormatException('Edge "from" must be a non-blank string.');
      }
      if (to is! String || to.trim().isEmpty) {
        throw const FormatException('Edge "to" must be a non-blank string.');
      }
      if (!nodes.containsKey(from)) {
        throw FormatException('Edge references unknown "from" node: $from.');
      }
      if (!nodes.containsKey(to)) {
        throw FormatException('Edge references unknown "to" node: $to.');
      }
      final rawLength = entry['length_m'];
      if (rawLength is! num || !rawLength.isFinite || rawLength <= 0) {
        throw const FormatException(
          'Edge "length_m" must be a finite number greater than 0.',
        );
      }
      final rawGeometry = entry['geometry'];
      if (rawGeometry is! List || rawGeometry.isEmpty) {
        throw const FormatException(
          'Edge "geometry" must be a non-empty JSON array.',
        );
      }
      final geometry = <GeoPoint>[];
      for (final point in rawGeometry) {
        if (point is! List || point.length != 2) {
          throw const FormatException(
            'Edge geometry points must be [lat, lon] pairs.',
          );
        }
        final lat = _finiteCoord(point[0], 'geometry lat');
        final lon = _finiteCoord(point[1], 'geometry lon');
        geometry.add((lat, lon));
      }
      (adjacency[from] ??= <_Edge>[]).add(
        _Edge(to, rawLength.toDouble(), List<GeoPoint>.of(geometry, growable: false)),
      );
    }

    return RoutingService._(nodes, adjacency);
  }

  /// Convenience: parse a JSON string, then delegate to [fromDecodedJson].
  factory RoutingService.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Graph JSON must be a top-level object.');
    }
    return RoutingService.fromDecodedJson(decoded);
  }

  /// Convenience loader reading the bundled graph asset via `rootBundle`.
  static Future<RoutingService> load() async {
    final jsonString = await rootBundle.loadString(graphAsset);
    return RoutingService.fromJsonString(jsonString);
  }

  bool hasNode(String id) => _nodes.containsKey(id);

  /// Finds the nearest graph node to the given coordinates ([lat], [lon]).
  ///
  /// Uses equirectangular approximation, which is fast and accurate for local
  /// pedestrian distances. Returns a record with `(String nodeId, GeoPoint coordinates)`.
  /// Throws [StateError] if the graph has no nodes.
  (String, GeoPoint) findNearestNode(double lat, double lon) {
    if (_nodes.isEmpty) {
      throw StateError('Walk graph contains no nodes.');
    }
    String? nearestId;
    GeoPoint? nearestPoint;
    var minDistanceSq = double.infinity;

    final latRad = lat * (math.pi / 180.0);
    final cosLat = math.cos(latRad);

    for (final entry in _nodes.entries) {
      final nodeLat = entry.value.$1;
      final nodeLon = entry.value.$2;
      final dLat = nodeLat - lat;
      final dLon = (nodeLon - lon) * cosLat;
      final distSq = dLat * dLat + dLon * dLon;
      if (distSq < minDistanceSq) {
        minDistanceSq = distSq;
        nearestId = entry.key;
        nearestPoint = entry.value;
      }
    }
    return (nearestId!, nearestPoint!);
  }

  /// Calculates the great-circle distance between two geographic coordinates in meters.
  static double distanceMeters(GeoPoint a, GeoPoint b) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (b.$1 - a.$1) * (math.pi / 180.0);
    final dLon = (b.$2 - a.$2) * (math.pi / 180.0);
    final lat1 = a.$1 * (math.pi / 180.0);
    final lat2 = b.$1 * (math.pi / 180.0);

    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final h = sinDLat * sinDLat +
        math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;
    final c = 2 * math.asin(math.sqrt(h));
    return r * c;
  }

  /// Shortest walking route from [startNodeId] to [destinationNodeId].
  ///
  /// Contract:
  ///   - Unknown [startNodeId] or [destinationNodeId] => [FormatException]
  ///     (a programmer/data error, not a user outcome).
  ///   - Valid ids but no connected directed path => [RouteResult.unavailable]
  ///     (P0-12) — never a straight line.
  ///   - start == destination (both valid) => available single-point route at
  ///     the node coordinate, distance 0.0.
  ///   - Success: reconstruct the ordered node path, concatenate each traversed
  ///     edge's geometry IN TRAVERSAL ORDER (de-duplicating the shared junction
  ///     vertex between consecutive edges), sum `length_m` for distance.
  RouteResult findRoute(String startNodeId, String destinationNodeId) {
    if (!_nodes.containsKey(startNodeId)) {
      throw FormatException('Unknown start node id: $startNodeId.');
    }
    if (!_nodes.containsKey(destinationNodeId)) {
      throw FormatException('Unknown destination node id: $destinationNodeId.');
    }

    if (startNodeId == destinationNodeId) {
      final point = _nodes[startNodeId]!;
      return RouteResult.available(
        geometry: List<GeoPoint>.of(<GeoPoint>[point], growable: false),
        distanceMeters: 0.0,
      );
    }

    final best = <String, double>{startNodeId: 0.0};
    // predecessor node id and the edge taken to reach each settled node
    final cameFromNode = <String, String>{};
    final cameFromEdge = <String, _Edge>{};
    final settled = <String>{};
    final heap = _MinHeap()..push(startNodeId, 0.0);

    while (!heap.isEmpty) {
      final (current, dist) = heap.pop();
      if (settled.contains(current)) {
        continue;
      }
      // Lazy deletion: skip stale heap entries.
      if (dist > (best[current] ?? double.infinity)) {
        continue;
      }
      settled.add(current);
      if (current == destinationNodeId) {
        break;
      }
      final edges = _adjacency[current];
      if (edges == null) {
        continue;
      }
      for (final edge in edges) {
        if (settled.contains(edge.to)) {
          continue;
        }
        final candidate = dist + edge.lengthM;
        if (candidate < (best[edge.to] ?? double.infinity)) {
          best[edge.to] = candidate;
          cameFromNode[edge.to] = current;
          cameFromEdge[edge.to] = edge;
          heap.push(edge.to, candidate);
        }
      }
    }

    if (!settled.contains(destinationNodeId)) {
      return const RouteResult.unavailable();
    }

    // Reconstruct the ordered edge path start -> destination.
    final edgePath = <_Edge>[];
    var cursor = destinationNodeId;
    while (cursor != startNodeId) {
      final edge = cameFromEdge[cursor]!;
      edgePath.add(edge);
      cursor = cameFromNode[cursor]!;
    }
    final orderedEdges = edgePath.reversed.toList(growable: false);

    final geometry = <GeoPoint>[];
    var distanceMeters = 0.0;
    for (final edge in orderedEdges) {
      distanceMeters += edge.lengthM;
      for (final point in edge.geometry) {
        // De-duplicate the shared junction vertex between consecutive edges.
        if (geometry.isNotEmpty &&
            geometry.last.$1 == point.$1 &&
            geometry.last.$2 == point.$2) {
          continue;
        }
        geometry.add(point);
      }
    }

    return RouteResult.available(
      geometry: List<GeoPoint>.of(geometry, growable: false),
      distanceMeters: distanceMeters,
    );
  }

  static double _finiteCoord(Object? value, String label) {
    if (value is! num || !value.isFinite) {
      throw FormatException('$label must be a finite number.');
    }
    return value.toDouble();
  }
}
