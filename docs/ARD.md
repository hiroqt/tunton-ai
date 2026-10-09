# ARD — TUNTON AI Application Requirements & Design

**Status:** Implementation contract for `PRD.md` P0 only · **Android-first Flutter** · **No runtime server** · **One bundled TFLite vision embedder**.

## 1. Architecture decision record

| Concern | Selected technology / rule | Why it exists |
|---|---|---|
| Mobile runtime | **Flutter + Dart**, Android release APK | Local, portable interactive UI with on-device computation |
| State | `flutter_riverpod` | Only current photo, candidates, selected destination/origin and route |
| Photo capture | `image_picker` | Camera or gallery input |
| Image preprocessing | Dart `image` package | Decode, convert, resize and normalize according to *actual* model tensor requirements |
| ML runtime | **`tflite_flutter`**, CPU-first | Run single local `.tflite` model directly on phone; physical Android device, API 26+ for documented package setup |
| Primary model | **Google MobileNetV3 Small Image Embedder** | Create reusable visual feature vectors, **not GPS** |
| Matching | L2-normalized cosine similarity **in Dart** | Rank tens of precomputed vectors without FAISS or database |
| Map UI | `flutter_map` + `latlong2` + bundled raster tiles with `AssetTileProvider` | Render offline Intramuros tiles and route overlay |
| Map source | Legally sourced OpenStreetMap-derived data | Local pedestrian geometry, landmark coordinates, OSM attribution |
| Route computation | **Pure Dart Dijkstra** over bundled JSON graph | Offline deterministic shortest walkable route |
| Storage | Read-only Flutter asset JSON, raster tiles, reference images and checkpoint | No database, network services, syncing or online asset retrieval |
| Preparation tools | Python and optionally OSMnx **on developer Mac only** | Precompute verified walking graph and image reference index before packaging |

Approved preparation-only packages (user decision, 2026-10-09): `ai-edge-litert`, `numpy`, `Pillow`, and `osmnx`, in an isolated Python environment. These prepare licensed photos, run the same MobileNetV3 checkpoint, export OSM-derived walking data, and render bundled raster tiles. They are not Android runtime dependencies. Backend evaluation photos and source/license records live under `test/datasets/` and are excluded from the APK; team-held-out photos belong in `test/datasets/held_out/team/`.

Project dataset restriction (user decision, 2026-10-09): every collected reference, held-out, and unknown-test photo must depict a documented Philippine location. Preparation source records require `country: PH`, a named location, and geographic source evidence. Map data remains the Intramuros pilot extract. This restriction describes the project dataset, not the original pretraining corpus of the approved general-purpose MobileNetV3 checkpoint.

Do not add dependencies because they are familiar or trendy. `image_picker`, `image`, `tflite_flutter`, `flutter_map`, `latlong2`, and `flutter_riverpod` are the only application-level packages approved for the P0 workload (plus Flutter itself / transitive dependencies).

## 2. Model artifacts and decision gate

### Primary approved model

- **Name:** MobileNetV3 Small **Image Embedder** (Google MediaPipe).
- **Official download:** https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite
- **Local APK asset:** `assets/models/landmark_embedder.tflite`.
- **Model role:** Image → numerical embedding used for similarity to supported reference photos. It does **not** infer coordinates or provide walking directions.
- **Runtime:** `tflite_flutter` with explicitly validated RGB input, tensor layout/shape/type, preprocessing, output dimensions and normalization. MediaPipe's high-level Tasks API handles preprocessing automatically, but raw TFLite does not. Copying a guess from a different MobileNet variant is unacceptable.

### Alternative source — documentation only, not part of P0 implementation

- **Name:** Community MobileCLIP-S1 TFLite checkpoint.
- **Hugging Face:** https://huggingface.co/anton96vice/mobileclip2_tflite
- **Candidate artifact:** `mobileclip_s1_datacompdr_last.tflite` (approximately 340 MB as listed by the repository).
- **Important provenance:** A **community conversion** of MobileCLIP S1. Apple's **MobileCLIP2-S0** at https://huggingface.co/apple/MobileCLIP2-S0 is a different official **PyTorch** checkpoint and is **not** plug-and-play `.tflite`.
- **Decision:** Do not download, bundle, initialize or expose a model selector for MobileCLIP as part of P0. Explicit approval to **replace** the model is required if accuracy is inadequate. A replacement must satisfy a working Android TFLite embedding-output test and regenerate the whole reference index. Do not combine vectors from two checkpoints.

## 3. Approved code tree — no speculative modules

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
│   ├── landmarks/
│   │   ├── landmarks.json
│   │   └── reference_embeddings.json
│   ├── maps/
│   │   └── intramuros_graph.json
│   ├── tiles/
│   │   └── {z}/{x}/{y}.png
│   └── images/
│       └── [licensed reference landmark images]
├── tools/
│   └── prepare_dataset.py
├── android/                # generated by Flutter
└── pubspec.yaml
```

The standard project/test/build artifacts created by `flutter create` are fine. No extra app folders, alternative backend, persistence layer, analytics pipeline or second runtime are permitted.

## 4. Fixed data contracts

### `assets/landmarks/landmarks.json`

Use real verified data; never ship placeholders like `0.0` below:

```json
[
  {
    "id": "landmark-001",
    "name": "Verified place name",
    "lat": 0.0,
    "lon": 0.0,
    "route_node_id": "n001"
  }
]
```

Each ID is unique, coordinates lie inside the pilot area, and `route_node_id` references a **walkable entrance or connected graph node**, not an arbitrary building centroid.

Approved dataset decision (2026-10-09): where OSM has no permitted pedestrian connector to the actual entrance, San Agustin and Baluarte de San Diego use an explicitly named **exterior public street approach**. The landmark marker and route endpoint are distinct recorded points. Routes stop at the mapped approach; no final connector, private-gate crossing, or current-access guarantee is implied. Endpoint source evidence and offsets are recorded in the backend map snapshot.

### `assets/landmarks/reference_embeddings.json`

```json
{
  "model_id": "bundled-mobilenetv3-small-embedder",
  "dimension": 0,
  "references": [
    {
      "landmark_id": "landmark-001",
      "image_asset": "assets/images/example-01.jpg",
      "vector": []
    }
  ]
}
```

This is a **schema illustration only**, not usable data. In the real file:

- `dimension` equals **the actual output tensor embedding length**.
- `vector` contains that exact number of finite values and is nonzero and L2-normalized.
- `model_id` and model checksum correspond to the bundled checkpoint. Checksum may be recorded in docs; do **not** add an unapproved runtime field unless necessary to prevent mismatch.
- `landmark_id` exists in `landmarks.json` and the reference photo is properly licensed.
- Every vector is computed using **identical model weights and identical image preprocessing** as the phone app.

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
      "length_m": 50.0,
      "geometry": [[0.0, 0.0], [0.0, 0.0]]
    }
  ]
}
```

**Coordinate convention:** `nodes` and `geometry` in this contract use **[latitude, longitude]** as stated; GeoJSON uses **[longitude, latitude]** and must be transformed during preparation, not silently interchanged.

- `length_m` must be finite and greater than zero; edge `geometry` must match the real mapped pedestrian path.
- Edges represent **permitted walking transitions**. Preserve one-way restrictions where available. Do not automatically treat all edges as bidirectional without checking semantics.
- The graph must have connected walkable paths for selected demo landmark pairs.
- Dijkstra uses `length_m`; reconstruct result from stored edge geometries, not just node-to-node straight line segments.

### Bundled tiles: `assets/tiles/{z}/{x}/{y}.png`

- One small Intramuros coverage area with enough registered zoom levels for the demo.
- Keep tiles, POIs, path graph and test landmarks spatially aligned.
- `AssetTileProvider` reads assets; no online tiles or fonts as fallback.
- Use an authorized offline tile archive/source and **© OpenStreetMap contributors** attribution. Do not bulk-fetch from prohibited public OSM tile services.

## 5. Behavior contracts by existing files

| File | One responsibility | P0 |
|---|---|---|
| `photo_screen.dart` | Choose or capture one photo, show preview/error | P0-01 |
| `embedding_service.dart` | Load one checkpoint, inspect tensors, preprocess, infer one image, normalize vector | P0-02 |
| `landmark_matcher.dart` | Read reference index, compare cosine scores, aggregate per distinct landmark, reject unreliable input | P0-03, P0-04 |
| `recognition_screen.dart` | Present up to three candidates, require confirmation | P0-05 |
| `landmark.dart` | Model verified local ID, name, lat/lon, route-node ID | P0-08 |
| `offline_map_screen.dart` | Render bundled map, selected destination and manual start | P0-06, P0-07 |
| `landmark_markers.dart` | Render supported POI markers from catalog | P0-06 |
| `routing_service.dart` | Read graph; run Dijkstra; reconstruct actual edge path; compute distance and estimated ETA | P0-09, P0-10 |
| `route_result.dart` | Hold route points, distance, ETA and route-unavailable state | P0-09, P0-10, P0-12 |
| `navigation_screen.dart` | Show route line, distance/ETA or unavailable state | P0-10, P0-12 |
| `app.dart` / `main.dart` | Wire the single flow and current Riverpod state | P0-01–P0-12 |
| `tools/prepare_dataset.py` | Build-time dataset normalization/precomputation/validation only | Input preparation |

## 6. Visual embedding algorithm contract

1. Decode one chosen photo; reject decode failure and unsupported large input before allocating unnecessary memory.
2. Inspect actual TFLite input/output tensor shapes/types and metadata. Verify the preprocessing (RGB channels, resize/crop, pixel scale, normalization); do not guess.
3. Load exactly one interpreter and reuse it. Default to CPU compatibility; acceleration is not a P0 dependency.
4. Compute one embedding; verify finite nonzero values and expected length; L2-normalize.
5. Compare query embedding with each stored normalized reference vector using cosine similarity (dot product for normalized vectors).
6. Reduce to **best similarity per landmark**, sort, and keep top 3 *distinct IDs*.
7. Use held-out true/unknown examples to choose a **conservative rejection rule**, not an arbitrary fabricated accuracy percentage. Unclear image yields **Not recognized** or candidates requiring confirmation.
8. Resolve confirmed ID through `landmarks.json`. Never let ML outputs generate coordinates.

## 7. Pedestrian routing contract

1. Confirmed photo match becomes destination ID and `route_node_id`.
2. User manually picks a known graph-backed start location.
3. Reject unknown/out-of-region start or destination.
4. Run Dijkstra across permitted directed edges, weighted by `length_m`.
5. If no route, display **Route unavailable**, not a straight line.
6. Reconstruct ordered stored geometries; use `latlong2` LatLng points for Flutter map route overlay.
7. Distance is sum of traversed `length_m`, ETA minutes = distance meters / **75 m/min** (4.5 km/h), with an explicit estimate label.
8. No GPS guidance, navigation rerouting, current closure data or travel-time guarantees.

## 8. Readiness gates

- **Gate A: Model:** Flutter loads the true image embedder, outputs correct nonzero embeddings, and matches a held-out landmark photo on real Android.
- **Gate B: Data:** Six real landmark locations, matching reference embeddings, licensed images, valid graph-backed nodes, legal offline tile source.
- **Gate C: Routing:** One genuine connected walking path and a disconnected-path error both behave correctly.
- **Gate D: Offline:** Installed release APK cold-starts and completes full P0 flow in airplane mode **without Mac connection**.
- **Gate E: Device:** Measure inference latency, route latency and actual memory on an 8 GB device, or state compatibility remains unverified.

## 9. Explicit exclusions

No OCR, GPS/EXIF, cloud, HTTP, server, Qwen/Gemma/GLM, multi-model runtime, downloadable maps, state framework changes, database, live turn-by-turn assistance, or generated mock coordinates/routes as product evidence. If a P0 fix appears to require architecture expansion, ask for approval first.

## 10. References

- Image embedder: https://developers.google.com/edge/mediapipe/solutions/vision/image_embedder
- Official model download: https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite
- MobileCLIP alternative (not bundled): https://huggingface.co/anton96vice/mobileclip2_tflite
- TFLite Flutter: https://pub.dev/packages/tflite_flutter
- Offline mapping: https://docs.fleaflet.dev/tile-servers/offline-mapping
- OSM tile usage: https://operations.osmfoundation.org/policies/tiles/
