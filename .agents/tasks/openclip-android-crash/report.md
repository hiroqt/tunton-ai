# OpenCLIP Android crash fix — evidence report

Date: 2026-10-10 (pre-cutoff). This report synthesizes already-recorded evidence only
(`verification.md`, `review.md`/`review.json`, `device-evidence.md`). No product code was
edited and nothing was committed in this step. No numbers, benchmarks, or offline proof are
fabricated; nothing is marked tested unless the source evidence shows it ran.

---

## 1. Root-cause analysis (with evidence)

The release APK aborted **natively, before OpenCLIP inference ran**, during ONNX Runtime
session introspection. The recorded evidence:

- **SIGABRT abort message naming the missing constructor:**
  ```
  java.lang.NoSuchMethodError: no non-static method
  Lai/onnxruntime/NodeInfo;.<init>(Ljava/lang/String;Lai/onnxruntime/ValueInfo;)V
  ```
  Abort fired on worker thread `pool-3-thread-1`.

- **Native backtrace through `getInputInfo`:** the failure occurred at
  `OrtSession.getInputInfo` via the JNI entry
  `Java_ai_onnxruntime_OrtSession_getInputInfo` inside `libonnxruntime4j_jni.so`.

- **exit-info confirming a native crash ~10 s after launch:**
  ```
  ApplicationExitInfo #0: reason=5 (APP CRASH(NATIVE))
  timestamp=2026-10-10 02:19:18.354
  ```
  This `reason=5` entry is the OLD (pre-fix) build (see device-evidence `A3`/`A9`); it is the
  only native crash on record and predates every post-fix install.

### Why it happened

The native library instantiates `ai.onnxruntime.NodeInfo(String, ValueInfo)` (and the sibling
JNI-callback classes) only from C++ via `GetMethodID`. Flutter's Gradle plugin turns on **R8**
(`isMinifyEnabled` + `isShrinkResources`) for the release build type by default. Because the
**ONNX Runtime 1.23.2 AAR ships no consumer ProGuard/keep rules**, R8 saw those constructors
and classes as unreferenced from Java and **stripped/renamed** them. At runtime the JNI
`GetMethodID` lookup for the now-missing constructor failed, leaving a pending
`NoSuchMethodError`, and ART's CheckJNI escalated that pending exception into a `SIGABRT`.

### Why no Kotlin try/catch could help

The abort is a **native-side process abort**. There is no Java/Kotlin stack frame around the
failed `GetMethodID` call, so no `try/catch` (not even one over `Throwable`) can intercept it.
The only effective fix is at the **build-configuration level** — stop R8 from removing the
symbols. Kotlin hardening addresses *catchable* failures only; it cannot address this abort.

### What is NOT the cause

**16 KB page alignment is NOT the cause.** The crash reproduces as a `NoSuchMethodError`/
SIGABRT on `getInputInfo`, and the fixed release build runs cleanly on a 16 KB-page device
(emulator `sdk_gphone16k_arm64`, Android 17, 16384-byte page). Page size is unrelated.

---

## 2. The fix

**Primary fix — disable R8 for the release build** (`android/app/build.gradle.kts`, release
build type):

```kotlin
signingConfig = signingConfigs.getByName("debug")  // preserved
isMinifyEnabled = false
isShrinkResources = false
```

- `isShrinkResources = false` is **required** alongside `isMinifyEnabled = false`: AGP rejects
  resource shrinking without code shrinking, so leaving it `true` would fail configuration.
- This removes the entire R8-stripping failure class for ORT **and** every other JNI-backed
  plugin (`image_picker`, `geolocator`, `flutter_map`).
- Trade-off: a larger, un-obfuscated release APK (**225.6 MB** recorded). Acceptable for a
  device-local demo.

**The `proguard-rules.pro` alternative was NOT needed.** That route would add a non-ARD file
(requiring explicit approval). The preferred no-new-file route built cleanly and the dex
inspection confirmed the symbols survived, so the keep-rules alternative was not taken.

---

## 3. Hardening list (`MainActivity.kt`)

The following native-path guarantees are in place (most were already present and were
preserved; the two "added" items are new in this fix):

- **Single reused session:** one lazy `OrtEnvironment`/`OrtSession`, guarded in
  `initialize()` so a second `configureFlutterEngine` reuses the existing session (SHA +
  dimension re-checked) rather than allocating a second ~96 MB one. Single-thread executor =
  one image at a time.
- **`runCatching { }` over `Throwable`:** wraps both channel calls, so `OutOfMemoryError` and
  `OrtException` map to `result.error(code, message, null)` rather than propagating.
- **Atomic copy + validation:** model streamed to a `.tmp` cache file, `sha256(tmp)` compared
  to the expected hash, then `renameTo(modelFile)`; the session is created from the file
  **path** (model bytes never land on the Java heap).
- **Input/output validation:** input checked `FLOAT`, shape `[1,3,224,224]`, all finite;
  output checked `FLOAT`, rank-2, `dim0==1`, size `==512 (>0)`, all finite, and rejected if
  all-zero (`values.any { it != 0f }`).
- **`use { }` closing:** `OnnxTensor` and `OrtSession.Result` are closed via `use {}`.
- **Added — main-looper reply:** replies posted via `Handler(Looper.getMainLooper())`
  (`reply { ... }`), giving exactly one reply per call (success XOR failure) on the expected
  thread.
- **Added — single-tag diagnostics:** `Log.i`/`Log.w` under tag `TUNTON_ORT` reporting tensor
  names/shapes and load/inference ms. No image data or embeddings are logged.
- **Dart visible-error states (unchanged, already present):** `_BackendGate`
  (`lib/main.dart`) shows a model-unavailable screen; `recognition_screen.dart` shows
  "Recognition unavailable" / "Not recognized" with retry; `embedding_service.dart` validates
  the manifest and the returned vector and never substitutes a placeholder embedding.

---

## 4. AGENTS.md section 10 — change-report block (filled honestly)

```text
P0 requirement (exact ID):
  P0-02 (run the on-device OpenCLIP ViT-B/32 LAION-2B image tower through native Android
         ONNX Runtime, no network) and P0-12 (fail visibly/safely instead of crashing).

Approved file(s) edited:
  android/app/build.gradle.kts (standard Flutter Android file — allowed)
  android/app/src/main/kotlin/com/example/tuntun/MainActivity.kt (standard Android source — allowed)
  README.md (AGENTS.md section-6 approved; map-stack wording corrected, unrelated to the crash
             fix, no "verified on Android" claim added)

What now works:
  The release build no longer aborts at OrtSession.getInputInfo. With R8 disabled, the ORT
  JNI-callback classes survive, the session loads, and a real 512-d OpenCLIP embedding is
  produced. On the emulator the release build runs real inference (positive, held-out,
  out-of-catalog -> Not recognized, and fully airplane-mode offline) with no crash. On the
  physical phone (debuggable build) the model loads and two real inferences run.

Model checkpoint and preprocessing verified (yes/no; evidence):
  YES (host-side export/parity + on-device tensor contract).
  - Manifest: model_sha256 94273ff4..., checkpoint laion/CLIP-ViT-B-32-laion2B-s34B-b79K
    rev 1a25a446..., input images[1,3,224,224] float, output embeddings[1,512] float,
    dimension 512, self_check_cosine 0.9976605772972107.
  - On device the loaded session reports input=images[1,3,224,224], output=embeddings[1,512],
    matching the manifest. Packaged .onnx = 96,156,490 bytes (matches manifest/expected size).
  NOTE: 512-d embeddings are presented as a RANKED similarity signal, NOT a calibrated
  probability.

Commands/tests actually run and results:
  flutter pub get            -> OK
  flutter analyze            -> No issues found!
  flutter test               -> All tests passed! (55 tests)
  flutter clean + pub get    -> OK
  flutter build apk --release-> Built app-release.apk (225.6 MB)
  apkanalyzer dex (release)  -> ai.onnxruntime.NodeInfo <init>(String, ValueInfo),
                                getInputInfo/getOutputInfo, and all JNI-callback classes
                                present UNOBFUSCATED; model + libonnxruntime.so +
                                libonnxruntime4j_jni.so packaged for arm64-v8a/armeabi-v7a/x86_64.
  (Per step instructions these suites were not re-run in the report step.)

Android release test (passed / failed / not run):
  PASSED on EMULATOR (emulator-5554, 16 KB page, Android 17): install, cold launch, session
  load, real 512-d inference (203-589 ms), ranked match, offline, out-of-catalog, no new
  native crash.
  NOT RUN on the physical phone for the RELEASE build: install -r was interrupted by a
  wireless-ADB drop (an empty/severed-stream error, NOT a signature mismatch).
  Physical phone with the DEBUGGABLE build: PASSED (session load + two real 512-d inferences,
  no crash).

Airplane-mode cold-launch test (passed / failed / not run):
  PASSED on EMULATOR (release build): airplane mode enabled, cold launch, session loaded and a
  full photo->embedding->match ran with networking OFF, crash buffer empty; airplane mode
  restored afterward.
  NOT RUN on the physical phone (no airplane toggle over wireless ADB) — remains a manual user
  step.

8 GB memory results (measured / not measured):
  NOT measured on an 8 GB device. Memory was measured only on a 12 GB-class vivo V2427 (NOT
  the 8 GB target) and on a ~4 GB emulator (also not a target):
    - Emulator release build: TOTAL PSS ~219-225 MB, RSS ~330 MB.
    - Phone debuggable build: TOTAL PSS ~335 MB, RSS ~261 MB (debug/JIT overhead).

Remaining blocker or scope decision:
  No blocker to the overall result (emulator proves the release build end to end). Remaining
  manual proof on the 8 GB target hardware and a physical-phone release install. The manifest
  android_verified flag stays false; flipping it is the user's decision.
```

---

## 5. VERIFIED vs NOT verified

**Verified (from recorded evidence):**

- The R8/`NoSuchMethodError` SIGABRT at `getInputInfo -> NodeInfo.<init>` is **resolved** —
  confirmed by dex inspection (symbols survive unobfuscated) and by crash-free on-device runs.
- Release build compiles clean, 55 tests pass, `flutter analyze` clean.
- **Emulator (16 KB page, release APK):** session loads (`images[1,3,224,224]` ->
  `embeddings[1,512]`), real 512-d inference 203-589 ms, correct ranked matches, airplane-mode
  offline inference, out-of-catalog -> "Not recognized", and a **held-out positive**
  (`test/datasets/held_out/public/binondo-church/1.png`, 1024x771, **NOT a reference
  duplicate**) ranking Binondo Church #1. No new native crash (crash buffer empty, exit-info
  clean).
- **Physical phone (vivo V2427, debuggable build):** session loads, two real 512-d inferences
  (89 ms / 157 ms), raw cosine 0.36-0.68 across the catalog (real, non-degenerate, image
  dependent), no crash.

**Reference-duplicate labeling:** the emulator parity run that ranked Binondo Church #1
(device-evidence `A4`) used `assets/images/binondo-church/1.png` — a **REFERENCE DUPLICATE,
NOT held-out**. The phone's two gallery inferences used the user's own newer photos (byte sizes
85,645 and 2,511,359 did not match the pushed 1,427,553-byte reference), so they are real
on-device inferences but NOT a controlled reference-duplicate parity run.

**Memory labeling:** the phone memory result is **measured on a 12 GB-class vivo V2427, NOT
8 GB**. The emulator is ~4 GB, also not a target device.

**NOT verified / NOT run:**

- Release-build install + inference on the **physical phone** (interrupted by a wireless-ADB
  drop — a severed stream, not a signature error).
- **Airplane-mode cold launch on the physical phone** (no airplane toggle over wireless ADB).
- **8 GB-class device** memory/latency measurement.
- A controlled **reference-duplicate parity run on the phone**.

---

## 6. Other R8 / native risks found

- **Correctness rests on R8 staying disabled.** Because the abort is uncatchable, the fix only
  holds while `isMinifyEnabled`/`isShrinkResources` stay `false`. If anyone re-enables R8 later
  without adding ORT keep rules, the same SIGABRT returns. Review relied on recorded
  apkanalyzer output, not an independent re-run.
- **Every other JNI-backed plugin benefits.** `image_picker`, `geolocator`, and `flutter_map`
  are now also protected from R8 stripping — but the flip side is the same latent risk if R8
  is reintroduced.
- **No obfuscation / larger APK (225.6 MB).** Acceptable for a device-local demo, but noted as
  a size/IP trade-off.
- **Unrelated README rewrite** was bundled into the crash-fix diff (Mapbox -> `flutter_map`
  wording). In-scope as a section-6 file and truthful (no false "verified on Android" claim),
  but ideally would travel in its own change. Non-blocking.

---

## 7. Leftover asset note

`/Users/arnel/tunton-ai/assets/models/landmark_embedder.tflite` is a legacy TFLite asset. It is
**not referenced in `pubspec.yaml`** (confirmed by search) and is **not part of the
OpenCLIP/ONNX path**. It was **left alone** — not loaded, not deleted, not shipped via the
asset manifest.

---

## 8. Remaining MANUAL steps for the user

1. **Physical-phone airplane-mode cold launch** of the release APK (re-enable Wireless
   debugging, `install -r` the debug-signed release APK — no signature prompt, no data wipe —
   then cold launch in airplane mode and confirm session load + a real inference with no
   crash).
2. **Held-out (non-reference) photo test on the phone** and a controlled reference-duplicate
   parity run (the phone picker previously selected the user's own photos instead of the pushed
   reference).
3. **8 GB-class device measurement** — install and measure memory/latency on actual 8 GB
   hardware (nothing measured so far is an 8 GB device).
4. **Decide whether to flip `android_verified` to `true`** in
   `assets/models/openclip_vit_b32_laion2b_int8.manifest.json`. **This is the user's
   decision.** This step and all prior steps left it `false` and added no "verified on Android"
   text to any repo doc. Recommend flipping only after the release build is confirmed on the
   physical phone (and ideally on an 8 GB device).

---

### Source evidence
- `/Users/arnel/tunton-ai/.agents/tasks/openclip-android-crash/verification.md`
- `/Users/arnel/tunton-ai/.agents/tasks/openclip-android-crash/review.md`,
  `/Users/arnel/tunton-ai/.agents/tasks/openclip-android-crash/review.json`
- `/Users/arnel/tunton-ai/.agents/tasks/openclip-android-crash/device-evidence.md`
- `/Users/arnel/tunton-ai/assets/models/openclip_vit_b32_laion2b_int8.manifest.json`
  (`android_verified: false`)
