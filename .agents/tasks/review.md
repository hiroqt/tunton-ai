# Real OpenCLIP embeddings and licensed images for sm-makati and mrt-edsa

Adds real, model-produced OpenCLIP ViT-B/32 reference embeddings and licensed Wikimedia Commons imagery for the two recognition-only landmarks `sm-makati` (Makati) and `mrt-edsa` (Pasay), both already registered in `landmarks.json`. Twelve CC/CC0 photos (8 reference + 4 held-out) were downloaded through the tool's approved-host path, processed with `prepare_dataset.py`'s exact PIL pipeline, and embedded through its real ONNX path; the 8 reference vectors were merged into `reference_embeddings.json` (now 59 refs), and `sources.json` grew to 103 entries. The coder deviated from the plan's `index`/`evaluate` run — using a targeted embed-and-merge instead — because the tool's `validate()` rejects pre-existing route-bearing Manila POIs; this deviation is disclosed in the gap doc and does not compromise honesty.

Watch for: the merge path bypassed the self-verifying `create_index` run (confirmed), so I independently re-ran the tool's ONNX embedding on two sampled PNGs and reproduced the stored vectors exactly (max|Δ|=0, cos=1.0) — the embeddings are genuinely model-produced, not fabricated. One pre-existing unpushed commit (`9ce4556`, from the earlier "add e2e testing" step) sits ahead of origin/main; it is NOT from this data task and this task made no commit (confirmed).

**Verdict**: APPROVED

## High-level view

Honesty is the gating concern and it holds. All 51 pre-existing reference vectors are byte-identical to the pre-task backup, the index header is unchanged, and the 8 new vectors are distinct, non-degenerate, 512-d and L2-normalized (max norm deviation 2.2e-16). Because the coder skipped the self-verifying `index` run, I spot-checked by re-embedding two new PNGs through `prepare_dataset.image_embedding`; both reproduced the stored vectors with zero difference, which is strong direct evidence the vectors came from the actual ONNX model on the actual bytes.

Checksums and licensing are real. The tool's `verify_photos()` passes on all 12 new entries, which re-hashes each processed PNG and confirms the embedded Author/Source/License/LicenseURL/Modifications text chunks match `sources.json` exactly — so the `sha256` values are real hashes of real bytes and attribution is embedded, not just declared. Every new source is CC0 or a CC BY/BY-SA variant with complete attribution, `country=PH`, real PH locations, and geographic_evidence carrying both a URL and a visual-review basis. CC0 entries use the exact canonical license_url string the existing entries use.

Scope is clean. Only the approved files changed (`sources.json`, the new PNGs, `reference_embeddings.json`, the gap doc); `landmarks.json` is untouched (both ids were already registered), `parity.json`/`parity_input.bin` were left unchanged, the temporary staging helper is deleted, and no commit or push was performed for this task. The gap doc honestly flags the Makati/Pasay offline-basemap coverage limitation as a deferred scope decision rather than pretending to solve it.

<details>
<summary>Issues (2)</summary>

1. **Plan deviation: merge path instead of index run (non-blocking)** — the coder used targeted embed-and-merge rather than `create_index`/`evaluate` because `validate()` rejects pre-existing route-bearing POIs. Disclosed in the gap doc; independently verified honest by re-embedding. No action required.
2. **Pre-existing unpushed commit ahead of origin (informational)** — `9ce4556` from the prior "add e2e testing" step is 1 ahead of origin/main and not pushed. It is not part of this data task and contains no data files. No action required for this task; flag before any later push decision.

</details>

<details>
<summary>Details</summary>

## Embeddings are real, not fabricated

The plan prescribed regenerating the whole index with `prepare_dataset.py index`, whose success would have been self-verifying (it re-hashes every photo and re-embeds every reference). The coder could not take that path: the shipped `landmarks.json` carries four Manila POIs with a `route_node_id` that the tool's `validate()` rejects, so a full `index` run fails on data that predates this task. The coder instead embedded only the 8 new reference PNGs through the pipeline's own `load_embedder` + `image_embedding` and merged them, leaving the 51 existing vectors in place. This is disclosed plainly in `docs/KNOWN_LANDMARK_GAPS.md`.

Because the merge path removes the self-verifying guarantee, I re-embedded two sampled new PNGs (`sm-makati/1.png`, `mrt-edsa/3.png`) through `prepare_dataset.image_embedding` against the same ONNX session the tool uses. Both reproduced the stored vectors with `max|Δ| = 0.00e+00` and `cos = 1.00000000`. Reproducing a 512-d vector bit-for-bit is only possible if the stored vector was produced by that same model on those same bytes — this is direct evidence the embeddings are genuine, not invented.

The new vectors are also structurally sound: all eight are distinct (no two share a hash), none is all-zero, each is 512-d, and the maximum L2-norm deviation from unity is 2.2e-16 — far inside the Dart matcher's ±0.001 gate.

## Existing index preserved

Comparing the regenerated `reference_embeddings.json` against `.agents/tasks/backup/reference_embeddings.json` by `(landmark_id, image_asset)`: all 51 pre-existing vectors are byte-identical, none dropped or mutated, and the header fields (`model_id`, `model_sha256`, `preprocessing_version`, `dimension`) are unchanged. Total refs went 51 → 59, with `sm-makati`=4 and `mrt-edsa`=4, both inside the required 3–5 band.

## Checksums and licensing

`verify_photos()` passes on all 12 new entries. That routine re-computes each processed PNG's SHA-256 against the `sha256` in `sources.json` and checks the embedded PNG text chunks (Author/Source/License/LicenseURL/Modifications) match the declared metadata — so the processed hashes are real hashes of real bytes and the attribution is physically embedded in the files, not merely asserted in JSON. `photo_sources()` also passes, which enforces field completeness, path canonicalization, split/path-prefix rules, and the no-duplicate-path / no-duplicate-original_sha256 cross-split leakage guard across all 103 entries.

Licensing per entry:
- `mrt-edsa` references: SJasminum, LMP 2001, Matthew Gan — all CC BY-SA 4.0 with version-specific license URLs.
- `sm-makati` references: Ramon FVelasquez, Judgefloro — all CC0, using the exact `http://creativecommons.org/publicdomain/zero/1.0/deed.en` string the existing CC0 entries use.
- Held-out: Mithril Cloud (CC BY 2.5), ChrisVillarin.com (CC BY 3.0), Judgefloro (CC0).

Every entry has `country=PH`, a real PH `location`, the exact required `modifications` string, and a `geographic_evidence` object with both `url` and a `basis` that cites the Commons category and states the image was visually reviewed against the named location.

## Held-out evaluation reported honestly

The gap doc records real-inference held-out results as top-3 = 4/4, including the imperfect case where `mrt-edsa/1.png` ranks `mrt-edsa` only at rank 2 behind `sm-makati` (0.689 vs 0.662). Reporting the near-miss rather than smoothing it over is consistent with the honesty requirement, and scores are explicitly labeled raw cosine, not calibrated probabilities.

## Scope and no-commit

Working tree shows exactly the expected modifications: `reference_embeddings.json`, `sources.json`, `docs/KNOWN_LANDMARK_GAPS.md`, the four new image directories, plus `pubspec.lock` and `plan.md`. `landmarks.json` is clean — not modified for these two ids, which were already registered. `parity.json`/`parity_input.bin` are unchanged (the parity anchor `fort-santiago/1.png` is untouched). The temporary `tools/_stage_new_landmarks.py` helper is deleted and no `.bak` files remain; the `.agents/tasks/backup/` copies persist outside the app bundle, which the plan allows.

No commit was made by this task: the only commit ahead of origin (`9ce4556`, 08:16) predates the image files (08:34), contains no data files, and belongs to the earlier e2e-testing step. That commit is unpushed; it is out of scope for this task but worth noting before any future push.

## Map rendering

The user's requirement that the new landmarks render on the map is satisfied at the data/marker level: both ids are in `landmarks.json`, `landmark_markers.dart` iterates all landmarks with no area filter, and `main.dart` loads the full catalog. The honest caveat — recorded in the gap doc — is that the bundled offline tiles cover only an Intramuros-sized extract, so the Makati/Pasay markers render over blank basemap. That is correctly flagged as a deferred scope decision, not silently patched.

</details>

<details>
<summary>File map</summary>

- `assets/landmarks/reference_embeddings.json` — 51 → 59 refs; adds 4 real vectors each for sm-makati and mrt-edsa; header and existing vectors unchanged.
- `test/datasets/sources.json` — 91 → 103 photo entries; adds 8 reference + 4 held-out licensed sources with real hashes and full attribution.
- `assets/images/{sm-makati,mrt-edsa}/{1..4}.png` — new processed reference PNGs (RGB, ≤1024, embedded attribution).
- `test/datasets/held_out/public/{sm-makati,mrt-edsa}/{1..2}.png` — new held-out PNGs.
- `docs/KNOWN_LANDMARK_GAPS.md` — honest gap doc; records pipeline deviation, licenses, held-out eval, and the deferred offline-basemap gap.
- Not modified: `landmarks.json`, `parity.json`, `parity_input.bin`.

Full diff: `git diff` plus untracked `assets/images/*`, `test/datasets/held_out/public/*`.

</details>
