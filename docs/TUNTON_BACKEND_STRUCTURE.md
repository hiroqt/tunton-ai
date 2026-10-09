# TUNTON Vision and Data Preparation Pipeline

**Runtime boundary:** Python is developer-machine tooling only. The Flutter Android app has no FastAPI server, localhost listener, remote inference, OCR, or upload. Native Android ONNX Runtime performs on-device inference; Dart matches candidates and routes Intramuros destinations.

## Approved pipeline

```text
Sources manifest + licensed images + verified POI catalog
                 │
                 ▼
       tools/prepare_dataset.py
  validate paths, license/provenance, checksums and area data
  load OpenCLIP ViT-B-32 / laion2b_s34b_b79k
  export image-only ONNX graph and inspect its tensor contract
  prepare identical OpenCLIP image tensors
  create L2-normalized reference vectors from that graph/model
  evaluate distinct held-out/unknown photos
                 │
                 ▼
 Model ONNX + catalog + reference index + evaluation report
```

Only the ONNX image tower, verified POI catalog, and matching reference index are app assets. Original model weights, photos, source records, held-out images, unknown images, and parity inputs remain in preparation/evaluation storage. The existing OSMnx flow prepares only the Intramuros walk graph. Map data and route coverage do not expand.

## Model contract

- OpenCLIP `ViT-B-32`, pretrained `laion2b_s34b_b79k`.
- Model provided transform is the sole preprocessing authority; record image size, resize/crop, interpolation, RGB order, mean/std, tensor layout and version.
- Export image tower only, fixed batch size 1. Record ONNX opset, input/output names, dimensions and dtypes, export package versions, original checkpoint SHA-256 and ONNX SHA-256.
- Compare ONNX Runtime output to OpenCLIP `encode_image` output on deterministic, already-preprocessed tensors. Require finite vectors with the observed output dimension. L2-normalize in the common preparation/runtime matching boundary.
- Reference vectors may only be used with exactly the same model checksum and preprocessing contract. No confidence percentages or threshold guesses.

## Catalog and source requirements

Each item has globally unique `id`, canonical `name`, `area_id`, verified `lat`/`lon`, and optional `route_node_id`. Only graph-backed Intramuros POIs may have a route node. Manila, Makati, and Pasay POIs outside Intramuros are recognition-only.

Keep specifically named fixed POIs. Exclude generic districts, temporary markets/events, ambiguous labels such as “Hesed”, and unspecified boundary markers until the user identifies an exact place. Every reference image needs its exact POI label, source/page and download URLs, author, explicit redistribution license, license URL, modifications, SHA-256 for original/prepared bytes, and geographic evidence. Each POI needs 3–5 references plus separate held-out examples. Never fill unknown coordinates, licenses, images, or vectors with invented data.

## Environment and versioning

Python 3.12 in the repository's ignored `.venv`. Record/pin OpenCLIP, PyTorch, ONNX, ONNX Runtime, NumPy, Pillow and OSMnx versions in preparation output. These packages are not Android dependencies. Android uses only the Maven Central `onnxruntime-android` artifact configured in Gradle and the Flutter platform channel.

Stage generated outputs atomically and refuse to overwrite existing model/index/catalog files. Validate source paths against traversal, file sizes before decoding, checksums, duplicate original images, split leakage, reference IDs, finite vectors, model/index metadata equality, and route-node references. No catalog or reference-index write should occur until the full staged generation passes validation.

## Required proof

1. Exact OpenCLIP checkpoint loads and transform settings are captured.
2. Exported ONNX metadata and checksum are recorded; ONNX output matches host model output within a documented numerical tolerance.
3. Reference and held-out evaluation uses disjoint source images; report top-1/top-3 and unknown false-accept counts without claiming calibrated probabilities.
4. The Android app loads the exact ONNX bytes and returns a finite vector through the MethodChannel.
5. Physical device latency/memory and any 8 GB compatibility claims are measured separately. Host and emulator checks do not establish phone readiness.
