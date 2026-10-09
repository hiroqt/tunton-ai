# TUNTON Backend and Data Pipeline E2E Guide

**Audience:** Backend/data-preparation AI agents and co-developers. **Scope:** Existing build-time Python pipeline only.
**Runtime service:** None. This guide does not add or approve an API, server, database, or network dependency.

## 1. Mission

Own a reproducible pipeline that validates real, licensed source data and produces the model, landmark, embedding, and pedestrian-graph artifacts required by TUNTON P0. The Mapbox basemap is downloaded through the Android SDK and is outside this build-time pipeline. Verify the backend pipeline from pinned inputs through generated outputs and evaluation evidence.

This task is backend-only. It does not implement or modify Flutter screens, app services, app dependencies, Android files, or frontend behavior. Preserve all existing frontend and unrelated files. The pipeline ends at validated local artifacts; downstream application integration is outside this guide.

## 2. Scope boundary and source of truth

For this project, **backend means build-time data preparation on the developer machine**. The sole approved implementation entrypoint is:

```text
tools/prepare_dataset.py
```

The installed app's P0 path remains offline and device-local. Do not create a runtime backend, FastAPI/Flask service, API endpoints, database, accounts, sync, uploads, analytics, telemetry, remote inference, or a Flutter HTTP client. No backend process may be required after installation.

Follow this authority order:

1. [`PRD.md`](PRD.md) — P0 goals and exclusions.
2. [`ARD.md`](ARD.md) — allowed files, packages, schemas, model, and data contracts.
3. [`ARCHITECTURE.md`](ARCHITECTURE.md) — system boundaries and data flow.
4. [`SETUP.md`](SETUP.md) — environment and preparation procedure.
5. Root [`AGENTS.md`](../AGENTS.md) — scope gate and guardrails.

This guide is a backend work procedure. It does not supersede those documents. Before code changes, state which P0 requirement the pipeline work supports and name the approved file. If the fix requires a new runtime service, dependency, or source path, stop for explicit scope review.

The preparation pipeline supplies evidence-bearing inputs for P0-02 (approved model), P0-03/04 (reference index and evaluation data), P0-08 (verified landmark catalog), P0-09 (pedestrian graph), and P0-11/12 (complete local assets and validated failure inputs). P0-06 Mapbox region download and offline rendering are Android app responsibilities. Passing backend checks alone does not pass those runtime requirements.

## 3. Backend pipeline topology

```text
Inputs
  ├── test/datasets/sources.json       photo source/provenance manifest
  ├── test/datasets/map_source.json    bounded, source-documented map snapshot
  ├── assets/images/                   prepared reference photos, when present
  └── assets/models/landmark_embedder.tflite (pinned checkpoint, when present)
             │
             ▼
tools/prepare_dataset.py
  ├── validate provenance, paths, checksums, schemas, bounds, and graph links
  ├── acquire only allowlisted HTTPS source bytes when local bytes are absent
  ├── normalize photos and create the real MobileNet reference index
  ├── derive pedestrian graph from the OSM map snapshot
  ├── evaluate held-out and unknown photos
  └── stage a complete output directory and refuse unsafe overwrites
             │
             ▼
Validated output directory
  ├── assets/                            distributable app-data candidates (no Mapbox map data)
  └── test/datasets/                     source records, evaluation data, reports, parity fixtures
```

The `test/datasets/` subtree is backend evaluation material and must not be copied into the app asset bundle. The team-held-out input directory is `test/datasets/held_out/team/`.

## 4. Approved backend stack

Use an isolated Python 3.12 environment on the developer machine. The currently approved preparation versions are:

| Component | Version | Purpose |
|---|---:|---|
| Python | 3.12 | Preparation CLI and backend checks |
| `ai-edge-litert` | 2.3.0 | Execute the approved TFLite image embedder while preparing vectors |
| `numpy` | 2.5.3 | Tensor, vector, normalization, and evaluation calculations |
| `Pillow` | 12.3.0 | Image decoding/conversion and legacy raster-tile rendering in the current tool |
| `osmnx` | 2.1.1 | Approved isolated map-preparation environment; not shipped or used as a runtime service |

Do not add dependencies for convenience. No web framework is approved. Do not build a parallel script tree: extend the existing `tools/prepare_dataset.py` only when the required backend behavior belongs there and remains within P0.

## 5. Backend ownership and deliverables

The backend/data-preparation owner is responsible for:

1. Maintaining source manifests and the map snapshot with geographic, license, attribution, and checksum evidence.
2. Validating trust-boundary inputs before downloads, decoding, inference, graph conversion, or export.
3. Producing normalized source photos and actual reference embeddings from the single approved model.
4. Producing a verified landmark catalog and pedestrian graph with real edge geometry. Mapbox offline data is downloaded by the app and must never be produced or redistributed by this pipeline.
5. Running the backend E2E pipeline and its negative/failure cases in disposable outputs.
6. Recording exact commands, environment versions, artifact checksums, report locations, and known blockers.

The backend handoff is a set of inspected artifacts and reproducible evidence. Do not report a Mac result as Android inference, airplane-mode, APK, or 8 GB device proof.

## 6. Input contracts and provenance

### 6.1 Photo source manifest

`test/datasets/sources.json` contains the photo records. Preserve the fields validated in `photo_sources()` in `tools/prepare_dataset.py`, including:

- Canonical relative `path`, `split`, and `landmark_id` for supported examples.
- `page_url`, `download_url`, author, license, license URL, and modification record.
- SHA-256 for both prepared bytes and original source bytes.
- `country: "PH"`, a named Philippine location, and geographic evidence with both `url` and `basis`.

Allowed splits and roots are enforced by the tool:

| Split | Required root | Rule |
|---|---|---|
| `reference` | `assets/images/` | Must identify a catalog landmark and have valid redistribution rights. |
| `held_out` | `test/datasets/held_out/` | Separate image/source from references; used to evaluate supported inputs. |
| `unknown` | `test/datasets/unknown/` | Must not have a supported `landmark_id`; used to inspect false matches/rejection behavior. |

Reject path traversal, symlink escape, duplicate paths, reused original source bytes across splits, missing attribution, invalid checksums, non-Philippine provenance, unsupported splits, oversized content, or invalid image format. Prepared reference images are lossless RGB PNG, at most 1024 pixels on a side, with embedded attribution matching the manifest.

Remote acquisition must retain the current HTTPS host allowlist, redirect checks, byte limits, and expected SHA-256 verification. Do not broaden the allowlist or skip a checksum to make preparation pass.

### 6.2 Map snapshot

`test/datasets/map_source.json` is the bounded OSM pedestrian-graph preparation input. Preserve its `schema_version`, metadata/source/license records, `bbox`, catalog evidence, landmarks, OSM nodes, ways, relations, and access evidence. Its OSM provenance supports the pedestrian graph; Mapbox is a separate basemap provider.

- `bbox` order is `[west, south, east, north]`; graph coordinates use latitude then longitude.
- Require Philippine map provenance and a small bounded Intramuros extent. Current data uses zooms 15–18.
- Keep only valid pedestrian transitions. Preserve access restrictions, foot directionality, edge lengths, and source geometry.
- Do not infer walking access from vehicle tags alone or fabricate route connectors.
- San Agustin Church and Baluarte de San Diego use explicitly named exterior public street approaches where the graph has no permitted connector to the entrance.
- Graph, Mapbox region, and landmarks must describe the same area; the app-side region download needs separate Android verification.

### 6.3 Model and image-vector contract

- Use the official Google MediaPipe MobileNetV3 Small **image embedder** named in `AGENTS.md` and `ARD.md`.
- Expected checkpoint SHA-256: `bbbb4c51a55a53905af1daec995ca1aae355046f8839bb8c9f5ce9271394bc40`.
- Inspected input: float32 `[1, 224, 224, 3]`; output: float32 `[1, 1024]`.
- Preprocessing: apply EXIF orientation, convert RGB, full-frame floor-index nearest resize to 224×224, scale pixels by 1/255, then L2-normalize the output vector.
- Every reference vector must be finite, nonzero, length 1024, normalized, and labeled with an existing catalog landmark ID and reference image path.
- Require six distinct landmarks and 3–5 reference images per landmark for the P0 demo data.
- Keep model ID, checkpoint, preprocessing, dimension, and generated vectors coupled. Never mix models or treat cosine similarity as calibrated confidence.

## 7. Output artifact contracts

`prepare` emits a complete staged tree. The backend owner validates these outputs before handing them downstream:

| Path | Required backend content |
|---|---|
| `assets/models/landmark_embedder.tflite` | Exact approved checkpoint and SHA-256 |
| `assets/images/<landmark>/<image>.png` | Licensed, labeled reference images with source attribution |
| `assets/landmarks/landmarks.json` | Unique IDs, verified names/coordinates, valid graph-backed route node IDs |
| `assets/landmarks/reference_embeddings.json` | Model ID, observed dimension, complete finite normalized reference vectors |
| `assets/maps/intramuros_graph.json` | Valid nodes and permitted directed pedestrian edges with `length_m` and actual `[lat, lon]` geometry |
| `test/datasets/sources.json` | Copied provenance manifest for audit; test-only |
| `test/datasets/map_source.json` | Copied map source snapshot for audit; test-only |
| `test/datasets/evaluation_report.json` | Held-out and unknown results plus environment and timing labels; test-only |
| `test/datasets/parity.json`, `parity_input.bin` | Input tensor/vector fixture for checking the Android model boundary; test-only |

The tool must refuse to overwrite existing outputs. Create a new destination for each full preparation run; inspect it before promoting files to their approved repository destinations. Preserve the distinction between distributable `assets/` and evaluation-only `test/datasets/`.

## 8. End-to-end backend integration procedure

The E2E integration check follows the backend path only; it uses no frontend, UI, API server, or database.

### Stage A — Prepare a fresh isolated environment

From the repository root:

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install \
  ai-edge-litert==2.3.0 numpy==2.5.3 Pillow==12.3.0 osmnx==2.1.1

PYTHON=.venv/bin/python
OUT="build/tunton-prepared-$(date +%Y%m%d-%H%M%S)"
test ! -e "$OUT"
```

Do not install these packages globally or into the Android runtime.

### Stage B — Run the full preparation pipeline

```bash
"$PYTHON" tools/prepare_dataset.py prepare \
  --sources test/datasets/sources.json \
  --map-source test/datasets/map_source.json \
  --source-root . \
  --output-dir "$OUT"
```

The current command stages a model and photos from verified local bytes when available, otherwise downloads only from allowed HTTPS hosts and checks the expected hashes. It validates source inputs, constructs the landmark and graph outputs, renders legacy OSM raster tiles, creates embeddings with the approved checkpoint, evaluates held-out and unknown photos, and writes output to a previously absent directory. Those generated raster tiles are not Mapbox data and are not consumed by the approved Mapbox runtime. The preparation implementation still needs a follow-up P0-06 alignment to stop treating those legacy tiles as required app outputs. A command failure, missing evidence, or bad schema is a pipeline failure; never use partially produced output.

### Stage C — Verify backend integration outputs

Check all of the following on the generated output:

1. Model file SHA equals the approved checkpoint hash; tensor shapes and dtypes match the documented contract.
2. Every reference image matches its source manifest checksum and embedded attribution.
3. Catalog has six unique supported IDs; each has 3–5 distinct reference images and a valid route node.
4. Every reference embedding is finite, nonzero, length 1024, L2-normalized, and tied to an existing landmark/image.
5. Graph edge endpoints exist; lengths are finite and positive; geometry has correct `[latitude, longitude]` order and follows source pedestrian geometry.
6. Intended landmark route endpoints have a real connected path; disconnected pairs remain disconnected instead of receiving a fabricated edge.
7. The OSM pedestrian graph and landmarks cover the same bounded Intramuros area intended for the Mapbox offline-region configuration. Legacy rendered tiles do not prove Mapbox coverage or offline operation.
8. Held-out evaluation uses images distinct from references and unknown inputs carry no landmark label. Report top-1/top-3 results, unknown score behavior, checkpoint, environment, and timing; state clearly that rejection is uncalibrated unless calibration evidence exists.
9. Output includes the expected test-only manifests, parity fixtures, and evaluation report, and does not contain partial files from an earlier run.
10. Record a SHA-256 manifest for the final output files and compare it to the promoted artifact set.

### Stage D — Verify backend failure behavior

Use disposable fixtures or temporary output roots to check that invalid/missing fields, bad checksums, reused reference/held-out sources, unsafe paths, invalid coordinates, unknown landmark IDs, missing route nodes, malformed vectors, non-finite values, invalid graph edges, and pre-existing destinations fail visibly and leave existing user data untouched. Never corrupt the real prepared tree to create a failure case.

## 9. CLI commands and existing backend checks

The preparation CLI supports:

```text
prepare          Full source → model/index/graph/evaluation pipeline into a new directory; currently also emits legacy raster tiles that Mapbox does not use.
index            Create real reference embeddings and parity fixtures in a prepared root.
evaluate         Re-run held-out/unknown matching and write a report at a new path.
compare-android  Compare expected and device-produced embedding vectors for identical model/image hashes.
```

Use `"$PYTHON" tools/prepare_dataset.py <command> --help` for the exact current arguments. `index` and report creation refuse to overwrite existing files. `compare-android` is a model-boundary parity check only; it is not a frontend test or proof of the complete Android app flow.

The existing focused backend suite can be run after preparation-code changes:

```bash
for test_file in test/prepare_dataset_*_test.py; do
  "$PYTHON" "$test_file" || exit 1
done
```

Coverage includes schema normalization/export through the CLI with temporary fixtures, malformed input and overwrite behavior, source/provenance boundaries, path containment, graph properties, and numerical parity validation. Legacy tile checks cover historical pipeline output only; they do not establish Mapbox coverage or acceptance. **The current `prepare_dataset_e2e_test.py` exercises the schema-export CLI path with synthetic fixtures; it does not run the full network/source/model/graph `prepare` workflow.** Do not represent that unit/E2E fixture coverage as a full real-data pipeline run. Stage A–D above records the separate full-pipeline integration evidence.

Do not run tests or real-data preparation against shared/production data. Use the local checkout and fresh disposable output directories. No tests or full pipeline results are claimed by this guide.

## 10. Security, privacy, licensing, and data integrity rules

- No user photo, identity, account data, telemetry, or analytics enters this pipeline.
- Keep test and held-out images out of distributable app assets.
- Do not place credentials or secrets in source manifests, generated JSON, logs, fixtures, or artifacts. The Mapbox app needs a scoped public access token for connected style/region download; supply it through app build configuration and never commit it. Public mobile tokens are extractable, so minimize scopes and review current usage charges/limits.
- Treat every manifest and map snapshot as untrusted. Keep strict schema/type checks, finite-number checks, input-size limits, path containment, redirect validation, checksum verification, and no-overwrite behavior.
- Preserve source and license details for every photo and pedestrian-graph dataset. Mapbox map data must be fetched from Mapbox through its SDK and may not be bundled, preloaded, or redistributed.
- The graph remains OSM-derived; retain required **© OpenStreetMap contributors** attribution. Do not use the public OSM tile service as a raster source.
- Do not claim current accessibility, gate status, or closure status from static offline data.

## 11. Backend agent/co-developer work report

Every backend task handoff should contain:

```text
P0 requirement supported:
Approved backend file(s) changed:
Input manifest/map snapshot and source revisions/checksums:
Model checkpoint SHA, tensor contract, and preprocessing:
Output paths and checksums:
Photo counts/splits, licensing/provenance, and six-landmark validation:
Graph connectivity/geometry and OSM graph attribution (Mapbox region download is verified separately on Android):
Exact commands run and observed outcomes:
Existing focused tests run and outcomes (or not run):
Real-data full-pipeline E2E: passed / failed / not run, environment identified:
Held-out and unknown report path/results:
Known limitations, blockers, and next backend owner:
```

Report Mac CPU evidence as Mac CPU evidence. Report Android parity only when the comparison actually ran. Device release, airplane-mode, and memory checks belong to separate acceptance work and must not be inferred from backend tests.

## 12. Stop conditions

Stop and report a blocker if model provenance, photo rights, Philippine location evidence, verified POI coordinates, legal map source, graph connectivity, or output integrity cannot be established. Do not weaken validation, manufacture vectors/roads/metrics, expand geography, introduce a runtime API, or delete/modify frontend or unrelated files to make the backend pipeline pass.

For governing contracts, see [`PRD.md`](PRD.md), [`ARD.md`](ARD.md), [`ARCHITECTURE.md`](ARCHITECTURE.md), and [`SETUP.md`](SETUP.md).
