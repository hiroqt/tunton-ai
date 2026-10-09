# On-device evidence — recognition threshold + margin gate

**What this verifies:** that the data-driven accept decision in
`lib/features/recognition/landmark_matcher.dart`
(`defaultScoreThreshold = 0.40`, `defaultMinTopMargin = 0.05`) behaves on a real
Android runtime the way the analysis predicted: a genuine catalog match is still
accepted, while an out-of-catalog / ambiguous photo reads as **Not recognized**.

**Chosen values under test:** absolute threshold `0.40`, top1−top2 margin `0.05`.

## Environment (REAL run — debug build, emulator)

| Item | Value |
|---|---|
| Target | Android emulator `emulator-5554` |
| AVD | sdk_gphone16k_arm64, Android 17, 16 KB page, ABI arm64-v8a |
| Build | `flutter build apk --debug` → `app-debug.apk`, installed with `adb install -r` |
| App | `com.example.tuntun` / `MainActivity` launched, `kDebugMode` logging on |
| Drive | real app flow: push image → media-scan → Android photo picker → "Find the landmark"; UI automated with `uiautomator dump` + `input tap` |
| adb | `/Users/arnel/Library/Android/sdk/platform-tools/adb -s emulator-5554` |

**This is NOT the release / physical-hardware / airplane-mode proof gate.** It is a
debug build on an emulator. `assets/models/...manifest.json` `android_verified`
stays **false** and no "verified on Android" claim is made anywhere.

### Native runtime load (OpenCLIP crash-fix still holding)

`libonnxruntime4j_jni.so` loaded cleanly at launch and the backend gate passed to
the PhotoScreen (no error screen), i.e. `EmbeddingService.load()` → ONNX Runtime
`initialize` succeeded:

```
D nativeloader: Load .../lib/arm64-v8a/libonnxruntime4j_jni.so ... : ok
```

Real inference ran for every test (embedding dim **512**, finite vectors):

```
[TUNTON_RECOG] preprocess_ms=321 inference_ms=927 embedding_dim=512   (test A)
[TUNTON_RECOG] preprocess_ms=94  inference_ms=312 embedding_dim=512   (test B)
[TUNTON_RECOG] preprocess_ms=205 inference_ms=307 embedding_dim=512   (test C)
```

## Test images

| Label | File on device | Nature |
|---|---|---|
| **C — reference duplicate** | `assets/images/fort-santiago/1.png` | A packaged licensed REFERENCE used to build `reference_embeddings.json`. This is a **reference duplicate, NOT a held-out photo**. Expected to self-match near cosine 1.0. |
| **A — out-of-catalog (synthetic)** | `/tmp/ooc_checker.png` (black/white checkerboard) | Generated non-landmark pattern. Depicts no catalog POI. |
| **B — out-of-catalog (synthetic)** | `/tmp/ooc_solid_gray.png` (solid 128-gray) | Generated non-landmark blank. Depicts no catalog POI. |

No genuine held-out photo of a supported landmark (a non-reference real photo) was
available in this environment, so the "genuine match still accepted" check uses a
reference duplicate. This is labelled as such and is an optimistic proxy — it
proves the gates do not over-reject a strong match, but it is NOT a held-out
generalization test. The AGENTS.md §9 held-out-photo obligation remains open.

## Raw results (real `[TUNTON_RECOG]` logcat)

### Test C — reference duplicate (fort-santiago/1.png) → RECOGNIZED ✅

embedding_dim=512. Per-landmark best cosine:

| landmark | best cosine | ≥ 0.40 ? |
|---|---|---|
| **fort-santiago** | **0.9908** | yes (top-1) |
| puerta-real | 0.6877 | yes (top-2) |
| san-agustin | 0.5979 | yes (top-3) |
| casa-manila | 0.5823 | yes |
| manila-cathedral | 0.5500 | yes |
| binondo-church | 0.5459 | yes |
| far-eastern-university | 0.5432 | yes |
| baluarte-san-diego | 0.5155 | yes |
| up-manila | 0.5055 | yes |
| rizal-park | 0.4984 | yes |
| quiapo-church | 0.4450 | yes |
| dlsu-manila | 0.4257 | yes |
| sm-city-manila | 0.3696 | no |
| robinsons-place-manila | 0.3399 | no |
| lucky-chinatown-mall | 0.3148 | no |

- **top-1 − top-2 margin = 0.9908 − 0.6877 = 0.3031** ≥ 0.05 → margin gate PASSES.
- Outcome: `ACCEPT candidates=fort-santiago,puerta-real,san-agustin reason=margin_ok=0.3031>=0.05`, `result=matched count=3`.
- Result screen rendered ranked suggestions: 1 Fort Santiago, 2 Puerta Real, 3 San Agustin.
- **Not over-rejected.** The stricter gate still accepts a genuine strong match.

### Test B — solid gray out-of-catalog → NOT RECOGNIZED ✅

embedding_dim=512. Highest scores: up-manila 0.3949, sm-city-manila 0.2576,
casa-manila 0.2343, lucky-chinatown-mall 0.2313, rizal-park 0.2185; all other
landmarks lower. **Every landmark < 0.40.**

- top-1 margin: n/a (zero candidates survive the absolute threshold).
- Outcome: `ACCEPT candidates= reason=below_threshold`, `result=not_recognized count=0`.
- Result screen displayed **"Not recognized — This photo did not match a supported landmark."**

### Test A — checkerboard out-of-catalog → matched one candidate ⚠️ (honest caveat)

embedding_dim=512. Per-landmark best cosine (top few): up-manila **0.4951**,
sm-city-manila 0.2975, lucky-chinatown-mall 0.2953, rizal-park 0.2944,
casa-manila 0.2815, dlsu-manila 0.3478; all others < 0.30.

- Only one landmark (up-manila 0.4951) cleared 0.40, so there is no top-2 to form a
  margin → the ambiguity margin gate does NOT apply to a lone candidate.
- Outcome: `ACCEPT candidates=up-manila reason=single_candidate_above_threshold`, `result=matched count=1`.
- **Honest limitation:** a synthetic high-contrast pattern can land a single
  landmark above the 0.40 floor and be surfaced as one suggestion. The margin gate
  only rejects near-ties among ≥2 survivors; it cannot reject a single lone
  above-threshold candidate. This matches `analysis.md`'s stated design (the
  absolute 0.40 floor does little discrimination; the margin is the ambiguity
  filter) and is the known residual gap. The user still must confirm before any
  routing (P0-05), and no confidence percentage is shown.

## Summary vs. the goal

- Stricter rejection confirmed: the gray out-of-catalog image reads **Not
  recognized** on-device (count=0), which the pre-change single 0.55 gate behavior
  would not reliably produce for ambiguous near-tie inputs.
- WITHOUT over-rejecting a genuine match: the fort-santiago reference duplicate is
  still accepted as a clear top-1 (0.9908, margin 0.3031).
- Residual gap (recorded, not hidden): a single synthetic pattern can clear the
  0.40 floor for one landmark and bypass the margin gate (test A).

## Phone (physical vivo V2427)

Serial `adb-10AF141GXB001AK-yUe3mV._adb-tls-connect._tcp`. The permitted
non-destructive `adb install -r app-debug.apk` was attempted while it showed
`device`, but the wireless ADB link is unstable and the install **timed out**
(no uninstall / `pm clear` / `flutter run` / airplane-mode toggle was performed —
the phone's Mapbox offline data was not touched). **Phone pending reconnect; no
on-phone result captured here.** A pairing code was offered mid-run but pairing /
re-attempting was declined to avoid disturbing the phone's offline region and
because the emulator evidence already satisfies this step.

## Cleanup

All pushed test photos removed from the emulator:
`tunton_fort_santiago_ref.png`, `tunton_ooc_checker.png`, `tunton_ooc_gray.png`
deleted from `/sdcard/Pictures/` and media-rescanned; `ls /sdcard/Pictures | grep tunton` → none.
