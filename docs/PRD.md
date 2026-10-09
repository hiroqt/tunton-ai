# PRD — TUNTON AI (Flutter, Local Vision, Offline Walking Navigation)

**Status:** MVP scope locked · **Event:** AppBuildersPH Hackathon 2026 · **Target:** Android Flutter application on a physical device · **Minimum design target:** 8 GB device RAM (requires measured verification) · **Pilot coverage:** Intramuros, Manila.

> **Product promise:** **Snap a supported landmark → recognize it with on-device AI → confirm it → choose a starting point → preview a real pedestrian route entirely offline.**

## 1. Problem, user, and value

A visitor has a photo of a landmark but doesn't know the landmark's name or where it is on a map. A cloud-only image search or online navigation service cannot be relied upon when connectivity is absent. TUNTON matches the photo against a **finite offline catalog of recognizable Intramuros landmarks**, displays the confirmed landmark on a **bundled offline map**, and computes a **walking route from a manually chosen start point** over a locally stored pedestrian network.

**Primary user:** Visitor in the pilot area with a photo of a known local landmark and an Android phone.

**Crucial limitation:** A recognized landmark gives the location **of the landmark depicted**, **not necessarily the photographer's coordinates**. This is a route **preview**, not live position tracking or a guarantee that footways are currently open.

## 2. Exactly one supported user journey

1. Launch the installed Android app with internet disabled.
2. Take or choose a photograph.
3. Run **one** on-device TFLite image-embedding model.
4. Compare the resulting vector with precomputed local reference-photo embeddings.
5. Display **up to three different landmark candidates**, or **Not recognized**.
6. Require the user to confirm a candidate, which becomes the destination.
7. Display the verified destination marker on the bundled Intramuros map.
8. User manually selects a known, graph-backed start point within the pilot map.
9. Run on-device Dijkstra shortest-path search along actual pedestrian graph edges.
10. Show path geometry, graph distance, and a walking ETA at the documented default of **4.5 km/h**. If no path is available, show **Route unavailable**.

## 3. P0 functional requirements and acceptance criteria

| ID | Requirement | Verifiable result |
|---|---|---|
| P0-01 | Capture / choose photo | Valid image is passed to local inference; unreadable images show a clear error. |
| P0-02 | Run on-device visual model | Single packaged MobileNetV3 Small **image embedder** TFLite checkpoint executes on physical Android without network calls. |
| P0-03 | Match supported landmarks | Inference vector compared with matching, precomputed local embeddings; results represent max. **3 distinct** landmarks. |
| P0-04 | Handle uncertainty | Unknown/ambiguous input can yield **Not recognized**; no invented GPS or fake confidence percentage. |
| P0-05 | Confirm a destination | No route destination is chosen unless the user confirms a candidate. |
| P0-06 | Load offline map | Bundled raster tiles show Intramuros and POI markers in airplane mode; no network basemap fallback. |
| P0-07 | Select origin manually | Start point chosen from supported mapped, graph-backed points; no live GPS prerequisite. |
| P0-08 | Resolve correct coordinates | Confirmed landmark's verified coordinates and route node come only from packaged landmark catalog. |
| P0-09 | Route by pedestrian network | Use actual connected pedestrian edges and edge geometry, never a straight-line substitute. |
| P0-10 | Show path, length, ETA | Display route on map, sum actual edge distances, label time as estimate. |
| P0-11 | Fully offline operation | Airplane-mode **cold launch** completes P0-01 through P0-10 without a laptop or server. |
| P0-12 | Fail visibly and safely | Invalid image, missing model/index/tiles, unknown landmark, out-of-coverage and disconnected path give truthful errors. |

**Demo dataset:** Begin with **six verified Intramuros landmarks**, approximately **3–5 appropriately licensed reference photographs each**, and **separate held-out test photographs**. A model that only matches an identical reference photo does not establish sufficient recognition quality.

## 4. Model choice: one model, not two running together

**Approved P0 model:** Google MediaPipe **MobileNetV3 Small Image Embedder**, packaged as `assets/models/landmark_embedder.tflite`. A generic 1,000-class MobileNet classifier is not an interchangeable image embedder.

- Official model guide: https://developers.google.com/edge/mediapipe/solutions/vision/image_embedder
- Published checkpoint: https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite
- Inference: `tflite_flutter` on the **phone**, with checked input/output tensor types, shape, preprocessing and normalization.

**Documented evaluation candidate, NOT a P0 dependency:** Community-converted **MobileCLIP-S1 TFLite** from https://huggingface.co/anton96vice/mobileclip2_tflite (file: `mobileclip_s1_datacompdr_last.tflite`). It is **not** Apple's official MobileCLIP2-S0 checkpoint; Apple's official https://huggingface.co/apple/MobileCLIP2-S0 file is PyTorch (`.pt`), not directly loadable by `tflite_flutter`.

**Model-switch rule:** Use MobileCLIP **only if** the team explicitly approves replacing MobileNetV3 after a failed landmark accuracy check, verifies the TFLite image-embedding output and preprocessing on Android, updates all model references, and **rebuilds every saved reference embedding**. Do **not** bundle or run both. The existing MobileNetV3 scope stays unchanged until approval.

**No Gemma, GLM, Qwen, OCR, or other LLM/VLM** in this MVP: image-to-image matching is the required local AI capability.

## 5. Constraints and quality requirements

- **Device-local runtime:** All inference, reference lookup, map rendering and routing run in the installed Flutter Android app, using bundled assets. No FastAPI, localhost server, cloud geocoder, mapping API, external ML endpoint, account, telemetry, or remote database.
- **8 GB device RAM:** Optimize for an 8 GB Android phone; run one inference at a time, load one interpreter, store short landmark vectors, don't decode every reference photo simultaneously. **Measure**, don't assume compatibility.
- **Map correctness:** Verified POI coordinates and a connected pedestrian graph covering the same Intramuros pilot region. Preserve edge geometry and directed-edge semantics when present. Attribution **© OpenStreetMap contributors** and legal map/image redistribution requirements apply. Do not bulk-download prohibited public OSM tiles for packaging.
- **User trust:** Candidate similarity is not calibrated location probability. Unknown is an acceptable result. Current gate/accessibility/road closure conditions are not known offline.
- **Release proof:** Install a release APK, disconnect connectivity, cold-launch, recognize an unseen supported photo, confirm, manually select start, calculate a genuine path, and record latency/memory and failures.

## 6. Out of scope — reject even if easy

- Arbitrary worldwide or Metro Manila street-scene geolocation; landmark recognition outside the packaged catalog.
- Live device GPS, EXIF-based positioning, automatic rerouting, voice or turn-by-turn guidance, traffic, road safety prediction, cycling or driving.
- OCR/sign recognition, chatbots, Gemma/Qwen/GLM or another LLM, custom model training, multiple simultaneous vision models, download-on-demand maps.
- Server components, user accounts, databases beyond bundled files, syncing, dashboards, search beyond fixed landmarks, additional geographic packs, iOS-specific demo work.
- Decorative extra screens or speculative framework / directory scaffolds for unapproved future features.

## 7. Minimal screens and failure states

| Screen | Allowed user controls | Required result |
|---|---|---|
| Photo | Take / Choose / Retry | Image preview, inference loading or invalid-image message |
| Recognition | See up to 3 candidates; confirm / retry | Clear candidate or **Not recognized** state |
| Offline map | View marker; choose fixed manual start | Verified destination and graph-backed origin shown |
| Navigation | View route / choose another supported start | Polyline, distance, ETA, or **Route unavailable** |

## 8. Benchmark and demo checklist

- [ ] Model produces a real embedding through TFLite **on Android**.
- [ ] Reference vectors came from the **same model, same preprocessing, same output dimension**.
- [ ] Supported held-out photo produces a sensible ranked candidate.
- [ ] Out-of-catalog photo can be rejected; ambiguous photos request user confirmation.
- [ ] Offline map, labels and landmark markers load from packaged data.
- [ ] Walking path follows verified network geometry; distance/ETA calculated from it.
- [ ] Airplane-mode cold launch reproduces the end-to-end flow without a Mac connected.
- [ ] Record actual inference latency, route latency and peak memory on the lowest tested device; never invent benchmark values.
- [ ] Prepare a short video, public repository, and disclose models, frameworks, API usage (including **none**), pre-existing assets/code and AI coding tools, as requested in the event briefing.

## 9. Delivery schedule and event gate

The official briefing describes a 24-hour event beginning Oct 9 and a **10:00 AM Oct 10** code/submission cutoff; do not mistake Demo Day presentation time for more development time. Build the pipeline first; reserve the final period before submission for device testing, an offline run, disclosures, and video. Demo format is **5-minute pitch/live demo + 3-minute Q&A**.

**Strict priority:** Valid image → actual TFLite embedding → actual photo match → verified location → rendered offline map → real connected walking route → airplane-mode proof. If a required piece is blocked, document the blocker; never simulate its result as real.

## 10. Related governing files

- `ARD.md` — exact implementation contracts and approved technologies/files.
- `ARCHITECTURE.md` — one-runtime topology and integration/data flow.
- `AGENTS.md` — change-control and coding-agent constraints.
- `SETUP.md` — developer install and asset preparation workflow.
- `TECH_STACK.md` — approved dependency rationales.
- `SKILL.md` — execution and validation steps for coding agents.

**Authority:** This `PRD.md` defines the product boundary. Changes to requirements require an explicit user/team decision, not autonomous agent interpretation.
