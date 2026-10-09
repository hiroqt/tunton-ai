# Disable R8 for release + harden the ONNX Runtime native path against catchable failures

The release APK was aborting natively before OpenCLIP inference ran: a SIGABRT from a failed JNI `GetMethodID` on `ai.onnxruntime.NodeInfo.<init>(String, ValueInfo)`, because Flutter's Gradle plugin turns on R8 (minify + resource shrinking) for release and the ORT 1.23.2 AAR ships no consumer keep rules, so R8 stripped/renamed the JNI-callback classes. The fix disables `isMinifyEnabled` and `isShrinkResources` on the release build (keeping the debug `signingConfig`), which removes that whole failure class for ORT and every other JNI-backed plugin. Alongside, `MainActivity.kt` gains main-looper reply posting and single-tag diagnostic logging on top of an already-hardened native path (single reused session, atomic SHA-validated model copy, session-from-path, input/output validation, `use{}` cleanup, `runCatching` over `Throwable`). The Dart layer was left unchanged because it already surfaces every catchable failure as a visible UI error with retry and never fabricates embeddings.

Watch for: the README is heavily rewritten in the same diff to correct the map-stack description (Mapbox → `flutter_map`), which is unrelated to the crash fix (confirmed, non-blocking since README is a section-6 approved file and adds no false "verified on Android" claim). A native abort is uncatchable by design, so correctness here rests entirely on R8 being disabled — the coder's dex inspection confirms the symbols survived unobfuscated (likely-to-confirmed, apkanalyzer evidence recorded but not independently re-run).

**Verdict**: APPROVED

## High-level view

The crash fix lives entirely at the build-configuration level, which is the correct layer: a native `GetMethodID` abort cannot be trapped in Kotlin, so no amount of `try/catch` would have helped. Disabling R8 keeps the ORT JNI-callback classes present under their real names. `isShrinkResources=false` is paired with `isMinifyEnabled=false`, which avoids the Gradle constraint that resource shrinking requires minification; the release build completed (225.6 MB APK).

The native hardening added in this diff is narrow: replies now post to the main looper via a `Handler`, and one `Log` tag (`TUNTON_ORT`) records tensor shapes and load/inference timings without touching image data or embeddings. The heavier guarantees the task asks for — one reused `OrtEnvironment`/`OrtSession`, single-image executor, atomic SHA-validated model copy, session created from a file path rather than a heap buffer, input/output length-finite-shape checks, `use{}` cleanup, and `runCatching` catching `Throwable` (so `OutOfMemoryError` and `OrtException` map to `result.error`) — were already present and are preserved. Each channel call produces exactly one reply (success XOR failure), and a second `configureFlutterEngine` reuses the existing session instead of allocating a second ~96 MB one.

The Dart side carries the user-visible failure contract. Native channel errors arrive as `PlatformException`; `MissingPluginException` arises in test/no-plugin contexts; both, plus timeouts and decode errors, land in a visible error state with a retry affordance — the backend gate's model-unavailable screen, the recognition screen's "Recognition unavailable" / "Not recognized" states, and the photo screen's permission/pick error text. No path invents an embedding or a prediction; every failure throws or renders an error.

Scope holds: only section-6 approved files and the standard Flutter Android `build.gradle.kts` were touched, `android_verified` stays `false`, and no "verified on Android" text was added anywhere.

<details>
<summary>Issues (2)</summary>

1. **Unrelated README rewrite bundled in the crash-fix diff** — the README's map-stack description was rewritten (Mapbox → `flutter_map`/`AssetTileProvider`) in the same change; it is in-scope as a section-6 file and adds no false claims, but it is not part of the OpenCLIP crash fix and belongs in its own change. Non-blocking.
2. **Correctness depends on R8 staying disabled, verified only by recorded dex inspection** — the fix is correct only if the ORT JNI symbols survive; this review relies on the coder's apkanalyzer output rather than an independent dex check. On-device inference remains unverified (correctly out of scope for this step). Non-blocking.

</details>

<details>
<summary>Details</summary>

## The fix is at the only layer that can work

The recorded root cause is a native abort: `libonnxruntime4j_jni.so` calls `GetMethodID` for `NodeInfo.<init>(String, ValueInfo)` during `OrtSession.getInputInfo`, R8 had removed/renamed that constructor, the lookup failed, and ART's CheckJNI turned the pending `NoSuchMethodError` into SIGABRT in `pool-3-thread-1`. That abort happens in native code with no Java frame to catch it, so hardening Kotlin alone could never fix this crash — the fix had to prevent the symbol from being stripped. Disabling R8 for release does exactly that:

```kotlin
signingConfig = signingConfigs.getByName("debug")   // preserved
isMinifyEnabled = false
isShrinkResources = false
```

`isShrinkResources = false` is required here: AGP rejects resource shrinking without code shrinking, so leaving it `true` with minify off would fail configuration. Pairing both to `false` is internally consistent and the release build produced an APK, confirming no configuration conflict. The change is additive inside the existing `release {}` block and leaves `defaultConfig`, `compileOptions`, `kotlin{}`, and the ORT dependency untouched.

The cost is a larger, un-shrunk release APK (225.6 MB recorded) and no obfuscation. For a device-local hackathon demo that is an acceptable trade; the alternative (a `proguard-rules.pro` keep file) would add a non-ARD file and need explicit approval, so the no-new-file route is the right call for this scope.

## Native path: what this diff adds vs. what it preserves

The diff itself adds only two things. Replies are now posted to the main looper:

```kotlin
private fun reply(block: () -> Unit) = mainHandler.post(block)
```

and both channel branches route their single outcome through it — `onSuccess { reply { result.success(..) } }` or `onFailure { reply { result.error(..) } }`, never both. That gives exactly one reply per call, delivered on the thread the MethodChannel expects, which is the correct fix for replying from the single-thread executor. The second addition is `Log.i`/`Log.w` under one tag (`TUNTON_ORT`) carrying tensor names/shapes and load/inference milliseconds; the logged strings contain no tensor values or embeddings, satisfying the no-image-data constraint.

The stronger guarantees the task enumerates were already in place and remain intact:

```
initialize():
  session?.let { check(sha==) ; check(dim==) ; return }   // reuse — no 2nd ~96MB session
  require(sha matches ^[0-9a-f]{64}$)
  copy asset -> MODEL_FILE.tmp (streamed), sha256(tmp)==expected, renameTo(modelFile)
  createSession(modelFile.absolutePath, ...)              // from PATH, not heap bytes
  validate input: FLOAT, shape==[1,3,224,224]
  validate output: FLOAT, rank-2, dim0==1, size==expectedDimension>0
  on any Throwable: loaded.close(); rethrow

embed():
  require(data.size==1*3*224*224 && all finite)
  OnnxTensor.createTensor(...).use { session.run(...).use { out ->
      out.use { values(512); check all finite && any != 0f } } }
```

The `session?.let { … return }` short-circuit is what prevents a second `configureFlutterEngine` (or a second `initialize` call after a config change) from allocating another session — the existing one is reused after a checksum/dimension check. Model bytes are streamed to a cache file and the session is opened from the path, so the ~96 MB model never lands on the Java heap. The output check `values.any { it != 0f }` rejects an all-zero vector, which (together with the Dart-side norm check) is what stops a degenerate embedding from being treated as a real match. `runCatching` wraps both calls and catches `Throwable`, so `OutOfMemoryError` and `OrtException` both become `result.error(...)` rather than propagating. No new execution providers are introduced; the session uses default `SessionOptions`.

## Dart failure contract and no-fabrication

No Dart file changed, and that is defensible because the catchable-failure contract already exists end to end. The native layer maps failures to `result.error("MODEL_UNAVAILABLE"/"INFERENCE_FAILED", ...)`, which surface in Dart as `PlatformException`. Those, along with `MissingPluginException` (no native plugin in widget tests), timeouts, and decode failures, are caught at three visible layers:

- `_BackendGate` (`main.dart`) renders a "Local landmark recognition is unavailable… then restart the app." screen on any load/`initialize` error, after disposing the embedding service.
- `RecognitionScreen` turns `snapshot.hasError` into "Recognition unavailable" with a "Try another photo" button, and an empty candidate list into "Not recognized" — both reachable from a thrown `PlatformException` during `embed`.
- `PhotoScreen._pick` catches `PlatformException` (distinguishing permission-denied) and a catch-all, writing a visible `_error`; `_recoverPhoto` catches `MissingPluginException` and others.

On fabrication: `EmbeddingService.embed` throws `FormatException` when the native side returns null, and `normalizeEmbedding` throws on wrong length, non-finite values, or a zero vector — it never substitutes a placeholder. The matcher consumes only a real normalized vector, and the recognition UI shows "Not recognized" rather than inventing a candidate. This holds the AGENTS.md section 8 "no made-up outputs" guardrail.

## Scope and disclosure

Files touched: `android/app/build.gradle.kts` (standard Flutter-generated Android file, allowed), `MainActivity.kt` (standard Android source, allowed), and `README.md` (section-6 approved). No new product-tree files, no new packages, no new screens. `assets/models/openclip_vit_b32_laion2b_int8.manifest.json` still reads `"android_verified": false`, and a repo-wide grep for "verified on android" finds nothing — the disclosure correctly still does not claim verified Android inference. On-device install/inference is explicitly a later step's job and is not required here.

The README rewrite is the one out-of-place element: it corrects every Mapbox reference to the actually-shipped `flutter_map` + bundled-tile stack. The edits are truthful and improve accuracy, and README is an approved file, so this is non-blocking — but it is unrelated to the crash fix and would ideally travel in its own change.

## Test coverage

The verification note records `flutter analyze` clean, 55 passing tests, a clean `flutter build apk --release` (225.6 MB), and dex inspection confirming the ORT JNI classes survive unobfuscated with the 96,156,490-byte model and both native `.so` libraries packaged for three ABIs. Per this step's instructions these suites were not re-run.

Not tested (correctly deferred, not a blocker here): on-device cold-launch in airplane mode, real inference on an 8 GB device, and held-out recognition — the only true proof that the R8 fix resolved the runtime abort. The dex evidence makes the fix highly likely to hold, but the SIGABRT is only provably gone once inference runs on hardware.

</details>

<details>
<summary>File map</summary>

- `android/app/build.gradle.kts` — release build: `isMinifyEnabled=false`, `isShrinkResources=false` added; `signingConfig` preserved; explanatory comment on the ORT/R8 interaction.
- `android/app/src/main/kotlin/com/example/tuntun/MainActivity.kt` — main-looper `reply{}` posting for exactly one reply per call; `TUNTON_ORT` logging of shapes and timings (no image data); existing session reuse / atomic copy / validation / `use{}` cleanup preserved.
- `README.md` — map-stack description corrected from Mapbox to `flutter_map`/bundled tiles (unrelated to the crash fix; truthful; no "verified on Android" claim added).

Full diff: `git diff` against `main` in `/Users/arnel/tunton-ai`.

</details>
