# TUNTON development map

This is a navigation guide to the existing implementation and the approved P0 target. It does not authorize new features, packages, APIs, or code paths. [`PRD.md`](PRD.md) and [`ARD.md`](ARD.md) remain authoritative.

## Current checkout

The current Flutter product source is intentionally smaller than the approved target tree:

```text
lib/
└── main.dart                         # generated Flutter counter starter; P0 flow not implemented

test/
├── widget_test.dart                 # generated starter test
├── prepare_dataset_unit_test.py      # build-time prep unit tests
└── prepare_dataset_e2e_test.py       # temporary-fixture CLI E2E tests

tools/
└── prepare_dataset.py                # build-time JSON validation, normalization, and export
```

The `app/`, feature, model, and product asset paths below are defined by [`ARD.md`](ARD.md); they are not all present yet. The Python utility prepares bundled data and never serves app requests. Do not treat this guide as evidence that a feature is implemented or verified.

## Approved Flutter structure

Use the feature-oriented tree already specified in [`ARD.md`](ARD.md). Add only the files needed for an identified P0 requirement, in their approved locations.

```text
lib/
├── main.dart                         # app entry and approved flow wiring
├── app/
│   └── app.dart                       # app shell and flow state
├── features/
│   ├── camera/
│   │   └── photo_screen.dart          # take or choose one photo
│   ├── recognition/
│   │   ├── embedding_service.dart     # one TFLite embedder
│   │   ├── landmark_matcher.dart     # local vector ranking / unknown result
│   │   └── recognition_screen.dart   # candidates and destination confirmation
│   ├── map/
│   │   ├── offline_map_screen.dart   # bundled map and manual start
│   │   └── landmark_markers.dart     # catalog markers
│   └── navigation/
│       ├── routing_service.dart      # graph Dijkstra and route result
│       └── navigation_screen.dart    # path, distance, ETA, or unavailable
└── shared/
    └── models/
        ├── landmark.dart             # verified catalog record
        └── route_result.dart          # route output contract

assets/
├── models/landmark_embedder.tflite
├── landmarks/{landmarks,reference_embeddings}.json
├── maps/intramuros_graph.json
├── tiles/{z}/{x}/{y}.png
└── images/                            # licensed reference photos

tools/
└── prepare_dataset.py                 # build-time preparation only
```

Flutter-generated platform/build files may exist alongside this tree. They are not a reason to add a runtime service, database, network client, or architecture layer. Use only the packages approved in `ARD.md` and `pubspec.yaml`.

## P0 ownership and dependency order

| P0 | Responsibility | Approved owner(s) |
|---|---|---|
| P0-01 | Capture or choose a readable photo | `photo_screen.dart` |
| P0-02 | Run the packaged MobileNetV3 Small embedder on Android | `embedding_service.dart` |
| P0-03–04 | Rank up to three distinct landmarks; reject unknown input | `landmark_matcher.dart` |
| P0-05 | Require confirmation before setting destination | `recognition_screen.dart` |
| P0-06–07 | Show bundled map and let user select graph-backed origin | `offline_map_screen.dart`, `landmark_markers.dart` |
| P0-08 | Resolve verified coordinates and graph node from catalog | `landmark.dart`, `landmarks.json` |
| P0-09–10 | Route on graph edges; show geometry, distance, estimated ETA | `routing_service.dart`, `route_result.dart`, `navigation_screen.dart` |
| P0-11–12 | Complete offline flow and show truthful failure states | Relevant approved screens and services above |

Implement in the dependency order in `AGENTS.md` / `ARD.md`: model validity, data validity, recognition, map, routing, integration, then device proof. A screen mock or sample output does not satisfy a runtime requirement.

## Agent task handoff

Point the task at the exact P0 ID and approved file(s), then include:

```text
P0 requirement:
Approved file(s):
Expected behavior:
Relevant data/model contract:
Required local verification:
Device/offline verification status:
```

Before editing, check the scope gate in root `AGENTS.md`. If a task needs another source file, package, service, or code directory, stop and identify the conflict for explicit scope review. Preserve unknown states, verified data provenance, local-only processing, and offline failure behavior.

## Current verification status

### Full dataset preparation — active work, 2026-10-09

The user approved extending the preparation tool to acquire licensed photos, generate actual MobileNetV3 vectors, rebuild real OSM graph/tiles, and prepare the Flutter embedding service for later Android parity. All collected project photos, including unknown tests, must depict source-documented Philippine locations. Public held-out images and team evaluation inputs stay under `test/datasets/`, outside APK assets; the empty team input folder is `test/datasets/held_out/team/`.

Current completed artifacts: approved MobileNet checkpoint (SHA-256 `bbbb4c51a55a53905af1daec995ca1aae355046f8839bb8c9f5ce9271394bc40`), six source-backed landmark records, 3,268 graph nodes, 7,245 directed edges, and 156 self-rendered XYZ tiles (zooms 15–18). San Agustin and Baluarte routes stop at explicitly named exterior public street approaches; no unmapped final connector is included. Current-access field inspection is pending.

Photo curation delivered 23 references (four each except three for Puerta Real), 12 independent public held-outs, and 12 Philippine unknown scenes — 47 PNGs total in `test/datasets/sources.json`. All are canonical lossless RGB PNG (≤1024 px/side) with per-file embedded attribution; the manifest records `country: PH`, a named location, and Commons geographic evidence for each. Canonical RGB PNG preparation is intentional: a real-image review found different JPEG decoder pixels between Pillow and Dart, and the prepared PNG produced identical Mac-side preprocessing tensors.

Held-out independence fix (2026-10-09): the Baluarte de San Diego held-out photo `test/datasets/held_out/public/baluarte-san-diego/1.png` was re-sourced from Diego Delso (who also shot a Baluarte reference) to Ranieljosecastaneda (CC BY-SA 4.0, Commons `File:Baluarte de San Diego in Intramuros Manila.jpg`, own work, Intramuros, Manila). Every landmark's held-out photographers are now disjoint from its reference photographers, so held-out matching is not a same-shoot near-duplicate. This is a Mac Python CPU result, not Android inference proof.

The isolated preparation environment is `/tmp/tunton-prep-runtime.Si4AXh/venv/bin/python` (Python 3.12; LiteRT 2.3.0, NumPy 2.5.3, Pillow 12.3.0, OSMnx 2.1.1). The build-time backend (preparation CLI, dataset, real embeddings, OSM graph/tiles, and the Flutter embedding service with its parity fixture) is complete and locally verified. Remaining P0 proof is on-device: actual Android TFLite inference, release APK install, airplane-mode cold launch, and 8 GB memory/latency measurement, plus the four approved Flutter screens.

### Completed in this checkout

- `tools/prepare_dataset.py` validates the ARD landmark, reference-embedding, and pedestrian-graph JSON shapes and references; it L2-normalizes vectors and exports the three canonical asset JSON files. It uses Python's standard library only, runs on the developer machine, and refuses to overwrite existing outputs.
- Unit and CLI E2E coverage use temporary schema fixtures. The fixtures are not product landmarks, embeddings, photos, or route evidence.
- Scope audit confirms the approved Python role is build-time preparation only. There is no runtime backend or API.

### Still required for the P0 product

1. **P0-02:** Add the approved model and verify its actual tensor contract and embedding output on Android.
2. **P0-03, P0-08, P0-09, P0-12:** Supply verified landmark records, matching licensed references and real model embeddings, a legally sourced tile set, and a real pedestrian graph. Run the prep tool against those inputs; structural validation does not prove their truth or provenance.
3. **P0-01–P0-12:** Implement the approved Flutter flow and its visible failure states in the ARD target files.
4. Build/install the release APK and complete held-out recognition, connected/disconnected routing, airplane-mode cold-launch, and device memory/latency checks.

### Verification evidence — 2026-10-09

Run in the isolated prep venv (`/tmp/tunton-prep-runtime.Si4AXh/venv/bin/python`, Python 3.12) and Flutter 3.44.8 on macOS CPU. These are build-time/host results, not Android or airplane-mode proof.

- Backend Python suite — passed, 21 tests across `prepare_dataset_unit_test` (6), `prepare_dataset_e2e_test` (3), `prepare_dataset_sources_test` (4), `prepare_dataset_map_test` (4), `prepare_dataset_pipeline_unit_test` (4). `prepare_dataset_sources_test` first failed on same-photographer leakage for `baluarte-san-diego` (Diego Delso in both reference and held-out) and passed after the held-out re-source.
- `py_compile tools/prepare_dataset.py test/prepare_dataset_*.py` — passed.
- Real-asset held-out recognition (`prepare_dataset.py evaluate`, report at `test/datasets/evaluation_report.json`) — 12/12 held-out photos rank the correct landmark in top-3; top-1 9/12 (misses stay within top-3, allowed by P0-03). Unknown top-1 similarities 0.16–0.60; `rejection_rule_calibrated: false` (similarity is a ranking metric, not calibrated confidence). Median inference ~20 ms on Mac CPU.
- `flutter analyze` — no issues.
- Dart tests `test/embedding_service_test.dart` + `test/preprocessing_parity_test.dart` — passed, 5 tests. Parity confirms Dart and Python produce identical float32 preprocessing tensors for the real PNG fixture.
- Android release install, airplane-mode cold launch, on-device TFLite inference, and 8 GB memory/latency — not run (requires the physical phone, still pending).

This map records progress, not readiness. Do not infer model validity, dataset quality, Android behavior, airplane-mode success, or 8 GB memory fit from files, schemas, fixture tests, or documentation alone.
