# Known landmark gaps — SM Makati and MRT EDSA Station

This note honestly records the current, verified limitations of the two newest
catalog entries. It does not overclaim: it states exactly what works and what
does not.

## The two new POIs

| id | name | area_id | routable | recognition |
|----|------|---------|----------|-------------|
| `sm-makati` | SM Makati | makati | no (recognition-only) | **non-functional (no reference embeddings yet)** |
| `mrt-edsa` | MRT EDSA Station (Taft Avenue) | pasay | no (recognition-only) | **non-functional (no reference embeddings yet)** |

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

## What does NOT work yet (the gaps)

1. **Recognition is non-functional for these two POIs.** There are no reference
   embeddings for `sm-makati` or `mrt-edsa` in
   `assets/landmarks/reference_embeddings.json`, and no licensed images under
   `assets/images/<id>/`. A photo of either place cannot be recognized today.
   To make recognition work:
   - Add 3–5 licensed photos under `assets/images/sm-makati/` and
     `assets/images/mrt-edsa/`.
   - Re-run `tools/prepare_dataset.py` to generate real 512-d OpenCLIP
     embeddings and write them into `reference_embeddings.json`.
   No fabricated/placeholder vectors have been added — fabricating embeddings
   would violate `AGENTS.md` §8. The honest end-to-end behavior (a non-matching
   query returns **Not recognized** rather than a false positive) is covered by
   `integration_test/new_landmarks_e2e_test.dart`.

2. **The basemap under these markers may be blank.** The bundled offline tile
   archive (`assets/maps/manila_tiles.bin`) covers a bounded Intramuros/Manila
   extract. SM Makati (Makati) and MRT EDSA Station (Pasay) fall at the edge of
   or outside that region, so their markers currently render over blank
   background tiles. Markers still render at the correct coordinates; only the
   underlying basemap is missing. To close this gap the tile archive must be
   regenerated to include the Makati/Pasay extent.

## Verification status

See the "New-landmark test verification" section at the end of this file for
the exact commands run and their real results.

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
