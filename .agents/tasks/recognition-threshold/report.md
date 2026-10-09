# Report — recognition accept threshold + top-1/top-2 margin gate

Serves PRD **P0-04** (Handle uncertainty — unknown/ambiguous input yields *Not
recognized*; no invented GPS, no fake confidence percentage) and supports P0-03
(max 3 distinct POIs). The user asked that a photo whose landmark is not in the
embeddings reference should not be shown as a confident match, so users are not
confused about whether the landmark is correct.

Sources used, unchanged by this step:
- Chosen values + distributions: `.agents/tasks/recognition-threshold/analysis.md`
- Commands/results for the logic change: `.agents/tasks/recognition-threshold/verification.md`
- On-device run: `.agents/tasks/recognition-threshold/device-evidence.md`

## AGENTS.md §10 change-report

```
P0 requirement (exact ID): P0-04 (Handle uncertainty / "Not recognized"); supports P0-03 (max 3 distinct POIs)

Approved file(s) edited:
  lib/features/recognition/landmark_matcher.dart   (approved list, AGENTS.md §6)
  test/landmark_matcher_test.dart                  (test for the above)
  (notes only, outside lib/: .agents/tasks/recognition-threshold/{analysis.md,analyze.py,verification.md,device-evidence.md,report.md})

What now works:
  The accept decision is now two gates instead of one. An absolute cosine floor
  (defaultScoreThreshold 0.55 -> 0.40) plus a NEW top1-minus-top2 margin gate
  (defaultMinTopMargin = 0.05). When >=2 landmarks clear the floor and the top two
  are within 0.05 of each other, the whole result is rejected to "Not recognized"
  instead of surfacing a confident #1. A genuine strong match (clear top-1) still
  passes. On the emulator: a solid-gray out-of-catalog image -> "Not recognized"
  (count=0, all 15 landmarks < 0.40); the fort-santiago reference duplicate -> still
  RECOGNIZED (top-1 0.9908, margin 0.3031, count=3). Known residual gap: a single
  lone candidate above the 0.40 floor bypasses the margin gate (synthetic
  checkerboard matched up-manila 0.4951 as one suggestion) — recorded, not hidden.

Chosen threshold + margin, with data justification:
  defaultScoreThreshold = 0.40, defaultMinTopMargin = 0.05.
  From analysis.md (n=51 refs, 15 landmarks, 512-dim, leave-one-out): INTRA(correct)
  and INTER(wrong) cosine distributions overlap heavily (INTER median 0.6645 vs
  INTRA p25 0.6896), so NO absolute cutoff cleanly separates correct from wrong -
  the absolute gate is deliberately NOT the discriminator. 0.40 sits just above the
  ~0.36-0.39 noise floor and below the observed on-device real-photo band (0.36-0.68)
  so genuine matches survive. The 0.05 margin is the real ambiguity filter: the
  measured margin distribution (median 0.1022, p25 0.0438) means 0.05 rejects the
  bottom ~31% near-tie cases while keeping the ~69% with a clear winner.

Model checkpoint and preprocessing verified (yes/no; evidence):
  No model re-export in this task. The packaged OpenCLIP image tower DID load and run
  on the Android emulator through ONNX Runtime (libonnxruntime4j_jni.so loaded ok;
  embedding_dim=512, finite vectors, inference_ms 307-927). Reference index read
  as-is: dimension 512, model_id openclip-vit-b32-laion2b-s34b-b79k-int8-dynamic.
  manifest self_check_cosine 0.9977. This is a DEBUG build on an EMULATOR, not the
  release / physical-hardware proof gate; android_verified stays false.

Commands/tests actually run and results:
  flutter pub get                  -> Got dependencies (exit 0)
  flutter analyze                  -> No issues found (exit 0)
  flutter test                     -> All 60 tests passed (exit 0)   [from verification.md]
  flutter build apk --debug        -> Built app-debug.apk (exit 0)
  adb -s emulator-5554 install -r  -> Success
  on-device app flow (push -> media-scan -> photo picker -> Find the landmark),
    captured [TUNTON_RECOG] logcat for 3 images:
      reference duplicate fort-santiago/1.png -> matched, top1 0.9908, margin 0.3031, count=3
      solid-gray out-of-catalog               -> not_recognized, count=0 (all < 0.40)
      checkerboard out-of-catalog             -> matched up-manila 0.4951 single candidate (margin gate n/a)
    (full numbers in device-evidence.md)

Android release test (passed / failed / not run):
  not run here. Release APK + release-mode run is a separate obligation (AGENTS.md §9),
  not performed in this step. Only a debug build on an emulator was run.

Airplane-mode cold-launch test (passed / failed / not run):
  not run here (inherited open obligation). This step ran the app online on an
  emulator to exercise the recognition decision; airplane-mode cold-launch proof is
  the physical-device gate and was not performed.

8 GB memory results (measured / not measured):
  not measured. No memory/latency profiling on 8 GB hardware was done in this step.

Remaining blocker or scope decision:
  1. Held-out proof gap: the "genuine match still accepted" check used a REFERENCE
     DUPLICATE (fort-santiago/1.png), not a held-out non-reference photo, because none
     was available in this environment. The AGENTS.md §9 held-out-photo test is still open.
  2. Residual recognition gap: a single lone candidate above the 0.40 floor is not
     subject to the margin gate, so a synthetic/odd image can still surface ONE
     suggestion (user must still confirm per P0-05). Future tuning should target the
     margin / a single-candidate floor, not just the absolute threshold.
  3. Physical phone (vivo V2427): wireless ADB unstable; permitted non-destructive
     install timed out. Phone pending reconnect; no on-phone evidence captured. Phone
     Mapbox/offline data left untouched (no uninstall / pm clear / flutter run / airplane toggle).
  4. Release APK, airplane-mode cold launch, and 8 GB memory remain to be run on
     physical hardware before any "verified on Android" claim; android_verified stays false.
```
