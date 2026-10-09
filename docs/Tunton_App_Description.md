# TUNTON App Description

**Tagline:** Snap a Landmark. Find Your Way. **Product target:** Android-first Flutter MVP for Intramuros, Manila.

## App description

TUNTON helps an Android visitor identify one of six supported Intramuros landmarks from a photograph and preview a walking route to it. Before going offline, the user downloads the fixed Mapbox style and Intramuros region through the Mapbox Flutter SDK. One MobileNetV3 Small image embedder runs on the phone. TUNTON compares its output with bundled reference embeddings, asks the user to confirm a candidate, then displays the verified destination on the Mapbox offline map. The user manually selects a graph-backed starting point, and the app computes a walking route over its packaged pedestrian graph.

The route is a static-data preview. Recognizing a landmark identifies the photographed place; it does not establish the photographer's location. TUNTON does not claim current gate access, closures, or live turn-by-turn guidance.

## P0 user journey

1. Open the installed Android app while connected and download the Mapbox style/Intramuros region; wait for the SDK to confirm completion.
2. Enable airplane mode and cold-launch the app.
3. Take or choose one photo.
4. Run local image preprocessing and on-device TFLite inference.
5. Show up to three distinct landmark candidates or **Not recognized**.
6. Require confirmation before setting the destination.
7. Show the destination on the Mapbox offline map.
8. Let the user choose a valid manual start point.
9. Compute and preview a real connected walking path, its graph distance, and estimated ETA; show **Route unavailable** when no path exists.

## Product boundaries

- Android release APK; one Intramuros data pack.
- One bundled Google MediaPipe MobileNetV3 Small image embedder.
- Landmark catalog, reference vectors, and pedestrian graph are bundled read-only assets. Mapbox map data is downloaded through the SDK and stored in its private offline store; it is not bundled or redistributed.
- Recognition and route calculation work locally. Map display works offline after the region download; first setup requires internet and a scoped public Mapbox token.
- No GPS/EXIF location, saved places, user accounts, photo uploads, app-owned analytics, online routing, OCR, or second AI model. The Mapbox SDK may send de-identified usage/location telemetry under its terms; keep its attribution control and opt-out visible.
- The 8 GB RAM device is a design target; compatibility is not proven without measurement.

## Short description

TUNTON recognizes supported Intramuros landmarks from a photo using on-device AI, then previews an offline walking route from a manually selected starting point.

## Hackathon pitch

**A landmark photo can become an offline route.** After a one-time Mapbox region download, TUNTON matches a visitor's photo on the Android device, asks them to confirm the place, and previews a real walking path using the SDK-managed offline map and bundled pedestrian data—without sending the photo to a cloud service.

## Documentation authority

This description is a concise product summary. [`PRD.md`](PRD.md) remains authoritative for scope and acceptance; see [`SDD.md`](SDD.md) for the Android system design. The current checkout's implementation status is in [`DEVELOPMENT_MAP.md`](DEVELOPMENT_MAP.md).
