# OpenCLIP Android on-device inference — raw proof evidence

Date: 2026-10-10 (pre-cutoff). Author: coding subagent (device-proof step). No commits made.

Goal: prove on REAL Android hardware that the OpenCLIP ViT-B/32 image tower loads
through native ONNX Runtime and produces a real embedding with NO crash (SIGABRT /
`NoSuchMethodError` on `ai.onnxruntime.NodeInfo.<init>` must be gone).

adb binary: `/Users/arnel/Library/Android/sdk/platform-tools/adb`

## Devices under test

| Role | Serial | Device | Android | Page size | RAM | Build installed at start |
|---|---|---|---|---|---|---|
| PRIMARY phone | `adb-10AF141GXB001AK-yUe3mV._adb-tls-connect._tcp` | vivo V2427 | 16 / API 36, arm64-v8a | 4096 | ~11.5 GB (12 GB-class, **NOT** 8 GB target) | DEBUGGABLE |
| 16 KB-page compat | `emulator-5554` | sdk_gphone16k_arm64 | 17 | 16384 | ~4 GB | crashing release build |

Launch activity (both): `com.example.tuntun/.MainActivity` (resolved via
`cmd package resolve-activity --brief com.example.tuntun`).

Phone package flags at start: `pkgFlags=[ DEBUGGABLE HAS_CODE ... ]`, versionName 1.0.0.
Release APK signer SHA-256 `bf05a8076dbd28c356a95d49d3d683917225a01be176ce8dd3bcc52cfdd117ba`
== `~/.android/debug.keystore` cert (`BF:05:A8:07:...`), so `install -r` is signature-safe.

Release APK: `build/app/outputs/flutter-apk/app-release.apk` (225,557,093 bytes),
signed with the debug keystore (signer SHA-256 `bf05a807…17ba`, matches
`~/.android/debug.keystore`), so `install -r` over the debuggable build does not
hit a signature mismatch and does not wipe app data.

Logging note: the native Kotlin path logs under tag `TUNTON_ORT` in BOTH debug and
release (session load ms, input/output tensor names+shapes, inference ms). The Dart
numeric logs under tag flutter / `[TUNTON_RECOG]` (embedding dim, per-landmark raw
cosine, candidate ids, L2-norm context) fire only in `kDebugMode`, i.e. only on the
DEBUGGABLE build. So: the RELEASE APK proves the crash is gone + tensor contract; the
DEBUGGABLE build on the phone yields the raw embedding-length / cosine numbers.

---

## DEVICE A — Emulator (emulator-5554, 16 KB page, Android 17) — RELEASE APK

### A1. Install (replaces the previously-crashing release build)
```
$ adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
Performing Streamed Install
Success          (4.359s wall)
```

### A2. Cold launch + session load (THE crash point) — NO CRASH
```
$ adb -s emulator-5554 shell am force-stop com.example.tuntun
$ adb -s emulator-5554 logcat -c
$ adb -s emulator-5554 shell am start -W -n com.example.tuntun/.MainActivity
Status: ok   LaunchState: COLD   TotalTime: 2309   WaitTime: 2311

$ adb -s emulator-5554 logcat -d -s TUNTON_ORT AndroidRuntime DEBUG libc
10-10 05:01:15.846  I TUNTON_ORT: session loaded in 2584ms input=images[1, 3, 224, 224] output=embeddings[1, 512]
```
This is the exact line (`OrtSession.getInputInfo` → `NodeInfo.<init>`) where the old
build hit SIGABRT. The session now loads; input tensor `images[1,3,224,224]` and output
`embeddings[1,512]` match the manifest contract. No `AndroidRuntime` / `DEBUG` / native
abort lines emitted.

### A3. Crash buffer + exit-info immediately after launch — clean
```
$ adb -s emulator-5554 logcat -b crash -d
(no output — empty)

$ adb -s emulator-5554 shell dumpsys activity exit-info com.example.tuntun
ApplicationExitInfo #0: timestamp=2026-10-10 02:19:18.354 reason=5 (APP CRASH(NATIVE))
```
The only NATIVE crash on record is at 02:19:18 — the OLD build, BEFORE this 05:01 install.
No new crash entry was created by our launch.

### A4. Real inference through the app's real flow (reference duplicate)
Pushed one licensed reference image (REFERENCE DUPLICATE, not held-out):
```
$ adb -s emulator-5554 shell mkdir -p /sdcard/Pictures/TuntonTest
$ adb -s emulator-5554 push assets/images/binondo-church/1.png /sdcard/Pictures/TuntonTest/binondo_ref1.png   (1,427,553 bytes)
$ adb -s emulator-5554 shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/TuntonTest/binondo_ref1.png
Broadcast completed: result=0
# content query -> _id=42, _display_name=binondo_ref1.png  (visible to picker)
```
Drove the real UI with `uiautomator dump` + `input tap`:
PhotoScreen "Choose from gallery" (540,1856) → Android Photo Picker
(`com.google.android.photopicker`) → tapped the pushed photo (179,1102) → "Done"
(907,2201) → back in app, "Selected landmark photo" shown → "Find the landmark" (540,1815).

Native inference log + crash check:
```
$ adb -s emulator-5554 logcat -d -s TUNTON_ORT
10-10 05:03:17.328  I TUNTON_ORT: inference completed in 589ms dim=512
$ adb -s emulator-5554 logcat -b crash -d
(no output — empty)
```
Recognition screen (Step 2 of 4: Confirm) rendered RANKED SUGGESTIONS from the real
embedding (content-desc read back via uiautomator):
```
1  Binondo Church — Manila
2  San Agustin Church — exterior public street approach
3  Manila Cathedral — Intramuros
```
Parity signal: the query was a Binondo Church reference image and the top-1 match is
Binondo Church — the model correctly recognized the reference's own landmark as rank 1.
(RAW cosine scores are not surfaced in the release UI/logs; the Dart `[TUNTON_RECOG]`
numeric logs are `kDebugMode`-only. Numeric embedding length / L2-norm / per-landmark
cosine are captured from the DEBUGGABLE build on the phone — Device B below.)

### A5. meminfo after inference (release build; ~4 GB emulator, NOT a memory target)
```
$ adb -s emulator-5554 shell dumpsys meminfo com.example.tuntun
Native Heap  142,624 KB dirty
TOTAL PSS    225,408 KB (~220 MB)      TOTAL RSS 339,712 KB (~332 MB)   SWAP PSS 549 KB
```

**Device A verdict: PASS.** Release APK on a 16 KB-page device loads the ORT session,
runs a real 512-d inference in ~589 ms, returns a correct ranked match, and produces NO
new native crash. The R8/NoSuchMethodError SIGABRT is resolved.

---

## DEVICE B — Phone (vivo V2427, arm64-v8a, Android 16/API 36, 4096 page) — DEBUGGABLE build

Memory label: **measured on 12 GB-class vivo V2427, NOT the 8 GB target.**

The phone shipped with the DEBUGGABLE build installed (confirmed `pkgFlags=[ DEBUGGABLE … ]`),
which is the build that emits the Dart `[TUNTON_RECOG]` numeric logs. I captured the raw
embedding / cosine numbers from it before attempting a release reinstall. (A release
`install -r` was then interrupted by a wireless-ADB drop — see B4; NOT a signature error.)

### B1. Session load — reached PhotoScreen (crash point passed)
Cold-launched `com.example.tuntun/.MainActivity`; the app rendered the PhotoScreen
("Step 1 of 4: Photo") WITHOUT hitting the backend-gate "recognition unavailable" error.
Reaching PhotoScreen requires `EmbeddingService.load()` → native `initialize()` →
`OrtSession.getInputInfo()` (the exact JNI path that previously SIGABRT'd on
`NodeInfo.<init>`) to succeed. No crash dialog, process stayed up.

### B2. Real inference #1 (gallery pick, through the real image_picker flow)
`adb -s <phone> logcat -s TUNTON_ORT flutter` captured (pid 4750), timestamps 05:27:xx:
```
[TUNTON_RECOG] photo_ready source=gallery bytes=85645 dimensions=740x492
[TUNTON_RECOG] recognition_requested
[TUNTON_RECOG] preprocess_ms=348 inference_ms=157 embedding_dim=512
[TUNTON_RECOG] landmark=manila-cathedral      best_cosine=0.6794 accepted=true
[TUNTON_RECOG] landmark=binondo-church        best_cosine=0.5988 accepted=true
[TUNTON_RECOG] landmark=fort-santiago         best_cosine=0.5728 accepted=true
[TUNTON_RECOG] landmark=casa-manila           best_cosine=0.5603 accepted=true
[TUNTON_RECOG] landmark=san-agustin           best_cosine=0.5120 accepted=false
[TUNTON_RECOG] landmark=up-manila             best_cosine=0.5025 accepted=false
[TUNTON_RECOG] landmark=lucky-chinatown-mall  best_cosine=0.4647 accepted=false
[TUNTON_RECOG] landmark=puerta-real           best_cosine=0.4643 accepted=false
[TUNTON_RECOG] landmark=far-eastern-university best_cosine=0.4475 accepted=false
[TUNTON_RECOG] landmark=robinsons-place-manila best_cosine=0.4399 accepted=false
[TUNTON_RECOG] landmark=sm-city-manila        best_cosine=0.4199 accepted=false
[TUNTON_RECOG] landmark=baluarte-san-diego    best_cosine=0.4070 accepted=false
[TUNTON_RECOG] landmark=quiapo-church         best_cosine=0.4034 accepted=false
[TUNTON_RECOG] landmark=dlsu-manila           best_cosine=0.3815 accepted=false
[TUNTON_RECOG] landmark=rizal-park            best_cosine=0.3639 accepted=false
[TUNTON_RECOG] candidates=manila-cathedral,binondo-church,fort-santiago
[TUNTON_RECOG] result=matched count=3 total_ms=521
```
Embedding dim = **512**, inference ms = **157**, preprocess ms = 348. Raw cosine scores
are presented as a RANKING signal (not probability), spanning 0.36–0.68 across the catalog
— i.e. the vector is real and non-degenerate (varied, finite values), NOT all-zero/constant.

### B3. Real inference #2 (second gallery pick)
```
[TUNTON_RECOG] photo_ready source=gallery bytes=2511359 dimensions=1024x1365
[TUNTON_RECOG] preprocess_ms=3246 inference_ms=89 embedding_dim=512
[TUNTON_RECOG] landmark=rizal-park             best_cosine=0.6311 accepted=true
[TUNTON_RECOG] landmark=sm-city-manila         best_cosine=0.6075 accepted=true
[TUNTON_RECOG] landmark=robinsons-place-manila best_cosine=0.5645 accepted=true
… (others below threshold 0.55) …
[TUNTON_RECOG] candidates=rizal-park,sm-city-manila,robinsons-place-manila
[TUNTON_RECOG] result=matched count=3 total_ms=3344
```
Embedding dim = **512**, inference ms = **89**. A completely different ranking from #2's
image vs #1's — the embeddings are genuinely image-dependent, not canned.

NOTE on the test images: the phone's photo picker (single-tap-return) selected the user's
own newer gallery photos sitting above my pushed reference, so these two queries were NOT
the pushed binondo reference duplicate (byte sizes 85,645 and 2,511,359 ≠ the 1,427,553-byte
PNG, and neither logged 1024x934). They are still valid REAL on-device inferences with real
512-d finite embeddings and real raw cosine scores. A controlled reference-duplicate parity
run on the phone (to compare on-device-vs-stored binondo cosine directly) was interrupted by
the wireless drop (B4). The emulator run (A4) IS a confirmed reference-duplicate: a
binondo_ref1.png query ranked Binondo Church #1.

### B4. Release `install -r` interrupted by wireless-ADB drop (NOT a signature mismatch)
```
$ adb -s <phone> install -r build/app/outputs/flutter-apk/app-release.apk
Performing Streamed Install
adb: failed to install …:            (empty reason)
$ adb -s <phone> get-state
error: device 'adb-10AF141GXB001AK-…_adb-tls-connect._tcp' not found
$ adb mdns services   -> (no services)
$ adb devices         -> only emulator-5554 remains
```
The TLS wireless connection dropped mid-stream (the task warned this can happen); the empty
install error is the severed stream, not a signature rejection. The debuggable build was
left installed and intact; NO uninstall / pm clear was performed, so the Mapbox
SDK-managed offline region and app data are untouched.

### B5. meminfo (debuggable build, live pid 4750 after the two inferences)
**measured on 12 GB-class vivo V2427, NOT 8 GB:**
```
$ adb -s <phone> shell dumpsys meminfo com.example.tuntun
Native Heap  16,684 KB dirty
TOTAL PSS   342,665 KB (~335 MB)   TOTAL RSS 266,932 KB (~261 MB)   TOTAL SWAP PSS 197,160 KB
```
(Debuggable builds carry JIT/debug overhead; the emulator RELEASE build measured lower,
TOTAL PSS ~220 MB.)

## DEVICE A (emulator) — additional RELEASE-build acceptance cases

All on emulator-5554, release APK. Images pushed to /sdcard/Pictures/TuntonTest/ and
media-scanned; driven through the real image_picker → recognition flow.

### A6. Out-of-catalog photo → "Not recognized" (test/datasets/unknown/2.png)
```
10-10 05:34:31  I TUNTON_ORT: inference completed in 250ms dim=512
Recognition screen: "Not recognized — This photo did not match a supported landmark."
```
A real 512-d inference still ran (dim=512); the matcher correctly produced an empty
candidate set (all cosines below the 0.55 threshold) → explicit "Not recognized", no crash.

### A7. Held-out positive (test/datasets/held_out/public/binondo-church/1.png, 1024x771 —
NOT a reference duplicate)
```
10-10 05:36:52  I TUNTON_ORT: inference completed in 203ms dim=512
Ranked suggestions: 1 Binondo Church (Manila), 2 San Agustin Church, 3 Manila Cathedral
```
Correct top-1 on a held-out image of the landmark.

### A8. Airplane-mode cold launch + offline inference (emulator; airplane mode toggled
here is allowed and was restored afterward)
```
$ adb -s emulator-5554 shell cmd connectivity airplane-mode enable   # airplane_mode_on=1
$ adb -s emulator-5554 shell am start -W -n com.example.tuntun/.MainActivity
Status: ok  LaunchState: COLD  TotalTime: 2267
10-10 05:37:43  I TUNTON_ORT: session loaded in 1000ms input=images[1, 3, 224, 224] output=embeddings[1, 512]
# app reached PhotoScreen (backend gate passed with NO network)
10-10 05:38:20  I TUNTON_ORT: inference completed in 343ms dim=512
Ranked suggestions: 1 Binondo Church (Manila), 2 San Agustin Church, 3 Manila Cathedral
$ adb -s emulator-5554 logcat -b crash -d | grep tuntun   -> (empty, no crash)
$ adb -s emulator-5554 shell cmd connectivity airplane-mode disable  # airplane_mode_on=0 (restored)
```
The model loads and a full photo→embedding→match runs with networking OFF — confirms the
device-local, no-network design on the release build.

### A9. Final emulator crash + memory after all runs (release build)
```
$ adb -s emulator-5554 logcat -b crash -d | grep tuntun     -> (empty)
$ adb -s emulator-5554 shell dumpsys activity exit-info com.example.tuntun
  most recent exits: reason=10 (USER REQUESTED / FORCE STOP) from my force-stops;
  the only APP CRASH(NATIVE) on record is 2026-10-10 02:19:18 — the OLD build, pre-install.
$ adb -s emulator-5554 shell dumpsys meminfo com.example.tuntun
  TOTAL PSS 223,895 KB (~219 MB)   TOTAL RSS 337,744 KB (~330 MB)   SWAP PSS 553 KB
```
(~4 GB emulator; NOT a memory target device, recorded for completeness.)

**Device A overall: PASS** — release build loads the session and runs real 512-d inference
(reference-duplicate, held-out positive, out-of-catalog→Not recognized, and fully offline),
with NO new native crash. The R8 SIGABRT is resolved on a 16 KB-page device.

---

### Device B status: PARTIAL — real inference PROVEN on the debuggable build
Session load + two real 512-d inferences + no crash are PROVEN on the phone (debuggable
build). The RELEASE build install/inference on the phone is **NOT RUN — phone wireless ADB
dropped mid `install -r`, pending user reconnect.** This is NOT a blocker for the overall
result: the emulator (Device A) proves the RELEASE build end to end (load + inference +
offline + out-of-catalog, no crash). If/when the phone's Wireless debugging is re-enabled,
a small follow-up will: `install -r` the debug-signed release APK (no signature prompt / no
data wipe), confirm release session-load + a real inference with no crash, run a controlled
reference-duplicate parity check, capture crash/exit-info/meminfo, and delete the leftover
`/sdcard/Pictures/TuntonTest` photo. Decision (per workflow parent): do not hold the
workflow waiting on the phone; finalize on the emulator-confirmed evidence.

---

## CLEANUP performed
- Emulator (emulator-5554): `rm -rf /sdcard/Pictures/TuntonTest`; MediaStore rescanned
  (no binondo/heldout/unknown rows remain); stray `/sdcard/*.xml` uiautomator dumps removed.
  Airplane mode restored to OFF (`airplane_mode_on=0`).
- Phone: a test photo was pushed to `/sdcard/Pictures/TuntonTest/` before the wireless
  drop; it could NOT be removed because the device went unreachable. **Pending cleanup on
  reconnect** (`rm -rf /sdcard/Pictures/TuntonTest`). The app itself was NOT uninstalled
  or cleared; Mapbox offline region / app data untouched.
- Host: `/tmp` ui-dump and logcat scratch files removed.
- No commits made (per instructions).

## SUMMARY

| Check | Emulator (16 KB page, release) | Phone vivo V2427 (debuggable) |
|---|---|---|
| ORT session loads (crash point) | PASS — `images[1,3,224,224]`→`embeddings[1,512]`, 1.0–2.6 s | PASS (reached PhotoScreen) |
| Real inference, dim 512, finite | PASS, 203–589 ms | PASS, 89 / 157 ms |
| Reference-duplicate match | PASS → Binondo Church #1 | not the pushed file (picker chose user photos) |
| Held-out positive | PASS → Binondo Church #1 | — |
| Out-of-catalog → Not recognized | PASS | — |
| Raw cosine scores (ranking, not prob.) | not surfaced in release build | PASS — 0.36–0.68 across catalog |
| Airplane-mode offline | PASS (session + inference offline) | left as manual user step (no airplane toggle on wireless ADB) |
| New native crash | NONE (crash buffer empty; exit-info clean) | NONE (crash buffer empty) |
| Release `install -r` on phone | n/a | NOT RUN — phone wireless ADB dropped, pending user reconnect (not a signature error) |
| Memory | PSS ~219 MB / RSS ~330 MB (~4 GB emu, not a target) | PSS ~335 MB / RSS ~261 MB — **measured on 12 GB-class vivo V2427, NOT 8 GB** |

**Conclusion:** The R8/`NoSuchMethodError` SIGABRT at `OrtSession.getInputInfo` →
`NodeInfo.<init>` is RESOLVED. On the emulator the RELEASE build loads the OpenCLIP ONNX
session and runs real 512-d inferences (positive, held-out, offline, and
out-of-catalog→Not recognized) with no crash. On the physical phone the model loads and
runs real inferences (debuggable build) producing real 512-d embeddings and raw cosine
scores with no crash. Remaining to fully close on the PHONE specifically (NOT RUN — phone
wireless ADB dropped, pending user reconnect, not blocking this workflow): (1) `install -r`
the RELEASE APK and repeat the load+inference, and (2) a controlled reference-duplicate
parity run — both blocked only by the dropped wireless ADB, not by the model. The manifest
`android_verified` flag STAYS `false` until the RELEASE build is confirmed on the physical
phone; nothing here claims verified Android inference beyond what was measured.

