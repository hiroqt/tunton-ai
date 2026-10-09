# Implementation Plan — Aggressive recognition + automatic single-best acceptance

## Context and scope

**Problem (treat as REAL, not already-fixed):** the current two-gate decision in
`lib/features/recognition/landmark_matcher.dart` still accepts non-reference
photos. The margin gate only engages when **≥2** candidates clear the 0.40 floor.
A photo that weakly matches **exactly one** landmark above 0.40 (an observed
synthetic image hit **0.4951** on one landmark) passes through as a lone confident
suggestion with no runner-up to trip the margin. The user wants a MORE AGGRESSIVE
rule so non-reference photos reliably read as **Not recognized**, and wants
recognition to be AUTOMATIC (no manual pick / no per-candidate Confirm).

**P0 requirements in play (exact IDs):**
- **P0-04** (Handle uncertainty → *Not recognized*; no fake confidence) — primary
  target of Change 1. The lone-candidate hole is a P0-04 defect.
- **P0-03** (match ≤3 distinct POIs) — invariants preserved by Change 1.
- **P0-05** (Confirm a destination) — the requirement the user has **authorized
  removing** in favor of automatic single-best acceptance (Change 2). This task
  carries that authorization; Change 4 records the dated scope note.
- **P0-01 / §2 journey** — the capture→recognize→(route|end) flow Change 2 and
  the Change-3 e2e test exercise.

**Working mode:** edit in place in `/Users/arnel/tunton-ai`. NO worktree, NO
commits, NO pushes. The repo is on `main` with intentional uncommitted work
(crash fix in `android/app/build.gradle.kts` + `MainActivity.kt`, README edit,
recognition tightening in `landmark_matcher.dart` + `test/landmark_matcher_test.dart`).
Leave all of that in place; build on it; revert nothing.

**Approved files this task may touch** (AGENTS.md §6 + the two docs for the scope
note + test harness + pubspec dev_dependencies):
- `lib/features/recognition/landmark_matcher.dart`
- `lib/features/recognition/recognition_screen.dart`
- `lib/main.dart`
- `lib/features/camera/photo_screen.dart` (in §6; auto-advance wiring lives here)
- `test/landmark_matcher_test.dart`
- `test/widget_test.dart`
- `pubspec.yaml` (dev_dependencies entry only)
- `integration_test/` harness (new test harness dir — allowed; `integration_test`
  ships with Flutter) OR a `test/` widget-level e2e (see Item 7 for which)
- `docs/PRD.md`, `docs/ARD.md` (scope note only)

**Out of bounds:** no new third-party packages, no new `lib/` files, no new
architecture dirs. Do NOT touch model/routing/offline-map/no-network locked
decisions. Keep `android_verified=false` in the model manifest; add NO "verified
on Android" text anywhere.

**Scope-expansion guard:** removing manual selection is achievable entirely within
`photo_screen.dart` (which already owns `_confirmDestination`) + `recognition_screen.dart`
+ trivial `main.dart` wiring — all §6-approved. `app.dart` only needs (at most)
trivial wiring and probably nothing. **If the implementer finds the auto-advance
cannot be done without a non-trivial change to a file NOT in the list above (e.g.
`app.dart` structural change), PAUSE via `send_message` severity `warning`** stating
the file and why, before expanding scope.

**Honesty constraints (AGENTS.md §8):** the data in
`.agents/tasks/recognition-threshold/analysis.md` already shows heavy INTRA/INTER
overlap — there is NO clean separation. Keep every threshold a ranking
accept/reject decision, never a probability/percentage. Do not fabricate device
test results.

---

## Build / test commands (discovered)

- Flutter 3.44.8 stable, `which flutter` = `/opt/homebrew/bin/flutter`.
- Analyzer: `flutter analyze` (must stay clean — 0 issues).
- Unit/widget tests: `flutter test` (runs everything under `test/`). The matcher
  and real-asset tests live in `test/landmark_matcher_test.dart`; screen/flow
  tests in `test/widget_test.dart`. There are 60 passing tests today.
- Release build (final gate, per AGENTS.md §9): `flutter build apk --release`.
- Integration test (if used): `flutter test integration_test/<file>.dart` runs on
  the host VM for pure-Dart/stubbed flows; a device run would be
  `flutter test integration_test/<file>.dart -d <device>`. Device run is NOT
  required for this plan's verification (airplane-mode device proof is a separate
  manual obligation).

Run `flutter pub get` after editing `pubspec.yaml`.

---

## Threshold selection method — DO NOT guess numbers; derive from analysis.md

All percentiles below are from `.agents/tasks/recognition-threshold/analysis.md`
(n=51, INTRA=correct leave-one-out, INTER=wrong-landmark, MARGIN=top1−top2).

### New constant: `defaultStrongMatchThreshold` (the lone-candidate gate)

This higher absolute threshold applies ONLY when the top candidate is the **sole**
landmark above `defaultScoreThreshold` (no second candidate to run the margin gate
against). It closes the 0.40–0.50 lone-noise hole while still accepting a genuine
dominant real-photo match.

Selection reasoning the implementer must apply (and record in analysis.md):
- The observed lone false hit was **0.4951**; the rule must reject it, so
  `defaultStrongMatchThreshold` must be **> 0.4951**.
- Genuine on-device real-photo matches were observed in the **0.36–0.68** raw-cosine
  band (per analysis.md). A dominant real match can land **mid-band**, so the gate
  must not exceed the upper band — keep it **≤ ~0.60** so a legitimate ~0.60–0.68
  dominant match still passes.
- Cross-check against the INTRA distribution: INTRA p25 = **0.6896**, median =
  **0.7729**; INTRA p10 = **0.5362**, p05 = **0.4561**. A strong-match gate at
  **0.55** sits just above the lone false hit (0.4951) and below INTRA p10
  (0.5362), so it keeps ≥90% of correct reference-grade matches (INTRA kept at
  0.55 = 84.3% from the trade-off table) while rejecting the 0.40–0.50 lone-noise
  band. The INTER-kept column shows 0.55 still admits wrong matches **when a
  runner-up exists** — that case is handled by the margin gate, not this one;
  this gate only governs the SOLE-candidate case where margin cannot apply.
- **Recommended value: `defaultStrongMatchThreshold = 0.55`.** This is the most
  defensible aggressive setting: strictly above the measured lone false positive,
  below the real-photo upper band, and above INTRA p10. If the implementer picks a
  different value it MUST be justified against these same percentiles in
  analysis.md and MUST remain `> 0.4951` and `≤ 0.60`.

### Keep (and consider widening) `defaultMinTopMargin` for the ≥2-candidate case

Current `defaultMinTopMargin = 0.05` rejects the bottom ~31% near-tie cases
(margin table: m=0.05 → 68.6% have a clear winner). The user asked for "more
aggressive." Options from the margin table: m=0.07 → 58.8% kept, m=0.10 → 51.0%
kept. Widening to **0.07** removes a further ~10% of near-tie ambiguous pairs at a
modest cost to genuine multi-candidate winners (whose median margin is 0.10, p25
0.044). **Recommendation: widen `defaultMinTopMargin` to 0.07**, justified as:
median genuine margin (0.10) still clears 0.07, while the near-tie band
(margin < 0.07, ~41% of cases) is rejected as ambiguous. The implementer MAY keep
0.05 if they document in analysis.md why 0.07 costs too many genuine winners; the
default decision for this plan is **0.07**. Either choice must be recorded in
analysis.md with the percentile reasoning.

### Keep `defaultScoreThreshold = 0.40` (floor, unchanged)

It stays the noise floor for the ≥2-candidate path; the margin gate remains the
primary discriminator there. Do not raise it (raising it rejects the real-photo
0.36–0.68 band).

### Net accept rule to encode (match()'s doc comment, verbatim intent)

> RECOGNIZED only if the best landmark clears the appropriate absolute threshold
> AND is unambiguous:
> - **Sole above-floor candidate:** accept only if its score ≥
>   `defaultStrongMatchThreshold` (the stronger lone-match gate). A single
>   0.40–0.55 match is now rejected → *Not recognized*.
> - **≥2 above-floor candidates:** accept the top only if top1 − top2 ≥
>   `minTopMargin`; otherwise reject the whole result.
> Everything else (nothing clears `scoreThreshold`, lone candidate below strong
> gate, or near-tie) → empty `MatchResult` = *Not recognized*.
> This is a ranking accept/reject decision, never a calibrated probability.

---

## Ordered implementation items

- [ ] **1. Add the `defaultStrongMatchThreshold` constant + field + constructor/factory
      threading in `landmark_matcher.dart`.**
      Add `static const double defaultStrongMatchThreshold = 0.55;` with a doc
      comment citing analysis.md (the 0.4951 lone false hit, 0.36–0.68 band, INTRA
      p10 0.5362) and the ranking-not-probability caveat. Add a `final double
      strongMatchThreshold;` field. Thread it through the private constructor
      `LandmarkMatcher._(...)` and ALL THREE factories/loaders exactly as
      `scoreThreshold` / `minTopMargin` are threaded: add a named parameter
      `double strongMatchThreshold = defaultStrongMatchThreshold` to
      `fromDecodedJson`, `fromJsonString` (pass through to `fromDecodedJson`), and
      `load` (pass through to `fromJsonString`). If widening the margin, also change
      `defaultMinTopMargin` from `0.05` to `0.07` here and update its doc comment to
      cite the m=0.07 → 58.8% figure. Do NOT touch `defaultScoreThreshold`.
      Preserve all other public shapes.
      Files: `lib/features/recognition/landmark_matcher.dart`
      Verify: `flutter analyze` clean. (Behavior verified in Item 2's tests.)

- [ ] **2. Implement the lone-candidate gate in `match()` and update its doc comment
      and kDebugMode logging.**
      After the descending sort and BEFORE the existing `candidates.length >= 2`
      margin block, add the sole-candidate branch: when exactly one candidate is
      above `scoreThreshold`, reject (return `const MatchResult(<LandmarkCandidate>[])`)
      unless that candidate's score ≥ `strongMatchThreshold`. Keep the ≥2-candidate
      margin gate unchanged except for the widened default. Preserve ALL invariants:
      cosine = plain dot product (NO re-normalization), MAX-per-landmark aggregation,
      descending sort, ≤ `maxCandidates` distinct ids, `FormatException` query
      validation, public `LandmarkCandidate` / `MatchResult` shapes, `isRecognized`
      / `top` semantics. Rewrite the `match()` doc comment to state the Net accept
      rule above verbatim in intent. Extend `kDebugMode` `debugPrint` so the ACCEPT
      / REJECT line names WHICH gate decided: `below_threshold`,
      `lone_below_strong(score<strongMatchThreshold)`, `ambiguous_margin`, or
      `accept_strong_single` / `accept_margin_ok`. Dependency-free: only
      `dart:convert`, `dart:math`, `flutter/foundation.dart`, `flutter/services.dart`.
      Files: `lib/features/recognition/landmark_matcher.dart`
      Verify: `flutter test test/landmark_matcher_test.dart` — all pass after Item 3.

- [ ] **3. Update `test/landmark_matcher_test.dart` for the lone-candidate gate and new
      defaults; add the regression test for the 0.40–0.55 lone hole.**
      Existing tests that construct a matcher with a single landmark and expect
      acceptance at low scores depend on the OLD lone behavior and MUST be updated:
      - `'a single candidate above threshold is accepted (margin gate n/a)'` — the
        single candidate query `[1.0,0.0]` scores 1.0 (≥0.55) so it still passes;
        keep it, but set `strongMatchThreshold: 0.55` explicitly for clarity.
      - `'defaults use the measured threshold and margin'` — add
        `expect(matcher.strongMatchThreshold, LandmarkMatcher.defaultStrongMatchThreshold);`
        and `expect(LandmarkMatcher.defaultStrongMatchThreshold, 0.55);`. If
        `defaultMinTopMargin` is widened, change the existing `expect(..., 0.05)` to
        `0.07`.
      Add NEW tests:
      - **Lone weak match is rejected:** one landmark, query giving cosine ≈ 0.4951
        (between `scoreThreshold` 0.40 and `strongMatchThreshold` 0.55) → expect
        `isRecognized == false`, empty candidates. This is the regression test for
        the reported hole; pick vectors so the single dot product lands ~0.50.
      - **Lone strong match is accepted:** one landmark, cosine ≥ 0.55 → recognized,
        `top` is that landmark.
      Keep every existing margin/sort/cap/FormatException/real-asset test intact
      (do not weaken them); only adjust fixtures that assumed the old thresholds.
      The real-asset self-match test (score ≈ 1.0) still passes unchanged.
      Files: `test/landmark_matcher_test.dart`
      Verify: `flutter test test/landmark_matcher_test.dart` — all pass, including
      the new lone-weak-reject and lone-strong-accept cases.

- [ ] **4. Record the final chosen numbers + lone-candidate rationale in analysis.md.**
      Append a short dated section ("Lone-candidate gate, 2026-10-10") stating:
      the lone-candidate hole, the observed 0.4951 false hit, the chosen
      `defaultStrongMatchThreshold` value with the percentile reasoning (0.4951 <
      value ≤ 0.60; INTRA p10 0.5362; INTRA-kept@0.55 = 84.3%), the margin decision
      (0.05 → 0.07 if widened, citing m=0.07 → 58.8%), and the plain statement that
      INTRA/INTER still overlap so this remains a defensible aggressive ranking
      decision, NOT a calibrated probability. No fabricated separation claims.
      Files: `.agents/tasks/recognition-threshold/analysis.md`
      Verify: file reads consistently with the constants shipped in Item 1 (manual
      read — this is a doc, not code).

- [ ] **5. Make recognition AUTOMATIC in `recognition_screen.dart` — remove manual
      candidate picking and the per-candidate Confirm.**
      Rework `_RecognitionScreenState`: keep `_matches` (the recognize Future),
      keep loading state ("Finding the landmark…"), keep error → `_unavailable()`
      ("Recognition unavailable") and empty → `_unavailable(unknown: true)`
      ("Not recognized" + "Try another photo"). When the recognize Future returns a
      NON-empty list, the screen consumes ONLY the FIRST element (the single
      accepted best match, which main.dart derives from `result.top` — see Item 6)
      and AUTOMATICALLY invokes `widget.onConfirm!(best)` once, after the frame
      settles (e.g. `WidgetsBinding.instance.addPostFrameCallback` inside the
      builder's done+non-empty branch, guarded by a `bool _advanced` so it fires
      exactly once). Remove `_selected`, the `_CandidateTile` list, the "Ranked
      suggestions" header, and the "Confirm destination" FilledButton entirely.
      Replace with a brief NON-BLOCKING result card naming WHICH landmark was
      auto-selected (name + area), plus the retained honesty disclaimer
      ("Suggestions are visual matches. Please verify the place…") shown but NOT
      blocking, plus a "Try another photo" button. Never fabricate a match when the
      list is empty / `top` is null. Keep `Semantics` headers and the
      `TuntonScaffold` / `JourneyMessage` styling. Update the subtitle copy
      ("Choose the landmark…then confirm") to reflect automatic behavior
      (e.g. "Matching your photo on this device.").
      Note: the screen's `recognize` still returns `Future<List<Landmark>>` and
      `onConfirm` stays `ValueChanged<Landmark>?` — the public widget constructor
      signature is unchanged, so `photo_screen.dart` and `widget_test.dart` keep
      compiling; only the INTERNAL interaction changes.
      Files: `lib/features/recognition/recognition_screen.dart`
      Verify: `flutter analyze` clean; behavior checked by Items 8 and 7.

- [ ] **6. Preserve the navigation contract through `photo_screen.dart` /
      `main.dart` — auto-advance reuses the EXISTING confirmed paths.**
      Confirm (read, likely no change needed) that `photo_screen.dart`'s
      `_confirmDestination` is passed as `onConfirm` and already routes:
      Intramuros+routable → `OfflineMapScreen` → `NavigationScreen` (existing map/
      Dijkstra flow); non-routable (incl. non-Intramuros) → the existing
      `AlertDialog` ("recognized, but…"/"routes only in Intramuros"). The automatic
      path from Item 5 calls this SAME `onConfirm`, so Intramuros still reaches the
      map/route and non-Intramuros still shows the current confirmed-non-routable
      dialog — DO NOT invent a new destination for non-Intramuros. In `main.dart`,
      `recognize()` returns `result.candidates` mapped to `Landmark`s; since the
      matcher now yields a single accepted best (or empty), the first element IS the
      auto-selected landmark — no change to `main.dart`'s mapping is required, but
      verify `result.candidates.first` corresponds to `result.top`. If any wiring
      change is needed it must stay trivial and within these two §6 files; if it
      would require a structural change to `app.dart` or a non-§6 file, PAUSE with a
      `warning` (see scope-expansion guard).
      Files: `lib/features/camera/photo_screen.dart` (only if wiring needs it),
      `lib/main.dart` (only if mapping needs it)
      Verify: `flutter analyze` clean; end-to-end behavior in Items 7 and 8.

- [ ] **7. Add the end-to-end test: stub the native `com.tunton/vision` MethodChannel
      and assert automatic advance vs Not-recognized.**
      Preferred form: `integration_test/recognition_flow_test.dart` using
      `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` and stubbing at the
      MethodChannel boundary via
      `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('com.tunton/vision'), ...)` so
      the REAL `EmbeddingService`, `LandmarkMatcher`, `recognition_screen`, and
      `photo_screen` navigation all run. The stub must answer `initialize`
      (`{'dimension': 512}`) and `embed` (return a controlled 512-length
      `List<double>`/`List<num>`). Pump the real app graph (reuse `main.dart`'s
      `_LocalBackend` wiring or build `PhotoScreen` with the real
      `recognizePhoto`/`startPoints`/`calculateRoute` as `main.dart` does), inject a
      photo via the `pickPhoto` injection seam, tap "Find the landmark", and assert:
      - **(a) Known reference vector:** stub `embed` to return the stored vector of a
        real catalog landmark (read one from `assets/landmarks/reference_embeddings.json`,
        ideally an Intramuros routable one) → the app AUTOMATICALLY advances to that
        landmark (its result card / the OfflineMapScreen for routable) with NO manual
        tap on a candidate and NO "Confirm destination" press (assert that text is
        absent). For a routable landmark, assert the map/next screen is reached; for
        robustness pick one known to be routable.
      - **(b) Noise / below-threshold vector:** stub `embed` to return a near-uniform
        512-vector that lands below the gates → "Not recognized" + "Try another
        photo" shown; no advance.
      Use the `test/widget_test.dart` `base64Decode` PNG fixture + `pickPhoto`
      injection for the photo bytes; load fonts as `widget_test.dart`'s `setUpAll`
      does so layout settles.
      **Fallback if integration_test on the host is infeasible here** (e.g.
      `embed`'s image preprocessing needs a decodable image the stub can't satisfy
      headlessly): add instead a widget-level e2e in
      `test/recognition_flow_e2e_test.dart` that drives `RecognitionScreen` with a
      stubbed `recognize: () async => [<catalog Landmark>]` and asserts the SAME
      two outcomes — automatic `onConfirm` fire with no Confirm button, and empty →
      "Not recognized". **Record in the change report WHICH form was used and why.**
      Prefer the MethodChannel integration_test; only fall back with a stated reason.
      Files: `integration_test/recognition_flow_test.dart` (preferred) OR
      `test/recognition_flow_e2e_test.dart` (fallback)
      Verify: `flutter test integration_test/recognition_flow_test.dart`
      (or `flutter test test/recognition_flow_e2e_test.dart`) — both assertions pass.

- [ ] **8. Update `test/widget_test.dart` for the automatic flow.**
      The following existing tests assert the OLD manual UI and MUST be rewritten to
      the automatic behavior (do not merely delete coverage — convert it):
      - `'destination confirmation requires an explicit selection'` → replace with a
        test that a non-empty `recognize` result triggers `onConfirm` AUTOMATICALLY
        with the first/best landmark and that NO "Confirm destination" button exists.
      - `'missing inference does not produce sample predictions'` → it asserts
        `find.text('Ranked suggestions')` is absent; keep the no-fabrication intent
        but update any now-removed strings; "Recognition unavailable" still shows
        when `recognize == null`.
      - The accessibility screen map test ("recognition" entry) that renders
        `RecognitionScreen(recognize: () async => [destination, origin], onConfirm:
        (_){})` — with auto-advance this now fires `onConfirm` on first frame; adjust
        so the test still passes (e.g. provide an `onConfirm` that records the call,
        and don't expect the candidate list). Keep the three accessibility guideline
        checks (`androidTapTargetGuideline`, `labeledTapTargetGuideline`,
        `textContrastGuideline`) passing for the new result-card layout.
      - `'unknown input stays unknown and offers retry'` → still valid ("Not
        recognized", "Try another photo", no "Confirm destination"); keep.
      Do not weaken unrelated map/navigation/photo tests. Any removed string
      assertion must be replaced with the automatic-flow equivalent.
      Files: `test/widget_test.dart`
      Verify: `flutter test` — the full suite passes (the prior 60 plus the new
      matcher and e2e cases; count will change as manual-UI tests are converted).

- [ ] **9. Add the `integration_test` dev dependency to `pubspec.yaml` (only if Item 7
      used the integration_test form).**
      Under `dev_dependencies`, add:
      ```yaml
        integration_test:
          sdk: flutter
      ```
      It ships with Flutter (no new third-party package). Leave `patrol` and all
      other deps untouched. If Item 7 fell back to a `test/` widget-level e2e, SKIP
      this item (no pubspec change needed) and note that in the report.
      Files: `pubspec.yaml`
      Verify: `flutter pub get` succeeds; `flutter analyze` clean.

- [ ] **10. Add the dated user-approved scope note to `docs/PRD.md` and `docs/ARD.md`.**
      This records the authorized P0-05 override (manual confirmation removed in
      favor of automatic single-best acceptance). Do NOT delete the original P0-05
      text — annotate it so the history is honest.
      - `docs/PRD.md`:
        - Line 22 (`6. Require the user to confirm a candidate.`) and the P0-05 row
          at line 36 and the Recognition UI-states row at line 74: add a note such as:
          *"Scope change (user-approved) 2026-10-10: manual confirmation removed; the
          app now automatically accepts the single best match that passes the
          aggressive recognition gate (sole candidate ≥ strong-match threshold, or
          top beats runner-up by the margin). This supersedes the earlier 'require
          confirmation' wording at the user's explicit request on 2026-10-10."*
      - `docs/ARD.md`:
        - Line 176 (`recognition_screen.dart | Present up to three candidates,
          require confirmation | P0-05`) and §6 step-7 line 194: add the same dated
          scope-change note (recognition now auto-accepts the single best passing
          match; confirmation step removed per the 2026-10-10 user decision).
      Keep the note short, dated, and worded as superseding — not erasing — P0-05.
      Touch nothing else in these docs. Add NO "verified on Android" text.
      Files: `docs/PRD.md`, `docs/ARD.md`
      Verify: manual read — notes are dated, reference P0-05, and match the shipped
      behavior; no other doc content changed.

- [ ] **11. Full verification gate (per AGENTS.md §9).**
      Run, in order:
      1. `flutter pub get`
      2. `flutter analyze` → expect **No issues found**.
      3. `flutter test` → expect all tests pass (matcher incl. lone-candidate
         regression, widget flow converted to automatic, e2e).
      4. `flutter build apk --release` → expect a successful release build (this
         also confirms the prior crash-fix gradle changes still build).
      Do NOT claim any on-device / airplane-mode / 8 GB-memory result — those remain
      manual obligations and were NOT run here. Fill the AGENTS.md §10 change-report
      with: P0-04 (+ P0-05 override, P0-03 preserved); files edited; what now works
      (lone-candidate hole closed; automatic single-best advance); model/preprocessing
      verified = unchanged (no model change); commands actually run + results;
      Android release test = build only (not device-run); airplane-mode = not run;
      8 GB memory = not measured; remaining blocker = device proof pending.
      Verify: all four commands succeed; report is honest about what was and was not
      run.

---

## Review loop stop contract (for the implement/review tail)

The implement-and-review loop must converge on an approved verdict file. The
reviewer (always the LAST child of the loop) writes
`/Users/arnel/tunton-ai/.agents/tasks/recognition-aggressive/review.json` with
`{"verdict": "APPROVED"}` or `{"verdict": "CHANGES_REQUESTED"}`; the loop's
`stopCondition` is a `fileCheck` on that path with `jsonPath` `verdict` equal to
`APPROVED`, `onMaxIterations: abort`.

## Assumptions / gaps noted

- Chosen `defaultStrongMatchThreshold = 0.55` and `defaultMinTopMargin = 0.07` are
  the plan's recommended values with percentile justification; the implementer may
  deviate only within the stated bounds and must record the final numbers in
  analysis.md.
- The e2e prefers MethodChannel-stubbed `integration_test`; the widget-level
  fallback is explicitly allowed because the real `embed` preprocessing decodes an
  image and may not run cleanly headless — the implementer picks the form that
  actually runs here and states which.
- `app.dart` is expected to need no change; if it does beyond trivial wiring, the
  implementer pauses with a `warning` rather than silently expanding scope.
