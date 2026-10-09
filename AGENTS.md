# AGENTS.md — TUNTON AI Scope and Coding-Agent Contract

> **MANDATORY for any coding agent or co-developer.** The project is a **one-day Flutter Android MVP**. Implement **only** what is enumerated as `P0` in `PRD.md`, using existing files and packages defined by `ARD.md`. Consult `ARCHITECTURE.md` for the current data flow. Do not reinterpret this as permission to make a complete Google Maps clone.

## 1. Mission

Build one working, fully device-local flow:

**Take/choose a photo → TFLite MobileNetV3 Small image embedding → match up to 3 distinct supported Intramuros landmarks → confirm destination → show bundled offline map → select manual start → Dart shortest walking route, distance, ETA.**

The output is a **working Android APK** with an **airplane-mode** live demo on physical hardware, targeting an **8 GB RAM** phone. The target is not proven until tested or otherwise defensibly measured; do not invent benchmark claims.

## 2. Source-of-truth hierarchy

1. `PRD.md`: product requirements and hard exclusions.
2. `ARD.md`: exact files, assets, dependencies and schema contracts.
3. `ARCHITECTURE.md`: visual runtime boundaries / sequencing.
4. `SETUP.md`, `TECH_STACK.md`, `SKILL.md`: install instructions, approved tools and task procedure.
5. `README.md`: summary for users/judges, **not authority to expand scope**.

If documentation differs, **do not silently improvise**. Keep P0 strict, fix inconsistencies only in the affected source-of-truth docs after explicit approval.

## 3. Pre-coding scope gate

Every task requires this check:

```text
Does the requested change directly implement / fix a PRD P0 requirement?
  NO  -> Stop. Mark out of scope.
  YES -> Is the target already defined in ARD file tree / allowed packages?
       NO  -> Ask for explicit approval before adding a file/package/API.
       YES -> Make the smallest local change, test it, report evidence.
```

The agent must identify the specific `P0-xx` ID and existing target files **before writing code**.

## 4. Locked runtime decisions

| Boundary | Required behavior |
|---|---|
| Platform | Flutter + Dart Android-first, physical demo phone |
| Primary local AI | **MobileNetV3 Small Image Embedder `.tflite`** only |
| Runtime | `tflite_flutter` on-device, one interpreter and one image at a time |
| Input | `image_picker`; preprocess with Dart `image` after inspecting actual tensors / metadata |
| Match | L2-normalized cosine similarity using packaged reference embeddings, grouped by landmark |
| Location | Verified `landmarks.json` coordinates; AI **never** invents lat/lon |
| Map | `flutter_map` with bundled tile assets; proper OSM attribution |
| Origin | Manual selection of a valid graph-backed point only; no GPS |
| Routing | Pure Dart Dijkstra over packaged walk graph with real edge geometry |
| Output | Path preview, distance, ETA fixed at 4.5 km/h; unknown/unavailable errors |
| Storage | Read-only bundled assets, not database/network |
| Prep | Python/OSMnx allowed only as build-time prep on Mac; not shipped as a service |

## 5. Model provenance and switching — strict rule

**Official MobileNetV3 Small image-embedder checkpoint:**

`https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite`

**Experimental alternative, not to install as P0:** Community MobileCLIP-S1 TFLite:

`https://huggingface.co/anton96vice/mobileclip2_tflite/blob/main/mobileclip_s1_datacompdr_last.tflite`

Do **not**:

- Add a MobileCLIP model selector, second model asset, multiple model interpreters or a new model-plugin architecture.
- Pretend the community MobileCLIP-S1 is the official Apple MobileCLIP2-S0 PyTorch checkpoint.
- Swap to MobileCLIP merely because the file is downloadable; verify TFLite image embedding output on Android first.
- Reuse MobileNet reference embeddings with a different model, preprocess or output dimension.
- Add Qwen2.5, Qwen-VL, Gemma, GLM, Ollama, cloud VLMs, OCR or new inference services.

If MobileNet performance is inadequate on **held-out** photos, **report evidence and request explicit team approval** before replacing it. On approval, update `PRD.md` / `ARD.md` / `ARCHITECTURE.md` / relevant setup instructions, choose **one** replacement checkpoint, re-index every reference photo, re-test actual Android inference. Model replacement is a deliberate scope-change decision, not an automatic fallback.

## 6. Approved code ownership; no invented abstractions

Only edit existing files listed in `ARD.md`:

```text
lib/main.dart
lib/app/app.dart
lib/features/camera/photo_screen.dart
lib/features/recognition/embedding_service.dart
lib/features/recognition/landmark_matcher.dart
lib/features/recognition/recognition_screen.dart
lib/features/map/offline_map_screen.dart
lib/features/map/landmark_markers.dart
lib/features/navigation/routing_service.dart
lib/features/navigation/navigation_screen.dart
lib/shared/models/landmark.dart
lib/shared/models/route_result.dart
assets/models/landmark_embedder.tflite
assets/landmarks/landmarks.json
assets/landmarks/reference_embeddings.json
assets/maps/intramuros_graph.json
assets/tiles/{z}/{x}/{y}.png
assets/images/[licensed landmark images]
tools/prepare_dataset.py
pubspec.yaml
```

Standard Flutter-generated Android files may be modified only as needed to make these approved dependencies run. Avoid new architecture directories, database layers, network clients, helper packages or additional product features.

## 7. Implement in dependency order

1. **Model validity:** The actual MobileNetV3 embedder checkpoint loads via `tflite_flutter` on the Android device. Record its tensors, produce finite embedding and verify reference pair similarity.
2. **Dataset validity:** Six real verified landmarks, 3–5 labeled reference images per place, matching vectors, graph-backed route node IDs, legal offline map tiles.
3. **Recognition:** Return top 3 different candidates or **Not recognized**; require confirmation.
4. **Map:** Offline tiles and correct markers, manual start selection, no live network calls.
5. **Route:** Graph Dijkstra, actual ordered edge path, correct distance and ETA, no-path error.
6. **Integration:** One end-to-end photo-to-route flow in the four approved screens.
7. **Proof:** Release APK, airplane-mode cold launch, held-out recognition tests, disconnected route, memory/latency measurements.

When time is limited, fix an existing P0 failure before writing a new screen or model adapter.

## 8. Quality, security and privacy guardrails

- **No made-up outputs:** Never fake image embeddings, model predictions, landmark locations, route geometry, distance, benchmark results, or offline proof.
- **No pretending similarity is calibrated probability:** Show a ranked suggestion, not "99% sure" unless properly validated and calibrated.
- **Do not mark a build tested unless it ran.** List hardware, command, result and any missing verification.
- **Offline means offline:** Don't rely on CDN UI scripts, tiles, model downloads, API proxies, hot-reload development servers, localhost FastAPI or a Mac running nearby.
- **Respect rights:** Image redistributions must be licensed. Offline map tiles must be legally obtained; public OpenStreetMap tiles are not for prohibited bulk offline downloading. Show **© OpenStreetMap contributors**.
- **No photos leave the phone** and no telemetry or user identity collection.
- **No misleading routing claims:** Walking path is a preview and cannot account for current gates, hazards or closures.

## 9. Testing / acceptance obligations

After each relevant change, run the smallest directly relevant check; before submission:

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

Then install on an actual Android device and **cold-launch in airplane mode**. Test:

- A held-out photo of a supported landmark (not a reference duplicate).
- Out-of-catalog photo → **Not recognized**/explicit confirmation.
- Valid connected pedestrian path with accurate rendered edge geometry.
- Disconnected node pair → **Route unavailable**; no straight-line replacement.
- Missing or malformed asset → visible error, not a crash or online fallback.
- Actual device memory and timings, especially on 8 GB hardware if available.

Commands in this file are **verification obligations**, not claims of current passing tests.

## 10. Required change-report format

```text
P0 requirement (exact ID):
Approved file(s) edited:
What now works:
Model checkpoint and preprocessing verified (yes/no; evidence):
Commands/tests actually run and results:
Android release test (passed / failed / not run):
Airplane-mode cold-launch test (passed / failed / not run):
8 GB memory results (measured / not measured):
Remaining blocker or scope decision:
```

## 11. Hackathon reporting requirements

According to the event briefing, the submission must disclose **models, tools/frameworks, APIs/cloud services, existing code and assets, and AI coding tools**; include a public GitHub repository and demo-video/X or LinkedIn link. The user must be able to answer **why local AI makes TUNTON valuable**. The official cutoff is **Oct 10, 2026, 10:00 AM**; do not defer source upload or tests until after the freeze. Only report verified results.

**Final rule:** If a new idea does not directly fix or complete the approved P0 journey, **do not build it**.
