# Implementation Plan — Real embeddings + licensed images for `sm-makati` and `mrt-edsa`

## Goal
Produce REAL OpenCLIP reference embeddings and licensed, attribution-stamped images for the two
NEW recognition-only landmarks already registered in `assets/landmarks/landmarks.json`:
`sm-makati` (area `makati`) and `mrt-edsa` (area `pasay`). Every vector must come from actually
running the OpenCLIP ONNX model over a real downloaded licensed photo via `tools/prepare_dataset.py`.
Every SHA-256 in `sources.json` must be a real hash of real bytes. Nothing is fabricated. If the
pipeline cannot produce a value honestly, STOP and report (see Honesty constraint below).

## Honesty constraint (AGENTS.md §8 — binding)
- NEVER hand-write an embedding vector, a checksum, or image bytes.
- Every reference vector is produced only by `create_index` / `evaluate` running the ONNX model.
- Every `original_sha256` is the real SHA-256 of the bytes downloaded from `upload.wikimedia.org`.
- Every processed `sha256` is the real SHA-256 of the PNG the tool's exact PIL pipeline wrote.
- If any download host is rejected, any checksum mismatches, any license is not actually CC/CC0, or
  any landmark cannot reach 3–5 reference vectors, STOP and report the exact tool error — do not
  invent, pad, or substitute values.

---

## Pipeline-path DECISION (made from reading the code — do not re-decide)

**Chosen path: targeted `index` + `evaluate` against the repo root. DO NOT use `prepare`.**

Why (verified by reading `tools/prepare_dataset.py`):
- `prepare_dataset()` rebuilds `assets/landmarks/landmarks.json` from `map_source.json['landmarks']`
  and `assets/maps/intramuros_graph.json` from the OSM snapshot, and enforces
  `0 < east-west <= 0.05` and `0 < north-south <= 0.05` on `snapshot['bbox']`.
- The repo's `test/datasets/map_source.json` has `bbox = [120.968, 14.581, 120.98, 14.596]` (a tiny
  Intramuros extract) and `landmarks = [fort-santiago, manila-cathedral, san-agustin, casa-manila,
  baluarte-san-diego, puerta-real]` — only 6 Intramuros POIs.
- Running `prepare` would therefore (a) OVERWRITE `landmarks.json` with just those 6, DROPPING all 10
  Manila/Makati/Pasay landmarks including `sm-makati` and `mrt-edsa`, then (b) fail `create_index`
  because the new photos label landmark_ids no longer in the catalog. The 0.05° cap (~5.5 km) also
  cannot be widened to reach Makati (~8 km away) / Pasay. So `prepare` is structurally wrong here.
- `index` (`create_index`) and `evaluate` operate against `--root .` and DO NOT touch
  `landmarks.json`, the graph, `map_source.json`, or tiles, and do not download. They read the
  existing catalog, verify photos already staged on disk, run the model, and write the index/parity
  / report. That is exactly the surgical scope this task needs.

**Overwrite + "every catalog POI needs 3–5 refs" facts (verified in code):**
- `create_index` refuses to run if ANY of these exist: `assets/landmarks/reference_embeddings.json`,
  `test/datasets/parity.json`, `test/datasets/parity_input.bin`. All three currently exist.
- `create_index` rebuilds the ENTIRE index from ALL `reference`-split photos in the passed
  `sources.json`, and asserts `3 <= count <= 5` for EVERY id in `landmarks.json`. A sources file
  containing only the two new landmarks would fail (the other 15 ids would have 0 refs).
- Therefore the index must be regenerated from the SUPERSET sources.json (existing 91 photos + the
  new ones). This is still fully honest and additive: all 91 existing images are present locally and
  byte-identical, so re-indexing reproduces the existing 51 vectors exactly and ADDS the new ones.
  The first reference photo stays `assets/images/fort-santiago/1.png`, so `parity.json` /
  `parity_input.bin` regenerate identically.

**Preserve-existing procedure:** back up the three output files, regenerate from the superset
sources.json, then (step 11) prove the 51 pre-existing vectors are byte-identical to the backup
before accepting. If any pre-existing vector changed, STOP and report.

---

## Verified environment facts (do not re-verify blindly, but these are the ground truth)
- Python: `/Users/arnel/tunton-ai/.venv/bin/python` → 3.12. Has `onnxruntime` 1.23.2, `open_clip`
  3.2.0, `PIL` 12.3.0, `numpy` 2.5.3, `onnx` present.
- Model: `assets/models/openclip_vit_b32_laion2b_int8.onnx` + `...manifest.json` present;
  manifest `model_sha256 = 94273ff4c9c4366403bc041f1f53621251fc0bf466842bced27d3c30ce13ef0d`,
  which equals the `model_sha256` already in `reference_embeddings.json`. Dimension 512.
- `landmarks.json` already contains `sm-makati` (makati) and `mrt-edsa` (pasay), both WITHOUT
  `route_node_id` (recognition-only). DO NOT edit `landmarks.json`.
- `sources.json`: 91 photos (51 reference / 30 held_out / 10 unknown). Shape of one entry is pinned
  below. CC0 entries already present and ALL use
  `license_url = "http://creativecommons.org/publicdomain/zero/1.0/deed.en"` — match that string.
- `reference_embeddings.json`: 51 references, every existing catalog landmark has 3–5 vectors.
- `assets/images/sm-makati` and `assets/images/mrt-edsa` DO NOT exist yet; neither do their
  `test/datasets/held_out/public/<id>/` dirs. All 91 existing photo files exist locally.
- Dart `LandmarkMatcher` rejects any reference vector whose L2 norm deviates from 1 by > 0.001.
  (The tool's `image_embedding` divides by the norm, so real outputs satisfy this.)
- Baseline `flutter test` (captured now, BEFORE any change): exactly TWO pre-existing failures —
  1. `test/landmark_matcher_test.dart` fails to COMPILE: it calls `matchBest(...)` and
     `referencePhotos` which no longer exist on `LandmarkMatcher` (API drift, unrelated to data).
  2. `widget_test.dart › "one best match is ready for explicit destination confirmation"`
     (`Bad state: No element` at widget_test.dart:245, UI-fixture drift, unrelated to data).
  These two MUST remain the only failures after this task. Do NOT fix them unless a change here
  trivially caused them (it will not — they are pre-existing and data-independent).

---

## Exact `sources.json` entry shape (copy field-for-field)
Required string fields (all non-empty, verified by `photo_sources`): `path`, `landmark_id`,
`split`, `page_url`, `download_url`, `author`, `license`, `license_url`, `original_sha256`,
`modifications`, `source_title`, `location`, `country` (must be `"PH"`),
`geographic_evidence` = object with `url` + `basis`, and `sha256`. `capture_date` is OPTIONAL
(the sm-city-manila entries omit it; omit it for the new photos unless you have a real value).
- `split` ∈ {`reference`, `held_out`}. For `reference`, `path` MUST start with `assets/images/`;
  for `held_out`, `path` MUST start with `test/datasets/held_out/` (existing held_out files use
  `test/datasets/held_out/public/<id>/N.png`). Do NOT add `unknown` photos (10 already exist).
- `sha256` and `original_sha256` must be lowercase 64-hex. Paths must be canonical relative
  (no `..`, no leading `/`, no backslash). No duplicate `path` and no duplicate `original_sha256`
  anywhere in the file (cross-split leakage guard).
- `modifications` MUST be EXACTLY:
  `EXIF orientation applied; converted to RGB; longest edge reduced to at most 1024 pixels using Pillow LANCZOS; lossless PNG with optimize=True; EXIF metadata omitted.`
- `country` MUST be `"PH"`; `location` a non-empty PH string; `geographic_evidence.basis` must state
  the Commons category/description identifies the named PH location AND that it was visually reviewed.

Model reference entry (shape in `reference_embeddings.json`, produced by the tool, never hand-made):
`{ "landmark_id", "image_asset" (= the `assets/images/...` path), "vector" (512 finite floats) }`.

---

## The vetted licensed images to use (download via tool `download()`; hosts limited to
## upload.wikimedia.org / storage.googleapis.com)

### mrt-edsa — REFERENCE (target 4–5), Commons Category:Taft Avenue station
1. Taft Avenue station (MRT) 01.jpg — `https://upload.wikimedia.org/wikipedia/commons/0/01/Taft_Avenue_station_%28MRT%29_01.jpg` — author `SJasminum` — CC BY-SA 4.0 `https://creativecommons.org/licenses/by-sa/4.0` — page `https://commons.wikimedia.org/wiki/File:Taft_Avenue_station_(MRT)_01.jpg`
2. Taft Avenue station (MRT) 02.jpg — `https://upload.wikimedia.org/wikipedia/commons/8/8b/Taft_Avenue_station_%28MRT%29_02.jpg` — author `SJasminum` — CC BY-SA 4.0 — page `https://commons.wikimedia.org/wiki/File:Taft_Avenue_station_(MRT)_02.jpg`
3. Taft Avenue MRT-3 2024-03-06.jpg — `https://upload.wikimedia.org/wikipedia/commons/7/70/Taft_Avenue_MRT-3_2024-03-06.jpg` — author `LMP 2001` — CC BY-SA 4.0 — page `https://commons.wikimedia.org/wiki/File:Taft_Avenue_MRT-3_2024-03-06.jpg`
4. LRT-1 MRT-3 Walkway EDSA Station Taft Station.jpg — `https://upload.wikimedia.org/wikipedia/commons/7/78/LRT-1_MRT-3_Walkway_EDSA_Station_Taft_Station.jpg` — author `Matthew Gan` — CC BY-SA 4.0 — page `https://commons.wikimedia.org/wiki/File:LRT-1_MRT-3_Walkway_EDSA_Station_Taft_Station.jpg`
5. MRT Taft Station - panoramio.jpg — `https://upload.wikimedia.org/wikipedia/commons/4/4e/MRT_Taft_Station_-_panoramio.jpg` — author `ChrisVillarin.com` — CC BY 3.0 `https://creativecommons.org/licenses/by/3.0` — page `https://commons.wikimedia.org/wiki/File:MRT_Taft_Station_-_panoramio.jpg`

### mrt-edsa — HELD_OUT (target 2, different photos from reference)
6. MRT3-LRT1 Bridge.jpg — `https://upload.wikimedia.org/wikipedia/commons/a/ab/MRT3-LRT1_Bridge.jpg` — author `Mithril Cloud` — CC BY 2.5 `https://creativecommons.org/licenses/by/2.5` — page `https://commons.wikimedia.org/wiki/File:MRT3-LRT1_Bridge.jpg`
7. One more from Category:Taft Avenue station via the Commons API (e.g. a `0362jf... EDSA Taft Avenue MRT Station...` file). Resolve its real `download_url`, `license`, `license_url`, `author`, `page_url` through the API (step 1) and verify a CC/CC0 license before use.

### sm-makati — REFERENCE (target 4–5), Commons Category:SM Makati
8. Smmakatijf.JPG — `https://upload.wikimedia.org/wikipedia/commons/a/af/Smmakatijf.JPG` — author `Ramon FVelasquez` — CC0 — page `https://commons.wikimedia.org/wiki/File:Smmakatijf.JPG`
9. 9991Makati Central Business District Landmarks 07.jpg — `https://upload.wikimedia.org/wikipedia/commons/4/42/9991Makati_Central_Business_District_Landmarks_07.jpg` — author `Judgefloro` — CC0 — page `https://commons.wikimedia.org/wiki/File:9991Makati_Central_Business_District_Landmarks_07.jpg`
10. ...Landmarks 08.jpg — `https://upload.wikimedia.org/wikipedia/commons/8/81/9991Makati_Central_Business_District_Landmarks_08.jpg` — `Judgefloro` — CC0
11. ...Landmarks 09.jpg — `https://upload.wikimedia.org/wikipedia/commons/5/5e/9991Makati_Central_Business_District_Landmarks_09.jpg` — `Judgefloro` — CC0
12. ...Landmarks 10.jpg — `https://upload.wikimedia.org/wikipedia/commons/5/53/9991Makati_Central_Business_District_Landmarks_10.jpg` — `Judgefloro` — CC0

### sm-makati — HELD_OUT (target 2, different photos from reference)
13. ...Landmarks 11.jpg — `https://upload.wikimedia.org/wikipedia/commons/5/54/9991Makati_Central_Business_District_Landmarks_11.jpg` — `Judgefloro` — CC0 — page `https://commons.wikimedia.org/wiki/File:9991Makati_Central_Business_District_Landmarks_11.jpg`
14. ...Landmarks 12.jpg — resolve real `download_url`/license via Commons API (expected CC0 `Judgefloro`) — page `https://commons.wikimedia.org/wiki/File:9991Makati_Central_Business_District_Landmarks_12.jpg`

**License string rules:**
- CC0 → `license = "CC0"`, `license_url = "http://creativecommons.org/publicdomain/zero/1.0/deed.en"`
  (EXACT string already used by all 4 existing CC0 entries; `author` = the uploader, non-empty).
- CC BY / CC BY-SA → the version-specific URL shown above (no trailing slash to match existing style,
  e.g. `https://creativecommons.org/licenses/by-sa/4.0`).
- `location`: `"SM Makati, Ayala Center, Makati, Metro Manila, Philippines"` /
  `"Taft Avenue station (MRT-3), EDSA, Pasay, Metro Manila, Philippines"`. `country = "PH"`.
- VISUALLY REVIEW each downloaded frame (step 6b). Drop any that does not clearly depict the
  building/station and pick another from the SAME Commons category via the API; record the real
  metadata for the replacement. Final per-landmark counts must land at 3–5 reference and ≥2 held_out.

---

# Ordered steps

- [ ] 1. Resolve the two API-sourced held_out candidates (items 7 and 14) and re-confirm every
      pinned license/URL. For each unresolved file query
      `https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url|extmetadata&titles=File:<name>`
      and read `imageinfo[0].url` (the real `upload.wikimedia.org` download URL), `extmetadata.LicenseShortName`,
      `extmetadata.License`/`LicenseUrl`, and `Artist`/`Attribution`. Confirm the license is CC0 or a
      CC BY/BY-SA variant; if not, STOP and pick another file from the same category. Record the real
      `download_url`, `license`, `license_url`, `author`, `page_url`, `source_title` for items 7 and 14.
      Files: none yet (research only; capture values for step 4).
      Verify: for each file, `/Users/arnel/tunton-ai/.venv/bin/python - <<'PY'` fetching the API JSON
      prints a non-empty `imageinfo[0].url` on `upload.wikimedia.org` and a CC/CC0 license short name.

- [ ] 2. Back up the three regenerated outputs so the preserve-existing check (step 11) and rollback
      are possible. Copy `assets/landmarks/reference_embeddings.json`,
      `test/datasets/parity.json`, `test/datasets/parity_input.bin` to
      `.agents/tasks/backup/` (create the dir). Do NOT delete the originals yet.
      Files: `.agents/tasks/backup/reference_embeddings.json`, `.agents/tasks/backup/parity.json`,
      `.agents/tasks/backup/parity_input.bin`.
      Verify: `ls -l .agents/tasks/backup/` shows all three; `python3 -c "import json;print(len(json.load(open('.agents/tasks/backup/reference_embeddings.json'))['references']))"` prints `51`.

- [ ] 3. Download each ORIGINAL and compute its real `original_sha256`, using the TOOL'S OWN
      `download()` so only approved hosts are allowed. Write a build-time helper
      `tools/_stage_new_landmarks.py` (temporary; delete in step 12) that imports `prepare_dataset`
      from `tools/`, and for each of the ~14 new files calls
      `data = prepare_dataset.download(download_url, EXPECTED)` — but since the expected hash is not
      yet known, instead fetch bytes once with an unverified fetch for discovery ONLY:
      replicate `download()`'s approved-host + 32 MiB checks, then compute
      `hashlib.sha256(bytes).hexdigest()`. Record each real `original_sha256`.
      (Discovery fetch and the tool's verified `download()` go to the same bytes; step 7 re-downloads
      through the tool's verified path so the pinned hash is enforced for real.)
      Files: `tools/_stage_new_landmarks.py` (new, temporary).
      Verify: the helper prints one real 64-hex `original_sha256` per file and all hosts were
      `upload.wikimedia.org`; no host-rejection error.

- [ ] 4. Build the superset `sources.json` by ADDING the new entries to the existing 91. For each new
      file create one entry with the pinned shape (section "Exact sources.json entry shape"):
      `reference` paths `assets/images/sm-makati/{1..N}.png` and `assets/images/mrt-edsa/{1..N}.png`;
      `held_out` paths `test/datasets/held_out/public/sm-makati/{1..M}.png` and
      `test/datasets/held_out/public/mrt-edsa/{1..M}.png`. Fill real `original_sha256` from step 3,
      the exact `modifications` string, correct license strings, `country":"PH"`, `location`,
      `geographic_evidence{url,basis}`. Leave `sha256` as a REAL value only after step 6 (or set a
      placeholder and finalize in step 6c). Do NOT touch existing entries.
      Files: `test/datasets/sources.json`.
      Verify: `/Users/arnel/tunton-ai/.venv/bin/python -c "import sys;sys.path.insert(0,'tools');import prepare_dataset as pd;ph=pd.photo_sources('test/datasets/sources.json');print(len(ph))"`
      runs WITHOUT error (this exercises every field/split/duplicate validation) and prints the new
      total (91 + number added). If `photo_sources` raises, fix the offending field and re-run.

- [ ] 5. Create the on-disk image directories. Make `assets/images/sm-makati/`,
      `assets/images/mrt-edsa/`, `test/datasets/held_out/public/sm-makati/`,
      `test/datasets/held_out/public/mrt-edsa/`.
      Files: those four directories.
      Verify: `ls -ld assets/images/sm-makati assets/images/mrt-edsa test/datasets/held_out/public/sm-makati test/datasets/held_out/public/mrt-edsa` lists all four.

- [ ] 6. Produce the processed PNGs with the tool's EXACT pipeline, compute their real `sha256`, and
      write them to the paths from step 4. Extend `tools/_stage_new_landmarks.py` to, for each new
      photo: `original = prepare_dataset.download(download_url, original_sha256)` (now VERIFIED
      against the step-3 hash), then replicate the tool's exact save block —
      `Image.open(io.BytesIO(original))` → `ImageOps.exif_transpose(...).convert('RGB')` →
      `thumbnail((1024,1024), Image.Resampling.LANCZOS)` → build `PngImagePlugin.PngInfo()` with text
      chunks `Author=author, Source=page_url, License=license, LicenseURL=license_url,
      Modifications=modifications` → `save(target, format='PNG', optimize=True, pnginfo=credits)`.
      Then (6a) `prepare_dataset.checksum(target)` → real processed `sha256`; (6b) open each PNG and
      visually/structurally sanity-check: `format=='PNG'`, `mode=='RGB'`, `max(size)<=1024`, and
      inspect the actual dimensions/content so it depicts the station/mall (drop & replace any that
      do not, updating step 1/4 metadata); (6c) write the real `sha256` back into the step-4 entries
      in `sources.json`.
      Files: new PNGs under the four dirs; `test/datasets/sources.json` (sha256 fields finalized);
      `tools/_stage_new_landmarks.py`.
      Verify: `/Users/arnel/tunton-ai/.venv/bin/python -c "import sys;sys.path.insert(0,'tools');import prepare_dataset as pd;pd.verify_photos([p for p in pd.photo_sources('test/datasets/sources.json') if p['landmark_id'] in ('sm-makati','mrt-edsa')],'.')"`
      exits 0 (this re-verifies each new PNG's real sha256 AND that embedded Author/Source/License/
      LicenseURL/Modifications text chunks match sources.json exactly). Any mismatch → STOP, fix, re-run.

- [ ] 7. Move the three existing output files aside so `create_index` can run (it refuses to
      overwrite). Rename `assets/landmarks/reference_embeddings.json`, `test/datasets/parity.json`,
      `test/datasets/parity_input.bin` to `*.bak` IN PLACE (they are already copied in step 2;
      renaming lets step 11 compare and lets a failure be rolled back).
      Files: the three files renamed to `.bak`.
      Verify: `ls assets/landmarks/reference_embeddings.json 2>&1` reports "No such file"; the three
      `.bak` files exist.

- [ ] 8. Regenerate the COMPLETE reference index over the superset sources.json, actually running the
      ONNX model. Run
      `/Users/arnel/tunton-ai/.venv/bin/python tools/prepare_dataset.py index --root . --sources test/datasets/sources.json`.
      This verifies all photos, loads the embedder, embeds every `reference` photo (existing 51 +
      new), enforces 3–5 refs per catalog id, validates landmarks/graph, and writes
      `reference_embeddings.json`, `parity.json`, `parity_input.bin`.
      Files (written by the tool): `assets/landmarks/reference_embeddings.json`,
      `test/datasets/parity.json`, `test/datasets/parity_input.bin`.
      Verify: stdout prints `Indexed <N> real reference photos; dimension 512` where
      `N = 51 + (new reference count)`. Non-zero exit or any `ValueError` → STOP and report the exact
      message (e.g. a 3–5 count violation means a landmark has too few/many references).

- [ ] 9. Run the held-out/unknown evaluation, actually running the model on held_out photos. Run
      `/Users/arnel/tunton-ai/.venv/bin/python tools/prepare_dataset.py evaluate --root . --sources test/datasets/sources.json --report test/datasets/evaluation_report.json`.
      Files (written by the tool): `test/datasets/evaluation_report.json`.
      Verify: stdout prints `Held-out top-3: X/Y; unknown inputs: Z`. Capture the full line. Then
      inspect `records` for the new held_out photos:
      `/Users/arnel/tunton-ai/.venv/bin/python -c "import json;r=json.load(open('test/datasets/evaluation_report.json'));[print(x['path'],x['expected'],x['top3'],{k:round(v,3) for k,v in x['scores'].items()}) for x in r['records'] if x.get('expected') in ('sm-makati','mrt-edsa')]"`.
      Record whether each new held_out photo ranks its own landmark in top-3 (report honestly; a miss
      is a real finding, not a reason to fabricate).

- [ ] 10. Count + L2-norm check on the two new landmarks in the regenerated index.
      `/Users/arnel/tunton-ai/.venv/bin/python - <<'PY'`
      load `assets/landmarks/reference_embeddings.json`, `from collections import Counter`, assert
      `3 <= count <= 5` for both `sm-makati` and `mrt-edsa`, and for every new vector assert
      `abs(sqrt(sum(v*v)) - 1) <= 0.001` (matches the Dart matcher gate). Print the two counts and
      max norm deviation.
      Files: none.
      Verify: script prints `sm-makati=<3..5>`, `mrt-edsa=<3..5>`, `max_norm_dev <= 0.001`, no assert
      failure. Any failure → STOP and report.

- [ ] 11. Preserve-existing proof: confirm the 51 pre-existing vectors are byte-identical to the
      backup and that parity regenerated identically.
      `/Users/arnel/tunton-ai/.venv/bin/python - <<'PY'`
      compare each reference in `.agents/tasks/backup/reference_embeddings.json` against the new file
      by `(landmark_id, image_asset)` and assert identical `vector` lists; also assert
      `model_id`/`model_sha256`/`preprocessing_version`/`dimension` unchanged; and compare
      `test/datasets/parity.json` and `test/datasets/parity_input.bin` byte-for-byte against the step-2
      backup. Print "existing-preserved: OK" or the first mismatch.
      Files: none.
      Verify: prints `existing-preserved: OK`. If ANY pre-existing vector changed or parity differs,
      STOP, restore the `.bak`/backup files, and report (do not accept a mutated index).

- [ ] 12. Clean up the temporary helper and the `.bak` files. Delete
      `tools/_stage_new_landmarks.py` and the three `*.bak` files from step 7. Keep
      `.agents/tasks/backup/` until the task is signed off (it is outside the app bundle), or delete
      it too if the reviewer prefers a clean tree. Do NOT delete `evaluation_report.json`.
      Files: remove `tools/_stage_new_landmarks.py`, `assets/landmarks/reference_embeddings.json.bak`,
      `test/datasets/parity.json.bak`, `test/datasets/parity_input.bin.bak`.
      Verify: `ls tools/_stage_new_landmarks.py 2>&1` and `ls *.bak` report "No such file".

- [ ] 13. Flutter dependency + analyzer + test gate; prove the data loads and the two pre-existing
      failures are UNCHANGED. Run `flutter pub get`, then `flutter analyze`, then `flutter test`.
      Files: none (verification only).
      Verify:
      - `flutter pub get` exits 0.
      - `flutter analyze` exits 0 (no NEW analyzer errors introduced by the data change — data files
        are not analyzed, so this should match the pre-task result).
      - `flutter test` shows EXACTLY the two pre-existing failures and no others:
        `test/landmark_matcher_test.dart` (compile error: `matchBest`/`referencePhotos`) and
        `widget_test.dart › "one best match ..."` (`Bad state: No element` at line 245). If any OTHER
        test newly fails — especially anything that loads `reference_embeddings.json` /
        `landmarks.json` — treat it as caused by this change and fix the data, not the test. The
        Dart matcher's norm gate (±0.001) is already satisfied by step 10, so a norm failure here
        would indicate a real problem.

- [ ] 14. Verify the new landmarks are RENDERED on the map (the user's explicit requirement).
      Confirmed by reading code (no code change needed, but prove it): `lib/main.dart` loads ALL of
      `landmarks.json` into `_LocalBackend.landmarks`; `landmark_markers.dart` renders a marker for
      every landmark in the iterable it is given (data-driven, no area filter); recognition of a
      recognition-only landmark surfaces the "<Area> place recognition is available; walking routes
      are currently supported in Intramuros" dialog in `photo_screen.dart` (expected — `sm-makati`
      and `mrt-edsa` have no `route_node_id`). Also confirm `_LocalBackend.load()` does NOT throw:
      its `missingReferences` check passes because both ids are in `landmarks.json`, and
      `unrouteableLandmarks` ignores recognition-only landmarks (they have `routeNodeId == null`).
      Files: none (confirmation only).
      Verify: `flutter test` (step 13) already drives `offline_map_screen` with marker rendering and
      shows no NEW failure; additionally grep-confirm no screen filters landmarks by `area_id` before
      building markers:
      `rg -n "area_id|areaId" lib/features/map` returns no filtering of the marker list. (This is a
      code-reading confirmation; the authoritative proof is the airplane-mode device run in step 16,
      flagged as a manual obligation.)

- [ ] 15. Write the honest gap doc. Create `docs/KNOWN_LANDMARK_GAPS.md` (approved doc target)
      stating: recognition for `sm-makati` (Makati) and `mrt-edsa` (Pasay) is now FUNCTIONAL with
      REAL OpenCLIP embeddings produced by `tools/prepare_dataset.py index`/`evaluate` over licensed
      Wikimedia Commons photos (list the files, authors, licenses, and that CC image licenses are
      retained per file); both are recognition-only (no `route_node_id`) by design. State the
      REMAINING gap clearly and honestly: the packaged offline basemap (`manila_tiles.bin` /
      `assets/tiles`) covers only an Intramuros ~0.05° extract, so Makati/Pasay markers render on the
      map layer but there is no offline basemap imagery under them, and the Dart Dijkstra walking
      route remains Intramuros-only — a WIDER basemap/region is a separate scope decision to be
      raised with the user, NOT implemented here. Record the exact `evaluate` stdout line and the
      per-landmark reference counts as evidence.
      Files: `docs/KNOWN_LANDMARK_GAPS.md`.
      Verify: file exists and names both landmarks, the real licenses, the functional-recognition
      claim, and the basemap-tiles gap as a flagged (not implemented) scope item.

- [ ] 16. (Manual, device obligation — DO NOT fabricate) Flag for the human: AGENTS.md §9 requires an
      actual-device airplane-mode cold launch to prove the two new landmarks recognize and render
      offline. This planning/data task cannot run on-device; the change-report must mark the
      airplane-mode and 8 GB-memory items as "not run" with that reason, per AGENTS.md §10. Do NOT
      claim a device result that was not produced.
      Files: none (the change-report, when written, must state this honestly).
      Verify: n/a (explicit honesty flag).

## Do-not / scope guards (restate)
- DO NOT edit `assets/landmarks/landmarks.json` (both landmarks already present, recognition-only).
- DO NOT run `prepare` (it would drop the Makati/Pasay catalog and enforce the 0.05° Intramuros bbox).
- DO NOT `git commit` or `git push`. Leave everything in the working tree.
- DO NOT fabricate any embedding, checksum, or image. Only approved files are touched:
  `test/datasets/sources.json`, `assets/images/{sm-makati,mrt-edsa}/*.png`,
  `test/datasets/held_out/public/{sm-makati,mrt-edsa}/*.png`,
  `assets/landmarks/reference_embeddings.json`, `test/datasets/parity.json`,
  `test/datasets/parity_input.bin`, `test/datasets/evaluation_report.json`,
  `docs/KNOWN_LANDMARK_GAPS.md`, plus the temporary `tools/_stage_new_landmarks.py` (deleted in 12).
- Preserve ALL existing `reference_embeddings.json` entries (proven byte-identical in step 11); only
  the two new landmarks' vectors are added.

---

## VERIFICATION NOTE (execution record)

**Path taken:** targeted embedding + merge (NOT `prepare`, NOT full `create_index`/`evaluate`).
Reason: the tool's `validate()` rejects the 4 pre-existing Manila POIs that carry a `route_node_id`
("only Intramuros POIs may have a route_node_id"). This predates the task — the committed
`reference_embeddings.json` fails the same `validate()`. Per parent decision, `validate()`,
`landmarks.json`, and all routing code were left untouched. New embeddings were generated with the
pipeline's own `load_embedder` + `image_embedding` (real OpenCLIP ONNX path) over the 8 new reference
PNGs and merged into the existing index; all 51 existing vectors preserved byte-for-byte.

**Images:** 12 licensed Commons photos (8 reference + 4 held_out) downloaded via the tool's
approved-host path and processed with its exact PIL pipeline; real `original_sha256` + processed
`sha256` pinned in `test/datasets/sources.json` (103 total). `photo_sources()` + `verify_photos()`
pass. All 12 visually confirmed to depict the landmark.
- mrt-edsa refs: SJasminum, LMP 2001, Matthew Gan — CC BY-SA 4.0.
- sm-makati refs: Ramon FVelasquez, Judgefloro — CC0.
- held_out: Mithril Cloud (CC BY 2.5), ChrisVillarin.com (CC BY 3.0), Judgefloro (CC0).

**Index:** 59 refs; header unchanged; sm-makati=4, mrt-edsa=4; new vectors max norm dev 2.2e-16;
51 existing vectors byte-identical to backup. parity.json/parity_input.bin unchanged.

**Held-out eval (real inference):** top-3 = 4/4.
- mrt-edsa/1 → [sm-makati .689, mrt-edsa .662, up-manila .600] hit(2)
- mrt-edsa/2 → [mrt-edsa .650, up-manila .556, sm-city-manila .495] hit(1)
- sm-makati/1 → [sm-makati .852, sm-city-manila .701, lucky-chinatown-mall .552] hit(1)
- sm-makati/2 → [sm-makati .784, sm-city-manila .660, lucky-chinatown-mall .592] hit(1)

**Flutter:** `flutter pub get` ok. `flutter analyze` — 6 pre-existing errors in
`test/landmark_matcher_test.dart` only, no new issues. `flutter test` — 52 pass, 2 fail (the two
documented pre-existing failures: landmark_matcher_test compile error + widget_test "one best match").

**Map rendering:** `landmark_markers.dart` iterates all landmarks with no area filter; `main.dart`
loads all of landmarks.json → both new POIs render as markers. Basemap-tiles gap for Makati/Pasay
flagged (not implemented) in docs/KNOWN_LANDMARK_GAPS.md.

**Not run (device obligations):** APK release build, airplane-mode cold launch, 8 GB memory — require
physical hardware; no device result claimed.

**No git commit / no push.** All changes left in the working tree.
