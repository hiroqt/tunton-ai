# ARCHITECTURE — TUNTON AI Flutter Offline MVP

**Authority:** Visual explanation of `PRD.md` P0 and `ARD.md` contracts, not a second set of product requirements. **Platform:** One Android phone. **Data coverage:** Bundled Intramuros pilot area. **Offline rule:** After installation, the phone needs neither internet nor a running Mac/backend.

## 1. System boundaries

The whole production system is **one Flutter APK**. Its runtime comprises:

- Flutter UI (photo → candidates → offline map → route preview).
- **One** packaged image embedding checkpoint executing through `tflite_flutter`.
- A small, local set of verified landmark metadata and precomputed reference embeddings.
- Map tiles supplied as app assets and rendered by `flutter_map`.
- A finite, local pedestrian graph and **pure Dart Dijkstra** route search.

A Python/OSMnx preparation step may run on a developer's Mac to **create bundled files**, but **never** serves requests to the phone at demo time.

```mermaid
flowchart TD
    A[Flutter camera or gallery] --> B[Dart image preprocessing]
    B --> C[On-device TFLite MobileNetV3 Small embedder]
    C --> D[Query embedding normalization]
    D --> E[Cosine similarity and per-landmark ranking]
    R[(Packaged reference embeddings)] --> E
    E --> F{Reliable supported candidates?}
    F -->|No| G[Not recognized]
    F -->|Yes| H[User confirms landmark]
    L[(Verified landmark catalog)] --> H
    H --> I[Offline Flutter map and destination pin]
    T[(Bundled raster tiles)] --> I
    I --> J[User manually picks mapped origin]
    J --> K[Dart Dijkstra walking path]
    W[(Bundled pedestrian graph)] --> K
    K --> M{Connected path?}
    M -->|No| N[Route unavailable]
    M -->|Yes| O[Polyline plus distance and estimated ETA]
```

**Do not add:** external server, online map/geocoder, user login, cloud AI call, live GPS feed, camera-based AR, or a second inference pipeline.

## 2. Model integration architecture

### Primary model path (only P0 option)

| Decision | Contract |
|---|---|
| Checkpoint | Google MediaPipe **MobileNetV3 Small Image Embedder** |
| Official binary | https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite |
| Phone path | `assets/models/landmark_embedder.tflite` |
| Flutter entry | `lib/features/recognition/embedding_service.dart` |
| Runtime | `tflite_flutter`; use one interpreter; CPU-first |
| Expected function | Produce an embedding vector for one preprocessed photo |
| Coordinates | **Never** produced by the model; obtained only by catalog ID lookup |

**Tensor validation comes before any UI integration:** Examine model metadata and actual tensor shapes/dtypes; establish RGB decoding, resize/crop, pixel scale and normalization. High-level MediaPipe documentation is **not** a substitute for checking raw TFLite inputs. Confirm a usable embedding output, not classifier logits. Compute the reference index using **the identical checkpoint and preprocessing** as the installed app.

### MobileCLIP: replacement candidate, not an additional architecture layer

The Hugging Face repository https://huggingface.co/anton96vice/mobileclip2_tflite publishes a **community-converted MobileCLIP-S1** TFLite checkpoint (`mobileclip_s1_datacompdr_last.tflite`). Its availability does **not** establish that it exposes the desired image embedding through your exact Flutter runtime. Its ~340 MB file size adds packaging cost.

- **P0 state:** Not bundled; no model selector, second interpreter, model-specific screens, or multi-model interfaces.
- **Only allowed reassessment:** If held-out photo tests make MobileNetV3 inadequate, team explicitly decides to **replace** it, verifies candidate image-output compatibility and licensing, and re-indexes all reference photos.
- **Never blend** MobileNetV3 and MobileCLIP embedding vectors or describe Apple's official MobileCLIP2-S0 PyTorch checkpoint as TFLite-ready.

## 3. User interaction sequence

```mermaid
sequenceDiagram
    actor User
    participant UI as Flutter UI
    participant AI as TFLite embedder (phone)
    participant Index as Local landmark files
    participant Map as Offline flutter_map
    participant Route as Dart Dijkstra
    User->>UI: Take/select photo
    UI->>AI: Preprocess and run one image
    AI-->>UI: Embedding vector
    UI->>Index: Compare with saved reference embeddings
    Index-->>UI: Ranked unique candidates or unknown
    UI-->>User: Show candidates; request confirmation
    User->>UI: Confirm supported landmark
    UI->>Index: Resolve verified coordinates and graph node
    Index-->>Map: Selected destination
    Map-->>User: Bundled map + destination pin
    User->>Map: Select valid manual start point
    Map->>Route: Origin node + destination node
    Route-->>Map: Connected graph geometry and length, or unavailable
    Map-->>User: Path, meters, estimated minutes / error
```

The `Index` participant means **bundled local JSON data accessed inside the app**, not a database server or new service.

## 4. One-time build-time preparation versus app runtime

| Build-time, on developer Mac | Runtime, on Android phone |
|---|---|
| Download permitted landmark reference photos and validate labels | Choose/capture one user photo |
| Download and record exact official model checkpoint | Run the **packaged** MobileNetV3 TFLite image embedder |
| Produce reference embeddings with same checkpoint and preprocessing | Compare current embedding against bundled reference vectors |
| Obtain verified Intramuros POI locations and walkable graph from OSM-derived data | Read local landmark catalog and pedestrian graph |
| Obtain/build licensed offline raster tiles, register assets | Render packaged raster tiles offline |
| Verify coordinate and graph connectivity | Compute connected shortest pedestrian path in Dart |
| Create and sign Android APK | Operate independently in airplane mode |

All inputs necessary for the demo must ship within the installed application. Development-time downloads are fine; runtime dependency on those hosts is not.

## 5. Reference dataset and location integrity

The image matching model solves **which supported landmark does this photo resemble?**, not **where is the camera?**. The lookup from a recognized ID to geographic coordinates is deterministic.

```text
Landmark ID  ─┬─> verified name + lat/lon   → map destination
              ├─> graph route_node_id      → walking path start/end
              └─> 3–5 reference photo IDs   → indexed local embeddings
```

Constraints:

- Begin with **six** supported Intramuros landmarks and a handful of licensed photos for each.
- Use distinct held-out query photos for judging, with an out-of-catalog set for rejection tests.
- Aggregate similarity across photos for each landmark, then return at most **three distinct landmark IDs**.
- Similarity is a ranking metric, not a percentage certainty. Require user confirmation.
- Coordinates are manually verified or retrieved/validated from OpenStreetMap **during dataset preparation**, not predicted by model or fetched online during use.

## 6. Offline map + pedestrian routing architecture

Two different data products are needed; one cannot substitute for the other.

| Data | Where packaged | What it does |
|---|---|---|
| Raster map tiles | `assets/tiles/{z}/{x}/{y}.png` | Visual display: buildings, paths, labels, etc. |
| POI catalog | `assets/landmarks/landmarks.json` | Verified names, coordinates, graph-backed route nodes |
| Walk graph | `assets/maps/intramuros_graph.json` | Machine-readable connected pedestrian edges, `length_m`, actual geometry |

**Routing procedure:** user origin ID + confirmed destination ID → validate within pilot area → map to known pedestrian nodes → Dijkstra over actual allowed edge lengths → reconstruct edge geometries in correct order → polyline in `flutter_map` → display distance and ETA = distance / 75 meters per minute (4.5 km/h). If no connected path, return **Route unavailable**. Do not create direct-line substitutes.

**Coordinate contract:** graph geometry uses `[latitude, longitude]` arrays in `ARD.md`; GeoJSON often uses `[longitude, latitude]`, so normalize during preparation. The renderer receives correctly ordered Flutter `LatLng` points.

**Navigation limitation:** This is a route **preview**, not current-position turn-by-turn guidance. The app doesn't know if gates, paths or entries are currently accessible; no live alerts or closures.

## 7. Existing file ownership — no new layers

| Existing location | Owns |
|---|---|
| `lib/features/camera/photo_screen.dart` | Camera / gallery input and image errors |
| `lib/features/recognition/embedding_service.dart` | Single TFLite checkpoint, preprocessing and inference |
| `lib/features/recognition/landmark_matcher.dart` | Index reading, cosine ranking, uncertainty/rejection |
| `lib/features/recognition/recognition_screen.dart` | Candidate display and confirmation |
| `lib/features/map/offline_map_screen.dart` | Bundled tile map and manual start selection |
| `lib/features/map/landmark_markers.dart` | Offline landmark markers |
| `lib/features/navigation/routing_service.dart` | Graph routing and distance/ETA |
| `lib/features/navigation/navigation_screen.dart` | Route result overlay and error |
| `lib/shared/models/{landmark,route_result}.dart` | Fixed DTOs within the above P0 flow |
| `lib/main.dart`, `lib/app/app.dart` | Bootstrap and minimal Riverpod state wiring |
| `tools/prepare_dataset.py` | Mac-only asset/index/graph preprocessing and validation |

Exact asset names and data shapes are defined in `ARD.md`. Do not create additional providers, repositories, BLoCs, use-case layers, or APIs if P0 works using these files.

## 8. Failure paths and user honesty

| Condition | UI response | Forbidden fallback |
|---|---|---|
| Unreadable file | Choose another photo | Silent success |
| Missing/incompatible model | Model unavailable | Cloud inference |
| Non-finite/incorrect embedding | Recognition unavailable | Random vector / fake candidate |
| Unfamiliar / ambiguous photo | **Not recognized** or candidate confirmation | Fabricated coordinates |
| Missing tiles | Offline map unavailable | Online tile fetching |
| Missing/invalid landmark node | Location unavailable | Nearest unverified building center |
| Disconnected graph | **Route unavailable** | Straight-line drawing |
| 8 GB device crashes/slows | Document failure and optimize within P0 | Claim hardware compatibility without testing |

## 9. Proof that the cloud is absent

A judge-facing **release Android build** should:

1. Install while network access is permitted for developer setup if needed.
2. Enter airplane mode; disconnect USB / Mac app-server dependency.
3. Cold-launch the app.
4. Match a previously unseen image of a supported landmark using on-phone AI.
5. Confirm destination; view the bundled map, select a manual origin, calculate a real walking route.
6. Show error handling with an unknown image or disconnected graph case.
7. Provide recorded actual model latency, route latency and memory usage on the lowest tested phone; disclose if 8 GB compatibility remains unverified.

No cloud inference, network tiles, analytics, telemetry, maps SDK, Google Maps API, or other runtime requests.

## 10. Links and authority

- `PRD.md`: exactly what must be built and how it will be accepted.
- `ARD.md`: locked dependencies, file tree, model and JSON contracts.
- `AGENTS.md`: instructions that prevent feature creep.
- `SETUP.md`: environment, model download, asset preparation, Android build.
- `TECH_STACK.md`: reason each runtime technology is needed.
- Source references: [Google image embedder](https://developers.google.com/edge/mediapipe/solutions/vision/image_embedder), [community MobileCLIP files](https://huggingface.co/anton96vice/mobileclip2_tflite), [Flutter TFLite plugin](https://pub.dev/packages/tflite_flutter), [flutter_map offline](https://docs.fleaflet.dev/tile-servers/offline-mapping), [OSM attribution and tile rules](https://operations.osmfoundation.org/policies/tiles/).
