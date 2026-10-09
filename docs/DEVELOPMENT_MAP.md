# TUNTON Development Map

This page distinguishes the current checkout from the approved Android P0 target. It is a navigation/status aid, not product authority. [`PRD.md`](PRD.md) defines scope; [`ARD.md`](ARD.md) defines approved files and contracts; [`SDD.md`](SDD.md) explains the Android design.

## Current checkout (scope and inventory updated 2026-10-10)

```text
lib/
├── main.dart                               # generated Flutter counter starter
├── features/
│   ├── recognition/
│   │   ├── embedding_service.dart          # OpenCLIP preprocessing + Android ONNX channel
│   │   └── landmark_matcher.dart           # local reference ranking
│   └── navigation/
│       └── routing_service.dart            # graph path calculation
└── shared/models/
    ├── landmark.dart
    └── route_result.dart

tools/
└── prepare_dataset.py                      # developer-machine asset preparation

assets/
├── models/openclip_vit_b32_laion2b_int8.onnx
├── images/                                  # licensed reference set
├── landmarks/{landmarks,reference_embeddings}.json
├── maps/intramuros_graph.json
└── tiles/{z}/{x}/{y}.png                      # legacy OSM-rendered tiles; not Mapbox SDK data
```

Observed inventory: 15 catalog records (6 routable Intramuros POIs and 9 recognition-only Manila POIs), 51 licensed reference images and 512-dimensional OpenCLIP vectors, 30 held-out images, 10 unknown images, 3,268 graph nodes, and 7,245 directed edges. The Manila batch covers Rizal Park, SM City Manila, Robinsons Place Manila, Lucky Chinatown Mall, UP Manila, De La Salle University Manila, FEU, Quiapo Church, and Binondo Church. The remaining requested Manila entries and Makati/Pasay catalog expansion are incomplete. Legacy OSM raster files are not the runtime basemap; Mapbox map data cannot be bundled. Inventory facts do not prove full area coverage, source rights, or app behavior.

The Manila catalog coordinates were matched to these named OpenStreetMap features: [Rizal Park (way 24159887)](https://www.openstreetmap.org/way/24159887), [SM City Manila (way 59342722)](https://www.openstreetmap.org/way/59342722), [Robinsons Manila (way 48894714)](https://www.openstreetmap.org/way/48894714), [Lucky Chinatown Mall (relation 14330018)](https://www.openstreetmap.org/relation/14330018), [UP Manila (relation 2918734)](https://www.openstreetmap.org/relation/2918734), [De La Salle University Manila (relation 11126048)](https://www.openstreetmap.org/relation/11126048), [Far Eastern University (way 28788717)](https://www.openstreetmap.org/way/28788717), [Quiapo Church (way 27086772)](https://www.openstreetmap.org/way/27086772), and [Binondo Church (way 108850879)](https://www.openstreetmap.org/way/108850879). These entries omit `route_node_id` and remain outside route coverage.

Android image inference uses ONNX Runtime through a Flutter MethodChannel in `MainActivity`; see `ARD.md` for exact model/data contracts and Android proof status.

## Approved Android target structure

Follow [`ARD.md`](ARD.md); add only the approved files needed for a specific P0 requirement.

```text
lib/
├── main.dart
├── app/app.dart
├── features/
│   ├── camera/photo_screen.dart
│   ├── recognition/{embedding_service,landmark_matcher,recognition_screen}.dart
│   ├── map/{offline_map_screen,landmark_markers}.dart
│   └── navigation/{routing_service,navigation_screen}.dart
└── shared/models/{landmark,route_result}.dart

assets/
├── models/openclip_vit_b32_laion2b_int8.onnx
├── images/[licensed reference photos]
├── landmarks/{landmarks,reference_embeddings}.json
├── maps/intramuros_graph.json

tools/prepare_dataset.py                      # build time only, never an app server
```

Flutter and Android runtime dependencies are recorded in `pubspec.yaml` and Gradle. OpenCLIP/PyTorch/ONNX/OSMnx are preparation-only dependencies documented in `ARD.md` and [`TUNTON_BACKEND_STRUCTURE.md`](TUNTON_BACKEND_STRUCTURE.md). Mapbox stores its SDK-managed offline region outside Flutter assets.

## P0 ownership map

| Requirement | Approved primary owner |
|---|---|
| P0-01 photo input | `photo_screen.dart` |
| P0-02 on-device embedding | `embedding_service.dart` |
| P0-03/04 candidates and unknown result | `landmark_matcher.dart` |
| P0-05 destination confirmation | `recognition_screen.dart` |
| P0-06/07 Mapbox offline-region download/render and manual start | `offline_map_screen.dart`, `landmark_markers.dart` |
| P0-08 verified coordinates and graph node | `landmark.dart`, `landmarks.json` |
| P0-09/10 graph route, geometry, distance, ETA | `routing_service.dart`, `route_result.dart`, `navigation_screen.dart` |
| P0-11/12 full offline flow and honest errors | Relevant approved flow files and packaged assets |

Implement in dependency order: model/runtime validity → data validity → recognition/unknown handling → map/manual origin → graph routing → end-to-end wiring → device proof. A screen mock, a schema fixture, or a Mac inference result does not prove Android acceptance.

## Verification state

Physical Android release install, airplane-mode cold launch, Android ONNX inference, and 8 GB memory/latency measurement still require device evidence. Refer to `SDD.md` and `SETUP.md`; report each as passed, failed, or not run with actual evidence.

When assigning work, include the exact P0 ID, approved file(s), behavior, relevant contract, local check, and device/offline status. Do not add a runtime backend, new model, additional map region, GPS, online map fallback, database, or architecture layer to solve a P0 task.
