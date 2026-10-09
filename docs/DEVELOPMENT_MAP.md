# TUNTON development map

This is a navigation guide to the existing implementation and the approved P0 target. It does not authorize new features, packages, APIs, or code paths. `PRD.md` and `ARD.md` remain authoritative.

## Current checkout

The current tracked Flutter source is intentionally smaller than the approved target tree:

```text
lib/
└── main.dart

test/
└── widget_test.dart
```

The `app/`, feature, model, and asset paths below are defined by `ARD.md`; they are not all present yet. Do not treat this guide as evidence that a feature is implemented or verified.

## Approved Flutter structure

Use the feature-oriented tree already specified in `ARD.md`. Add only the files needed for an identified P0 requirement, in their approved locations.

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

This map records structure, not readiness. Use the source requirements and actual command/device evidence to report what works. Do not infer model validity, dataset quality, Android behavior, airplane-mode success, or 8 GB memory fit from files or documentation alone.
