# ARD — TUNTON AI Architecture & Requirements Design

**Authority:** Implements `PRD.md` only; no additions are authorized by this document.  
**Target:** Flutter Android demo running fully on one 8 GB RAM smartphone.  
**Design principle:** Small, deterministic, and completely offline at runtime.

## 1. Architecture in one sentence

A single Flutter app loads a bundled MobileNetV3 Small TFLite image embedder and offline landmark vectors, renders bundled local map tiles, and routes over a bundled pedestrian graph using pure Dart.

```text
Camera / Gallery
       |
       v
 Flutter image preprocessing
       |
       v
 TFLite MobileNetV3 Small embedder     assets/models/landmark_embedder.tflite
       |
       v
 Normalize query vector
       |
       v
 Cosine comparison ------------------- assets/landmarks/reference_embeddings.json
       |                               assets/landmarks/landmarks.json
       v
 Top 3 distinct landmarks / Unknown
       |
       v
 User confirms destination
       |
       +--> flutter_map offline tiles - assets/tiles/
       |
       v
 Manual starting-point selection
       |
       v
 Dart Dijkstra ----------------------- assets/maps/intramuros_graph.json
       |
       v
 Route polyline + distance + ETA
```

**No runtime backend, HTTP service, cloud geocoder, remote database, Google Maps SDK, or Ollama.** The Python preparation script is not shipped as a mobile service.

## 2. Architecture decisions (locked)

| Decision | Selected option | Why / constraint |
|---|---|---|
| Mobile UI | Flutter + Dart | One device-local mobile codebase. |
| Demo target | Android | Must ship a tested APK inside one day; iOS is not an acceptance requirement. |
| Vision | MobileNetV3 Small Image Embedder TFLite | Low-overhead on-device image vectors; no hosted model. |
| Inference API | `tflite_flutter` | Bundled interpreter on the phone. |
| Similarity | Cosine similarity in Dart | Tens of references do not need FAISS or a vector database. |
| Offline basemap | `flutter_map` + bundled raster tiles with `AssetTileProvider` | No tile requests to a server. |
| Route data | One vetted pedestrian graph in JSON | Full navigation service is unnecessary. |
| Routing | Dijkstra shortest path in Dart | Deterministic, testable graph traversal. |
| Location input | Recognized landmark + manually selected start | Avoids false precision from images and live GPS dependency. |
| Data storage | Read-only bundled JSON / image / TFLite assets | No database engine required. |
| State | `flutter_riverpod` | Keep only current photo, match state, selected points, and route. |

## 3. Approved code and asset boundaries

Follow this existing MVP shape. The standard files created by `flutter create` and generated package files are permitted; do not invent other architectural layers or folders.

```text
tunton/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   └── app.dart
│   ├── features/
│   │   ├── camera/
│   │   │   └── photo_screen.dart
│   │   ├── recognition/
│   │   │   ├── embedding_service.dart
│   │   │   ├── landmark_matcher.dart
│   │   │   └── recognition_screen.dart
│   │   ├── map/
│   │   │   ├── offline_map_screen.dart
│   │   │   └── landmark_markers.dart
│   │   └── navigation/
│   │       ├── routing_service.dart
│   │       └── navigation_screen.dart
│   └── shared/
│       └── models/
│           ├── landmark.dart
│           └── route_result.dart
├── assets/
│   ├── models/
│   │   └── landmark_embedder.tflite
│   ├── maps/
│   │   └── intramuros_graph.json
│   ├── tiles/
│   │   └── {z}/{x}/{y}.png
│   ├── landmarks/
│   │   ├── landmarks.json
│   │   └── reference_embeddings.json
│   └── images/
│       └── [bundled, licensed landmark photos]
├── tools/
│   └── prepare_dataset.py
├── android/                  # Flutter-generated
├── ios/                      # Flutter-generated; not a hackathon demo target
└── pubspec.yaml
```

`tools/prepare_dataset.py` is a **build-time-only** helper for normalizing/validating downloaded OSM pedestrian data, landmark IDs, coordinates, and precomputed embeddings. No new Python runtime, second backend, database, or agent modules.

## 4. Fixed local data contracts

### `assets/landmarks/landmarks.json`

Each landmark record has:

```json
{
  "id": "landmark-001",
  "name": "Verified landmark name",
  "lat": 0.0,
  "lon": 0.0,
  "route_node_id": "n001"
}
```

**Rules:** `lat`/`lon` are verified in the pilot region; `route_node_id` corresponds to a valid pedestrian graph vertex near a walkable entrance. Example numbers are schema placeholders only. Use unique IDs and actual prepared coordinates.

### `assets/landmarks/reference_embeddings.json`

```json
{
  "model_id": "bundled-mobilenetv3-small-embedder",
  "dimension": 128,
  "references": [
    {
      "landmark_id": "landmark-001",
      "image_asset": "assets/images/example-01.jpg",
      "vector": [0.0, 0.0]
    }
  ]
}
```

**Schema illustration only:** The vector shown is truncated and the `dimension` is a placeholder. Use the **actual** TFLite output dimension and store complete finite, normalized vectors. Match each reference to a known `landmark_id`. The model used to produce the reference vectors **must be exactly the model included in the APK**, with the same preprocessing. Fail early if model ID, tensor shape, or vector dimension does not match.

### `assets/maps/intramuros_graph.json`

```json
{
  "nodes": [
    {"id": "n001", "lat": 0.0, "lon": 0.0},
    {"id": "n002", "lat": 0.0, "lon": 0.0}
  ],
  "edges": [
    {
      "from": "n001",
      "to": "n002",
      "length_m": 45.0,
      "geometry": [[0.0, 0.0], [0.0, 0.0]]
    }
  ]
}
```

**Rules:** Coordinates in graph JSON use `[latitude, longitude]`, then convert to `LatLng` for Flutter; never swap with GeoJSON's `[longitude, latitude]` convention. Use real geometry, positive lengths, verified pedestrian-only connections, and explicit directionality where applicable. Dijkstra should preserve edge geometry instead of inventing straight lines between geographically distant vertices.

### `assets/tiles/{z}/{x}/{y}.png`

- Ship raster tiles only for the chosen Intramuros coverage and zoom range.
- Register all relevant asset directories in `pubspec.yaml`; `AssetTileProvider` requires correct asset registration.
- No fallback to network tile providers or online fonts/labels.
- Show OSM attribution and comply with licensing and tile-source redistribution rights.
- Tiles, graph nodes, and landmarks must describe the **same coverage area**.

## 5. On-device inference sequence

1. User selects a single photo via `image_picker`.
2. Decode and resize using Dart `image`, applying the bundled model's exact expected RGB layout, input type, normalization, and dimensions.
3. Load the model once through `tflite_flutter`. Inspect tensors and verify supported input/output configuration.
4. Run inference on one image. Extract the **embedding output tensor**, not generic ImageNet classification labels.
5. L2-normalize the query embedding; reject malformed or zero vectors.
6. Compute cosine similarity against the stored normalized vectors.
7. Aggregate per-landmark (e.g., best reference similarity) and return top three **different landmarks**, never multiple entries for the same place.
8. Apply a rejection rule established using held-out examples; if no reliable result, display **Not recognized**. Similarity scores are ranking signals, **not calibrated location confidence percentages**.
9. User confirms a candidate; `landmarks.json` provides its **verified** coordinates and mapped route node.

**Integration risk:** A MediaPipe task model can contain metadata/preprocessing assumptions. Using the raw TFLite interpreter bypasses MediaPipe task preprocessing. Verify the actual tensor layout and normalization instead of assuming a particular RGB normalization or output size. Test one known reference-vs-query pair before integrating the UI.

## 6. Route computation sequence

1. Destination is the user-confirmed landmark's `route_node_id`.
2. User selects one valid start landmark/graph-backed marker on the map.
3. Read the corresponding origin route node and reject unknown IDs/out-of-bounds selection.
4. Run Dijkstra using `length_m` as edge weight on the bundled pedestrian graph.
5. If no valid connected path exists, respond **Route unavailable**; do not substitute a straight line.
6. Reconstruct the graph edge geometry into an ordered polyline; render with `flutter_map`.
7. Sum the actual edge lengths for total distance. Estimate walk time = `distance_m / 75` minutes (4.5 km/h), rounded for display.
8. Show that route information is preloaded and **not based on live closures, traffic, or GPS tracking**.

## 7. UI boundaries

Only these app states/screens are needed:

- **Photo screen:** camera/gallery choice, image preview, loading, invalid-image error.
- **Recognition screen:** up to three candidate landmarks, user confirmation, explicit unknown result.
- **Offline map screen:** local map tiles, selected destination marker, manual start selection, bundled POI markers.
- **Navigation screen:** plotted walking path, distance, walking ETA, unavailable-route message.

No authentication, onboarding wizard, settings system, dashboards, chat tab, or multi-day journey features.

## 8. Data and device readiness gates

**Before integration:**
- Bundled model loads on an Android phone and produces a stable embedding.
- The reference index is produced with the same model and preprocessing, and at least one held-out photo matches meaningfully.
- The map has offline tiles for the chosen location.
- The graph connects at least one known pair of landmarks and produces a real non-straight edge path.

**Before judging:**
- Cold-launch in airplane mode and complete the full user journey.
- Run an unknown-photo test and a disconnected-route test.
- Measure recognition inference time, route calculation time, and peak memory on target hardware.
- Confirm the app does not require a laptop, local HTTP service, or internet after installation.

## 9. Failure/edge state contract

| Condition | Required UI behavior |
|---|---|
| Model absent or incompatible | Recognition unavailable; explain local model problem; no fake matches. |
| Invalid/unreadable photo | Request a different photo. |
| Unknown or ambiguous image | Show **Not recognized** or candidate list requiring explicit selection. |
| No start point chosen | Do not calculate route; prompt for manual start. |
| Selected points outside supported map | Explain map coverage limit. |
| Graph nodes disconnected | Show **Route unavailable**; do not draw a direct line. |
| Tiles missing | Surface incomplete offline map error; never silently call a network tile service. |

## 10. Scope gate

Any implementation decision that adds cloud/network services, a new backend, another vision model, OCR, live tracking, alternate routing modes, or data beyond Intramuros is **rejected** unless the user explicitly changes the PRD. Do not add speculative abstractions, new code folders, or future-facing modules.

**References:**
- https://pub.dev/packages/tflite_flutter
- https://docs.fleaflet.dev/tile-servers/offline-mapping
- https://github.com/google-ai-edge/mediapipe-samples-web/blob/main/src/tasks/image-embedder.ts
- https://operations.osmfoundation.org/policies/tiles/
