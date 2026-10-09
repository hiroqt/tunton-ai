# OpenCLIP Android crash fix — verification note

Date: 2026-10-10 (pre-cutoff). Author: coding subagent. Working tree uncommitted.

## P0 requirement(s)
- **P0-02** Run on-device visual model: single packaged OpenCLIP ViT-B/32 LAION-2B image tower runs through native Android ONNX Runtime without network calls.
- **P0-12** Fail visibly and safely: missing/mismatched model and inference errors give truthful errors, not a crash.

## Confirmed root cause (not re-derived)
Release build aborted natively before inference: SIGABRT in `pool-3-thread-1`,
`java.lang.NoSuchMethodError: no non-static method
Lai/onnxruntime/NodeInfo;.<init>(Ljava/lang/String;Lai/onnxruntime/ValueInfo;)V`
at `OrtSession.getInputInfo` (JNI `Java_ai_onnxruntime_OrtSession_getInputInfo`).
Flutter's Gradle plugin enables R8 (minify + shrinkResources) for release by default.
`NodeInfo(String, ValueInfo)` and related classes are instantiated only from native
JNI code (`libonnxruntime4j_jni.so` via `GetMethodID`); the ORT 1.23.2 AAR ships no
consumer keep rules, so R8 stripped/renamed them. The failed `GetMethodID` left a
pending `NoSuchMethodError` and ART CheckJNI aborted the process. A native abort cannot
be caught in Kotlin — the fix had to be at the build-configuration level.

## Fix applied (FIX DECISION 1 — preferred, no new file)
`android/app/build.gradle.kts` release build type:
- `isMinifyEnabled = false`
- `isShrinkResources = false`
- existing `signingConfig = signingConfigs.getByName("debug")` kept.

This removes the whole R8-stripping failure class for ORT and every other
native/JNI-backed plugin (image_picker, geolocator, flutter_map). The alternative
proguard-rules.pro route (needs user approval; adds a non-ARD file) was NOT taken
because the preferred route built cleanly and the dex inspection confirms the symbols
survived.

## Fix applied (FIX DECISION 2 — hardening, minimal, catchable failures only)
`android/app/src/main/kotlin/com/example/tuntun/MainActivity.kt`:
- Already present and kept: one lazy `OrtEnvironment`/`OrtSession` reused (guarded in
  `initialize()` so a second `configureFlutterEngine` does NOT create a second session),
  single-thread executor (one image at a time), `runCatching { }` wrapping both channel
  calls (catches `Throwable`, so `OutOfMemoryError` and `OrtException` are covered) mapped
  to `result.error(code, message, null)`, atomic temp-file + `renameTo`, SHA-256 validation
  before reusing a cached copy, session created from file PATH (streamed copy, never 96 MB
  on the Java heap), input length/finite/shape validation, output length-512/finite
  validation, `use {}` on `OnnxTensor` and `OrtSession.Result`.
- Added: replies now posted on the main looper via a `Handler(Looper.getMainLooper())`
  (`reply { ... }`) instead of the executor thread — exactly one reply per call.
- Added: `Log.i`/`Log.w` under a single tag `TUNTON_ORT` reporting tensor names/shapes,
  session load ms, inference ms, and failure class. No image data or embeddings logged.
- No new execution providers added.

Dart side already surfaces visible error states (no fabricated embeddings/predictions):
`_BackendGate` in `lib/main.dart` shows a model-unavailable screen on failure;
`recognition_screen.dart` shows `Recognition unavailable` / `Not recognized` with retry;
`embedding_service.dart` validates the manifest and the returned vector. No Dart changes
were required for the catchable-failure guardrails, so none were made.

## Map stack note
The shipped app uses `flutter_map` (^8.3.2) with bundled raster tiles
(`assets/tiles/{z}/{x}/{y}.png`, `AssetTileProvider`) and "© OpenStreetMap contributors"
attribution — NOT Mapbox. There is no map access token and no `--dart-define`; the
release build needs none. (The Mapbox wording in AGENTS.md/PRD describes the approved
target doc, not the current implementation.) The R8 fix is independent of the map stack.

## Untouched by design
- `assets/models/openclip_vit_b32_laion2b_int8.manifest.json` `"android_verified": false`
  left unchanged. No "verified on Android" text written anywhere.
- `assets/models/landmark_embedder.tflite` left alone (legacy TFLite asset; not part of the
  OpenCLIP/ONNX path).
- No disclosure text changed; README/docs already state on-device OpenCLIP.

## Commands run and results
From `/Users/arnel/tunton-ai`:

| Command | Result |
|---|---|
| `flutter pub get` | OK (deps resolved) |
| `flutter analyze` | `No issues found!` (ran in 3.5s) |
| `flutter test` | `All tests passed!` — 55 tests (widget_test.dart, preprocessing_parity_test.dart, etc.) |
| `flutter clean` + `flutter pub get` | OK |
| `flutter build apk --release` | `✓ Built build/app/outputs/flutter-apk/app-release.apk (225.6MB)` |

### Dex inspection (apkanalyzer, Android SDK cmdline-tools) on app-release.apk
Command: `apkanalyzer dex code --class ai.onnxruntime.NodeInfo app-release.apk`
and `apkanalyzer dex packages --defined-only app-release.apk`.

- The crashing symbol survived UNOBFUSCATED:
  `ai.onnxruntime.NodeInfo <init>(java.lang.String,ai.onnxruntime.ValueInfo)` present;
  smali signature `.method public constructor <init>(Ljava/lang/String;Lai/onnxruntime/ValueInfo;)V`.
- `OrtSession.getInputInfo(long,long,long)` and `getOutputInfo(long,long,long)` present
  unobfuscated.
- All JNI-callback classes present with real names: `NodeInfo`, `ValueInfo`, `TensorInfo`,
  `MapInfo`, `SequenceInfo`, `OnnxTensor`, `OnnxMap`, `OnnxSequence`, `OrtException`,
  `OrtSession$Result`, `OrtSession$SessionOptions`, `OnnxJavaType`. No single-letter /
  obfuscated class or method names observed → R8 confirmed disabled.
- Model asset packaged: `assets/flutter_assets/assets/models/openclip_vit_b32_laion2b_int8.onnx`
  = 96,156,490 bytes (matches expected size and manifest `model_sha256`).
- Native libs packaged for arm64-v8a / armeabi-v7a / x86_64:
  `libonnxruntime.so` and `libonnxruntime4j_jni.so` (the JNI library performing the
  `GetMethodID` lookups).

## Build warnings (non-blocking)
- Patrol plugin applies legacy KGP (future-Flutter deprecation warning only).
- `source/target value 8 is obsolete` javac warnings from a transitive plugin.
- MaterialIcons tree-shaking (expected).
None affect the ORT path or the release build result.

## NOT done in this step (owned by a later step)
- On-device install and real inference (airplane-mode cold launch, held-out photo,
  memory/latency on 8 GB hardware). The APK builds and the ORT symbols are intact, but
  Android inference is NOT yet verified on hardware; `android_verified` stays `false`.
