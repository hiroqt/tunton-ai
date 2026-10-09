# PRD — TUNTON AI (Flutter, Local Vision, Offline Walking Navigation)

**Status:** Approved scope update, 2026-10-10 · **Target:** Android Flutter application on a physical device · **Minimum design target:** 8 GB device RAM (requires measured verification) · **Recognition coverage:** named POIs in Manila, Makati, and Pasay · **Routing coverage:** Intramuros only.

> **Product promise:** **Download the fixed Mapbox region once while connected → recognize and confirm a supported landmark → choose a manual start or opt in to GPS snapping → preview an Intramuros walking route offline.**

## 1. Problem, user, and value

A visitor has a photo of a named Philippine place but doesn't know its name. TUNTON matches it against a finite local catalog of named Manila, Makati, and Pasay POIs. Only Intramuros supports the existing map and walking route; recognition elsewhere ends at the confirmed place result.

**Primary user:** Visitor in the pilot area with a photo of a known local landmark and an Android phone.

**Crucial limitation:** A recognized landmark gives the location **of the landmark depicted**, **not the photographer's coordinates**. GPS is an optional, explicit source for the route origin only. It is not inferred from the photo. GPS is used only in the foreground; manual graph-backed start selection remains available. The route is a preview, not a guarantee that footways are currently open.

## 2. Exactly one supported user journey

1. While connected, prepare the Intramuros offline map region in the installed Android app; after download completes, disable internet and cold-launch the app.
2. Take or choose a photograph.
3. Run **one** on-device OpenCLIP ViT-B/32 image encoder through native Android ONNX Runtime.
4. Compare the resulting vector with precomputed local reference-photo embeddings.
5. Display **up to three different landmark candidates**, or **Not recognized**.
6. Require the user to confirm a candidate. *(Scope change (user-approved) 2026-10-10: manual confirmation removed; the app now automatically accepts the single best match that passes the aggressive recognition gate — a sole candidate ≥ the strong-match threshold, or a top candidate that beats the runner-up by the margin. This supersedes the earlier "require confirmation" wording at the user's explicit request on 2026-10-10.)*
7. For a non-Intramuros POI, show its verified catalog identity and end the journey. For Intramuros, continue to the existing route flow.
8. User selects a known graph-backed start manually, or explicitly requests a current GPS fix that is snapped to the nearest Intramuros graph node. Permission or location failure leaves manual selection available.
9. Run on-device Dijkstra shortest-path search along actual pedestrian graph edges.
10. Show path geometry, graph distance, and a walking ETA at the documented default of **4.5 km/h**. If no path is available, show **Route unavailable**.

## 3. P0 functional requirements and acceptance criteria

| ID | Requirement | Verifiable result |
|---|---|---|
| P0-01 | Capture / choose photo | Valid image is passed to local inference; unreadable images show a clear error. |
| P0-02 | Run on-device visual model | Single packaged OpenCLIP ViT-B/32 LAION-2B image tower runs through native Android ONNX Runtime without network calls. |
| P0-03 | Match supported POIs | Inference vector compared with same-model, precomputed local embeddings for catalog POIs; results represent max. **3 distinct** POIs. |
| P0-04 | Handle uncertainty | Unknown/ambiguous input can yield **Not recognized**; no invented GPS or fake confidence percentage. |
| P0-05 | Confirm a destination | No route destination is chosen unless the user confirms a candidate. *(Scope change (user-approved) 2026-10-10: superseded — the app automatically accepts the single best passing match; the manual confirmation step was removed at the user's explicit request on 2026-10-10.)* |
| P0-06 | Prepare and load Mapbox offline map | While connected, download the Mapbox style and fixed Intramuros region through the SDK. After download completes, the map and POI markers render in airplane mode from SDK-managed local storage; no network basemap fallback. Mapbox map data is not bundled or redistributed in the APK. |
| P0-07 | Select a graph-backed origin | User can choose a mapped start manually or opt in to GPS; GPS is snapped to the nearest Intramuros graph node and never used as a destination. |
| P0-08 | Resolve correct coordinates | Confirmed landmark's verified coordinates and route node come only from packaged landmark catalog. |
| P0-09 | Route by pedestrian network | The walking path uses actual connected pedestrian edges and geometry. For GPS starts, show the direct GPS-to-node connector as an approximate snap segment, not as verified walkable geometry. |
| P0-10 | Show path, length, ETA | Display graph distance plus any GPS snap distance and label total distance/time as estimates; disclose that the snap segment may not be walkable. |
| P0-11 | Offline operation after map preparation | After the Mapbox region is fully downloaded, airplane-mode **cold launch** completes P0-01 through P0-10 without a laptop or server. |
| P0-12 | Fail visibly and safely | Invalid image, missing model/index, incomplete/unavailable Mapbox offline region, unknown landmark, out-of-coverage and disconnected path give truthful errors. |

**Dataset:** Use specifically named POIs from the user-provided Manila, Makati, and Pasay list. Keep ambiguous district/event entries out until precisely identified. Each POI needs verified coordinates, 3–5 openly licensed references, and separate held-out inputs. Recognition coverage does not imply map or routing coverage.

## 4. Model choice: one model, not two running together

**Approved P0 model:** OpenCLIP `ViT-B-32` with pretrained tag `laion2b_s34b_b79k`. Package the exported image encoder as ONNX at `assets/models/openclip_vit_b32_laion2b_int8.onnx`; use native Android ONNX Runtime via a Flutter platform channel. Exporting and reference-index generation use the pinned OpenCLIP checkpoint and the exact model-provided image transforms. The full text encoder and tokenizer are not packaged.

**No Gemma, GLM, Qwen, OCR, or other LLM/VLM** in this MVP: image-to-image matching is the required local AI capability.

## 5. Constraints and quality requirements

- **Device-local runtime:** Inference uses native ONNX Runtime in the installed Flutter Android app; Dart performs local matching and existing Intramuros routing. There is no FastAPI/localhost service, cloud inference, geocoder, account, analytics, or remote database. Existing map behavior is unchanged.
- **8 GB device RAM:** Optimize for an 8 GB Android phone; run one inference at a time, load one interpreter, store short landmark vectors, don't decode every reference photo simultaneously. **Measure**, don't assume compatibility.
- **Map correctness:** Verified POI coordinates and a connected pedestrian graph covering the same Intramuros pilot region. Preserve edge geometry and directed-edge semantics when present. Use Mapbox's SDK-managed offline region; keep its attribution control visible. The pedestrian graph remains OSM-derived and must show **© OpenStreetMap contributors**. Do not bundle or redistribute Mapbox map data or fetch public OSM raster tiles.
- **User trust:** Candidate similarity is not calibrated location probability. Unknown is an acceptable result. Current gate/accessibility/road closure conditions are not known offline.
- **Release proof:** Install a release APK, disconnect connectivity, cold-launch, recognize an unseen supported photo, confirm, use a manual or GPS-snapped start, calculate a genuine graph path, and record latency/memory and failures.

## 6. Out of scope — reject even if easy

- Arbitrary worldwide or Metro Manila street-scene geolocation; landmark recognition outside the packaged catalog.
- EXIF-based positioning, background GPS tracking, automatic rerouting, voice or turn-by-turn guidance, traffic, road safety prediction, cycling or driving. Foreground GPS is limited to an explicit start selection and location display; it never reroutes.
- OCR/sign recognition, chatbots, Gemma/Qwen/GLM or another LLM, custom model training, multiple simultaneous vision models, additional/user-selected downloadable map regions.
- Server components, user accounts, databases beyond bundled files, syncing, dashboards, search beyond fixed landmarks, additional geographic packs, iOS-specific demo work. The single fixed Mapbox region download required by P0-06 is in scope.
- Decorative extra screens or speculative framework / directory scaffolds for unapproved future features.

## 7. Minimal screens and failure states

| Screen | Allowed user controls | Required result |
|---|---|---|
| Photo | Take / Choose / Retry | Image preview, inference loading or invalid-image message |
| Recognition | Retry only — the single best passing match is accepted automatically | Auto-selected match card or **Not recognized** state *(Scope change (user-approved) 2026-10-10: manual candidate selection and the Confirm step were removed in favor of automatic single-best acceptance, superseding "see up to 3 candidates; confirm".)* |
| Offline map | Download fixed Mapbox region while connected; view marker; choose manual or optional GPS-snapped start | Download completion is confirmed before offline use; verified destination and graph-backed origin shown; approximate GPS connector disclosed |
| Navigation | View route / choose another supported start | Polyline, distance, ETA, or **Route unavailable** |

## 8. Benchmark and demo checklist

- [ ] Model produces a real embedding through ONNX Runtime **on physical Android**.
- [ ] Reference vectors came from the **same model, same preprocessing, same output dimension**.
- [ ] Supported held-out photo produces a sensible ranked candidate.
- [ ] Out-of-catalog photo can be rejected; ambiguous photos request user confirmation.
- [ ] Mapbox style and Intramuros region download completes while connected; map, labels and markers render after airplane-mode cold launch.
- [ ] Walking path follows verified network geometry; distance/ETA calculated from it.
- [ ] Airplane-mode cold launch reproduces the end-to-end flow without a Mac connected.
- [ ] Record actual inference latency, route latency and peak memory on the lowest tested device; never invent benchmark values.
- [ ] Prepare a short video, public repository, and disclose models, frameworks, Mapbox SDK/API usage, pre-existing assets/code and AI coding tools, as requested in the event briefing.

## 9. Delivery schedule and event gate

The official briefing describes a 24-hour event beginning Oct 9 and a **10:00 AM Oct 10** code/submission cutoff; do not mistake Demo Day presentation time for more development time. Build the pipeline first; reserve the final period before submission for device testing, an offline run, disclosures, and video. Demo format is **5-minute pitch/live demo + 3-minute Q&A**.

**Strict priority:** Valid image → actual native ONNX embedding → actual photo match → verified location → for Intramuros only, existing map and real walking route → device proof. If a required piece is blocked, document the blocker; never simulate its result as real.

## 10. Related governing files

- `ARD.md` — exact implementation contracts and approved technologies/files.
- `ARCHITECTURE.md` — one-runtime topology and integration/data flow.
- `AGENTS.md` — change-control and coding-agent constraints.
- `SETUP.md` — developer install and asset preparation workflow.
- `TECH_STACK.md` — approved dependency rationales.
- `SKILL.md` — execution and validation steps for coding agents.

**Authority:** This `PRD.md` defines the product boundary. Changes to requirements require an explicit user/team decision, not autonomous agent interpretation.
