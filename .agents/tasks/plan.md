# Implementation Plan — TUNTON AI offline Dart logic layer

Scope gate (root AGENTS.md + docs/PRD.md + docs/ARD.md + docs/ARCHITECTURE.md): this plan creates ONLY the four approved ARD §3 backend files plus their tests. P0 IDs: P0-03, P0-04 (matcher), P0-08 (landmark), P0-09, P0-10, P0-12 (route_result + routing). No new packages, no new directories, no network/db/server, no second model, no OCR/GPS. Approved packages only: flutter, image, tflite_flutter, cupertino_icons. Pubspec package name is `tuntun` (pre-existing typo) — import `package:tuntun/...`. Dart SDK ^3.12.2 (records + patterns available).

Style contract (confirmed by reading lib/features/recognition/embedding_service.dart + test/embedding_service_test.dart): plain Dart classes, static factory `load()` for IO, `List<double>` embeddings already L2-normalized, `FormatException` for bad data / `StateError` for bad lifecycle, no external packages beyond `image`/`tflite_flutter`, no Riverpod, no code-gen, plain immutable classes with `const` constructors where possible, `List<...>.filled(..., growable: false)` style. Tests use `package:flutter_test/flutter_test.dart` and plain `test(...)` / `expect(...)` / `throwsFormatException`.

Data contracts (confirmed against the real files on disk):
- `assets/landmarks/landmarks.json`: JSON array of 6 objects, each EXACTLY `{"id":String,"name":String,"lat":double,"lon":double,"route_node_id":String}`. First id `fort-santiago`, route_node_id `"1034882636"`. All 6 route_node_ids resolve to real graph nodes.
- `assets/landmarks/reference_embeddings.json`: `{"model_id":"bundled-mobilenetv3-small-embedder","dimension":1024,"references":[{"landmark_id":String,"image_asset":String,"vector":[1024 doubles, L2-normalized]}]}`. 23 references: 4 each except `puerta-real` has 3. All landmark_id values exist in landmarks.json. Vector norms ≈ 1.0.
- `assets/maps/intramuros_graph.json`: `{"nodes":[{"id":String,"lat":double,"lon":double}],"edges":[{"from":String,"to":String,"length_m":double,"geometry":[[lat,lon],...]}]}`. 3268 nodes, 7245 DIRECTED edges, 5 one-way-only pairs (no reverse). Coordinate convention `[latitude, longitude]`. All `length_m` finite and > 0 (min ≈ 0.175). geometry endpoints correspond to from/to node coords.

Verification commands (from AGENTS.md §9): `flutter pub get`, `flutter analyze`, `flutter test test/<file>`. Tests must be the real verification — no grep checks. Note: `flutter test` runs only Dart `*_test.dart`; the Python `prepare_dataset_*` tests are out of this task's scope.

---

## Decided public API (implementer MUST use these exact shapes; do not re-decide)

### lib/shared/models/landmark.dart (P0-08) — dependency-free

```dart
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
  /// Throws FormatException when: id/name/route_node_id missing/blank (after trim),
  /// lat not in [-90,90], lon not in [-180,180], or lat/lon non-finite / not num.
  factory Landmark.fromJson(Map<String, dynamic> json);

  /// Parses the whole catalog string (a JSON array). Throws FormatException if the
  /// top-level JSON is not a List, any element is not a Map, any element fails
  /// Landmark.fromJson, or two entries share the same id (duplicate-id rejection).
  /// Returns a growable:false list in file order.
  static List<Landmark> listFromJsonString(String jsonString);
}
```
Notes: use `num` cast then `.toDouble()` so integer JSON (e.g. `0`) is accepted. Equality not required for P0; may add `==`/`hashCode` only if a test needs it (it does not).

### lib/shared/models/route_result.dart (P0-09, P0-10, P0-12) — dependency-free

```dart
/// A single ordered geographic point in [latitude, longitude] order (matches the
/// graph coordinate convention). Dependency-free local type (NOT latlong2).
typedef GeoPoint = (double lat, double lon);

class RouteResult {
  /// Available route. `geometry` is the ordered polyline reconstructed by
  /// concatenating edge geometries in traversal order; `distanceMeters` is the
  /// summed length_m along the path. Both required and finite; distance >= 0.
  const RouteResult.available({
    required this.geometry,          // List<GeoPoint>, growable:false, >= 2 points
    required this.distanceMeters,    // double, finite, >= 0
  }) : isAvailable = true;

  /// First-class "no connected path" state (P0-12). NOT a zero-length route and
  /// NOT a straight line. geometry is empty, distanceMeters is 0.
  const RouteResult.unavailable()
      : geometry = const <GeoPoint>[],
        distanceMeters = 0,
        isAvailable = false;

  final List<GeoPoint> geometry;
  final double distanceMeters;
  final bool isAvailable;

  /// ETA RULE (ARD §7.7, PRD §10): 4.5 km/h = 75 m/min.
  /// etaMinutes = distanceMeters / metersPerMinute. For unavailable, returns 0.
  static const double metersPerMinute = 75.0;
  double get etaMinutes => isAvailable ? distanceMeters / metersPerMinute : 0.0;
}
```
Rationale for the two-named-constructor + `bool isAvailable` shape over a sealed class: it is the smallest first-class representation, matches the plain-class style of embedding_service.dart, and lets UI do `if (result.isAvailable)` without pattern-match boilerplate. `GeoPoint` as a record (`(double,double)`) keeps it dependency-free per the task; order is `[lat, lon]` to match graph geometry exactly so no axis-swap is ever needed.

### lib/features/recognition/landmark_matcher.dart (P0-03, P0-04) — dependency-free math

```dart
/// One ranked candidate: a distinct landmark id and its RAW best cosine similarity
/// (dot product of two L2-normalized vectors). NOT a calibrated probability.
class LandmarkCandidate {
  const LandmarkCandidate(this.landmarkId, this.score);
  final String landmarkId;   // matches an id in landmarks.json
  final double score;        // raw cosine similarity in roughly [-1, 1]
}

/// Result of matching one query embedding. `candidates` is 0..3 distinct landmark
/// ids sorted by score descending. `isRecognized` is true iff at least one
/// candidate passed the threshold (P0-04 "Not recognized" is first-class).
class MatchResult {
  const MatchResult(this.candidates);
  final List<LandmarkCandidate> candidates; // growable:false, length 0..3
  bool get isRecognized => candidates.isNotEmpty;
  LandmarkCandidate? get top => candidates.isEmpty ? null : candidates.first;
}

class LandmarkMatcher {
  LandmarkMatcher._(this._dimension, this._refsByLandmark, this.scoreThreshold);

  static const String referenceAsset =
      'assets/landmarks/reference_embeddings.json';

  /// Conservative default rejection THRESHOLD (ranking signal, not probability).
  /// Default 0.55: a true held-out match of these L2-normalized MobileNetV3
  /// embeddings scores well above this, while unrelated photos fall below. Tunable.
  static const double defaultScoreThreshold = 0.55;

  final int _dimension;
  // landmark_id -> list of that landmark's reference vectors (each length _dimension)
  final Map<String, List<List<double>>> _refsByLandmark;
  final double scoreThreshold;

  /// Build from already-parsed JSON (preferred for tests — no IO).
  /// Validates: dimension is a positive int; references non-empty; each vector
  /// length == dimension and all finite; landmark_id non-blank. Throws
  /// FormatException on any violation. maxCandidates default 3.
  factory LandmarkMatcher.fromDecodedJson(
    Map<String, dynamic> json, {
    double scoreThreshold = defaultScoreThreshold,
  });

  /// Convenience: parse a JSON string then delegate to fromDecodedJson.
  factory LandmarkMatcher.fromJsonString(
    String jsonString, {
    double scoreThreshold = defaultScoreThreshold,
  });

  /// Convenience loader reading the bundled asset via rootBundle.
  /// (flutter/services import is allowed — it is part of Flutter, not a new package.)
  static Future<LandmarkMatcher> load({
    double scoreThreshold = defaultScoreThreshold,
  });

  int get dimension => _dimension;

  /// ARD §6 steps 5-7. query must have length == dimension and all finite, else
  /// FormatException. For each landmark compute MAX cosine similarity across its
  /// reference vectors; sort landmarks by that best score descending; drop any
  /// below scoreThreshold; keep at most `maxCandidates` (default 3) DISTINCT ids.
  /// Returns MatchResult (empty candidates == Not recognized).
  MatchResult match(List<double> query, {int maxCandidates = 3});
}
```
Rationale for threshold default 0.55: the task requires a conservative, tunable, documented ranking threshold and forbids a calibrated %; 0.55 is a named constant the implementer can retune against held-out evidence. Cosine = plain dot product because both the query (from embedding_service.normalizeEmbedding) and every stored reference vector are already L2-normalized — do NOT re-normalize. `load()` uses `rootBundle.loadString` (`package:flutter/services.dart`), consistent with Flutter asset access and adding no package.

### lib/features/navigation/routing_service.dart (P0-09, P0-10) — pure-Dart Dijkstra

```dart
class RoutingService {
  RoutingService._(this._nodes, this._adjacency);

  static const String graphAsset = 'assets/maps/intramuros_graph.json';

  // node id -> (lat, lon)
  final Map<String, GeoPoint> _nodes;
  // from-node id -> outgoing directed edges (DIRECTED: from->to only)
  final Map<String, List<_Edge>> _adjacency;

  /// Build from already-parsed graph JSON (preferred for tests — no IO).
  /// Validates: nodes list of {id,lat,lon} with unique non-blank ids and finite
  /// coords; edges list of {from,to,length_m,geometry}; length_m finite and > 0;
  /// from/to reference known node ids; geometry a non-empty list of [lat,lon]
  /// pairs. Throws FormatException on any violation. Builds DIRECTED adjacency
  /// (each edge added to _adjacency[from] only — never the reverse).
  factory RoutingService.fromDecodedJson(Map<String, dynamic> json);

  factory RoutingService.fromJsonString(String jsonString);

  /// Convenience loader reading the bundled asset via rootBundle.
  static Future<RoutingService> load();

  bool hasNode(String id);

  /// Dijkstra over DIRECTED edges weighted by length_m.
  /// CONTRACT (chosen, be consistent):
  ///   - Unknown startNodeId or destinationNodeId (not in graph) => throw
  ///     FormatException. These are programmer/data errors, not user outcomes.
  ///   - Valid ids but no connected directed path => RouteResult.unavailable()
  ///     (P0-12) — NEVER a straight line.
  ///   - start == destination (both valid) => available route, single point
  ///     [node coord], distanceMeters 0.0, etaMinutes 0.0.
  ///   - Success: reconstruct ordered node path start->dest; concatenate each
  ///     traversed edge's `geometry` IN TRAVERSAL ORDER into one polyline,
  ///     de-duplicating the shared vertex between consecutive edges; sum
  ///     length_m for distanceMeters; return RouteResult.available(...).
  RouteResult findRoute(String startNodeId, String destinationNodeId);
}

// Private edge record: destination node, weight, ordered geometry.
class _Edge { final String to; final double lengthM; final List<GeoPoint> geometry; ... }

// Private binary min-heap keyed by tentative distance (dart:collection has no PQ).
class _MinHeap { void push(String node, double dist); (String,double) pop(); bool get isEmpty; }
```
Rationale for the invalid-id-vs-unavailable split: an unknown node id means the caller passed something not in the catalog/graph (a bug or malformed data) — fail loudly with FormatException; a valid-but-unreachable pair is a legitimate runtime outcome the UI must show as "Route unavailable", so it returns `RouteResult.unavailable()`. Geometry concatenation de-duplicates the shared endpoint vertex between consecutive edges so the polyline has no repeated point at each node junction. Heap is a minimal array-based binary min-heap (lazy-deletion: pop skips stale entries whose popped distance exceeds the recorded best) to get O(E log V) without a PQ package.

---

## Ordered implementation items

- [ ] 1. Create `lib/shared/models/landmark.dart` with the `Landmark` class, `Landmark.fromJson`, and `static List<Landmark> listFromJsonString(String)` exactly per the API above. Dependency-free (`dart:convert` only). Validate blank id/name/routeNodeId, lat∈[-90,90], lon∈[-180,180], non-finite rejection, and duplicate-id rejection in `listFromJsonString`.
      Files: lib/shared/models/landmark.dart
      Verify: `flutter analyze lib/shared/models/landmark.dart` reports no errors (test added in item 5).

- [ ] 2. Create `lib/shared/models/route_result.dart` with the `GeoPoint` typedef, `RouteResult.available`, `RouteResult.unavailable`, `isAvailable`, `distanceMeters`, `geometry`, `metersPerMinute = 75.0`, and `etaMinutes` getter exactly per the API above. Dependency-free.
      Files: lib/shared/models/route_result.dart
      Verify: `flutter analyze lib/shared/models/route_result.dart` reports no errors (test added in item 6).

- [ ] 3. Create `lib/features/recognition/landmark_matcher.dart` with `LandmarkCandidate`, `MatchResult`, and `LandmarkMatcher` (`fromDecodedJson`, `fromJsonString`, async `load`, `match`) exactly per the API above. Cosine = dot product (no re-normalization); max-per-landmark; sort desc; drop below `scoreThreshold`; cap at `maxCandidates` distinct ids. Validate query length == dimension and finite (FormatException). Imports: `dart:convert`, `package:flutter/services.dart` (rootBundle) only — no new package.
      Files: lib/features/recognition/landmark_matcher.dart
      Verify: `flutter analyze lib/features/recognition/landmark_matcher.dart` reports no errors (tests added in item 7).

- [ ] 4. Create `lib/features/navigation/routing_service.dart` with `RoutingService` (`fromDecodedJson`, `fromJsonString`, async `load`, `hasNode`, `findRoute`), private `_Edge` and `_MinHeap`, exactly per the API above. DIRECTED adjacency (never add reverse). Dijkstra weighted by `length_m`; unknown ids throw FormatException; disconnected pair returns `RouteResult.unavailable()`; success concatenates edge geometries in traversal order with shared-vertex de-dup and sums `length_m`. Imports: `dart:convert`, `package:flutter/services.dart`, and `package:tuntun/shared/models/route_result.dart` only.
      Files: lib/features/navigation/routing_service.dart
      Verify: `flutter analyze lib/features/navigation/routing_service.dart` reports no errors (tests added in item 8).

- [ ] 5. Create `test/landmark_test.dart` (plain `test(...)` style). Cover: valid `fromJson`; integer lat/lon accepted; blank id/name/route_node_id rejected (`throwsFormatException`); lat 90.1 and lon 180.1 rejected; NaN/Infinity rejected; `listFromJsonString` parses the real catalog shape and preserves order; duplicate-id string rejected; also load the REAL `assets/landmarks/landmarks.json` via `File('assets/landmarks/landmarks.json').readAsStringSync()` and assert 6 landmarks and first id `fort-santiago` / route_node_id `1034882636`.
      Files: test/landmark_test.dart
      Verify: `flutter test test/landmark_test.dart` — all tests pass.

- [ ] 6. Create `test/route_result_test.dart`. Cover: `available` holds geometry + distance; `etaMinutes` math — 150 m => 2.0 min, 75 m => 1.0 min; `unavailable()` has `isAvailable == false`, empty geometry, `etaMinutes == 0.0`, and is DISTINCT from a zero-length available route (`available(geometry:[p], distanceMeters:0)` has `isAvailable == true`).
      Files: test/route_result_test.dart
      Verify: `flutter test test/route_result_test.dart` — all tests pass.

- [ ] 7. Create `test/landmark_matcher_test.dart`. Synthetic cases over a small dimension built with `fromDecodedJson`: max-per-landmark aggregation, descending sort, top-3-distinct cap (4+ landmarks => only 3 returned), below-threshold => `isRecognized == false` (Not recognized), query wrong length => `throwsFormatException`, query with NaN => `throwsFormatException`. REAL case: load `assets/landmarks/reference_embeddings.json`, build matcher, feed a stored reference vector as the query, and assert its own landmark ranks `top.landmarkId` #1 with score ≈ 1.0.
      Files: test/landmark_matcher_test.dart
      Verify: `flutter test test/landmark_matcher_test.dart` — all tests pass.

- [ ] 8. Create `test/routing_service_test.dart`. Hand-made tiny graph via `fromDecodedJson`: assert shortest-path node order, summed distance, geometry concatenation order (traversal order, shared-vertex de-dup), a one-way edge is NOT traversable backward (reverse direction => `unavailable`), disconnected pair => `unavailable`, start==destination => available single-point zero-distance, unknown node id => `throwsFormatException`. REAL case: load `assets/maps/intramuros_graph.json` + `assets/landmarks/landmarks.json`, route `fort-santiago` route_node (`1034882636`) -> `puerta-real` route_node (`9834302082`); assert `isAvailable`, `distanceMeters > 0`, geometry length >= 2, `etaMinutes > 0`.
      Files: test/routing_service_test.dart
      Verify: `flutter test test/routing_service_test.dart` — all tests pass.

- [ ] 9. Full-suite verification. Run the project's gate commands and confirm the new Dart tests and the pre-existing Dart tests all pass and analysis is clean.
      Files: (none)
      Verify: `flutter pub get` then `flutter analyze` (no new issues) then `flutter test test/landmark_test.dart test/route_result_test.dart test/landmark_matcher_test.dart test/routing_service_test.dart` — all pass. (Do not add assets to pubspec; tests read assets via dart:io `File`, so no pubspec change is required.)

## Notes / assumptions
- Asset reading in tests uses `dart:io File(...)` with the repo-relative path (as the existing `preprocessing_parity_test.dart` already does), so NO `flutter:assets:` pubspec change is needed and scope stays additive.
- `LandmarkMatcher.load()` / `RoutingService.load()` use `rootBundle` (part of Flutter via `package:flutter/services.dart`) — this is Flutter itself, not a new package, and is the standard offline asset path for the real screens that will call these later (those screens are OUT of scope here).
- `landmark.dart` and `route_result.dart` have zero inter-dependency and no package imports; `landmark_matcher.dart` depends on nothing in this set; `routing_service.dart` depends only on `route_result.dart`. Hence the order: models first, then the two services, then tests.
