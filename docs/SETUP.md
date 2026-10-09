# SETUP.md — TUNTON AI Flutter Android MVP

> **Audience:** Hackathon teammates, co-developers, and demo operators.  
> **Build window:** One day. **Required demo:** physical Android phone. **Minimum hardware target:** 8 GB RAM (must be measured on an actual 8 GB device).  
> **Scope:** Photo → local MobileNetV3 Small embedding → up to 3 landmark candidates → user confirmation → bundled Intramuros map → manually selected start → local walking route, distance, and ETA.

This guide is **setup, asset handoff, run, and test documentation only**. It does **not** add product features, runtime dependencies, methods, or source-code folders. If instructions conflict, `PRD.md` defines what must exist, `ARD.md` defines where/how, and `AGENTS.md` restricts implementation. Read those documents before coding.

## 0. Know what you are setting up

- **Developer machine:** MacBook Air M5 running macOS. Internet is permitted to install developer tools, Python preparation libraries, open-source model weights, and properly licensed map data **before the offline demo**.
- **Demo target:** One physical **Android** phone. The final release APK performs AI inference and routing on the phone; no Mac, localhost service, Python process, or internet is needed once installed.
- **Geographic coverage:** **Intramuros, Manila only**. Begin with six distinctive, verified landmarks and approximately 3–5 correctly labeled reference photos per landmark.
- **On-device AI:** One bundled **MobileNetV3 Small image embedder** TFLite checkpoint. **Not** an ImageNet classifier, GPT/LLM, OCR engine, or remote inference service.
- **Local mapping/navigation:** `flutter_map` + bundled authorized raster tiles; a separate vetted pedestrian graph; shortest walking path via Dijkstra in Dart.
- **Excluded:** EXIF/GPS location inference, live position tracking, worldwide geolocation, iOS demo work, dynamic map downloads, server/backend, user accounts, and additional packages/models.

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
flutter pub add tflite_flutter image_picker image flutter_map latlong2 flutter_riverpod
flutter pub get
flutter analyze
```

Do **not** add `google_maps_flutter`, geolocation/GPS plugins, OCR, FAISS, Ollama, HTTP clients, database servers, cloud SDKs, or a second state-management system.

`image_picker` on Android normally needs no additional Android permission configuration. If your particular Android SDK or package version requires a compatibility change, use only the standard Flutter-generated Android project files; do not build a new native feature.

## 3. Required project assets (must be real, not placeholders)

The existing `ARD.md` is the canonical file tree. These specific assets must be available **before** a functional offline demo:

```text
assets/
  models/landmark_embedder.tflite
  landmarks/landmarks.json
  landmarks/reference_embeddings.json
  maps/intramuros_graph.json
  tiles/{z}/{x}/{y}.png
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

### 3E. Obtain LEGALLY distributable offline map tiles

Obtain or produce a **small raster tile bundle licensed for offline packaging and redistribution**, matching the chosen Intramuros area and zoom range. Store tiles using this exact convention:

`assets/tiles/{z}/{x}/{y}.png`

**Never scrape or prefetch `tile.openstreetmap.org` into the APK.** The OpenStreetMap Foundation explicitly prohibits bulk downloading and offline use of its standard public tile server. Use a provider/data source that affirmatively permits offline redistribution, or render tiles from appropriately licensed OSM geographic source data during preparation. [OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/).

The runtime map uses `flutter_map`'s `AssetTileProvider`, not an online `NetworkTileProvider`. Keep **© OpenStreetMap contributors** visible, along with any required additional attribution from the actual tile provider. Verify that the map visually covers the exact graph and photo landmarks.

**Important asset trap:** Flutter does **not** automatically include all nested files under `assets/tiles/` when only the top-level directory is declared. Register **every actual lowest-level tile directory** in `pubspec.yaml`. To enumerate those directories on macOS:

```bash
find assets/tiles -type f -name '*.png' \
  | sed 's#/[^/]*$#/#' \
  | sort -u \
  | sed 's#^#    - #'
```

Copy the output under `flutter: assets:`; keep the paths that **actually exist**, not examples or placeholders. Do **not** write an online tile URL or fallback into the app. Official guidance: [flutter_map offline tile providers](https://docs.fleaflet.dev/layers/tile-layer/tile-providers).

## 4. Register bundled assets in `pubspec.yaml`

Keep the packages and asset tree exactly within `ARD.md`. In the existing `flutter:` section, register the concrete files below **plus your real nested tile directory paths**:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/models/landmark_embedder.tflite
    - assets/landmarks/landmarks.json
    - assets/landmarks/reference_embeddings.json
    - assets/maps/intramuros_graph.json
    - assets/images/
    # Add the real assets/tiles/<z>/<x>/ directories here.
    # Do not leave this comment as your only tile registration.
```

If your `assets/images/` folder has no usable images yet, do not declare it until the images exist. Maintain the indentation of the existing `pubspec.yaml` and avoid a duplicate `flutter:` block.

Once all assets exist and are registered:

```bash
flutter pub get
flutter analyze
```

**Pass:** Flutter successfully bundles the TFLite checkpoint, reference JSON, map graph, photos, and all required Intramuros tiles. **Fail/blocker:** missing asset, incomplete tile coverage, or model/data mismatch.

## 5. Run the app on the phone (connected development)

First pick the physical phone from `flutter devices`. Then:

```bash
flutter run -d <android-device-id>
```

Replace `<android-device-id>` with the actual device ID. This command runs a developer build; **do not** use a debug build as final evidence of resource efficiency.

### Minimum functional smoke test

1. Open the photo screen; choose or take one **unseen supported** landmark photo.
2. Confirm the TFLite model runs **on the phone** and returns candidates from local embeddings.
3. Choose the correct landmark; confirm its marker is placed at a stored verified coordinate.
4. Select a supported **manual starting point** on the bundled Intramuros map.
5. Confirm the route follows actual walking graph geometry, with distance and estimated walking time (fixed 4.5 km/h).
6. Test an **unknown photo** and a **disconnected route**. Expected outcomes are **Not recognized** and **Route unavailable**.

## 6. Build the release APK and install it

```bash
flutter analyze
flutter build apk --release
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

1. Finish installing the APK, permissions, model, and all local assets while development internet is still available.
2. On the Android phone, **enable airplane mode**, verify Wi-Fi **and mobile data** are disabled, and leave them disabled for the full demo. GPS is not required.
3. **Force-close** TUNTON (not merely background it) and **cold-launch** the installed release app.
4. Pick a held-out landmark photo. Verify recognition executes without any Mac/localhost connection.
5. Confirm a landmark, choose a manual start, and render the actual bundled map and pedestrian route.
6. Verify distance/ETA and the offline failure states (`Not recognized`, `Route unavailable`).
7. Repeat once with a different supported landmark photo. If one resource fails without internet, the offline test **fails** until corrected.
8. As an additional independence check, unplug USB and keep the Mac disconnected; the app must still run standalone.

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
| Map is blank offline | Verify licensed tile files, every leaf tile directory registration, map coverage, zoom range, `AssetTileProvider`. | Add an online map fallback. |
| Route appears straight/unrealistic | Validate graph connectivity, verified landmark node IDs, edge geometry, lat/lon order and Dijkstra reconstruction. | Draw a straight point-to-point polyline as a substitute. |
| `Route unavailable` for known landmarks | Validate pedestrian graph and entrances; check directed/undirected edges and disconnected components. | Invent pedestrian connectors. |
| Slow/low-memory phone | One interpreter instance, one image at a time, small region/tiles, compact embeddings, CPU-only baseline. | Load additional LLMs or add background processes. |

## 9. Co-developer handoff and responsibilities

**No new code layout or services.** Use the exact existing files/ownership in `AGENTS.md` and `ARD.md`.

| Track | Required handoff to integration |
|---|---|
| Vision | Bundled `.tflite`, verified tensor/preprocessing spec, complete `reference_embeddings.json`, held-out matching result. |
| Map/data | Verified `landmarks.json`, licensed `assets/tiles/` coverage, actual `intramuros_graph.json`, working mapped origin/destination pair. |
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
- [ ] Licensed offline tiles render at the required area and zoom levels.
- [ ] Pedestrian graph has real geometry and confirmed connected landmark pairs.
- [ ] Unknown/ambiguous photos and disconnected graph cases fail safely.
- [ ] `flutter analyze` passes and **release APK installs**.
- [ ] Cold-launch in airplane mode works without USB/Mac/network services.
- [ ] App memory and recognition/routing times recorded on the target phone.
- [ ] If 8 GB device testing was impossible, limitation is disclosed; compatibility is **not** asserted as proven.

**Final product scope:** One Android Flutter app, one on-device TFLite embedder, one prepackaged Intramuros map and walking graph, one confirmed-landmark destination, one manually selected origin, and one offline walking-route preview.
