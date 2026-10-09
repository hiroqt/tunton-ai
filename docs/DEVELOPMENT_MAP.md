# TUNTON Development Map

This page distinguishes the current checkout from the approved Android P0 target. It is a navigation/status aid, not product authority. [`PRD.md`](PRD.md) defines scope; [`ARD.md`](ARD.md) defines approved files and contracts; [`SDD.md`](SDD.md) explains the Android design.

## Current checkout (inspected 2026-10-09)

```text
lib/
├── main.dart                               # generated Flutter counter starter
├── features/
│   ├── recognition/
│   │   ├── embedding_service.dart          # local TFLite preprocessing/inference logic
│   │   └── landmark_matcher.dart           # local reference ranking
│   └── navigation/
│       └── routing_service.dart            # graph path calculation
└── shared/models/
    ├── landmark.dart
    └── route_result.dart

tools/
└── prepare_dataset.py                      # developer-machine asset preparation

assets/
├── models/landmark_embedder.tflite
├── images/                                  # licensed reference set
├── landmarks/{landmarks,reference_embeddings}.json
├── maps/intramuros_graph.json
└── tiles/{z}/{x}/{y}.png                      # legacy OSM-rendered tiles; not Mapbox SDK data
```

Observed asset inventory: 6 catalog records, 23 reference images and vectors (1024 dimensions), 3,268 graph nodes, 7,245 directed edges, and 156 legacy OSM-rendered tile files. Mapbox map data cannot be bundled; these raster files are not the target runtime basemap and should not be presented as proof of Mapbox readiness. The model file SHA-256 is `bbbb4c51a55a53905af1daec995ca1aae355046f8839bb8c9f5ce9271394bc40`. These are file/inventory facts, not proof that the app flow works or that data is legally/physically validated.

The current `lib/main.dart` is still the generated counter sample. Approved app shell, camera/recognition/map/navigation screens, and full flow wiring are not present. Current `pubspec.yaml` declares `image` and `tflite_flutter`; the other packages in the ARD-approved target are not yet declared.

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
├── models/landmark_embedder.tflite
├── images/[licensed reference photos]
├── landmarks/{landmarks,reference_embeddings}.json
├── maps/intramuros_graph.json

tools/prepare_dataset.py                      # build time only, never an app server
```

The approved app packages are `image_picker`, `image`, `tflite_flutter`, `mapbox_maps_flutter`, and `flutter_riverpod`, in addition to Flutter. The target Mapbox region is downloaded by its SDK and stored outside the Flutter asset tree. The current checkout has not yet migrated its dependency or map screen; use versions/contracts recorded in `pubspec.yaml` and `ARD.md` as the implementation is completed. The approved preparation-only environment is separately documented in `ARD.md` and [`TUNTON_BACKEND_STRUCTURE.md`](TUNTON_BACKEND_STRUCTURE.md).

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

No physical Android release install, airplane-mode cold launch, Android TFLite inference, or 8 GB memory/latency measurement is established by this inventory. Refer to the verification sections in `SDD.md` and `SETUP.md`; report each check as passed, failed, or not run with its actual evidence.

When assigning work, include the exact P0 ID, approved file(s), behavior, relevant contract, local check, and device/offline status. Do not add a runtime backend, new model, additional map region, GPS, online map fallback, database, or architecture layer to solve a P0 task.
