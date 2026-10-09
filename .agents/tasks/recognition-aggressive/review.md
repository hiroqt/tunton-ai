# Aggressive rejection gate + automatic single-best recognition

The change closes a known hole in `LandmarkMatcher.match` where a photo that weakly matched exactly one landmark above the 0.40 floor leaked through as a confident #1 (observed at cosine 0.4951), and it removes the manual candidate-pick / Confirm step so recognition advances automatically on the single accepted best match. A new `defaultStrongMatchThreshold = 0.55` gates the lone-candidate case, the margin gate is widened from 0.05 to 0.07 for the ≥2-candidate case, and `recognition_screen.dart` now consumes only `result.top`, firing the existing `onConfirm` navigation contract once per result. The P0-05 confirmation requirement is annotated as a dated, user-approved scope change in both PRD and ARD. The thresholds are drawn from the measured percentiles in `analysis.md`, not guessed, and every doc/comment keeps the honest "heavy INTRA/INTER overlap, ranking not probability" framing.

Watch for: nothing blocking. The bundled README edits describe a `flutter_map`/asset-tile map that diverges from the Mapbox PRD contract, but that is pre-existing documentation reconciliation unrelated to this task and already self-flagged in the README (**possible**, informational only).

**Verdict**: APPROVED

## High-level view

The threshold work is data-grounded and honest. `defaultStrongMatchThreshold = 0.55` sits strictly above the measured 0.4951 lone false hit, below the 0.36–0.68 real-photo band, and just above INTRA p10 (0.5362); the margin widening to 0.07 is justified against the m=0.07 → 58.8% figure. The matcher's own doc comment and `analysis.md` both state plainly that INTRA/INTER overlap too much for any absolute cutoff to separate correct from wrong, so the decision stays a ranking accept/reject — no probability framing, no fabricated clean separation.

The lone-candidate hole is genuinely closed. A new `candidates.length == 1` branch rejects any sole candidate below `strongMatchThreshold` before the margin block runs, and the 0.4951 case is pinned by a regression test whose fixture I verified lands at exactly 0.4951 on a unit-norm query. The new threshold is threaded through the private constructor and all three factories (`fromDecodedJson`, `fromJsonString`, `load`) exactly as the existing parameters are.

Matcher invariants are intact: cosine is still a plain dot product with no re-normalization, aggregation is still max-per-landmark, sort is descending, the cap keeps ≤ `maxCandidates` distinct ids, query validation still throws `FormatException`, and `LandmarkCandidate` / `MatchResult` public shapes are unchanged.

The automatic flow requires no manual selection and no per-candidate Confirm. `recognition_screen.dart` consumes `matches.first` (which equals `result.top`), fires `onConfirm` once via a post-frame callback guarded by `_advanced` and `mounted`, never fabricates a match on an empty list, and preserves the loading, error, and Not-recognized states, the honesty disclaimer, the Semantics header, and the unchanged public constructor. `photo_screen.dart`, `main.dart`, and `app.dart` are untouched, so the existing navigation contract (routable → OfflineMapScreen, non-routable → the confirmed-non-routable dialog) carries through verbatim with no invented destination.

Scope held: only approved files plus the authorized PRD/ARD scope note, the `integration_test/` harness, and the `integration_test` SDK dev-dependency. No new third-party packages, no new `lib/` files, `android_verified` untouched, no "verified on Android" text added anywhere. The e2e test stubs the `com.tunton/vision` MethodChannel and asserts auto-advance for a real reference vector versus Not-recognized for a noise vector.

<details>
<summary>Issues (1)</summary>

1. **README map contract drift (informational)** — the bundled README edits describe a `flutter_map`/`AssetTileProvider` tile map that diverges from the Mapbox SDK offline-region contract in `docs/PRD.md`. Pre-existing and self-flagged in the README; unrelated to this task. No action required for this review; reconcile separately if desired.

</details>

<details>
<summary>Details</summary>

### Threshold choice is data-grounded and stays a ranking decision

`defaultStrongMatchThreshold = 0.55` is justified in both the matcher doc comment and the dated `analysis.md` section against the n=51 reference distribution: strictly above the observed 0.4951 lone false hit, ≤ 0.60 so a genuine dominant real-photo match in the 0.55–0.68 band still passes, and just above INTRA p10 (0.5362) keeping ~84.3% of correct reference-grade matches. The margin widening (0.05 → 0.07) cites m=0.07 → 58.8% kept with the genuine median margin 0.10 still clearing it. `defaultScoreThreshold` stays 0.40 as the noise floor. No clean-separation claim is made — `analysis.md` and the doc comment both state the INTRA/INTER overlap explicitly and keep the language at "ranking accept/reject, never a calibrated probability." (**confirmed**)

### Lone-candidate gate actually closes the 0.40–0.55 hole

In `match()`, after the descending sort, an `isEmpty` check returns Not recognized, then a `candidates.length == 1` branch rejects a sole candidate scoring `< strongMatchThreshold` and only accepts it otherwise. The ≥2 path reaches the widened margin gate. The regression test `lone weak match between floor and strong gate is rejected (0.40-0.55 hole)` uses query `[0.4951, 0.868819]`; I verified that is unit-norm and dots to exactly 0.4951 against `[1,0]`, so it genuinely exercises the gap between the 0.40 floor and the 0.55 gate and expects `top == null`, `isRecognized == false`, empty candidates. Companion tests pin lone-strong accept (0.60) and below-floor reject (0.30), also math-verified. The new field is threaded through `LandmarkMatcher._`, `fromDecodedJson`, `fromJsonString`, and `load` with the default, matching the existing `scoreThreshold`/`minTopMargin` pattern. (**confirmed**)

### Matcher invariants preserved

The scoring loop computes `dot += query[i] * reference[i]` with no re-normalization (both sides are already L2-normalized), takes the max over each landmark's references, sorts descending, and the kept slice is `sublist(0, maxCandidates)` of distinct landmark ids. Query length/finiteness still throw `FormatException`. `LandmarkCandidate` and `MatchResult` are unchanged, and `isRecognized`/`top` semantics are intact (empty == Not recognized). (**confirmed**)

### Automatic flow and preserved navigation contract

`recognition_screen.dart` drops `_selected`, the `_CandidateTile` list, the "Ranked suggestions" header, and the "Confirm destination" button. On a non-empty result it takes `matches.first` and schedules `widget.onConfirm!(best)` in a post-frame callback guarded by `bool _advanced` (fires once) and `if (mounted)`. An empty list routes to `_unavailable(unknown: true)` ("Not recognized" + "Try another photo") — no fabricated match. The loading state ("Finding the landmark…"), error state ("Recognition unavailable"), honesty disclaimer ("Suggestions are visual matches. Please verify the place before continuing."), a Semantics `header` on the match card, and the unchanged public constructor (`recognize`, `onConfirm`) are all retained.

`main.dart`'s `recognize` maps `result.candidates` to `Landmark`s in order, so `matches.first` is `result.top`. Because the matcher now yields a single accepted best (lone case) or an ordered list with the true winner first (margin case), consuming the first element is correct. `photo_screen.dart`, `main.dart`, and `app.dart` are unchanged (empty diff), so `_confirmDestination` still routes routable landmarks to `OfflineMapScreen` and non-routable ones to the existing AlertDialog — no invented destination for non-Intramuros. (**confirmed**)

### Scope, honesty, and documentation

Edited files: `landmark_matcher.dart`, `recognition_screen.dart`, `test/landmark_matcher_test.dart`, `test/widget_test.dart`, `integration_test/app_test.dart`, `pubspec.yaml` (dev-dependency `integration_test: sdk: flutter` only), `docs/PRD.md`, `docs/ARD.md`, plus the pre-existing uncommitted README/gradle/MainActivity work the plan said to leave in place. No new third-party package, no new `lib/` file, no architecture dir. The PRD override is recorded with a dated "Scope change (user-approved) 2026-10-10" note on the journey step, the P0-05 row, and the Recognition UI-states row, preserving (not erasing) the original wording; ARD carries the matching note on the `recognition_screen.dart` row and the §6 step-7 line. No "verified on Android" text was added and `android_verified` is untouched. (**confirmed**)

### e2e test asserts automatic-advance vs Not-recognized

`integration_test/app_test.dart` stubs `com.tunton/vision` through `TestDefaultBinaryMessengerBinding`, answering `initialize` with `{'dimension': 512}` and `embed` with a controlled vector, so the real `EmbeddingService`, `LandmarkMatcher`, `RecognitionScreen`, and `PhotoScreen` navigation run. Test (a) feeds the stored fort-santiago reference vector and asserts the app auto-advances to the routable landmark's start-selection step ("Choose starting point") with "Confirm destination" and "Ranked suggestions" absent. Test (b) feeds a uniform 512-vector and asserts "Not recognized" + "Try another photo", "Confirm destination" absent. The implementer's `verification.md` records this ran on `emulator-5554` with 2/2 passing. (**confirmed**)

### Verification evidence

`verification.md` is present and records `flutter pub get` resolving, `flutter analyze` → "No issues found!", `flutter test` → 62/62 pass (naming the new lone-gate, strong-gate, defaults, and rewritten auto-advance tests), and the integration test 2/2 on an emulator. Not-run items (release APK, airplane-mode cold launch, 8 GB memory) are honestly listed as outstanding manual obligations, not claimed. Per the task instruction I did not re-run the suites; I spot-checked the load-bearing test fixtures' cosine math independently and they are consistent with the asserted gate boundaries. (**confirmed**)

</details>

<details>
<summary>File map</summary>

- `lib/features/recognition/landmark_matcher.dart` — new `defaultStrongMatchThreshold`/`strongMatchThreshold`, widened `defaultMinTopMargin` 0.05→0.07, lone-candidate gate + per-gate debug logging; invariants unchanged.
- `lib/features/recognition/recognition_screen.dart` — removed manual pick/Confirm; auto-advance on `matches.first` via guarded post-frame callback; new `_AutoMatchCard`; states/disclaimer/accessibility preserved.
- `test/landmark_matcher_test.dart` — new lone-weak-reject (0.4951), lone-strong-accept, below-floor, ambiguity, and defaults tests.
- `test/widget_test.dart` — rewrote confirmation test to assert automatic advance with no Confirm button.
- `integration_test/app_test.dart` — MethodChannel-stubbed e2e: auto-advance vs Not-recognized.
- `pubspec.yaml` — `integration_test: sdk: flutter` dev-dependency.
- `docs/PRD.md`, `docs/ARD.md` — dated user-approved P0-05 scope-change notes.
- `README.md`, `android/app/build.gradle.kts`, `android/.../MainActivity.kt` — pre-existing uncommitted work, left in place per plan.

Full diff: `git -C /Users/arnel/tunton-ai diff main`
</details>
