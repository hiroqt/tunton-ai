# AGENTS.md — TUNTON AI Scope and Coding-Agent Contract

## Start here

- Use [`docs/README.md`](docs/README.md) as the documentation index and [`docs/DEVELOPMENT_MAP.md`](docs/DEVELOPMENT_MAP.md) for the current versus approved Flutter tree.
- Use [`docs/SDD.md`](docs/SDD.md) for Android system design and P0 traceability. It explains, but does not override, the PRD/ARD/architecture contracts.
- Product scope remains in [`docs/PRD.md`](docs/PRD.md); file/package contracts remain in [`docs/ARD.md`](docs/ARD.md); runtime flow remains in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). The docs index does not override them.
- The tree documented in [`docs/ARD.md`](docs/ARD.md) is the approved target, not a claim that every file or feature exists in the current checkout.

> **MANDATORY for any coding agent or co-developer.** The user explicitly approved a 2026-10-10 scope change to OpenCLIP ViT-B/32 LAION-2B on native Android ONNX Runtime and recognition for named Manila, Makati, and Pasay POIs. Routing remains Intramuros-only. This supersedes the original MobileNet/TFLite-only and Intramuros-only recognition decisions below. OCR and runtime services remain excluded. Follow the updated PRD, ARD, and ARCHITECTURE.

## 1. Mission

Build one working, fully device-local flow:

**Take/choose a photo → native Android OpenCLIP image embedding → match up to 3 distinct named Manila/Makati/Pasay POIs → confirm. Intramuros matches may continue to the existing map and Dart walking route.**

The output is a **working Android APK** with an **airplane-mode** live demo on physical hardware, targeting an **8 GB RAM** phone. The target is not proven until tested or otherwise defensibly measured; do not invent benchmark claims.

## 2. Source-of-truth hierarchy

1. [`docs/PRD.md`](docs/PRD.md): product requirements and hard exclusions.
2. [`docs/ARD.md`](docs/ARD.md): exact files, assets, dependencies and schema contracts.
3. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): visual runtime boundaries / sequencing.
4. [`docs/SDD.md`](docs/SDD.md): Android system design overview, subordinate to PRD/ARD/ARCHITECTURE.
5. [`docs/SETUP.md`](docs/SETUP.md), `SKILL.md`: install instructions, approved tools and task procedure.
6. [`README.md`](README.md): summary for users/judges, **not authority to expand scope**.

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
| Primary local AI | **OpenCLIP ViT-B/32 LAION-2B image tower `.onnx`** only |
| Runtime | Native Android ONNX Runtime via Flutter MethodChannel; one session and one image at a time |
| Input | `image_picker`; preprocess with Dart `image` per the exported tensor contract |
| Match | L2-normalized cosine similarity using packaged reference embeddings, grouped by landmark |
| Location | Verified `landmarks.json` coordinates; AI **never** invents lat/lon |
| Map | `mapbox_maps_flutter` with an SDK-managed offline style/region; allow network only for explicit download/update, then disable the map network stack; retain Mapbox and OSM graph attribution |
| Origin | Manual graph-backed start or user-requested GPS start snapped to a valid Intramuros graph node; manual selection remains available |
| Routing | Pure Dart Dijkstra over packaged walk graph with real edge geometry |
| Output | Path preview, graph distance plus any disclosed approximate GPS connector, ETA at 4.5 km/h; unknown/unavailable errors |
| Storage | Read-only bundled model/catalog/graph assets plus the Mapbox SDK-managed offline region downloaded while connected |
| Prep | Python/OSMnx allowed only as build-time prep on Mac; not shipped as a service |

## 5. Model provenance and switching — strict rule

**Approved model:** OpenCLIP ViT-B/32 with pretrained tag `laion2b_s34b_b79k`. Export only its image tower to ONNX; the text tower and tokenizer are not packaged. Couple the ONNX file, preprocessing contract, output dimension, reference index and checksums. If the model/export/runtime fails the Android proof gate, stop and report the evidence; do not silently use another model or send photos to a service.

## 6. Approved code ownership; no invented abstractions

Only edit existing files listed in `docs/ARD.md`:

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
assets/models/openclip_vit_b32_laion2b_int8.onnx
assets/landmarks/landmarks.json
assets/landmarks/reference_embeddings.json
assets/maps/intramuros_graph.json
assets/images/[licensed landmark images]
tools/prepare_dataset.py
pubspec.yaml
```

Standard Flutter-generated Android files may be modified only as needed to make these approved dependencies run. Avoid new architecture directories, database layers, network clients, helper packages or additional product features.

## 7. Implement in dependency order

1. **Model validity:** The exported OpenCLIP image tower loads through ONNX Runtime on Android. Record tensor names/shapes, produce a finite embedding and verify parity/reference similarity.
2. **Dataset validity:** Each catalog POI has a verified location and 3–5 licensed references with matching vectors. Only Intramuros entries require graph-backed route nodes; other areas are recognition-only.
3. **Recognition:** Return top 3 different candidates or **Not recognized**; require confirmation.
4. **Map:** Download the Mapbox style and Intramuros region while connected, confirm completion, then verify offline rendering, correct markers, and manual/GPS-snapped start selection. No map network calls are needed after download.
5. **Route:** Graph Dijkstra, actual ordered edge path, correct distance and ETA, no-path error.
6. **Integration:** One end-to-end photo-to-route flow in the four approved screens.
7. **Proof:** Release APK, airplane-mode cold launch, held-out recognition tests, disconnected route, memory/latency measurements.

When time is limited, fix an existing P0 failure before writing a new screen or model adapter.

## 8. Quality, security and privacy guardrails

- **No made-up outputs:** Never fake image embeddings, model predictions, landmark locations, route geometry, distance, benchmark results, or offline proof.
- **No pretending similarity is calibrated probability:** Show a ranked suggestion, not "99% sure" unless properly validated and calibrated.
- **Do not mark a build tested unless it ran.** List hardware, command, result and any missing verification.
- **Offline means downloaded first:** Mapbox map data must be downloaded from Mapbox through its SDK and may not be bundled or redistributed. Verify the SDK-managed region is complete before airplane mode; do not add a network basemap fallback. Keep the SDK's Mapbox attribution visible and show **© OpenStreetMap contributors** for the OSM-derived pedestrian graph.
- **Respect rights:** Image redistributions must be licensed. Use Mapbox's SDK-managed offline storage under its terms; never package Mapbox map data in the APK.
- **No photos leave the phone** and no app-owned analytics or user identity collection. Mapbox SDK may send de-identified usage/location telemetry under its terms; expose its opt-out through the visible attribution control.
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
