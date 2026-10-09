# AGENTS.md — TUNTON AI MVP Engineering Rules

> **Applies to every coding agent working in this repository.** Read `PRD.md` first, `ARD.md` second, and `SKILL.md` for the task-specific execution procedure. These documents are the complete scope authority for the one-day MVP.

## Mission

Implement **only** a Flutter Android demo application that takes a photo of a **supported Intramuros landmark**, uses a **bundled TFLite image embedding model** to suggest matches, has the user confirm a destination, and computes a **walking route from a manually selected start point** on a completely offline bundled map.

The finished demo must work directly on a phone in **airplane mode**, using an **8 GB RAM device as the minimum target**. Never move inference or route computation onto the developer's Mac, a localhost backend, or an internet service.

## Non-negotiable scope lock

1. **PRD P0 features only.** No P1/P2 enhancements, speculative future work, or new workflows.
2. **No extra code structure.** Use the exact folders/files defined in `ARD.md`, plus standard Flutter-generated files and required platform permission/asset configuration. Do not create services, controllers, repositories, extensions, packages, scripts, or architecture layers outside that structure.
3. **No additional methods for unrelated functionality.** Implement only code paths directly required by photo capture/pick, TFLite embedding, local matching, candidate confirmation, local map display, manual origin selection, shortest walking route, distance, ETA, and necessary error handling.
4. **No network dependencies during execution.** No cloud inference, Google Maps, remote geocoding, online tile fallback, HTTP backend, or external storage. Internet may be used **during developer preparation only** to obtain licenses, model, permitted map files, and packages.
5. **No model training, extra AI model, LLM, OCR, EXIF geolocation, live GPS tracking, voice directions, or automatic rerouting.**
6. **No invented location or route.** A match is a *candidate*, not an exact camera position. Only stored verified coordinates may be mapped. Routing follows graph edges, never a straight-line substitute.
7. **No hidden success claims.** Do not state 8 GB compatibility, recognition accuracy, or offline success without measured tests.
8. **No unnecessary dependencies.** Core runtime libraries are restricted to Flutter/Dart, `tflite_flutter`, `image_picker`, Dart `image`, `flutter_map`, `latlong2`, and `flutter_riverpod`. Preparation may use Python/OSMnx only through `tools/prepare_dataset.py`.

## Source-of-truth hierarchy

1. `PRD.md` — **what** may be built, P0 acceptance criteria and excluded features.
2. `ARD.md` — **how** to implement approved functionality, files, data contracts and architecture decisions.
3. `SKILL.md` — narrow working procedure/checklist to implement and validate P0 tasks.
4. Existing user-approved code — preserve it unless it violates the above.

If a requirement is ambiguous, choose the **smallest change within the existing structure** and explain any blocker. Do not invent a feature or a new module to resolve ambiguity.

## Allowed repository structure

Only implement inside the app structure documented in `ARD.md`, specifically:

```text
lib/main.dart
lib/app/app.dart
lib/features/camera/photo_screen.dart
lib/features/recognition/{embedding_service,landmark_matcher,recognition_screen}.dart
lib/features/map/{offline_map_screen,landmark_markers}.dart
lib/features/navigation/{routing_service,navigation_screen}.dart
lib/shared/models/{landmark,route_result}.dart
assets/models/landmark_embedder.tflite
assets/landmarks/{landmarks,reference_embeddings}.json
assets/maps/intramuros_graph.json
assets/tiles/{z}/{x}/{y}.png
assets/images/
tools/prepare_dataset.py
pubspec.yaml
```

The Android/iOS folders and build-generated files from `flutter create` are expected, but **Android is the required demo target**. Modify native platform configuration only as necessary for the current Android app and camera/gallery permissions.

## Team boundaries (parallel development without new architecture)

| Track | Owned existing files | Done when |
|---|---|---|
| Vision | `recognition/*`, landmark data, model asset | A held-out known photo yields a confirmable candidate or safely reports unknown. |
| Map/routing | `map/*`, `navigation/*`, bundled graph/tiles | Offline map draws a valid pedestrian path between connected mapped points. |
| Flutter integration | `camera/*`, `app/app.dart`, `main.dart`, shared models | End-to-end journey from photo to destination to route works. |
| QA / dataset preparation | `tools/prepare_dataset.py`, real device testing | Assets are valid, graph connected, offline cold-start validated, measurements recorded. |

Where ownership overlaps, agree on the small existing data contract first. Avoid parallel edits to the same file.

## Required implementation order

1. Verify Flutter physical Android device, bundled `.tflite` model, and actual input/output tensors.
2. Verify local reference embeddings use the **same model and exact preprocessing**.
3. Prove single-photo matching independently with held-out photos; reject unknown/ambiguous inputs.
4. Verify map tiles render offline; verify walking graph gives a nontrivial connected path.
5. Wire only the approved UI sequence: **photo → candidates → confirmation → map → manual start → route + distance + ETA**.
6. Handle invalid photo, unavailable model/data, unknown landmark, and disconnected-route states.
7. Build/install APK and test **airplane-mode cold launch**, including route drawing, on a physical phone.
8. Run `flutter analyze`; resolve errors. If tests already exist, run the applicable tests. Log real performance numbers instead of guessing.

## Technical correctness guards

- **Embeddings:** Do not compare ImageNet class probabilities. Decode RGB tensors and normalize input exactly as the TFLite model expects. Normalize embedding vectors before cosine matching. Inspect the actual output tensor dimension; do not hardcode the illustrative ARD value.
- **Matching:** Rank up to three **distinct landmarks**, not three photos of one landmark. Similarity is not probability. The user must confirm before mapping the landmark.
- **Location semantics:** The recognized place is the landmark depicted, **not** the camera/user's exact current location. Origin is manually chosen from valid mapped points.
- **Routing:** Dijkstra uses positive walking-edge distances. Graph geometries are preserved and converted to display coordinates consistently. Return **Route unavailable** when a path cannot be found.
- **Map:** Bundle legal offline tile assets and verify the pilot area's real coverage. No CDN icons/fonts or accidental network requests. Display OpenStreetMap contributor attribution.
- **Memory:** One loaded TFLite interpreter, one photo inference at a time, compact reference index, no additional LLM, no server, avoid loading all reference images into RAM.

## Agent change protocol

For **every proposed change**, apply this decision gate:

```text
Does PRD.md explicitly require it as P0?
  NO -> Do not implement.
  YES -> Does ARD.md provide an existing file or data path?
            NO -> Ask before creating a new structure.
            YES -> Implement the smallest working change there.
```

Before coding, state the P0 acceptance criterion and the **specific existing file(s)** to edit. After coding, report:

- P0 behavior implemented;
- Files modified;
- Commands/tests run and observed results;
- Offline or 8 GB tests **not yet run**;
- Any open blocker **without** adding extra features to address it.

Do not report a check as passed unless you actually executed it.

## Definition of done

A released Android install can: choose/take a photo, identify candidate(s) with local TFLite, let the user confirm a supported landmark, display it on a bundled map, accept a manual mapped origin, and draw a **connected pedestrian route** with distance/ETA **after Wi-Fi and mobile data are disabled**. Unsupported inputs and routes fail safely. Resource claims are supported by measurements.

**Final rule:** If a change does not directly help this one user journey, **do not build it**.
