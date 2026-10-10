# Known landmark gaps — SM Makati and MRT EDSA Station

This note honestly records the current, verified limitations of the two newest
catalog entries. It does not overclaim: it states exactly what works and what
does not.

## The two new POIs

| id | name | area_id | routable | recognition |
|----|------|---------|----------|-------------|
| `sm-makati` | SM Makati | makati | no (recognition-only) | **functional (4 real OpenCLIP reference embeddings)** |
| `mrt-edsa` | MRT EDSA Station (Taft Avenue) | pasay | no (recognition-only) | **functional (4 real OpenCLIP reference embeddings)** |

Both entries are present in `assets/landmarks/landmarks.json` with verified
coordinates and parse without error (the catalog now holds 17 unique ids).

## What works today

- **Catalog registration.** Both POIs load through
  `Landmark.listFromJsonString`, have `hasValidLocation == true`, and are
  correctly recognition-only (`isRoutable == false`, `routeNodeId == null`).
  Covered by `test/new_landmarks_test.dart`.
- **Map markers.** `landmarkMarkers()` produces a marker at each POI's exact
  catalog position, and `OfflineMapScreen` renders that destination marker in
  the live widget tree without throwing. Covered by
  `test/new_landmarks_test.dart`.
- **Recognition.** Both POIs now carry **real** 512-d OpenCLIP ViT-B/32
  (laion2b_s34b_b79k, int8) reference embeddings in
  `assets/landmarks/reference_embeddings.json` — 4 vectors each, every vector
  L2-normalized (max norm deviation 2.2e-16, within the Dart matcher's ±0.001
  gate). The vectors were produced by running the packaged OpenCLIP ONNX model
  over licensed Wikimedia Commons photos through `tools/prepare_dataset.py`'s
  own embedding path. No vector was hand-written.

  Licensed source photos (retained under their CC/CC0 terms, with per-file
  Author/Source/License/LicenseURL/Modifications PNG text chunks):

  | id | reference images | authors | licenses |
  |----|------------------|---------|----------|
  | `mrt-edsa` | `assets/images/mrt-edsa/1-4.png` | SJasminum, LMP 2001, Matthew Gan | CC BY-SA 4.0 |
  | `sm-makati` | `assets/images/sm-makati/1-4.png` | Ramon FVelasquez, Judgefloro | CC0 |

  Held-out evaluation (real inference, 2 photos per landmark, scored against the
  full 59-vector index): **top-3 = 4/4**. `sm-makati` held-out photos rank
  `sm-makati` top-1 (cosine 0.85, 0.78); `mrt-edsa` held-out photos rank
  `mrt-edsa` top-1 (0.65) and rank-2 (0.66). Held-out source photos
  (`test/datasets/held_out/public/<id>/1-2.png`): `mrt-edsa` from Mithril Cloud
  (CC BY 2.5) and ChrisVillarin.com (CC BY 3.0); `sm-makati` from Judgefloro
  (CC0). Scores are raw cosine similarity, not calibrated probabilities.

## What does NOT work yet (the gaps)

1. **The basemap under these markers may be blank.** The bundled offline tile
   archive (`assets/maps/manila_tiles.bin`) covers a bounded Intramuros/Manila
   extract. SM Makati (Makati) and MRT EDSA Station (Pasay) fall at the edge of
   or outside that region, so their markers currently render over blank
   background tiles. Markers still render at the correct coordinates; only the
   underlying basemap is missing. The `tools/prepare_dataset.py` `prepare` map
   step enforces a <=0.05deg bbox (an Intramuros-sized extract), so widening the
   basemap to cover Makati (~8 km away) and Pasay needs a separate tile-region
   design. **This is flagged as a scope decision for the user, not implemented
   here.** Walking-route navigation also remains Intramuros-only by design:
   `sm-makati` and `mrt-edsa` are recognition-only (no `route_node_id`).

## Verification status

See the "New-landmark test verification" section at the end of this file for
the exact commands run and their real results.

## Embedding pipeline verification (real embeddings for the two new POIs)

Recorded after generating real embeddings. Only verified results are listed.
All commands were run from the repo root on macOS using `.venv/bin/python`.

- **Pipeline path used:** targeted embedding + merge, **not** `prepare` and
  **not** the full `create_index`/`evaluate`. Reason: the shipped
  `landmarks.json` has 4 pre-existing Manila POIs (`rizal-park`,
  `sm-city-manila`, `robinsons-place-manila`, `up-manila`) that carry a
  `route_node_id`, which the tool's `validate()` rejects ("only Intramuros POIs
  may have a route_node_id"). That mismatch between the tool's stricter rule and
  the shipped data/runtime predates this task; the committed
  `reference_embeddings.json` itself fails the same `validate()`. Per decision,
  `validate()`, `landmarks.json`, and all routing code were left untouched.
  Instead, embeddings for only the 8 new reference images were produced with the
  pipeline's own `load_embedder` + `image_embedding` (the real OpenCLIP ONNX
  path) and merged into the existing index, preserving all 51 existing vectors.
- **Images:** 12 licensed photos downloaded through the tool's approved-host
  path (`upload.wikimedia.org`) and processed with the tool's exact PIL pipeline
  (EXIF transpose, RGB, longest edge <=1024 px LANCZOS, lossless PNG
  optimize=True, embedded attribution). 8 reference + 4 held_out. Real
  `original_sha256` and processed `sha256` pinned in `test/datasets/sources.json`
  (103 photos total; 91 pre-existing preserved). `photo_sources()` and
  `verify_photos()` both pass on the new entries.
- **Merged index:** `assets/landmarks/reference_embeddings.json` now has 59
  references. Header (`model_id`, `model_sha256`, `preprocessing_version`,
  `dimension`) unchanged. `sm-makati` = 4 vectors, `mrt-edsa` = 4 vectors (both
  in the required 3–5 range). New vectors' max L2-norm deviation = 2.2e-16. All
  51 pre-existing vectors verified byte-identical to the pre-task backup.
  `parity.json` / `parity_input.bin` left unchanged (the parity anchor
  `fort-santiago/1.png` is untouched).
- **Held-out evaluation (real inference):** top-3 = 4/4. Per photo:
  - `held_out/public/mrt-edsa/1.png` → top3 `[sm-makati 0.689, mrt-edsa 0.662, up-manila 0.600]` (hit, rank 2)
  - `held_out/public/mrt-edsa/2.png` → top3 `[mrt-edsa 0.650, up-manila 0.556, sm-city-manila 0.495]` (hit, rank 1)
  - `held_out/public/sm-makati/1.png` → top3 `[sm-makati 0.852, sm-city-manila 0.701, lucky-chinatown-mall 0.552]` (hit, rank 1)
  - `held_out/public/sm-makati/2.png` → top3 `[sm-makati 0.784, sm-city-manila 0.660, lucky-chinatown-mall 0.592]` (hit, rank 1)
- `flutter pub get` — succeeded.
- `flutter analyze` — 6 pre-existing errors, all in
  `test/landmark_matcher_test.dart` (`matchBest`/`referencePhotos` API drift,
  unrelated to this data change). No new issues.
- `flutter test` — 52 passed, 2 failed; the 2 failures are the documented
  pre-existing ones (`landmark_matcher_test.dart` compile error and
  `widget_test.dart: one best match ...` `Bad state: No element`). No new
  failures; the suites that load `reference_embeddings.json` / `landmarks.json`
  and render markers pass, confirming the merged index loads and the Dart
  matcher accepts the new vectors.

Not run (device obligations per AGENTS.md §9/§10): `flutter build apk --release`,
airplane-mode cold launch on physical hardware, and 8 GB on-device
memory/latency measurement. These require physical hardware and were not
produced; no device result is claimed.

## New-landmark test verification

Recorded after the test work for the two new POIs. Only verified results are
listed. All commands were run from the repo root on macOS (darwin-arm64).

- `flutter pub get` — succeeded (dependencies resolved).
- `flutter analyze` — **not clean**: 6 pre-existing errors, ALL confined to the
  unrelated committed file `test/landmark_matcher_test.dart` (it calls
  `matchBest`/`referencePhotos`, which the current `LandmarkMatcher` no longer
  defines). Verified these exist on a clean HEAD before this task's edits. The
  three files touched by this task
  (`test/new_landmarks_test.dart`, `integration_test/new_landmarks_e2e_test.dart`,
  `test/landmark_test.dart`) analyze with **no issues**.
- `flutter test test/new_landmarks_test.dart` — **passed** (all catalog
  registration + marker + offline-map rendering tests). The console prints
  "Unable to load asset: assets/tiles/..." for Makati/Pasay tiles; that is the
  expected blank-basemap gap, not a test failure.
- `flutter test test/landmark_test.dart` — **passed** after updating the stale
  bundled-catalog count from 15 to the real 17 (a factual correction to the
  actual data, not a weakening). The matching assertions on the two new POIs
  live in `test/new_landmarks_test.dart`.
- Full `flutter test` — all suites pass EXCEPT two pre-existing failures that
  are unrelated to this task and reproduce on a clean HEAD:
  `test/landmark_matcher_test.dart` (fails to compile, see above) and
  `test/widget_test.dart: one best match is ready for explicit destination
  confirmation` (`Bad state: No element`).
- `flutter test integration_test/new_landmarks_e2e_test.dart -d emulator-5554`
  — **passed on an Android emulator** (sdk gphone16k arm64, API 37). The real
  EmbeddingService (native channel stubbed), LandmarkMatcher and
  RecognitionScreen ran; a diffuse noise query was correctly rejected to
  **Not recognized**, and neither new POI was falsely matched.
- `flutter test integration_test/app_test.dart -d emulator-5554` — **passed**
  (2 tests), confirming the existing e2e flow still works.

Not run: `flutter build apk --release`, airplane-mode cold launch on physical
hardware, and 8 GB on-device memory/latency measurement were out of scope for
this test-focused task.
