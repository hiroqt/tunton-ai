---
name: tunton-flutter-offline-mvp
description: Implement and validate the scope-locked TUNTON Flutter Android MVP for offline photo-to-landmark recognition and walking-route preview. Use for tasks touching existing photo, TFLite, landmark-match, offline-map, or Dart shortest-path files; never expand beyond PRD P0.
---

# TUNTON Flutter Offline MVP — Agent Skill

## Purpose

This skill is a **task procedure**, not permission to create new features or architecture. Apply it only to the existing TUNTON Flutter MVP. Read `docs/PRD.md` and `docs/ARD.md` before editing code; follow `AGENTS.md` scope limits.

## Preconditions

- The task maps to a specific **P0** requirement in `docs/PRD.md`.
- The implementation can be contained in existing files listed in `docs/ARD.md`.
- A physical Android device is available for final release-build/offline demonstration.
- One supported district (Intramuros), verified POI coordinates, a licensed small map asset set, and a connected walking graph are prepared or explicitly identified as blockers.
- The MobileNetV3 Small **image embedder** model is bundled; do not use a classifier-output model as a substitute.

## Inputs and outputs

| Input | Allowed output |
|---|---|
| Photo taken or chosen by user | Up to three distinct supported landmark candidates, or **Not recognized**. |
| Confirmed landmark candidate | Stored landmark ID, name, verified coordinates and valid route node. |
| Manual start point + confirmed destination | Offline shortest walking route, distance in meters, ETA in minutes, or **Route unavailable**. |
| Bundled map/graph/model assets | Offline rendered map and local inference, with no runtime network dependency. |

## Procedure (run in this order)

### Step 1 — Check scope

- Identify the exact `P0-xx` criterion in `docs/PRD.md`.
- Identify the existing target file(s) in `docs/ARD.md`.
- Reject new modules, packages, backends, model families, GPS features, or map regions not explicitly approved.

### Step 2 — Validate bundled assets

- Inspect `assets/models/landmark_embedder.tflite` through `tflite_flutter`; record real input and output tensor shape/types.
- Ensure `assets/landmarks/landmarks.json` has unique IDs, verified lat/lon, and graph-backed route node IDs.
- Ensure `assets/landmarks/reference_embeddings.json` has full-length finite vectors with the **actual** output dimension; reference vectors came from the **same model + preprocessing**.
- Confirm pilot-region offline tile files are registered as Flutter assets and cover the test route.
- Confirm `assets/maps/intramuros_graph.json` contains a connected, pedestrian-valid route for demo landmarks.
- If assets are missing or incompatible, report a blocker; never synthesize false map geometry or locations.

### Step 3 — Implement/verify on-device visual matching

1. `image_picker`: obtain exactly one image.
2. Dart `image`: decode, RGB conversion, resize, and normalize based on **verified tensor requirements**.
3. `tflite_flutter`: reuse one interpreter; perform one local embedding inference.
4. L2-normalize and compare against bundled reference vectors using cosine similarity.
5. Aggregate by landmark ID; return at most three different candidates.
6. If candidates are unreliable or input unsupported, return **Not recognized**.
7. Require explicit confirmation; do not turn embedding similarity into a confidence percentage or GPS assertion.

**Sanity check:** Test with a held-out image of a supported landmark and at least one image outside the known catalog. Reusing an exact reference photo is **not** sufficient proof.

### Step 4 — Implement/verify offline mapping and routing

1. Render locally bundled raster tiles through `flutter_map` and `AssetTileProvider` only.
2. Show bundled landmark markers and the confirmed candidate destination.
3. Let the user choose a known, graph-backed **manual** starting point.
4. Read graph node and edge data from packaged JSON.
5. Run pure Dart Dijkstra over `length_m` with valid connected pedestrian edges.
6. Convert the chosen edges' actual route geometries to the Flutter map polyline.
7. Sum distance and estimate walking time at **4.5 km/h**.
8. For invalid/out-of-range/disconnected points, show **Route unavailable**—never fake a path.

### Step 5 — Wire the one permitted UI flow

`photo_screen.dart` → `recognition_screen.dart` → `offline_map_screen.dart` → `navigation_screen.dart`

Only pass the current image/match, selected landmark ID, manual origin ID, and computed route. The user can reselect a candidate/start within that flow. Do not add unrelated screens or state features.

### Step 6 — Verify and report

- `flutter analyze` completes without relevant errors.
- Release APK installs and launches on a physical Android phone.
- **Cold-launch with airplane mode enabled**; perform recognition and routing.
- Test unsupported image, invalid photo, missing model/data handling, and a graph pair with no path.
- Record actual recognition latency, route computation latency, and peak memory on the device.
- Show source attribution for bundled map data and identify any licensing/asset blockers.
- Report what was tested and what remains unverified. Do not claim 8 GB compatibility without an 8 GB device run or equivalent defensible measurement.

## Fixed guardrails

- **Only in-scope code:** Nothing beyond PRD P0 or the ARD file tree.
- **Phone-only runtime:** No FastAPI, local network backend, hosted services, online tiles, cloud AI, or dependency on the Mac once installed.
- **One vision model:** MobileNetV3 Small image embedder; no additional OCR/LLM/vision model.
- **One area and one mode:** Intramuros pedestrian routes only.
- **One user journey:** Image → recognized landmark → manual start → route preview.
- **Privacy:** No photo uploads or telemetry.
- **Uncertainty:** Unknown remains unknown; unconnected routes remain unavailable.

## Required agent response format

After each implementation task, use this short status format:

```text
P0 requirement:
Existing files changed:
Behavior completed:
Validation executed and result:
Offline Android test (passed / failed / not run):
8 GB memory evidence (measured / not measured):
Remaining blocker:
```

Do not create planning documents, tests, helper folders, or libraries outside the approved structure unless the user explicitly changes scope.
