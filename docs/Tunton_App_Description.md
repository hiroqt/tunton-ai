# TUNTON App Description

**Tagline:** Snap a Landmark. Find Your Way. **Product target:** Android-first Flutter app with recognition for named Manila, Makati, and Pasay POIs; route preview remains Intramuros-only.

## App description

TUNTON helps an Android visitor identify a supported named landmark or place in Manila, Makati, or Pasay from a photograph using OpenCLIP ViT-B/32 on-device through native Android ONNX Runtime. It compares the output with local reference embeddings and asks the user to confirm a candidate. Only Intramuros destinations continue to the existing map and Dart walking-route preview; other areas are recognition-only. The expanded city catalog still requires verified coordinates, 3–5 openly licensed images, and held-out examples per POI.

The route is a static-data preview. Recognizing a landmark identifies the photographed place; it does not establish the photographer's location. TUNTON does not claim current gate access, closures, or live turn-by-turn guidance.

## P0 user journey

1. Open the installed Android app while connected and download the Mapbox style/Intramuros region; wait for the SDK to confirm completion.
2. Enable airplane mode and cold-launch the app.
3. Take or choose one photo.
4. Run local OpenCLIP image preprocessing and native Android ONNX inference.
5. Show up to three distinct landmark candidates or **Not recognized**.
6. Require confirmation before setting the destination.
7. Show the destination on the Mapbox offline map.
8. Let the user choose a valid manual start point or explicitly request a GPS start snapped to the nearest graph node.
9. Compute and preview a real connected walking path, its graph distance, and estimated ETA; show **Route unavailable** when no path exists.

## Product boundaries

- Android release APK; one Intramuros data pack.
- One bundled OpenCLIP ViT-B/32 LAION-2B image tower, exported to dynamically quantized ONNX.
- Landmark catalog, reference vectors, and pedestrian graph are bundled read-only assets. Mapbox map data is downloaded through the SDK and stored in its private offline store; it is not bundled or redistributed.
- Recognition and route calculation work locally. Map display works offline after the region download; first setup requires internet and a scoped public Mapbox token.
- No EXIF positioning, background GPS, saved places, user accounts, photo uploads, app-owned analytics, online routing, OCR, or second AI model. Foreground GPS is optional, stays on the device, and does not reroute. The Mapbox SDK may send de-identified usage/location telemetry under its terms; keep its attribution control and opt-out visible.
- The 8 GB RAM device is a design target; compatibility is not proven without measurement.

## Short description

TUNTON recognizes supported named POIs across Manila, Makati, and Pasay from a photo using on-device OpenCLIP. Intramuros destinations can continue to an offline walking-route preview from a manual or GPS-snapped start point. A GPS snap connector is approximate and may not be walkable.

## Hackathon pitch

**A landmark photo can become an offline route.** TUNTON matches a visitor's photo on Android, asks them to confirm the place, and offers the existing Intramuros walking-path preview without sending photos to a cloud service. Recognition outside Intramuros does not imply routing coverage.

## Documentation authority

This description is a concise product summary. [`PRD.md`](PRD.md) remains authoritative for scope and acceptance; see [`SDD.md`](SDD.md) for the Android system design. The current checkout's implementation status is in [`DEVELOPMENT_MAP.md`](DEVELOPMENT_MAP.md).
