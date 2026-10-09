# Change report — aggressive rejection + automatic single-best recognition

```
P0 requirement (exact ID):
  P0-04 (Handle uncertainty → Not recognized; no fake confidence) — primary.
  P0-05 (Confirm a destination) — AUTHORIZED override: manual confirmation
    removed in favor of automatic single-best acceptance (user decision 2026-10-10).
  P0-03 (≤3 distinct POIs) — invariants preserved.

Approved file(s) edited:
  lib/features/recognition/landmark_matcher.dart   (Change 1: aggressive rejection)
  lib/features/recognition/recognition_screen.dart (Change 2: automatic, no manual pick)
  test/landmark_matcher_test.dart                  (Change 3: matcher tests)
  test/widget_test.dart                            (Change 3: automatic-flow widget test)
  integration_test/app_test.dart                   (Change 3: e2e harness — NEW)
  pubspec.yaml                                     (dev_dependencies: integration_test)
  docs/PRD.md                                      (dated scope note only)
  docs/ARD.md                                      (dated scope note only)
  .agents/tasks/recognition-threshold/analysis.md  (final chosen numbers recorded)
  No new third-party packages. No new lib/ files. No architecture dirs.

What now works:
  - CHANGE 1 — Lone-candidate hole closed. Added defaultStrongMatchThreshold = 0.55,
    a higher absolute gate that a SOLE above-floor candidate must clear. The
    observed 0.4951 lone noise hit is now rejected; a genuine dominant real-photo
    match (0.55–0.68 band) still passes. The ≥2-candidate margin gate is kept and
    widened defaultMinTopMargin 0.05 → 0.07 (justified in analysis.md). The floor
    defaultScoreThreshold stays 0.40. New threshold threaded through the private
    constructor and all three factories (fromDecodedJson / fromJsonString / load)
    exactly like scoreThreshold/minTopMargin. match()'s doc comment encodes the
    net accept rule; kDebugMode logging now names the deciding gate
    (below_threshold / lone_below_strong / ambiguous_margin / accept_strong_single
    / accept_margin_ok). All invariants preserved: cosine = plain dot product (no
    re-normalization), max-per-landmark aggregation, descending sort, ≤maxCandidates
    distinct ids, FormatException on query length/finiteness, public
    LandmarkCandidate/MatchResult shapes unchanged. Dependency-free.
  - CHANGE 2 — Recognition is automatic. The choose-one-of-3 + Confirm interaction
    was removed. On a non-empty result the screen consumes ONLY result.top (the
    single accepted best) and automatically invokes onConfirm once (post-frame,
    guarded by a _advanced flag). Intramuros routable → existing OfflineMapScreen /
    Dijkstra flow (unchanged _confirmDestination in photo_screen.dart); non-routable
    → the existing confirmed-non-routable AlertDialog (PRESERVED; no new destination
    invented). Empty/null top → existing "Not recognized" + "Try another photo".
    Loading and "Recognition unavailable" states kept. A non-blocking auto-match
    card names the selected landmark and keeps the "visual match, please verify"
    honesty disclaimer visible without gating. Semantics headers and
    TuntonScaffold/JourneyMessage styling preserved. photo_screen.dart and
    main.dart needed NO change (verified result.candidates.first == result.top);
    no scope expansion, app.dart untouched.
  - CHANGE 3 — End-to-end test added.

Model checkpoint and preprocessing verified (yes/no; evidence):
  No model change. EmbeddingService / preprocessing / manifest untouched;
  android_verified stays false. The real-asset self-match test still passes
  (score ≈ 1.0) confirming the reference index + matcher math are intact.

Commands/tests actually run and results (full log in verification.md):
  flutter pub get   → Got dependencies! (PASS)
  flutter analyze   → No issues found! (PASS, 0 new issues)
  flutter test      → All tests passed! (62/62 PASS)
  flutter test integration_test/app_test.dart -d emulator-5554 → All tests passed!
    (2/2 PASS): known vector auto-advances (gate=accept_margin_ok, no Confirm);
    noise vector → Not recognized (gate=below_threshold).

E2E form used and why:
  Preferred MethodChannel-stubbed integration_test form was used
  (integration_test/app_test.dart). It stubs com.tunton/vision via
  TestDefaultBinaryMessengerBinding so the REAL EmbeddingService + LandmarkMatcher
  + RecognitionScreen + PhotoScreen navigation run end to end, and it executed
  successfully on emulator-5554. No fallback was needed — the base64 PNG fixture
  decodes headlessly through prepareImage, so the full pipeline ran.

Android release test (passed / failed / not run):
  flutter build apk --release — NOT run in this step (not required for the e2e
  evidence; remains the final manual gate). Not claimed as passed.

Airplane-mode cold-launch test (passed / failed / not run):
  NOT run (physical-device obligation).

8 GB memory results (measured / not measured):
  NOT measured.

Remaining blocker or scope decision:
  Physical-device airplane-mode cold launch, release-APK gate, and 8 GB
  memory/latency measurement remain outstanding manual obligations. No code
  blocker. The INTRA/INTER distributions still overlap heavily (stated in
  analysis.md) — the thresholds are the most defensible aggressive RANKING
  accept/reject decision, never a calibrated probability; no clean separation
  is claimed.
```

---

# Change report (final, with on-emulator evidence) — aggressive rejection + automatic single-best recognition

```
P0 requirement (exact ID):
  P0-04 (Handle uncertainty → Not recognized; no invented GPS / no fake
    confidence) — PRIMARY requirement served by the aggressive rejection gate.
  P0-05 (Confirm a destination) — AUTHORIZED OVERRIDE. The "require the user to
    confirm a candidate" wording of P0-05 (and the P0-03/P0-04 recognition
    journey steps that referenced confirmation) was SUPERSEDED by user-approved
    automatic single-best acceptance on 2026-10-10. This override is documented
    in docs/PRD.md (journey step 6, the P0-05 traceability row, and the
    Recognition UI-states row all carry a dated "Scope change (user-approved)
    2026-10-10" note that preserves, not erases, the original wording) and in
    docs/ARD.md (recognition_screen.dart row + §6 step-7 note).
  P0-03 (≤3 distinct POIs) — matcher invariants preserved.

Approved file(s) edited:
  lib/features/recognition/landmark_matcher.dart   (aggressive rejection gate)
  lib/features/recognition/recognition_screen.dart (automatic, no manual pick)
  test/landmark_matcher_test.dart                  (matcher gate tests)
  test/widget_test.dart                            (automatic-flow widget test)
  integration_test/app_test.dart                   (e2e harness — NEW)
  pubspec.yaml                                     (dev_dependencies: integration_test)
  docs/PRD.md                                      (dated scope note only)
  docs/ARD.md                                      (dated scope note only)
  .agents/tasks/recognition-threshold/analysis.md  (final chosen numbers recorded)
  No new third-party packages. No new lib/ files. No architecture dirs.
  ALL CHANGES REMAIN UNCOMMITTED.

What now works:
  - Aggressive rejection. Exact new thresholds now in landmark_matcher.dart:
      defaultScoreThreshold        = 0.40  (absolute noise floor, unchanged)
      defaultMinTopMargin          = 0.07  (widened from 0.05)
      defaultStrongMatchThreshold  = 0.55  (NEW — strong-single-match value)
    The lone-candidate hole is CLOSED: previously a photo that weakly matched
    exactly ONE landmark above the 0.40 floor had no runner-up to trip the margin
    gate, so it leaked through as a confident #1 (observed at cosine ~0.4951).
    A new candidates.length == 1 branch now rejects any sole candidate scoring
    < strongMatchThreshold (0.55) BEFORE the margin block runs; a lone candidate
    is accepted only if it reaches 0.55. The ≥2-candidate case still uses the
    (now widened 0.07) margin gate. The new threshold is threaded through the
    private constructor and all three factories (fromDecodedJson / fromJsonString
    / load) exactly like scoreThreshold/minTopMargin. Invariants preserved:
    cosine = plain dot product (no re-normalization), max-per-landmark
    aggregation, descending sort, ≤maxCandidates distinct ids, FormatException on
    query length/finiteness, unchanged LandmarkCandidate/MatchResult shapes.
  - Automatic recognition — no manual selection or option. recognition_screen.dart
    consumes ONLY result.top (the single accepted best) and automatically invokes
    onConfirm once via a post-frame callback guarded by a _advanced flag; the
    choose-one-of-3 candidate list and the "Confirm destination" button were
    removed. Empty/null top → existing "Not recognized" + "Try another photo".
    Loading / "Recognition unavailable" states, the "visual match, please verify"
    honesty disclaimer, and Semantics headers are preserved. photo_screen.dart,
    main.dart, and app.dart are UNCHANGED; the existing navigation contract
    (routable → OfflineMapScreen/Dijkstra, non-routable → confirmed-non-routable
    dialog) carries through with no invented destination.

Model checkpoint and preprocessing verified (yes/no; evidence):
  No model change in this task. EmbeddingService / preprocessing / manifest were
  not touched. Embedding dimension observed as 512 on every emulator run (see
  device-evidence.md). The real-asset self-match unit test still passes
  (score ≈ 1.0), confirming the reference index + matcher math are intact.
  android_verified remains FALSE; no "verified on Android" claim was added
  anywhere.

Commands/tests actually run and results (full logs in verification.md):
  flutter pub get   → Got dependencies! (PASS)
  flutter analyze   → No issues found! (PASS, 0 new issues)
  flutter test      → All tests passed! (62/62 PASS), incl. new lone-weak-reject
    (query dots to exactly 0.4951 → top == null), lone-strong-accept, below-floor
    reject, ambiguity, defaults (scoreThreshold 0.40 / minTopMargin 0.07 /
    strongMatchThreshold 0.55), and the rewritten auto-advance widget test
    (no Confirm button, no "Ranked suggestions", onConfirm fires automatically).
  E2E FORM USED: the preferred MethodChannel-stubbed integration_test form
    (integration_test/app_test.dart). It stubs com.tunton/vision via
    TestDefaultBinaryMessengerBinding so the REAL EmbeddingService +
    LandmarkMatcher + RecognitionScreen + PhotoScreen navigation run end to end;
    only ONNX inference is replaced by a controlled 512-d vector. No fallback was
    needed.
  flutter test integration_test/app_test.dart -d emulator-5554 →
    All tests passed! (2/2 PASS): (a) known fort-santiago reference vector
    auto-advances (gate=accept_margin_ok, margin 0.3015 ≥ 0.07) with no Confirm;
    (b) uniform 512 noise vector → Not recognized + "Try another photo".

  ON-EMULATOR app run (emulator-5554, sdk_gphone16k_arm64, Android 17 / API 37,
  arm64-v8a; DEBUG build installed via adb; see device-evidence.md — ONLINE
  EMULATOR ONLY, physical phone NOT touched, android_verified stays false):
    * GENUINE reference-duplicate image (fort-santiago/1.png): deciding cosine
      fort-santiago 0.9908, margin 0.3031 ≥ 0.07, gate=accept_margin_ok → app
      AUTO-ADVANCED to Fort Santiago's Start screen with NO manual selection,
      NO candidate list, NO Confirm tap (reproduced on a second run).
    * NON-reference / lone ~0.49 image (synthetic noise): only up-manila cleared
      the 0.40 floor at 0.4585 (the previously-leaking lone-candidate shape, in
      the ~0.49 leak band), gate=lone_below_strong (0.4585 < 0.55) →
      "Not recognized" with no auto-advance. Reproduced again with a tan-solid
      image (up-manila 0.4665, lone_below_strong → Not recognized).
    * Honest edge case recorded in device-evidence.md: a synthetic blue-gradient
      image produced TWO weak above-floor candidates (0.4905 / 0.4143) whose gap
      0.0761 just cleared the 0.07 margin, so the margin path admitted it. The
      REQUIRED lone-candidate leak is closed; the two-weak-candidate margin path
      can still admit an adversarial synthetic input — flagged, not hidden.

Android release test (passed / failed / not run):
  flutter build apk --release — NOT run in this step (remains the final manual
  gate). Not claimed as passed. (A DEBUG APK was built and installed on the
  emulator for the on-device check above; the RELEASE gate is still outstanding.)

Airplane-mode cold-launch test (passed / failed / not run):
  NOT run (physical-device obligation; the online emulator was used only to drive
  the recognition flow, not for an airplane-mode cold launch).

8 GB memory results (measured / not measured):
  NOT measured.

Remaining blocker or scope decision:
  No code blocker. Outstanding manual obligations: release-APK gate, physical
  8 GB-device airplane-mode cold launch, and 8 GB memory/latency measurement.
  SCOPE DECISION on record: P0-05's "require confirmation" is superseded by
  user-approved automatic single-best acceptance (2026-10-10), documented in
  docs/PRD.md and docs/ARD.md. HONESTY: INTRA (correct) and INTER (wrong)
  distributions still overlap heavily (analysis.md) — these thresholds are the
  most defensible aggressive RANKING accept/reject decision, never a calibrated
  probability; no clean separation is claimed. One honest open edge case: the
  two-weak-candidate margin path can still admit an adversarial synthetic image
  (flagged above), separate from the now-closed lone-candidate hole. All changes
  remain UNCOMMITTED.
```
