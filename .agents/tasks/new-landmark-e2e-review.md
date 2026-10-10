# E2E/widget tests and honesty gap doc for SM Makati and MRT EDSA Station

The change registers two recognition-only POIs (`sm-makati`/Makati, `mrt-edsa`/Pasay) in the bundled catalog and adds test coverage that asserts only genuinely-true behavior for them: device-free catalog-registration and map-marker tests in `test/`, a channel-stubbed photo→recognize e2e in `integration_test/`, a stale catalog-count correction (15→17) in `test/landmark_test.dart`, and an honest gap doc (`docs/KNOWN_LANDMARK_GAPS.md`) plus a README pointer. No reference embeddings or licensed images were added for either POI, so recognition remains non-functional and the e2e proves the honest "Not recognized" outcome rather than a fabricated positive match. The approach reuses the existing `integration_test/app_test.dart` harness exactly, keeping the real `EmbeddingService`/`LandmarkMatcher`/`RecognitionScreen` in the loop and stubbing only the native ONNX call.

Watch for: nothing blocking. The honesty-critical risks (fabricated vectors, a rigged recognition stub, a weakened existing test) were all checked against the actual repo state and are absent (confirmed). The recorded verification evidence is specific and the claimed pre-existing failures were independently reproduced from the parent branch (confirmed).

**Verdict**: APPROVED

## High-level view

The honesty posture holds. `assets/landmarks/reference_embeddings.json` was not touched by the commit and contains no `sm-makati`/`mrt-edsa` entries, so there is no fabricated vector anywhere in the diff. The e2e feeds a uniform `[1,1,…,1]` 512-vector through the real `EmbeddingService.embed` → `normalizeEmbedding` → `LandmarkMatcher.match` path — the same proven noise technique already used by `app_test.dart`'s "Not recognized" test — so the assertion exercises genuine matching math, not a stub that pretends recognition works.

The three required test groups are all present and correctly scoped. Catalog registration (both POIs present, clean parse, `hasValidLocation == true`, `isRoutable == false`, `routeNodeId == null`, 17 unique ids, no duplicates) and map-marker rendering (a `Marker` at each POI's exact catalog position plus an exception-free `OfflineMapScreen` build) live in `test/new_landmarks_test.dart` so they run device-free. The channel-stubbed "Not recognized" flow lives in `integration_test/new_landmarks_e2e_test.dart` and carries a prominent comment explaining why recognition is non-functional for these two POIs.

No existing test was weakened or deleted. The only edit to an existing test is the 15→17 count in `test/landmark_test.dart`, which matches the real catalog (confirmed: 17 ids in the file; the parent branch asserted 15). The two failures the commit flags as pre-existing — `landmark_matcher_test.dart` compile errors and the `widget_test.dart` "one best match" `Bad state` — were independently reproduced from `origin/main`: the `matchBest`/`referencePhotos` calls exist on the parent, and neither file was modified by this commit.

The gap doc is factual and does not overclaim. It states plainly that recognition is non-functional (no embeddings, no licensed images), lists the exact steps to close the gap (add licensed photos, rerun `prepare_dataset.py`), and warns that the offline basemap tiles under the Makati/Pasay markers may be blank. The README adds a one-line pointer with the same honest framing.

<details>
<summary>Issues (0)</summary>

No blocking or non-blocking findings. All honesty-critical and correctness checks passed against the actual repository state.

</details>

<details>
<summary>Details</summary>

## No fabricated embeddings anywhere in the diff

The honesty crux of this task is whether recognition for the two new POIs was faked. It was not (confirmed). `assets/landmarks/reference_embeddings.json` does not appear in the commit's file list, and a direct search of the file finds zero occurrences of `sm-makati` or `mrt-edsa`; the embedded ids are the original 16 Manila/Intramuros landmarks. There is no placeholder vector, no zero-filled stand-in, no copied vector reused under a new id.

The e2e's "Not recognized" assertion rides the real matching path rather than a rigged shortcut. The stub returns `List<num>.filled(EmbeddingService.dimension, 1.0)` for the `embed` method call; that value flows through the genuine `EmbeddingService.embed`, which runs it through `normalizeEmbedding` to produce a true L2-normalized uniform vector, and then into `LandmarkMatcher.match`, which computes real cosine dot products against the real reference set and applies the real `scoreThreshold`/`minTopMargin`/`strongMatchThreshold` gates. This is the identical technique `app_test.dart` already uses in its `noise vector below the gates shows Not recognized` test, and both tests are recorded as passing on the emulator. The outcome is therefore an empirically-confirmed property of the real pipeline, not an assertion rigged by the stub. Because neither new POI has any reference vector, there is no code path by which the stub could cause a false positive for them — the test additionally asserts `find.text('SM Makati')` and `find.text('MRT EDSA Station (Taft Avenue)')` are both absent, nailing down that neither is surfaced as a confident destination.

The in-code comment block at the top of `new_landmarks_e2e_test.dart` explains *why* the test asserts "Not recognized" and not a positive match, naming the missing reference embeddings and licensed images and citing AGENTS.md §8. This satisfies the requirement that the channel-stub flow carry a comment explaining why recognition is non-functional for these two POIs.

## The three required test groups are correct and correctly placed

Catalog registration lives in `test/new_landmarks_test.dart` and asserts exactly the required facts. Both POIs are looked up by id (with an explicit `StateError` if missing); each is checked for `name`, `areaId`, `hasValidLocation == true`, `isRoutable == false`, `routeNodeId == null`, and exact `latitude`/`longitude` via `closeTo(..., 1e-9)`. These assertions are backed by the real model: `Landmark.isRoutable` is `routeNodeId != null`, and the catalog entries carry no `route_node_id`, so both resolve to non-routable with a null node (confirmed by reading `landmark.dart` and the catalog JSON). The uniqueness/count test asserts `landmarks.length == 17` and `ids.toSet().length == ids.length`; `listFromJsonString` additionally throws on any duplicate id, so a clean parse is itself proof of uniqueness. The real file contains 17 `"id"` entries (confirmed).

Map-marker rendering is covered two ways in the same device-free file. `landmarkMarkers()` is asserted to emit exactly one marker whose `point` equals both `sm.position` and `LatLng(sm.latitude, sm.longitude)` for each POI — a genuine marker at the catalog coordinate, matching the `landmark_markers.dart` implementation that sets `point: place.position`. Then `OfflineMapScreen` is pumped with each POI as destination; the test asserts `tester.takeException() == null`, that a `FlutterMap` is present, and that `find.bySemanticsLabel('Destination: ${destination.name}')` finds the marker. That semantics label matches the `Semantics(label: 'Destination: ${place.name}')` the marker builder emits for the destination id. The `loadZooms: () async => const [17]` injection is a legitimate existing seam (present on the parent branch) used so the map body renders instead of the unavailable state; the test honestly notes it does not assert tile pixels, consistent with the blank-basemap gap.

The channel-stubbed "Not recognized" e2e lives in `integration_test/` and is a faithful clone of `app_test.dart`: same `MethodChannel('com.tunton/vision')`, same `TestDefaultBinaryMessengerBinding` mock handler for `initialize`/`embed`, same `buildApp()` wiring of the real services, and the same `captureAndRecognize` driving sequence. Placing the device-free registration and marker tests in `test/` (so they run without a device) and only the channel-stubbed flow in `integration_test/` matches the required split exactly.

## No existing test weakened; the one edit is a factual correction

The only change to an existing test is `test/landmark_test.dart` flipping `expect(landmarks.length, 15)` to `17`, with a comment pointing at the new entries. The parent branch (`origin/main`) asserted `15` and the real catalog now holds `17` ids (both confirmed), so this tracks reality rather than relaxing an assertion — the test still pins an exact count and would fail if a POI were dropped or duplicated. The detailed per-POI assertions were added in a new file rather than diluting the existing one.

## Pre-existing failures are genuinely pre-existing

The commit is candid that `flutter analyze` is not clean and that two tests fail, attributing all of it to unrelated pre-existing code. This was independently checked. `test/landmark_matcher_test.dart` references `matchBest`/`referencePhotos` on `origin/main` (6 occurrences), and the current `LandmarkMatcher` defines neither, so the compile error predates this task; the file was not touched by the commit. The `widget_test.dart` "one best match" test exists on the parent and `widget_test.dart` was likewise not modified here. Flagging these honestly rather than papering over them is the correct posture, and none of them are introduced or worsened by this change.

## Gap doc and README are factual

`docs/KNOWN_LANDMARK_GAPS.md` states what works (registration, markers) and what does not (recognition non-functional for want of embeddings/images; basemap tiles possibly blank for Makati/Pasay) without overclaiming. It gives the concrete remediation path (add 3–5 licensed photos, rerun `tools/prepare_dataset.py` to produce real 512-d embeddings) and explicitly records that no fabricated vectors were added, citing AGENTS.md §8. Its verification section mirrors the commit message's recorded results and is clear about what was not run (release APK build, airplane-mode cold launch, 8 GB memory measurement). The README adds a single pointer row with matching framing — registered and mapped, but recognition and basemap tiles not yet in place.

## Verification evidence is sufficient; no suite re-run needed

The commit records specific, reproducible evidence: `flutter pub get` ok; `flutter analyze` with 6 errors confined to the unrelated `landmark_matcher_test.dart`; `test/new_landmarks_test.dart` and `test/landmark_test.dart` passing; the full suite passing except the two pre-existing failures; and both integration tests passing on an Android emulator (API 37). The specific honesty-critical claims (no embeddings added, count was 15 now 17, pre-existing failures reproduce on the parent) were each independently confirmed from the repo and git history, which removes any articulable doubt that would warrant re-running a suite. No spot-check was required.

</details>

<details>
<summary>File map</summary>

- `assets/landmarks/landmarks.json` — adds `sm-makati` (Makati) and `mrt-edsa` (Pasay) entries with verified coordinates, no route node.
- `test/new_landmarks_test.dart` (new) — device-free catalog-registration + marker-creation + `OfflineMapScreen` rendering tests for both POIs.
- `integration_test/new_landmarks_e2e_test.dart` (new) — channel-stubbed photo→recognize e2e asserting honest "Not recognized" with no false match; mirrors `app_test.dart`.
- `test/landmark_test.dart` — bundled-catalog count corrected 15→17 to match real data.
- `docs/KNOWN_LANDMARK_GAPS.md` (new) — honest record of recognition and basemap gaps plus remediation and verification status.
- `README.md` — one-line pointer to the gap doc.

Full diff: `git show 9ce4556`.

</details>
