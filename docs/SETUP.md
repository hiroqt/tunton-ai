# TUNTON AI setup and verification

**Scope:** Local photo → OpenCLIP ViT-B/32 image embedding on Android → top 3 named Manila/Makati/Pasay POIs → confirmation. Only Intramuros continues to existing map/routing. No OCR, FastAPI, phone-local HTTP server, or new map packs.

## Developer setup

Install Flutter/Dart, Android Studio and Android Platform Tools using their official guides. Use the project Python 3.12 virtual environment only for model export and dataset preparation; Python is not shipped to Android.

The preparation tool requires pinned versions of `open_clip_torch`, PyTorch, ONNX, ONNX Runtime, NumPy, Pillow and OSMnx. Install from the versions recorded in `docs/TUNTON_BACKEND_STRUCTURE.md`. Keep model weights in the Hugging Face cache or another ignored preparation cache; do not commit the original training checkpoint.

## Model export contract

Checkpoint: OpenCLIP model name `ViT-B-32`, pretrained tag `laion2b_s34b_b79k`. Use OpenCLIP's model-provided transform for that tag, not a generic CLIP mean/std. Export only the image tower with fixed batch size 1 to:

```text
assets/models/openclip_vit_b32_laion2b_int8.onnx
```

The export manifest must record checkpoint tag, source checkpoint checksum, ONNX checksum, exporter and opset versions, input/output tensor names/shapes/types, output dimension, resize/crop/interpolation/channel order, mean/std and normalization. Host validation compares ONNX Runtime output against `model.encode_image` on the identical normalized tensor. Android then validates finite output and the same tensor contract before packaging is accepted.

## Dataset preparation

Keep named, verified POIs in `assets/landmarks/landmarks.json`. Each record has unique `id`, exact `name`, `area_id`, `lat`, and `lon`. `route_node_id` is optional and allowed only for currently graph-backed Intramuros destinations. Other Manila, Makati, and Pasay entries are recognition-only.

Each POI needs 3–5 openly licensed reference photos. Keep held-out and unknown photos in `test/datasets/`, never in the APK. Every photo needs source/page/download URLs, author, explicit license and license URL, modifications, original/prepared SHA-256, split, POI ID when supported, and evidence that it depicts the stated Philippine place. Reject missing permissions, duplicate originals, cross-split leakage, invalid paths, corrupt or oversized files. Do not invent coordinates, sources, or vectors.

Run `tools/prepare_dataset.py` to validate the source manifest, prepare photos, export/reference vectors from the exact OpenCLIP model, validate area/route contracts, and evaluate held-out and unknown inputs. Keep score threshold decisions tied to the recorded evaluation set; similarity is not a probability. Do not overwrite existing outputs in place.

The existing OSMnx preparation remains limited to the Intramuros pedestrian graph. No graph or offline map data is created for the additional recognition areas.

## Android runtime

The Flutter service preprocesses one photo and sends the exact tensor to native Android via a MethodChannel. Kotlin loads one `onnxruntime-android` CPU session from the bundled ONNX asset, reuses it, and returns the feature vector. It does not open a socket, start FastAPI/Python, send photos over a network, or fall back to another model. The Dart matcher computes L2-normalized cosine scores, groups by POI, and returns up to three distinct IDs or Not recognized.

Failures (bad image/tensor, missing or mismatched model/index, inference errors, unverified candidate) must stay explicit. Logs may contain timing and failure class, never image bytes or embeddings.

## Checks

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Run the focused Python preparation self-check/evaluation from the repository environment. Then install the release APK on a physical Android phone, exercise a held-out supported image and an unknown image, and record model inference latency and peak memory. Verify 8 GB only on actual 8 GB hardware. An emulator build or host ONNX result is not physical-device proof. Existing map/offline checks apply only to Intramuros and are unchanged by recognition coverage.
