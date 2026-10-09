# SETUP.md — TUNTON AI Flutter Android MVP

> **Audience:** Hackathon teammates, co-developers, and demo operators.  
> **Build window:** One day. **Required demo:** physical Android phone. **Minimum hardware target:** 8 GB RAM (must be measured on an actual 8 GB device).  
> **Scope:** Connected Mapbox region download → photo → local MobileNetV3 Small embedding → up to 3 landmark candidates → user confirmation → offline Intramuros map → manually selected start → local walking route, distance, and ETA.

This guide is **setup, asset handoff, run, and test documentation only**. It does **not** add product features, runtime dependencies, methods, or source-code folders. If instructions conflict, `PRD.md` defines what must exist, `ARD.md` defines where/how, and `AGENTS.md` restricts implementation. Read those documents before coding.

## 0. Know what you are setting up

- **Developer machine:** MacBook Air M5 running macOS. Internet is permitted to install developer tools, Python preparation libraries, and model weights; the Android app downloads the Mapbox offline region from Mapbox while connected before the offline demo.
- **Demo target:** One physical **Android** phone. The release APK performs AI inference and routing on the phone. Mapbox requires an initial connected download of the offline region after installation; after that completes, the demo needs no Mac, localhost service, Python process, or internet.
- **Geographic coverage:** **Intramuros, Manila only**. Begin with six distinctive, verified landmarks and approximately 3–5 correctly labeled reference photos per landmark.
- **On-device AI:** One bundled **MobileNetV3 Small image embedder** TFLite checkpoint. **Not** an ImageNet classifier, GPT/LLM, OCR engine, or remote inference service.
- **Mapping/navigation:** `mapbox_maps_flutter` with one SDK-managed Intramuros offline region downloaded while connected; a separate vetted pedestrian graph; shortest walking path via Dijkstra in Dart.
- **Excluded:** EXIF/GPS location inference, live position tracking, worldwide geolocation, iOS demo work, additional map regions, server/backend, user accounts, and additional models.

## 1. Prerequisites (install once on the Mac)

You need:

1. Flutter SDK on your PATH, Dart (ships with Flutter), Git, and an editor.
2. Android Studio and Android SDK packages: **SDK Platform**, **Platform-Tools**, **Command-line Tools**, and whichever build tools `flutter doctor` requests.
3. Android phone with **8 GB RAM for compatibility testing**, Android **API level 26 or newer** for the selected `tflite_flutter` package version, a USB data cable, and USB debugging enabled.
4. **Python 3.12** for `tools/prepare_dataset.py` on the developer machine **only**. The approved isolated preparation environment uses LiteRT 2.3.0, NumPy 2.5.3, Pillow 12.3.0, and OSMnx 2.1.1. Python is **not installed on the phone**.

Official references: [Flutter installation](https://docs.flutter.dev/install/custom), [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup), and [tflite_flutter](https://pub.dev/packages/tflite_flutter).

Check existing tools before installing duplicates:

```bash
flutter --version
flutter doctor -v
python3 --version
```

If `flutter` is not found, install the Flutter SDK using Flutter's macOS installation guide, add its `bin/` to your shell PATH, open a fresh terminal, then repeat the commands. Install Android Studio/SDK using its SDK Manager rather than manually inventing SDK paths. Resolve **Android toolchain** errors reported by `flutter doctor` first; unrelated iOS warnings do not block this Android-only demo.

```bash
flutter doctor --android-licenses
flutter doctor -v
```

### Connect and verify the real Android phone

On Android: **Settings → About phone → tap Build number repeatedly** (menu wording varies) → **Developer options → USB debugging**. Connect over USB and approve the debugging authorization prompt.

```bash
flutter devices
adb devices
```

**Pass:** Your physical Android phone is listed and authorized. **Blocker:** `unauthorized`, missing device, or incompatible API level; fix cable/permissions/Android tooling **before** building AI code.

## 2. Get the repository and approved dependencies

If the Flutter repository already exists, **do not recreate or overwrite it**. Clone or open the team's existing repository, then enter the Flutter project root (the directory containing `pubspec.yaml`):

```bash
# Only when cloning an existing team repository:
# git clone <team-repository-url> tunton
cd tunton
```

If no repository/project exists yet, create the single approved Android Flutter app and then place the four governing Markdown documents plus this setup guide in its root:

```bash
flutter create --platforms=android tunton
cd tunton
```

Install **only** the dependencies approved by `ARD.md`:

```bash
flutter pub add tflite_flutter image_picker image mapbox_maps_flutter flutter_riverpod
flutter pub get
flutter analyze
```

Do **not** add `google_maps_flutter`, `flutter_map`, geolocation/GPS plugins, OCR, FAISS, Ollama, unrelated HTTP clients, database servers, cloud inference SDKs, or a second state-management system. Follow Mapbox's current official Flutter installation guide and pin a release compatible with the repository's actual Flutter/Dart version.

`image_picker` on Android normally needs no additional Android permission configuration. If your particular Android SDK or package version requires a compatibility change, use only the standard Flutter-generated Android project files; do not build a new native feature.

## 3. Required project assets (must be real, not placeholders)

The existing `ARD.md` is the canonical file tree. These specific assets must be available **before** a functional offline demo:

```text
assets/
  models/landmark_embedder.tflite
  landmarks/landmarks.json
  landmarks/reference_embeddings.json
  maps/intramuros_graph.json
  images/                         # properly licensed landmark reference photos
```

All files must describe **the same Intramuros coverage**. Do not treat a downloaded model alone as a working product, or fabricate coordinates / routes when map data is missing.

### 3A. Download the one approved local AI checkpoint

This official MediaPipe example references the MobileNetV3 Small **image embedder** checkpoint. Download it **during preparation**; package the downloaded bytes into the APK:

```bash
mkdir -p assets/models
curl -fL \
  'https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite' \
  -o assets/models/landmark_embedder.tflite

ls -lh assets/models/landmark_embedder.tflite
file assets/models/landmark_embedder.tflite
shasum -a 256 assets/models/landmark_embedder.tflite
```

Reference: [MediaPipe's published image-embedder example](https://github.com/google-ai-edge/mediapipe-samples-web/blob/main/src/tasks/image-embedder.ts).

**Crucial validation gate:** In `lib/features/recognition/embedding_service.dart`, load the checkpoint through `tflite_flutter`, inspect **actual input/output tensor shapes and types**, and verify the tensor represents embeddings. Follow the checkpoint's expected RGB layout, image size, values/normalization, and output handling. **Do not assume** input shape, embedding length, normalization, or that a standard MobileNet classifier has equivalent output.

If the model fails to load or the output is not usable as embeddings through the selected raw TFLite runtime, **report a blocker immediately**. Do not quietly switch to another model or new inference framework without explicit scope approval.

### 3B. Prepare the Intramuros landmark catalog

The map/data teammate supplies **six** distinct recognizable landmarks with verified geographic coordinates and pedestrian graph-backed start/destination node IDs. The fixed catalog file is:

`assets/landmarks/landmarks.json`

Each entry uses the exact `ARD.md` fields:

```json
{
  "id": "landmark-001",
  "name": "Verified landmark name",
  "lat": 0.0,
  "lon": 0.0,
  "route_node_id": "n001"
}
```

**The example above is only a schema.** Never ship the placeholder coordinates. Use verified point coordinates and a **walkable entry point** in the offline graph, not a building centroid that lies behind a wall or inside an inaccessible area.

For the photos, add **3–5 images per landmark**, labeled to match its catalog ID. Check rights/redistribution permissions. Keep separate **unseen** pictures for recognition tests; copying a reference picture into the input does not prove the matcher works on new images.

### 3C. Generate and validate the offline reference embeddings

The AI teammate computes vectors **once during preparation** using the **same checkpoint and same preprocessing** that the Flutter runtime uses. This is preparation work within the existing `tools/prepare_dataset.py` responsibility—do not add a runtime server or extra script tree.

Prepare `assets/landmarks/reference_embeddings.json` using the exact ARD contract:

- `model_id`: identifies the bundled checkpoint.
- `dimension`: the **observed** embedding length, not the illustrative ARD placeholder.
- `references`: landmark ID, reference image asset path, complete finite **L2-normalized** vector.

**Acceptance checks before integration:**

- The model loads on the **actual Android phone** and produces an embedding of the expected shape.
- The generated reference vectors match that exact checkpoint and preprocessing.
- At least one **held-out** photo ranks its correct landmark among the top 3 distinct candidates.
- An out-of-area or unrecognized photo can produce **Not recognized**; similarities are **not calibrated confidence percentages**.

If the preparation tooling is not implemented yet, generating `reference_embeddings.json` is a task for the AI teammate; do not invent random vectors or bypass actual inference.

### 3D. Prepare pedestrian map data on the Mac (preparation only)

Install the data-preparation library **on the Mac**, not inside the Android app:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install osmnx
```

Use the single existing approved script path, `tools/prepare_dataset.py`, to obtain/convert a **walking** graph for the chosen Intramuros area, validate the landmark IDs, and export the exact `ARD.md` graph contract into:

`assets/maps/intramuros_graph.json`

If using OSMnx, an applicable data source is a `network_type='walk'` pedestrian graph prepared **online before** the demonstration. Preserve real edge geometry and directionality, edge `length_m`, node IDs, and `[latitude, longitude]` coordinates. Verify at least one nontrivial connected pair of landmarks; if no path exists, the app must report **Route unavailable**, never a straight-line substitute. [OSMnx documentation](https://osmnx.readthedocs.io/).

**No fake fallback:** If the approved graph data is unavailable or does not connect the selected landmarks, fix the input data or report the blocker. Do not draw invented roads.

### 3E. Configure Mapbox and prepare its offline region

Use the official [`mapbox_maps_flutter` SDK](https://docs.mapbox.com/flutter/maps/guides/install/). Mapbox map data must be downloaded from Mapbox by the SDK; Mapbox terms do not allow packaging or redistributing downloaded offline data. Do not put Mapbox tiles or styles under `assets/`, in the repository, or in the APK.

Create a scoped public Mapbox access token. Supply it through build configuration (for example, `--dart-define=ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"`) and keep it out of source control. A mobile public token is recoverable from the APK, so restrict it to the minimum scopes and allowed URLs supported by Mapbox. Do not use a secret token in a client app. Check current account pricing and limits before release because offline downloads make Mapbox service requests.

Use the SDK's `OfflineManager` and `TileStore` to download the fixed Intramuros style and region while connected. Show progress/errors and mark the map ready only after the SDK confirms completion. On later launches, verify the region remains available before entering the offline journey. If it is missing or incomplete, show a clear not-ready state and offer the connected download action. Allow SDK network access only during that explicit download/update; after completion, disable the Mapbox network stack using the pinned SDK's offline switch so missing resources fail visibly instead of triggering an online fallback.

Keep the SDK's Mapbox logo/attribution control visible; it also provides the per-user Mapbox telemetry opt-out required by the SDK terms. The SDK may send de-identified usage/location telemetry by default under its terms. The pedestrian graph remains OSM-derived, so also display **© OpenStreetMap contributors** for that separate data source. Align the Mapbox region and zoom range with the pilot graph and landmarks. See [Mapbox Flutter offline example](https://docs.mapbox.com/flutter/maps/examples/offline/), [Flutter SDK terms and telemetry](https://docs.mapbox.com/flutter/maps/guides/), [offline map restrictions](https://docs.mapbox.com/ios/maps/guides/offline/concepts/), and [installation/token setup](https://docs.mapbox.com/flutter/maps/guides/install/).

## 4. Register bundled assets in `pubspec.yaml`

Keep the packages and asset tree exactly within `ARD.md`. In the existing `flutter:` section, register the concrete bundled files below:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/models/landmark_embedder.tflite
    - assets/landmarks/landmarks.json
    - assets/landmarks/reference_embeddings.json
    - assets/maps/intramuros_graph.json
    - assets/images/
    # Mapbox map data is SDK-managed; do not register it as Flutter assets.
```

If your `assets/images/` folder has no usable images yet, do not declare it until the images exist. Maintain the indentation of the existing `pubspec.yaml` and avoid a duplicate `flutter:` block.

Once all assets exist and are registered:

```bash
flutter pub get
flutter analyze
```

**Pass:** Flutter bundles the TFLite checkpoint, reference JSON, map graph, and photos; connected setup downloads the Mapbox style/region and verifies completion. **Fail/blocker:** missing bundled asset, failed/incomplete region download, or model/data mismatch.

## 5. Run the app on the phone (connected development)

First pick the physical phone from `flutter devices`. Then:

```bash
flutter run -d <android-device-id> --dart-define=ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
```

Replace `<android-device-id>` with the actual device ID. This command runs a developer build; **do not** use a debug build as final evidence of resource efficiency.

### Minimum functional smoke test

1. Open the photo screen; choose or take one **unseen supported** landmark photo.
2. Confirm the TFLite model runs **on the phone** and returns candidates from local embeddings.
3. Choose the correct landmark; confirm its marker is placed at a stored verified coordinate.
4. Select a supported **manual starting point** on the downloaded Mapbox Intramuros map.
5. Confirm the route follows actual walking graph geometry, with distance and estimated walking time (fixed 4.5 km/h).
6. Test an **unknown photo** and a **disconnected route**. Expected outcomes are **Not recognized** and **Route unavailable**.

## 6. Build the release APK and install it

```bash
flutter analyze
flutter build apk --release --dart-define=ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
```

Expected default build artifact:

`build/app/outputs/flutter-apk/app-release.apk`

Install on the phone via USB (the standard `adb` command comes with Android SDK Platform-Tools):

```bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The installation requires the Android signing/build prerequisites to be configured. Do not assume a generated APK is ready until it successfully installs and launches on the target device.

## 7. OFFLINE acceptance test — mandatory before presenting

This checks **real application independence**, not just whether a screen remains cached.

1. Install the APK and configure the scoped public Mapbox token.
2. While connected, download the Mapbox style and fixed Intramuros region; wait for SDK-confirmed completion and verify the visible attribution/telemetry opt-out control.
3. On the Android phone, **enable airplane mode**, verify Wi-Fi **and mobile data** are disabled, and leave them disabled for the full journey. GPS is not required.
4. **Force-close** TUNTON (not merely background it) and **cold-launch** the installed release app.
5. Pick a held-out landmark photo. Verify recognition executes without any Mac/localhost connection.
6. Confirm a landmark, choose a manual start, and render the actual Mapbox offline region and pedestrian route.
7. Verify distance/ETA and the offline failure states (`Not recognized`, `Route unavailable`).
8. Repeat once with a different supported landmark photo. If one resource fails without internet, the offline test **fails** until corrected.
9. As an additional independence check, unplug USB and keep the Mac disconnected; the app must still run standalone.

### Record real evidence

- Test device model, Android version, and **actual installed RAM**.
- Vision model name/checkpoint, measured single-photo recognition time, and whether the image was held out.
- Measured routing time for the demonstrated graph pair.
- Observed app memory footprint during inference and map rendering, including how it was measured.
- Airplane-mode **release** test: passed/failed and date.
- Data coverage limitations and unsupported-photo outcome.

**Memory inspection (developer may use USB for measurement while the phone remains in airplane mode):** Find the app's Android `applicationId` in the existing `android/app/build.gradle` or `build.gradle.kts`, then run:

```bash
adb shell dumpsys meminfo <application-id>
```

Run this at idle, during/after recognition, and while displaying the route. `dumpsys meminfo` is a **snapshot**, not automatically a true peak-memory measurement; if using repeated samples, label the result **highest observed sample**. Do not claim that a 16 GB phone proves performance on an 8 GB phone.

## 8. Fast troubleshooting (only within approved MVP)

| Symptom | Check / fix | Do not do |
|---|---|---|
| `flutter: command not found` | Verify SDK installed, Flutter `bin` on PATH, reopen terminal. | Build a different framework. |
| `flutter doctor` Android toolchain error | SDK Manager components, accepted licenses, configured Android SDK. | Ignore it and claim the APK is ready. |
| Phone not in `flutter devices` | USB data cable, USB debugging, accept authorization, run `adb devices`. | Switch to an emulator for the final proof. |
| TFLite interpreter fails to load | Check checkpoint exists, `pubspec.yaml`, native Android support, Android API level and logs. | Replace with cloud inference / arbitrary new model. |
| Model outputs nonsensical matches | Verify preprocessing and input/output tensor types, exact checkpoint reference vectors, cosine normalization, held-out tests. | Treat ImageNet labels as embeddings or report a fake confidence. |
| App cannot find bundled images/JSON | Check case-sensitive asset path and `pubspec.yaml` indentation, then rerun `flutter pub get`. | Fetch runtime assets from cloud storage. |
| Map is blank offline | Verify Mapbox region/style download completion, persisted SDK store, region coverage, token configuration, and airplane-mode behavior. | Claim readiness or add an online map fallback. Retry the connected download and report a blocker if needed. |
| Route appears straight/unrealistic | Validate graph connectivity, verified landmark node IDs, edge geometry, lat/lon order and Dijkstra reconstruction. | Draw a straight point-to-point polyline as a substitute. |
| `Route unavailable` for known landmarks | Validate pedestrian graph and entrances; check directed/undirected edges and disconnected components. | Invent pedestrian connectors. |
| Slow/low-memory phone | One interpreter instance, one image at a time, small region/tiles, compact embeddings, CPU-only baseline. | Load additional LLMs or add background processes. |

## 9. Co-developer handoff and responsibilities

**No new code layout or services.** Use the exact existing files/ownership in `AGENTS.md` and `ARD.md`.

| Track | Required handoff to integration |
|---|---|
| Vision | Bundled `.tflite`, verified tensor/preprocessing spec, complete `reference_embeddings.json`, held-out matching result. |
| Map/data | Verified `landmarks.json`, completed Mapbox offline region, actual `intramuros_graph.json`, working mapped origin/destination pair. |
| Flutter UI | Photo/candidate/confirmation/map/route flow using the fixed data contracts, clear unknown/no-route error states. |
| QA | Installed release APK, disconnected full-flow test, Android device model/RAM, measured recognition/routing/memory evidence. |

Before merging, each teammate reports only:

```text
P0 requirement(s):
Existing files changed:
Inputs/assets delivered:
Test command(s) and observed result(s):
Offline release-device test: passed / failed / not run
8 GB device evidence: measured / not measured
Blocker:
```

**Stop rule:** When the P0 photo → confirmed landmark → manually selected origin → offline walking route works, fix errors and test it. Do not add OCR, GPS, accounts, another model, cloud integrations, future-platform scaffolding, or unnecessary libraries.

## 10. Ready-to-demo checklist

- [ ] `flutter doctor` shows Android toolchain ready; physical Android device detected.
- [ ] Approved Flutter packages installed; no unapproved runtime packages.
- [ ] Correct MobileNetV3 Small image-embedder model bundled and tensor contract verified.
- [ ] Six verified Intramuros landmarks and correctly labeled images available.
- [ ] Reference vectors computed with **exactly the runtime model and preprocessing**.
- [ ] Mapbox style/region download completes while connected and renders at the required area/zoom levels after cold-launch in airplane mode.
- [ ] Pedestrian graph has real geometry and confirmed connected landmark pairs.
- [ ] Unknown/ambiguous photos and disconnected graph cases fail safely.
- [ ] `flutter analyze` passes and **release APK installs**.
- [ ] Cold-launch in airplane mode works without USB/Mac/network services.
- [ ] App memory and recognition/routing times recorded on the target phone.
- [ ] If 8 GB device testing was impossible, limitation is disclosed; compatibility is **not** asserted as proven.

**Final product scope:** One Android Flutter app, one on-device TFLite embedder, one prepackaged Intramuros map and walking graph, one confirmed-landmark destination, one manually selected origin, and one offline walking-route preview.
