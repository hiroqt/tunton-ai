# Verification — recognition accept-threshold + margin gate

**Task:** make the recognition accept decision stricter and data-driven so
ambiguous / non-reference photos are rejected as "Not recognized" instead of
shown as a confident #1 (serves PRD **P0-04**, supports P0-03).

**Workspace:** `/Users/arnel/tunton-ai` — changes left UNCOMMITTED per instruction.

## Chosen values (from measured data — see analysis.md)

- `defaultScoreThreshold = 0.40` (was `0.55`)
- `defaultMinTopMargin = 0.05` (new)

The reference-vs-reference INTRA (correct) and INTER (wrong-landmark) cosine
distributions overlap heavily (INTER median ~0.66 vs INTRA p25 ~0.69), so the
absolute threshold alone cannot separate correct from wrong. Real on-device
held-out photos were observed at raw cosine 0.36–0.68, so a high absolute gate
would reject genuine matches. The **margin gate (0.05)** is therefore the primary
ambiguity filter: when top-1 and top-2 landmark scores are within 0.05 the result
is rejected as "Not recognized". Full reasoning + percentiles in `analysis.md`.

## Files changed (approved list only, AGENTS.md §6)

- `lib/features/recognition/landmark_matcher.dart`
  - `defaultScoreThreshold` 0.55 → 0.40 with doc comment citing analysis.
  - Added `static const double defaultMinTopMargin = 0.05;` with doc comment.
  - Added `final double minTopMargin;` field; threaded through the private
    constructor and all three factories (`fromDecodedJson`, `fromJsonString`,
    `load`) as a named param defaulting to `defaultMinTopMargin`, mirroring
    `scoreThreshold`.
  - `match(...)`: after sort + absolute threshold, applies the margin gate —
    if ≥2 candidates and `candidates[0].score - candidates[1].score < minTopMargin`
    returns an empty `MatchResult` (Not recognized). Debug logging extended to
    log the margin and the accept/reject reason. Public shapes of
    `LandmarkCandidate` / `MatchResult` and the `FormatException` validation
    behavior unchanged. Cosine = plain dot product, max-per-landmark,
    descending sort, ≤3 distinct ids all preserved.
- `test/landmark_matcher_test.dart`
  - Fixed `caps the result at 3` fixture (old near-tie scores would now be
    rejected by the margin gate) to give alpha a clear win while 4 landmarks
    stay above threshold.
  - Added: margin near-tie → Not recognized; clear dominant winner → recognized;
    below absolute threshold (no tie) → Not recognized; single candidate above
    threshold → accepted; defaults equal the measured 0.40 / 0.05.

No map code changed. Confirmed `lib/features/map/offline_map_screen.dart` and
`lib/features/map/landmark_markers.dart` never consume `MatchResult`; the only
consumer of `matcher.match()` is `lib/main.dart`, which maps candidates to
confirmed destinations, so an empty (Not recognized) result cannot reach the map.

## Commands actually run and results

Run from `/Users/arnel/tunton-ai`.

### 1. `flutter pub get`
```
Got dependencies!
```
Exit code 0. (16 packages have newer incompatible versions — pre-existing,
unrelated to this change.)

### 2. `flutter analyze`
```
Analyzing tunton-ai...
No issues found! (ran in 3.6s)
```
Exit code 0. Clean — no new issues.

### 3. `flutter test` (full suite)
```
00:03 +60: All tests passed!
```
Exit code 0. All 60 tests passed.

### Matcher file alone — `flutter test test/landmark_matcher_test.dart`
All 14 tests passed, including:
- `ambiguity gate: two near-equal top scores within the margin => Not recognized`
  (debug log confirmed: `REJECT ambiguous ... margin=0.0000 < minTopMargin=0.05`)
- `ambiguity gate: a clear dominant winner beyond the margin is recognized`
- `below the absolute threshold stays Not recognized even without a tie`
- `a single candidate above threshold is accepted (margin gate n/a)`
- `defaults use the measured threshold and margin` (0.40 / 0.05)
- `real asset: a stored reference vector self-matches its own landmark`
  (512-dim real asset, top score ~1.0 >> threshold, margin well above 0.05)

## Not run (out of scope for this step / environment)

- `flutter build apk --release` and on-device airplane-mode cold launch: this
  step is the recognition decision change only; device/APK proof is a separate
  obligation (AGENTS.md §9) and no physical device run was performed here.
- 8 GB device memory/latency measurement: not applicable to this logic change;
  no device run performed.

## Change-report (AGENTS.md §10)

```
P0 requirement (exact ID): P0-04 (Handle uncertainty / Not recognized); supports P0-03
Approved file(s) edited:
  lib/features/recognition/landmark_matcher.dart
  test/landmark_matcher_test.dart
What now works: ambiguous photos (top-1 and top-2 landmark scores within 0.05)
  are rejected as "Not recognized" instead of shown as a confident #1; absolute
  threshold lowered to 0.40 to keep the genuine real-photo band (0.36-0.68) while
  the margin gate does the ambiguity filtering.
Model checkpoint and preprocessing verified (yes/no; evidence): n/a for this change
  (no model re-export). Reference embeddings read as-is (512-dim,
  openclip-vit-b32-laion2b-s34b-b79k-int8-dynamic) for the data analysis.
Commands/tests actually run and results:
  flutter pub get -> Got dependencies (exit 0)
  flutter analyze -> No issues found (exit 0)
  flutter test -> All 60 tests passed (exit 0)
Android release test (passed / failed / not run): not run
Airplane-mode cold-launch test (passed / failed / not run): not run
8 GB memory results (measured / not measured): not measured
Remaining blocker or scope decision: none; device/APK proof is a separate step.
```
