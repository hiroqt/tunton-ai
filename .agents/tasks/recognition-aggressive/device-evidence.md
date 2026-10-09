# On-device check — aggressive rejection + automatic recognition

**Scope of this document:** ON-DEVICE check on the ONLINE EMULATOR ONLY. The
physical phone was **not** touched (its wireless ADB install conflict is a
separate, unresolved task). All results below are real captures from the
running app via `[TUNTON_RECOG]` debug logcat and on-screen UI dumps — nothing
here is synthesized or assumed. `android_verified` remains **false**; this is
emulator evidence, not a "verified on Android" claim.

## Environment

| Item | Value |
|---|---|
| Device | `emulator-5554` (online emulator) |
| Model | `sdk_gphone16k_arm64` |
| Android | release 17, SDK 37 |
| ABI | `arm64-v8a` |
| Flutter | 3.44.8 stable |
| App id / activity | `com.example.tuntun` / `.MainActivity` |
| Build | fresh **DEBUG** build (`flutter build apk --debug`) installed with `adb -s emulator-5554 install -r` → `Success` |
| adb | `/Users/arnel/Library/Android/sdk/platform-tools/adb` |
| Embedding dim (observed every run) | **512** |

Flow driven through the real app: push image → `/sdcard/Pictures/` →
media-scan → launch app → "Choose from gallery" → Android photo picker
(`com.google.android.photopicker`) → tap thumbnail → **Done** → "Find the
landmark". Thumbnails selected via `uiautomator dump` + `input tap`. The modern
photo picker is multi-select, so each selection required an explicit **Done**
tap after the thumbnail tap.

Thresholds in the installed build (from `landmark_matcher.dart`):
`scoreThreshold=0.40`, `minTopMargin=0.07`, `strongMatchThreshold=0.55`.

---

## Case (a) — reference-DUPLICATE image AUTO-advances, no manual selection

**Image:** `assets/images/fort-santiago/1.png` pushed to
`/sdcard/Pictures/tunton_refdup_fortsantiago.png`. This is a **reference
duplicate** (byte-for-byte one of the packaged reference images that produced a
stored embedding), **NOT a held-out photo**. Loaded in-app as
`photo_ready source=gallery bytes=1404038 dimensions=819x1024` (byte count
matches the pushed file exactly).

Real recognition log:

```
[TUNTON_RECOG] preprocess_ms=279 inference_ms=294 embedding_dim=512
[TUNTON_RECOG] landmark=fort-santiago       best_cosine=0.9908 accepted=true
[TUNTON_RECOG] landmark=puerta-real         best_cosine=0.6877 accepted=true
[TUNTON_RECOG] landmark=san-agustin         best_cosine=0.5979 accepted=true
[TUNTON_RECOG] landmark=casa-manila         best_cosine=0.5823 accepted=true
[TUNTON_RECOG] landmark=manila-cathedral    best_cosine=0.5500 accepted=true
[TUNTON_RECOG] landmark=binondo-church      best_cosine=0.5459 accepted=true
[TUNTON_RECOG] landmark=far-eastern-university best_cosine=0.5432 accepted=true
[TUNTON_RECOG] landmark=baluarte-san-diego  best_cosine=0.5155 accepted=true
[TUNTON_RECOG] landmark=up-manila           best_cosine=0.5055 accepted=true
[TUNTON_RECOG] landmark=rizal-park          best_cosine=0.4984 accepted=true
[TUNTON_RECOG] landmark=quiapo-church       best_cosine=0.4450 accepted=true
[TUNTON_RECOG] landmark=dlsu-manila         best_cosine=0.4257 accepted=true
[TUNTON_RECOG] landmark=sm-city-manila      best_cosine=0.3696 accepted=false
[TUNTON_RECOG] landmark=robinsons-place-manila best_cosine=0.3399 accepted=false
[TUNTON_RECOG] landmark=lucky-chinatown-mall best_cosine=0.3148 accepted=false
[TUNTON_RECOG] ACCEPT gate=accept_margin_ok candidates=fort-santiago,puerta-real,san-agustin margin=0.3031>=0.07 threshold=0.40
[TUNTON_RECOG] result=matched count=3 total_ms=589
```

- **Gate that decided:** `accept_margin_ok` (top1 fort-santiago 0.9908,
  top2 puerta-real 0.6877, margin 0.3031 ≥ 0.07).
- **Deciding cosine:** fort-santiago **0.9908** (near-identity, as expected for
  a reference duplicate).
- **UI result:** the recognition screen **auto-advanced with no manual
  selection, no candidate list, no Confirm tap** — the next screen captured was
  **"Step 3 of 4: Start"** with `DESTINATION = Fort Santiago`. The automatic
  advance (`WidgetsBinding.addPostFrameCallback` → `onConfirm`) fired on its
  own.
- Re-ran the same selection a second time → identical cosines and
  `result=matched count=3 total_ms=628` (reproducible).

**Conclusion (a): CONFIRMED.** A genuine catalog reference-duplicate image
automatically advances to that landmark with no manual selection.

> Note (unrelated to recognition): on the Start/Map screen the debug build
> logged `Unable to load asset: assets/tiles/.../*.png — Asset not found`. That
> is the offline-map tile concern, a separate task, not part of this recognition
> check.

---

## Case (b) — out-of-catalog / weak image reads "Not recognized" under the aggressive gate

Three non-landmark test images were used to drive the gate. These are
**build-time test artifacts only** (generated locally, pushed to the emulator,
and deleted afterward — never shipped as assets):
`tunton_synth_noise.png` (random RGB noise, 788096 B),
`tunton_synth_blue.png` (blue sky-like gradient, 1994 B),
`tunton_synth_tan.png` (solid tan, 1881 B). Each loaded as 512×512.

### b1 — lone-candidate leak case REPRODUCED and now REJECTED (noise image)

This is the previously-leaking **lone-candidate** path (an image that weakly
matches exactly ONE landmark above the 0.40 floor, with no runner-up to trip the
margin gate — the ~0.49 single-match that used to leak through as a confident
#1). Loaded as `photo_ready bytes=788096 dimensions=512x512`.

```
[TUNTON_RECOG] preprocess_ms=80 inference_ms=230 embedding_dim=512
[TUNTON_RECOG] landmark=up-manila           best_cosine=0.4585 accepted=true
[TUNTON_RECOG] landmark=sm-city-manila      best_cosine=0.3591 accepted=false
[TUNTON_RECOG] landmark=rizal-park          best_cosine=0.3578 accepted=false
[TUNTON_RECOG] landmark=quiapo-church ... far-eastern-university ... (all others 0.18–0.36, accepted=false)
[TUNTON_RECOG] REJECT gate=lone_below_strong top1=up-manila(0.4585) < strongMatchThreshold=0.55 => Not recognized
[TUNTON_RECOG] result=not_recognized count=0 total_ms=312
```

- **Only one landmark cleared 0.40** (up-manila at **0.4585**) — exactly the
  lone-candidate shape that previously leaked. 0.4585 sits in the old leak band
  (≈0.49 reported earlier; here 0.46).
- **Gate that decided:** `lone_below_strong` — 0.4585 < strongMatchThreshold
  0.55 → **rejected**.
- **UI result:** recognition screen showed **"Not recognized — This photo did
  not match a supported landmark. Try a clearer view or another photo."** (Step
  2 of 4), with a "Try another photo" button. No auto-advance to any landmark.

### b2 — lone-candidate rejection REPRODUCED again (tan solid image)

```
[TUNTON_RECOG] landmark=up-manila best_cosine=0.4665 accepted=true
...(all other landmarks < 0.40, accepted=false)...
[TUNTON_RECOG] REJECT gate=lone_below_strong top1=up-manila(0.4665) < strongMatchThreshold=0.55 => Not recognized
[TUNTON_RECOG] result=not_recognized count=0 total_ms=333
```

- Lone candidate up-manila **0.4665** → `lone_below_strong` → **Not
  recognized**. On-screen "Not recognized" card confirmed via screenshot.

**Conclusion (b): CONFIRMED.** Out-of-catalog / weak images that produce a lone
0.40–0.55 match (the previously-leaking case, reproduced at 0.4585 and 0.4665)
are now REJECTED by the `lone_below_strong` gate and the app shows "Not
recognized" with no auto-advance.

---

## Honest edge-case finding — the margin gate still admitted a synthetic two-weak-match image

The blue sky-gradient image (`tunton_synth_blue.png`, 1994 B, loaded 512×512)
did **not** read "Not recognized". It produced **two** above-floor candidates:

```
[TUNTON_RECOG] landmark=up-manila  best_cosine=0.4905 accepted=true
[TUNTON_RECOG] landmark=rizal-park best_cosine=0.4143 accepted=true
...(all other landmarks < 0.40)...
[TUNTON_RECOG] ACCEPT gate=accept_margin_ok candidates=up-manila,rizal-park margin=0.0761>=0.07 threshold=0.40
[TUNTON_RECOG] result=matched count=2 total_ms=559
```

- top1 up-manila 0.4905, top2 rizal-park 0.4143, **margin 0.0761 ≥ 0.07** →
  `accept_margin_ok` → auto-advanced to **"University of the Philippines
  Manila"** (a recognition-only, non-routable POI, so it showed the recognition
  confirmation rather than a route).

This is reported truthfully, not hidden: for a synthetic sky-colored input, two
weak matches both cleared the 0.40 floor and their gap just exceeded the 0.07
margin, so the margin path accepted it. The **required** lone-candidate leak IS
closed (b1/b2), but the two-weak-candidate margin path can still admit an
adversarial synthetic image whose two best scores happen to sit ~0.08 apart.
Flagging for a product decision — no code was changed in this check.

---

## Summary table

| Image (label) | Loaded bytes | Deciding cosine(s) | Gate | App result |
|---|---|---|---|---|
| fort-santiago/1.png (**reference duplicate**) | 1404038 | fort-santiago 0.9908, margin 0.3031 | `accept_margin_ok` | auto-advance → Fort Santiago (Start screen), no manual selection |
| noise (synthetic test artifact) | 788096 | up-manila 0.4585 (lone) | `lone_below_strong` | **Not recognized** |
| tan solid (synthetic test artifact) | 1881 | up-manila 0.4665 (lone) | `lone_below_strong` | **Not recognized** |
| blue gradient (synthetic test artifact) | 1994 | up-manila 0.4905 / rizal-park 0.4143, margin 0.0761 | `accept_margin_ok` | auto-advanced → UP Manila (honest edge case) |

- Embedding dimension observed on every run: **512**.
- `android_verified` kept **false**. Emulator evidence only; the physical phone
  was not touched.

## Cleanup

All pushed test photos removed from the emulator and media-scanned:
`tunton_refdup_fortsantiago.png`, `tunton_synth_noise.png`,
`tunton_synth_gray.png`, `tunton_synth_blue.png`, `tunton_synth_tan.png`.
Verified: `ls /sdcard/Pictures/ | grep tunton` → none remain. Temporary
`uiautomator`/screenshot dumps on the device were also removed. Local synthetic
test images under `/tmp` are not part of the repo and were never added as
assets.
