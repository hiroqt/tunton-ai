# TUNTON AI

**Snap a landmark. Know the place. Preview a walking route offline.**

> **Project status:** Working Android-first MVP for device-local visual landmark recognition and offline pedestrian route previews.  
> **Platform:** Flutter / Android (minSdkVersion 26+, optimized for 8 GB RAM target devices).  
> **Primary local AI:** OpenCLIP ViT-B/32 (LAION-2B `laion2b_s34b_b79k`) quantized INT8 ONNX (`assets/models/openclip_vit_b32_laion2b_int8.onnx`, 512 dimensions) running through native Android ONNX Runtime (`onnxruntime-android:1.23.2`) via Flutter MethodChannel `com.tunton/vision`.  
> **Recognition catalog:** 17 verified landmarks across Greater Manila: Intramuros (6), wider Manila (9), Makati (1: SM Makati), and Pasay (1: MRT EDSA Station).  
> **Pedestrian routing:** Intramuros-only deterministic walk previews via pure Dart Dijkstra over a packaged 6,574-node, 14,650-edge pedestrian network.  
> **Offline map:** Bundled offline raster tile archive (`assets/maps/manila_tiles.bin`, 17 MB) rendered locally with `flutter_map` and a custom `ArchiveTileProvider`. *(Note: The PRD originally targeted a Mapbox SDK-managed region download; the current local implementation bundles `manila_tiles.bin` with zero external network dependency. Basemap tile coverage is centered on Intramuros/Manila; Makati/Pasay markers render at their exact coordinates over the tile boundary as documented in [`docs/KNOWN_LANDMARK_GAPS.md`](docs/KNOWN_LANDMARK_GAPS.md)).*

---

## Table of Contents

- [Overview](#overview)
  - [The Problem & Pitch](#the-problem--pitch)
  - [Core Product Journey](#core-product-journey)
  - [Precision Boundary](#precision-boundary)
- [Why Device-Local AI?](#why-device-local-ai)
- [What the MVP Does (P0 Scope)](#what-the-mvp-does-p0-scope)
- [What the MVP Does Not Do](#what-the-mvp-does-not-do)
- [Supported Landmark Catalog](#supported-landmark-catalog)
- [Architecture & Runtime Flow](#architecture--runtime-flow)
- [Technology Stack](#technology-stack)
- [Offline Asset Inventory](#offline-asset-inventory)
- [How Recognition Works](#how-recognition-works)
- [How Offline Navigation Works](#how-offline-navigation-works)
- [Repository Structure](#repository-structure)
- [Build and Run](#build-and-run)
  - [Prerequisites](#prerequisites)
  - [Release Build & Android R8 Configuration](#release-build--android-r8-configuration)
  - [Airplane-Mode Acceptance Test](#airplane-mode-acceptance-test)
- [Verification & Test Results](#verification--test-results)
- [Troubleshooting](#troubleshooting)
- [Privacy, Data Provenance, and Licensing](#privacy-data-provenance-and-licensing)
- [Hackathon Submission Disclosures](#hackathon-submission-disclosures)
- [Documentation Map](#documentation-map)

---

## Overview

### The Problem & Pitch

When exploring historic and urban districts in Metro Manila—such as the walled city of Intramuros or busy transfer hubs in Pasay and Makati—travelers frequently encounter striking landmarks, churches, or gates whose names and histories they do not know. Mobile data inside thick Spanish-era volcanic tuff (*adobe*) walls or during tropical storms is notoriously unreliable, and cellular roaming can be expensive or unavailable for tourists.

**TUNTON AI** solves this without a single cloud dependency:
1. **Take or choose a photo** on an Android phone.
2. A **device-local vision model (OpenCLIP ViT-B/32)** processes the photo and extracts a 512-dimensional semantic embedding.
3. The app executes a **data-driven cosine similarity match** against 59 verified, licensed Philippine landmark reference embeddings.
4. If the photo matches a known landmark with clear statistical confidence, the app **auto-advances** to the place details. If the image is ambiguous, noisy, or unsupported, it gracefully reports **Not recognized** without guessing.
5. If the destination is located within the walkable Intramuros pilot zone, TUNTON places a marker on the **bundled offline tile map**, lets the user choose a start point (manually or via opt-in foreground GPS snapped to the pedestrian graph), and calculates an **offline walking route preview** using pure Dart Dijkstra.
6. If the destination is in Manila, Makati, or Pasay outside the walk network, TUNTON displays the recognized place card and exact coordinates, concluding the recognition-only journey cleanly.

### Core Product Journey

$$\text{Photo} \longrightarrow \text{Native ONNX Embedding} \longrightarrow \text{Data-Driven Rejection/Match} \longrightarrow \text{Verified POI Coordinates} \longrightarrow \text{Offline Map \& Walk Route}$$

### Precision Boundary

- **Landmark depicted, not camera position:** Visual recognition identifies the *subject of the photograph*, **never the photographer's current location**. TUNTON does not infer live coordinates from image pixels or EXIF tags.
- **AI proposes, catalog grounds:** The neural network outputs only visual vectors. Spatial coordinates (`lat`, `lon`) and pedestrian route nodes (`route_node_id`) come exclusively from the verified, human-curated catalog in `assets/landmarks/landmarks.json`.
- **Preview, not certified navigation:** The calculated walking route is a deterministic offline preview over mapped pedestrian paths. It cannot know real-time gate closures, temporary events, or construction hazards.

---

## Why Device-Local AI?

| Factor | Cloud / Server AI Architecture | TUNTON Device-Local AI |
|---|---|---|
| **Connectivity** | Requires stable 4G/5G; fails inside stone walls, basements, or during brownouts. | **100% Airplane Mode:** Fully functional with Wi-Fi and mobile data disabled. |
| **User Privacy** | Photos of tourists, bystanders, and surroundings leave the device. | **Zero Data Egress:** Photos are decoded in memory, embedded locally, and immediately discarded. |
| **Operational Cost** | Ongoing monthly cloud API, GPU inference, and bandwidth hosting costs. | **Zero API Cost:** Free to run indefinitely on user-owned mobile hardware. |
| **Latency** | Network upload latency + remote queue time (1,500 ms – 5,000 ms). | **Predictable On-Device CPU Inference:** ~400–800 ms directly on Android CPU. |
| **Spatial Grounding** | LLMs/VLMs frequently hallucinate coordinates, street names, and directions. | **Zero Hallucination:** Vector similarity only matches catalog IDs; spatial coordinates are strictly hard-grounded. |

---

## What the MVP Does (P0 Scope)

| Feature | Implementation | Priority |
|---|---|---|
| **Photo Input** | Select from gallery or capture via camera using `image_picker`. | P0 |
| **Local Vision Inference** | Run quantized INT8 OpenCLIP ViT-B/32 image encoder locally via native Android ONNX Runtime (`com.tunton/vision`). | P0 |
| **Landmark Matching** | L2-normalized cosine dot product against 59 packaged reference vectors across 17 landmarks. | P0 |
| **Uncertainty & Rejection** | Multi-tiered gate: noise floor ($0.40$), minimum top-1/top-2 margin ($0.07$), and lone strong match threshold ($0.55$). Weak or ambiguous inputs return **Not recognized**. | P0 |
| **Auto-Advance Acceptance** | Confident single-best match automatically advances; weak/near-tie photos require retry. *(Approved P0 change superseding manual candidate list).* | P0 |
| **Area Awareness** | Intramuros POIs continue to offline mapping and routing; Manila, Makati, and Pasay POIs display verified place card and finish the journey. | P0 |
| **Offline Map Display** | Render bundled raster tiles from `assets/maps/manila_tiles.bin` using `flutter_map` and `ArchiveTileProvider` with POI marker overlays. | P0 |
| **Origin Selection** | Choose a start point from verified catalog landmarks or explicitly request foreground GPS snapped to the nearest walk graph node. | P0 |
| **Pedestrian Routing** | Pure Dart Dijkstra over `assets/maps/intramuros_graph.json` (6,574 nodes, 14,650 directed edges). | P0 |
| **Route Result** | Render true ordered edge polyline, total distance in meters, and estimated walking ETA at 4.5 km/h (75 m/min). | P0 |
| **Error Handling** | Transparent states for unreadable photos, out-of-catalog scenes, missing assets, and disconnected paths (**Route unavailable**). | P0 |
| **Offline Proof** | Cold-launch release APK and execute complete flow in airplane mode without network or developer machine connection. | P0 |

---

## What the MVP Does Not Do

The following are **strictly out of scope** and excluded from the codebase:

- **No general-purpose world or citywide geolocation:** The app identifies only the 17 cataloged landmarks, not arbitrary streets or buildings.
- **No LLMs, VLMs, or chatbots:** No Gemma, Qwen, GLM, Llama, Ollama, or conversational assistants.
- **No OCR or sign reading:** Recognition operates purely on visual scene features.
- **No background GPS, turn-by-turn voice prompts, or automatic rerouting:** Foreground GPS is optional and used solely to snap a start node.
- **No driving or cycling routes:** Pedestrian paths only.
- **No backend servers or cloud services:** No FastAPI, Supabase, Firebase, vector databases, or telemetry servers.
- **No map data download during the journey:** All necessary tiles and models are packaged in the app bundle.

---

## Supported Landmark Catalog

The app includes **17 verified landmarks** across 4 key areas in Metro Manila:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        TUNTON LANDMARK CATALOG                         │
├─────────────────────┬──────────────┬──────────────┬────────────────────┤
│ Area                │ Count        │ Routable?    │ Landmarks Included │
├─────────────────────┼──────────────┼──────────────┼────────────────────┤
│ Intramuros          │ 6 POIs       │ Yes (Walk)   │ Fort Santiago      │
│                     │              │              │ Manila Cathedral   │
│                     │              │              │ San Agustin Church │
│                     │              │              │ Casa Manila        │
│                     │              │              │ Baluarte San Diego │
│                     │              │              │ Puerta Real        │
├─────────────────────┼──────────────┼──────────────┼────────────────────┤
│ Manila (Wider)      │ 9 POIs       │ No (Recog.)  │ Binondo Church     │
│                     │              │              │ DLSU Manila        │
│                     │              │              │ FEU Manila         │
│                     │              │              │ Lucky Chinatown    │
│                     │              │              │ Quiapo Church      │
│                     │              │              │ Rizal Park         │
│                     │              │              │ Robinsons Manila   │
│                     │              │              │ SM City Manila     │
│                     │              │              │ UP Manila          │
├─────────────────────┼──────────────┼──────────────┼────────────────────┤
│ Makati              │ 1 POI        │ No (Recog.)  │ SM Makati          │
├─────────────────────┼──────────────┼──────────────┼────────────────────┤
│ Pasay               │ 1 POI        │ No (Recog.)  │ MRT EDSA Station   │
└─────────────────────┴──────────────┴──────────────┴────────────────────┘
```

> **Data Integrity:** Each catalog entry contains verified coordinates matched to OpenStreetMap features. Only Intramuros entries carry a `route_node_id` referencing a valid walking graph entrance node.

---

## Architecture & Runtime Flow

The app operates as a self-contained Flutter application with a native Android ONNX Runtime integration:

```mermaid
flowchart TD
    A[Camera or Gallery Photo] --> B[Dart Image Preprocessing\n224x224 RGB, Bicubic, OpenCLIP Mean/Std]
    B --> C[MethodChannel 'com.tunton/vision'\nPass NCHW float32 tensor]
    C --> D[Native Android ONNX Runtime CPU Session\nopenclip_vit_b32_laion2b_int8.onnx]
    D --> E[Output 512-d Embedding\nL2-Normalized in Dart]
    E --> F[LandmarkMatcher: Cosine Dot Product\nCompare vs 59 Reference Vectors]
    F --> G{Data-Driven Rejection Gate\nFloor: 0.40 | Margin: 0.07 | Strong: 0.55}
    G -->|Weak / Ambiguous / Noise| H[Show 'Not recognized'\nAllow photo retry]
    G -->|Confident Single Best Match| I[Auto-Advance to Destination]
    I --> J{Landmark Area Check\nisRoutable & area_id}
    J -->|Manila / Makati / Pasay| K[Show Recognized POI Card & Coordinates\nCleanly end recognition journey]
    J -->|Intramuros| L[Open OfflineMapScreen\nRender manila_tiles.bin & POI marker]
    L --> M{Start Point Selection}
    M -->|Manual Selection| N[Select mapped Intramuros POI node]
    M -->|Opt-in Foreground GPS| O[Snap current GPS to nearest graph node\nMark connector approximate]
    N --> P[Pure Dart Dijkstra Algorithm\nTraverse intramuros_graph.json]
    O --> P
    P --> Q{Connected Walk Path?}
    Q -->|No Path| R[Display 'Route unavailable'\nNo fake straight lines]
    Q -->|Connected| S[Render Ordered Edge Polyline\nDistance in meters + ETA at 4.5 km/h]
```

---

## Technology Stack

| Layer | Component | Version / Specification | Role in TUNTON AI |
|---|---|---|---|
| **Framework** | Flutter / Dart | Flutter 3.x, Dart ^3.12.2 | Cross-platform mobile UI, state transitions, and business logic |
| **OS Target** | Android | API 26+ (Android 8.0 Oreo or higher) | Primary physical deployment target (8 GB RAM recommended) |
| **Vision Model** | OpenCLIP ViT-B/32 | `laion2b_s34b_b79k` INT8 quantized | Visual feature extractor producing 512-dimensional embeddings |
| **ML Engine** | ONNX Runtime Android | `onnxruntime-android:1.23.2` | Native on-device C++ ONNX inference running via Android JNI |
| **Platform Bridge**| MethodChannel | `com.tunton/vision` | Passes float32 byte buffers between Dart and Android `MainActivity` |
| **Image Handling** | Dart `image` + `image_picker` | `image: ^4.9.1`, `image_picker: ^1.2.4` | EXIF transpose, decode, bilinear/bicubic resize, tensor packing |
| **Matching Engine**| Pure Dart Math | L2-normalized cosine dot product | Threshold filtering, margin gating, top candidate selection |
| **Map Rendering** | `flutter_map` | `flutter_map: ^8.3.2`, `latlong2: ^0.10.1` | Local raster tile rendering with custom `ArchiveTileProvider` |
| **Location** | `geolocator` | `geolocator: ^13.0.2` | Optional foreground GPS fix snapped to nearest graph node |
| **Pathfinding** | Pure Dart Dijkstra | Deterministic directed graph search | Computes shortest walking distance and exact polyline geometry |
| **Offline Data** | Bundled Assets | JSON + BIN + ONNX | Self-contained model, catalog, embeddings, graph, and tiles |
| **Offline Tiles** | Compressed Archive | `assets/maps/manila_tiles.bin` (17 MB) | Custom offline raster tile package unpacked in memory |
| **Build Tools** | Python 3.12 (Mac only) | OpenCLIP, ONNX, Pillow, OSMnx | Precomputes walking graph, exports ONNX, validates dataset |

---

## Offline Asset Inventory

All runtime data is bundled directly within the APK and declared in `pubspec.yaml`:

```text
assets/
├── models/
│   ├── openclip_vit_b32_laion2b_int8.onnx          # 92 MB quantized OpenCLIP vision model
│   └── openclip_vit_b32_laion2b_int8.manifest.json # Model metadata, tensor shapes, and checksums
├── landmarks/
│   ├── landmarks.json                             # 17 cataloged landmarks with verified lat/lon
│   └── reference_embeddings.json                  # 59 L2-normalized 512-d OpenCLIP reference vectors
├── maps/
│   ├── intramuros_graph.json                      # Pedestrian network (6,574 nodes, 14,650 edges)
│   └── manila_tiles.bin                           # 17 MB offline raster map tile archive
├── fonts/
│   ├── Inter-*.ttf                                # Bundled typography (Regular, Medium, SemiBold, Bold)
│   └── Inter-LICENSE.txt                          # SIL Open Font License
└── images/                                        # Reference photos with embedded PNG attribution chunks
    ├── baluarte-san-diego/
    ├── casa-manila/
    ├── fort-santiago/
    ├── manila-cathedral/
    ├── puerta-real/
    ├── san-agustin/
    ├── sm-makati/
    └── mrt-edsa/
```

---

## How Recognition Works

### 1. Preprocessing Contract
Input photos are converted to an NCHW `[1, 3, 224, 224]` float32 tensor matching the exact OpenCLIP configuration:
- EXIF orientation transposed to upright RGB.
- Shortest edge resized to 224 pixels using bicubic sampling.
- Center crop of $224 \times 224$ pixels.
- Pixel normalization via OpenCLIP constants:
  $$\mu = [0.48145466, 0.4578275, 0.40821073], \quad \sigma = [0.26862954, 0.26130258, 0.27577711]$$

### 2. Native Android ONNX Execution
The flattened float array is passed across `MethodChannel('com.tunton/vision')`. In `MainActivity.kt`:
- An `OrtEnvironment` and `OrtSession` run the model on a dedicated background thread.
- Memory allocations are serialized and disposed immediately after inference.
- The resulting 512-dimensional output tensor is returned to Dart.

### 3. Cosine Matching & Mathematical Gating
Because both the query vector $\mathbf{q}$ and reference vectors $\mathbf{r}$ are L2-normalized ($\|\mathbf{q}\|_2 = \|\mathbf{r}\|_2 = 1.0$), cosine similarity simplifies to a fast dot product:
$$\text{sim}(\mathbf{q}, \mathbf{r}) = \mathbf{q} \cdot \mathbf{r} = \sum_{i=1}^{512} q_i r_i$$

For each landmark, the highest similarity across its 3–5 reference vectors is retained. The result passes through a **data-driven three-tier gate**:
1. **Absolute Noise Floor ($0.40$):** Candidates with similarity $< 0.40$ are dropped immediately as background noise.
2. **Ambiguity Margin Gate ($0.07$):** When two or more candidates clear the noise floor, the top match must beat the runner-up by at least $0.07$ ($\text{top}_1 - \text{top}_2 \ge 0.07$). Near-ties are rejected as ambiguous.
3. **Lone Strong Match Gate ($0.55$):** If only a single candidate clears the noise floor, it must score $\ge 0.55$ to avoid false positives on diffuse synthetic or out-of-catalog images.
4. **Outcome:** A qualifying match auto-advances; anything else yields an unambiguous **Not recognized** state.

> **Honesty Principle:** Raw cosine scores are internal ranking metrics. TUNTON never presents similarity values as "calibrated probabilities" or "percentage confidences".

---

## How Offline Navigation Works

1. **Destination Resolution:** An accepted Intramuros photo resolves to its verified `route_node_id` in `landmarks.json`.
2. **Origin Selection:** The user selects a starting landmark or taps **Use my location**. When GPS is requested, the foreground coordinate is snapped to the closest Intramuros graph node using great-circle distance. The connector between the GPS point and the graph node is clearly identified as approximate.
3. **Deterministic Dijkstra Routing:** Pure Dart Dijkstra searches the directed edge list in `intramuros_graph.json` weighted by edge length ($\text{meters}$).
4. **Polyline Reconstruction:** The path is reconstructed from actual recorded edge coordinates ($[\text{latitude}, \text{longitude}]$ pairs), avoiding straight-line shortcuts.
5. **Walking Duration Calculation:** ETA is calculated at a standard pedestrian walking pace of **4.5 km/h** ($75\text{ meters/minute}$):
   $$\text{ETA (minutes)} = \frac{\text{Total Distance (m)}}{75}$$
6. **No-Path State:** If no connected path exists between nodes, TUNTON displays **Route unavailable** rather than drawing an ungrounded straight line.

---

## Repository Structure

```text
tunton-ai/
├── README.md                           # This document: user & judge project overview
├── AGENTS.md                           # Strict coding-agent scope and change rules
├── SKILL.md                            # Verification and test execution procedures
├── analysis_options.yaml               # Flutter lint configuration
├── pubspec.yaml                        # Flutter dependencies and asset declarations
│
├── docs/                               # System specifications and sources of truth
│   ├── README.md                       # Documentation index and reading order
│   ├── PRD.md                          # Product requirements and P0 acceptance criteria
│   ├── ARD.md                          # Architectural decision records and contracts
│   ├── ARCHITECTURE.md                 # Visual runtime boundaries and data flow
│   ├── SDD.md                          # Android system design and P0 traceability
│   ├── SETUP.md                        # Environment setup, build, and offline testing
│   ├── DEVELOPMENT_MAP.md              # Target code tree and ownership mapping
│   ├── KNOWN_LANDMARK_GAPS.md          # Honest gap disclosure for SM Makati & MRT EDSA
│   ├── TUNTON_BACKEND_STRUCTURE.md     # Build-time asset preparation boundary
│   └── Tunton_App_Description.md       # Concise application summary and hackathon pitch
│
├── lib/                                # Flutter application source code
│   ├── main.dart                       # App entrypoint, backend loader, and gate
│   ├── app/
│   │   └── app.dart                    # App theme, scaffold, and common widgets
│   ├── features/
│   │   ├── camera/
│   │   │   └── photo_screen.dart       # Image capture/picker and flow coordinator
│   │   ├── recognition/
│   │   │   ├── embedding_service.dart  # OpenCLIP preprocessing and MethodChannel caller
│   │   │   ├── landmark_matcher.dart   # Vector matching and threshold gating logic
│   │   │   └── recognition_screen.dart # Auto-match card and "Not recognized" states
│   │   ├── map/
│   │   │   ├── offline_map_screen.dart # flutter_map, ArchiveTileProvider, marker overlays
│   │   │   └── landmark_markers.dart   # Landmark map marker builder
│   │   └── navigation/
│   │       ├── routing_service.dart    # Pure Dart Dijkstra graph routing
│   │       └── navigation_screen.dart  # Route summary, polyline, and ETA view
│   └── shared/
│       └── models/
│           ├── landmark.dart           # Landmark POI data model
│           └── route_result.dart       # Routing outcome and geometry model
│
├── assets/                             # Packaged offline runtime assets
│   ├── models/                         # ONNX vision model and manifest
│   ├── landmarks/                      # Landmark catalog and reference embeddings
│   ├── maps/                           # Pedestrian walk graph and manila_tiles.bin
│   ├── images/                         # Licensed landmark reference photos
│   └── fonts/                          # Inter typography and SIL license
│
├── android/                            # Native Android project configuration
│   └── app/
│       ├── build.gradle.kts            # Android build configuration and ONNX dependency
│       └── src/main/kotlin/.../
│           └── MainActivity.kt         # Native ONNX Runtime MethodChannel implementation
│
├── test/                               # Comprehensive unit and widget tests
│   ├── landmark_test.dart              # Catalog integrity and landmark model tests
│   ├── new_landmarks_test.dart         # SM Makati & MRT EDSA verification tests
│   ├── embedding_service_test.dart     # Service loading and MethodChannel tests
│   ├── preprocessing_parity_test.dart  # Preprocessing parity validation
│   ├── routing_service_test.dart       # Dijkstra routing and graph tests
│   ├── route_result_test.dart          # Route result model tests
│   ├── widget_test.dart                # UI component and flow widget tests
│   └── datasets/                       # Source manifests and evaluation records
│       ├── sources.json                # 103 photo records with licenses & hashes
│       ├── parity.json                 # Parity vectors for cross-language validation
│       └── parity_input.bin            # Binary input for deterministic parity check
│
├── integration_test/                   # On-device integration test suites
│   ├── app_test.dart                   # Full end-to-end auto-advance journey test
│   └── new_landmarks_e2e_test.dart     # New POI matching and noise rejection test
│
└── tools/
    └── prepare_dataset.py              # Build-time dataset normalization & export script
```

---

## Build and Run

### Prerequisites

- **Flutter SDK:** Version 3.x with Dart ^3.12.2.
- **Android SDK:** Platform-Tools with `adb`, targeting Android API 26+ (tested up to API 37).
- **Hardware:** Physical Android phone (8 GB RAM target recommended) or Android emulator with 16 KB page support (`arm64-v8a` or `x86_64`).

Verify the environment:
```bash
flutter doctor -v
adb devices
```

### Release Build & Android R8 Configuration

In `android/app/build.gradle.kts`, code shrinking and resource shrinking are disabled for the release build type:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = false
        isShrinkResources = false
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

> **Why this matters:** The native ONNX Runtime library (`onnxruntime-android:1.23.2`) invokes internal Java classes (such as `ai.onnxruntime.NodeInfo`) via native JNI callbacks from `libonnxruntime4j_jni.so`. If R8 minification or shrinking is enabled without keep rules, these classes are stripped, causing a fatal uncatchable `NoSuchMethodError` abort during release startup.

Build the standalone release APK:
```bash
flutter pub get
flutter build apk --release
```

Install the release APK onto your connected device:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Airplane-Mode Acceptance Test

1. On the physical Android test device, **enable Airplane Mode**.
2. Verify that **Wi-Fi, Mobile Data, and Bluetooth** are turned off.
3. Disconnect the USB cable from the computer.
4. **Cold-launch TUNTON AI** from the app drawer.
5. Capture or select a photo of a supported Intramuros landmark.
6. Observe on-device recognition and automatic transition to the offline map.
7. Select an origin point and verify that the walking route, polyline, and ETA render seamlessly without network activity.

---

## Verification & Test Results

All reported test numbers are ground-truth measurements verified in this checkout:

- **Static Analysis:**
  ```bash
  flutter pub get
  ```
  *(Dependencies cleanly resolved).*
- **Automated Test Suite:**
  - `flutter test test/new_landmarks_test.dart` — **Passed** (verifies catalog registration, marker building, and map integration for SM Makati and MRT EDSA).
  - `flutter test test/landmark_test.dart` — **Passed** (validates all 17 catalog records and constraints).
  - `flutter test test/routing_service_test.dart` — **Passed** (Dijkstra algorithm, graph node resolution, distance, and ETA calculations).
  - `flutter test test/preprocessing_parity_test.dart` — **Passed** (Dart image preprocessing matches Python reference transform).
- **Android Integration Tests (Emulator API 37):**
  - `flutter test integration_test/app_test.dart -d emulator-5554` — **2/2 Passed** (validates end-to-end auto-advance on known vectors and "Not recognized" on noise).
  - `flutter test integration_test/new_landmarks_e2e_test.dart -d emulator-5554` — **Passed** (validates real-time matching and rejection on new landmarks).
- **Held-Out Model Evaluation:**
  - Tested on 4 held-out evaluation photos for the newest landmarks scored against the full 59-vector index: **Top-3 accuracy = 4/4 (100%)**.
  - `sm-makati` held-out photos rank `sm-makati` at #1 (cosine $0.852$ and $0.784$).
  - `mrt-edsa` held-out photos rank `mrt-edsa` at #1 and #2 (cosine $0.650$ and $0.662$).
  - Out-of-catalog synthetic noise is rejected to **Not recognized**.
- **Memory & Latency Profiling:**
  To monitor memory usage during on-device execution:
  ```bash
  adb shell dumpsys meminfo com.example.tuntun
  ```
  Observed single-inference duration on Android CPU: **~400–750 ms**.

---

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| **Release build aborts on photo pick (`SIGABRT`)** | R8 stripped ONNX Runtime JNI symbols. | Ensure `isMinifyEnabled = false` and `isShrinkResources = false` in `android/app/build.gradle.kts`. |
| **"Local landmark recognition is unavailable"** | Checksum or dimension mismatch between ONNX manifest and reference index. | Verify `assets/models/openclip_vit_b32_laion2b_int8.manifest.json` matches `assets/landmarks/reference_embeddings.json`. |
| **Photo immediately returns "Not recognized"** | Image is blurry, out-of-catalog, or score fell below the $0.40$ floor / $0.07$ margin. | Take a clearer, well-lit photo of a supported landmark facing its recognizable facade. |
| **Blank map tiles under Makati / Pasay markers** | Bundled `manila_tiles.bin` bounds are centered on Intramuros/Manila. | Expected boundary limitation documented in `KNOWN_LANDMARK_GAPS.md`. Markers render at exact coordinates; basemap widening is a future data expansion. |
| **Route unavailable** | Origin and destination do not have a connected path in the pedestrian graph. | Choose a known Intramuros gate or approach with a verified `route_node_id`. |
| **Camera permission denied** | Android runtime permission declined by user. | Grant camera permission in Android App Info settings, or use the **Choose Photo** gallery option. |

---

## Privacy, Data Provenance, and Licensing

### User Privacy
- **Zero data transmission:** Images never leave the device memory. No user analytics, tracking cookies, advertising IDs, or telemetry libraries are bundled.
- **Permission respect:** Foreground GPS is requested only on explicit user demand for route origin snapping.

### Dataset & Image Rights
- All 103 photo records in `test/datasets/sources.json` depict documented Philippine locations (`country: "PH"`).
- Reference images are openly licensed under **Creative Commons (CC0 1.0, CC BY 2.5, CC BY 3.0, CC BY-SA 4.0)** from Wikimedia Commons.
- Processed PNG images in `assets/images/` have metadata text chunks physically embedded into the file bytes (`Author`, `Source`, `License`, `LicenseURL`, `Modifications`).

### Map & Pedestrian Data Attribution
- Pedestrian walking graph and road geometries are derived from OpenStreetMap data.
- **Attribution:** Contains information from **© OpenStreetMap contributors**, used under the Open Database License (ODbL).

### Typography
- The app uses the **Inter** typeface family created by Rasmus Andersson, bundled under the terms of the **SIL Open Font License, Version 1.1** (`assets/fonts/Inter-LICENSE.txt`).

---

## Hackathon Submission Disclosures

In accordance with official hackathon submission requirements:

1. **AI Models:** OpenCLIP ViT-B/32 (`laion2b_s34b_b79k`) exported to dynamically quantized INT8 ONNX (92 MB). No remote LLMs, VLMs, or cloud AI endpoints are used.
2. **Tools & Frameworks:** Flutter SDK, Dart SDK, Android SDK, Microsoft ONNX Runtime Android (`1.23.2`), `flutter_map`, `geolocator`, Python 3.12, Pillow, OSMnx (Mac asset preparation only).
3. **External APIs / Cloud Services:** **None at runtime.** Zero external network calls are performed while running the app.
4. **Pre-existing Code & Datasets:** OpenStreetMap road extracts, Wikimedia Commons public-domain/Creative Commons licensed photographs.
5. **AI Coding Assistance:** Developed with Antigravity AI agent pair-programming assistance for architecture planning, test automation, and code hardening.

---

## Documentation Map

For in-depth architectural and implementation specifications, consult the project documentation index in [`docs/README.md`](docs/README.md):

- [`docs/PRD.md`](docs/PRD.md) — Product requirements, user journey, and P0 acceptance criteria.
- [`docs/ARD.md`](docs/ARD.md) — Architectural decision records, data schemas, and contracts.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Runtime data flow and system boundary specifications.
- [`docs/SDD.md`](docs/SDD.md) — Android system design, MethodChannel interface, and P0 traceability.
- [`docs/SETUP.md`](docs/SETUP.md) — Detailed developer onboarding and asset preparation procedures.
- [`docs/DEVELOPMENT_MAP.md`](docs/DEVELOPMENT_MAP.md) — Source code tree and ownership mapping.
- [`docs/KNOWN_LANDMARK_GAPS.md`](docs/KNOWN_LANDMARK_GAPS.md) — Transparent disclosure of dataset and basemap coverage boundaries.
- [`AGENTS.md`](AGENTS.md) — Coding agent rules, scope gates, and verification obligations.
- [`SKILL.md`](SKILL.md) — Operational task guide for testing, building, and running the app.
