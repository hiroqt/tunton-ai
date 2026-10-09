#!/usr/bin/env python3
"""Prepare TUNTON's licensed photos, MobileNetV3 embeddings, and offline OSM assets."""
import argparse
import json
import math
import hashlib
import io
import sys
import time
import statistics
import os
import shutil
import tempfile
import urllib.request
from urllib.parse import urlparse
from pathlib import Path
from pathlib import PurePosixPath
MODEL_ID = 'bundled-mobilenetv3-small-embedder'
MODEL_SHA256 = 'bbbb4c51a55a53905af1daec995ca1aae355046f8839bb8c9f5ce9271394bc40'
MODEL_URL = 'https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite'

def checksum(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def dataset_path(root, relative):
    text(relative, 'dataset path')
    parsed = PurePosixPath(relative)
    if parsed.is_absolute() or '..' in parsed.parts or '\\' in relative or (parsed.as_posix() != relative):
        fail('dataset paths must be canonical relative paths')
    path = Path(root) / relative
    if not path.resolve().is_relative_to(Path(root).resolve()):
        fail('dataset path escapes root')
    return path

def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as target:
        temporary = Path(target.name)
        try:
            json.dump(value, target, indent=2, ensure_ascii=False, allow_nan=False)
            target.write('\n')
        except Exception:
            temporary.unlink(missing_ok=True)
            raise
    try:
        os.link(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)

def photo_sources(path):
    manifest = read_json(path)
    photos = manifest.get('photos') if isinstance(manifest, dict) else None
    if not isinstance(photos, list) or not photos:
        fail('source manifest must contain photos')
    seen_paths, seen_originals = (set(), set())
    for photo in photos:
        if not isinstance(photo, dict):
            fail('photo source must be an object')
        for key in ('path', 'page_url', 'download_url', 'author', 'license', 'license_url', 'sha256', 'original_sha256', 'modifications'):
            text(photo.get(key), 'photo ' + key)
        if photo.get('country') != 'PH':
            fail('every project photo must have verified Philippines (PH) provenance')
        text(photo.get('location'), 'photo Philippine location')
        evidence = photo.get('geographic_evidence')
        if not isinstance(evidence, dict):
            fail('photo requires geographic source evidence')
        text(evidence.get('url'), 'photo geographic evidence URL')
        text(evidence.get('basis'), 'photo geographic evidence basis')
        dataset_path('.', photo['path'])
        if photo.get('split') not in ('reference', 'held_out', 'unknown'):
            fail('invalid photo split')
        prefix = {'reference': 'assets/images/', 'held_out': 'test/datasets/held_out/', 'unknown': 'test/datasets/unknown/'}[photo['split']]
        if not photo['path'].startswith(prefix):
            fail('photo path does not match its dataset split')
        if photo['split'] == 'unknown':
            if photo.get('landmark_id') is not None:
                fail('unknown photos cannot have a supported landmark label')
        else:
            text(photo.get('landmark_id'), 'photo landmark_id')
        for key in ('sha256', 'original_sha256'):
            if len(photo[key]) != 64 or any((c not in '0123456789abcdef' for c in photo[key])):
                fail('photo checksums must be lowercase SHA-256')
        if photo['path'] in seen_paths or photo['original_sha256'] in seen_originals:
            fail('duplicate source photo or cross-split leakage')
        seen_paths.add(photo['path'])
        seen_originals.add(photo['original_sha256'])
    return photos

def image_tensor(path):
    """The same EXIF/RGB/floor-index resize and pixel scale as embedding_service.dart."""
    import numpy as np
    from PIL import Image, ImageOps
    path = Path(path)
    if path.stat().st_size > 20 * 1024 * 1024:
        fail('encoded image exceeds 20 MiB')
    with Image.open(path) as source:
        if source.width * source.height > 16000000:
            fail('decoded image exceeds 16 megapixels')
        rgb = np.asarray(ImageOps.exif_transpose(source).convert('RGB'))
    rows = np.arange(224) * rgb.shape[0] // 224
    columns = np.arange(224) * rgb.shape[1] // 224
    return (rgb[rows[:, None], columns[None, :]].astype(np.float32) / np.float32(255)).reshape(1, 224, 224, 3)

def load_embedder(path):
    import numpy as np
    from ai_edge_litert.interpreter import Interpreter
    if checksum(path) != MODEL_SHA256:
        fail('model checksum does not match the approved MobileNetV3 artifact')
    model = Interpreter(model_path=str(path), num_threads=1)
    model.allocate_tensors()
    inputs, outputs = (model.get_input_details(), model.get_output_details())
    if len(inputs) != 1 or len(outputs) != 1 or inputs[0]['shape'].tolist() != [1, 224, 224, 3] or (outputs[0]['shape'].tolist() != [1, 1024]) or (inputs[0]['dtype'] != np.float32) or (outputs[0]['dtype'] != np.float32):
        fail('model tensor contract differs from the inspected artifact')
    return model

def image_embedding(model, path):
    import numpy as np
    model.set_tensor(model.get_input_details()[0]['index'], image_tensor(path))
    model.invoke()
    vector = model.get_tensor(model.get_output_details()[0]['index']).reshape(-1).astype(np.float64)
    norm = np.linalg.norm(vector)
    if len(vector) != 1024 or not np.isfinite(vector).all() or (not math.isfinite(norm)) or (norm == 0):
        fail('inference produced an invalid embedding')
    return (vector / norm).tolist()

def verify_photos(photos, root):
    from PIL import Image
    for photo in photos:
        path = dataset_path(root, photo['path'])
        if checksum(path) != photo['sha256']:
            fail('photo checksum mismatch: ' + photo['path'])
        with Image.open(path) as image:
            if image.format != 'PNG' or image.mode != 'RGB' or max(image.size) > 1024:
                fail('prepared photo must be lossless RGB PNG, at most 1024 pixels per side')
            for key, field in (('Author', 'author'), ('Source', 'page_url'), ('License', 'license'), ('LicenseURL', 'license_url'), ('Modifications', 'modifications')):
                if image.info.get(key) != photo[field]:
                    fail('prepared photo is missing matching embedded attribution: ' + photo['path'])

def create_index(root, sources):
    root = Path(root)
    destinations = [root / 'assets/landmarks/reference_embeddings.json', root / 'test/datasets/parity.json', root / 'test/datasets/parity_input.bin']
    if any((path.exists() for path in destinations)):
        fail('refusing to overwrite existing index or parity files')
    photos = photo_sources(sources)
    verify_photos(photos, root)
    landmarks = read_json(root / 'assets/landmarks/landmarks.json')
    ids = {item['id'] for item in landmarks}
    if any((photo['split'] != 'unknown' and photo['landmark_id'] not in ids for photo in photos)):
        fail('photo label is outside the landmark catalog')
    model = load_embedder(root / 'assets/models/landmark_embedder.tflite')
    index = {'model_id': MODEL_ID, 'dimension': 1024, 'references': []}
    for photo in photos:
        if photo['split'] == 'reference':
            index['references'].append({'landmark_id': photo['landmark_id'], 'image_asset': photo['path'], 'vector': image_embedding(model, dataset_path(root, photo['path']))})
    graph = read_json(root / 'assets/maps/intramuros_graph.json')
    validate(landmarks, index, graph)
    if len(ids) != 6 or any((not 3 <= sum((ref['landmark_id'] == item for ref in index['references'])) <= 5 for item in ids)):
        fail('MVP catalog requires six landmarks and 3–5 references each')
    first = next((photo for photo in photos if photo['split'] == 'reference'))
    tensor_bytes = image_tensor(dataset_path(root, first['path'])).tobytes()
    parity = {'model_sha256': MODEL_SHA256, 'image_path': first['path'], 'image_sha256': first['sha256'], 'input_shape': [1, 224, 224, 3], 'output_shape': [1, 1024], 'preprocessing': 'EXIF orientation; RGB; full-frame floor-index nearest resize 224x224; pixel/255; output L2', 'input_sha256': hashlib.sha256(tensor_bytes).hexdigest(), 'embedding': index['references'][0]['vector'], 'android_verified': False}
    written = []
    try:
        for path, value in zip(destinations[:2], (index, parity)):
            write_json(path, value)
            written.append(path)
        with destinations[2].open('xb') as target:
            written.append(destinations[2])
            target.write(tensor_bytes)
    except Exception:
        for path in written:
            path.unlink(missing_ok=True)
        raise
    return index

def evaluate(root, sources):
    import numpy as np
    root = Path(root)
    photos = photo_sources(sources)
    verify_photos(photos, root)
    index = read_json(root / 'assets/landmarks/reference_embeddings.json')
    landmarks = read_json(root / 'assets/landmarks/landmarks.json')
    ids = {item['id'] for item in landmarks}
    if any((photo['split'] != 'unknown' and photo['landmark_id'] not in ids for photo in photos)):
        fail('photo label is outside the landmark catalog')
    validate(landmarks, index, read_json(root / 'assets/maps/intramuros_graph.json'))
    model = load_embedder(root / 'assets/models/landmark_embedder.tflite')
    records, timings = ([], [])
    for photo in photos:
        if photo['split'] == 'reference':
            continue
        start = time.perf_counter()
        query = np.asarray(image_embedding(model, dataset_path(root, photo['path'])))
        timings.append((time.perf_counter() - start) * 1000)
        scores = {}
        for ref in index['references']:
            score = float(np.dot(query, ref['vector']))
            scores[ref['landmark_id']] = max(scores.get(ref['landmark_id'], -1), score)
        ranked = sorted(scores, key=lambda item: (-scores[item], item))[:3]
        records.append({'path': photo['path'], 'split': photo['split'], 'expected': photo.get('landmark_id'), 'top3': ranked, 'scores': {item: scores[item] for item in ranked}})
    known = [item for item in records if item['split'] == 'held_out']
    unknown = [item for item in records if item['split'] == 'unknown']
    if not known or not unknown:
        fail('evaluation requires separate supported and unknown photos')
    return {'model_id': MODEL_ID, 'model_sha256': MODEL_SHA256, 'environment': 'Mac Python CPU; no Android proof', 'held_out_count': len(known), 'unknown_count': len(unknown), 'top1_correct': sum((item['expected'] == item['top3'][0] for item in known)), 'top3_correct': sum((item['expected'] in item['top3'] for item in known)), 'rejection_rule_calibrated': False, 'inference_ms': {'median': statistics.median(timings), 'max': max(timings)}, 'records': records}

def download(url, expected_sha):
    allowed = {'upload.wikimedia.org', 'storage.googleapis.com'}

    def check_url(target):
        parsed = urlparse(target)
        if parsed.scheme != 'https' or parsed.hostname not in allowed or parsed.username or parsed.password:
            fail('download host is not an approved public dataset source')

    class PublicRedirect(urllib.request.HTTPRedirectHandler):

        def redirect_request(self, request, response, code, message, headers, newurl):
            check_url(newurl)
            return super().redirect_request(request, response, code, message, headers, newurl)
    check_url(url)
    opener = urllib.request.build_opener(PublicRedirect())
    request = urllib.request.Request(url, headers={'User-Agent': 'TUNTON-offline-dataset-preparation/1.0'})
    for attempt in range(3):
        try:
            with opener.open(request, timeout=30) as response:
                content = response.read(32 * 1024 * 1024 + 1)
            if len(content) > 32 * 1024 * 1024:
                fail('source download exceeds 32 MiB')
            if hashlib.sha256(content).hexdigest() != expected_sha:
                fail('download checksum differs from recorded source')
            return content
        except OSError:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)

def prepare_dataset(sources, map_source, source_root, output_dir):
    from PIL import Image, ImageOps, PngImagePlugin
    output = Path(output_dir).resolve()
    if output.exists():
        fail('preparation output directory must not already exist')
    output.parent.mkdir(parents=True, exist_ok=True)
    photos = photo_sources(sources)
    snapshot = read_json(map_source)
    if snapshot.get('metadata', {}).get('country') != 'PH':
        fail('map source must be identified as Philippines (PH) data')
    bounds = snapshot['bbox']
    if not isinstance(bounds, list) or len(bounds) != 4:
        fail('map bbox must be [west, south, east, north]')
    west, south, east, north = bounds
    coordinate(south, west, 'map southwest corner')
    coordinate(north, east, 'map northeast corner')
    if not 0 < east - west <= 0.05 or not 0 < north - south <= 0.05:
        fail('map extent must be a bounded pilot-area extract')
    zooms = snapshot['tile_zooms']
    if not isinstance(zooms, list) or not zooms or len(set(zooms)) != len(zooms) or any((isinstance(z, bool) or not isinstance(z, int) or (not 15 <= z <= 18) for z in zooms)):
        fail('map zooms must be distinct integers from 15 through 18')
    for node in snapshot['osm_nodes']:
        coordinate(node['lat'], node['lon'], 'OSM node')
    with tempfile.TemporaryDirectory(prefix='.tunton-prep-', dir=output.parent) as temp:
        stage = Path(temp) / 'bundle'
        stage.mkdir()
        model_path = Path(source_root) / 'assets/models/landmark_embedder.tflite'
        model_target = stage / 'assets/models/landmark_embedder.tflite'
        model_target.parent.mkdir(parents=True)
        if model_path.is_file():
            if checksum(model_path) != MODEL_SHA256:
                fail('source model checksum mismatch')
            shutil.copyfile(model_path, model_target)
        else:
            model_target.write_bytes(download(MODEL_URL, MODEL_SHA256))
        for photo in photos:
            target = dataset_path(stage, photo['path'])
            target.parent.mkdir(parents=True, exist_ok=True)
            local = dataset_path(source_root, photo['path'])
            if local.is_file():
                if checksum(local) != photo['sha256']:
                    fail('source photo checksum mismatch: ' + photo['path'])
                shutil.copyfile(local, target)
            else:
                original = download(photo['download_url'], photo['original_sha256'])
                with Image.open(io.BytesIO(original)) as image:
                    if image.width * image.height > 100000000:
                        fail('original image exceeds 100 megapixels')
                    image = ImageOps.exif_transpose(image).convert('RGB')
                    image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                    credits = PngImagePlugin.PngInfo()
                    for key, field in (('Author', 'author'), ('Source', 'page_url'), ('License', 'license'), ('LicenseURL', 'license_url'), ('Modifications', 'modifications')):
                        credits.add_text(key, photo[field])
                    image.save(target, format='PNG', optimize=True, pnginfo=credits)
                if checksum(target) != photo['sha256']:
                    fail('derived photo differs from pinned preparation: ' + photo['path'])
        graph = walking_graph(snapshot)
        write_json(stage / 'assets/landmarks/landmarks.json', snapshot['landmarks'])
        write_json(stage / 'assets/maps/intramuros_graph.json', graph)
        tile_count = render_map_tiles(map_source, stage / 'assets/tiles')
        create_index(stage, sources)
        report = evaluate(stage, sources)
        report['tile_count'] = tile_count
        report['graph_nodes'] = len(graph['nodes'])
        report['graph_edges'] = len(graph['edges'])
        report['asset_bytes'] = sum((path.stat().st_size for path in (stage / 'assets').rglob('*') if path.is_file()))
        write_json(stage / 'test/datasets/evaluation_report.json', report)
        shutil.copyfile(sources, stage / 'test/datasets/sources.json')
        shutil.copyfile(map_source, stage / 'test/datasets/map_source.json')
        (stage / 'test/datasets/held_out/team').mkdir(parents=True)
        if output.exists():
            fail('refusing to replace an existing preparation directory')
        stage.rename(output)
    return report

def compare_android(expected, actual):
    import numpy as np
    expected, actual = (read_json(expected), read_json(actual))
    if expected.get('model_sha256') != MODEL_SHA256:
        fail('expected parity model is not the approved checkpoint')
    image_sha = expected.get('image_sha256')
    if not isinstance(image_sha, str) or len(image_sha) != 64 or any((c not in '0123456789abcdef' for c in image_sha)):
        fail('expected parity requires a valid image SHA-256')
    for key in ('model_sha256', 'image_sha256'):
        if expected.get(key) != actual.get(key):
            fail('Android parity ' + key + ' mismatch')
    for record in (expected, actual):
        values = record.get('embedding')
        try:
            valid = isinstance(values, list) and len(values) == 1024 and all((not isinstance(value, bool) and isinstance(value, (int, float)) and math.isfinite(value) for value in values))
        except (OverflowError, TypeError, ValueError):
            valid = False
        if not valid:
            fail('parity embedding must contain 1024 finite numeric values')
    left, right = (np.asarray(expected['embedding'], dtype=float), np.asarray(actual['embedding'], dtype=float))
    if left.shape != (1024,) or right.shape != (1024,) or (not np.isfinite(left).all()) or (not np.isfinite(right).all()) or (not math.isclose(float(np.linalg.norm(left)), 1, abs_tol=0.0001)):
        fail('Android parity embedding must contain 1024 finite values')
    error = float(np.max(np.abs(left - right)))
    if error > 0.0001:
        fail(f'Android parity maximum absolute error {error} exceeds 0.0001')
    return {'max_absolute_error': error, 'passed': True}

def dataset_main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    prepare = commands.add_parser('prepare', help='rebuild a real dataset into a new directory')
    prepare.add_argument('--sources', required=True)
    prepare.add_argument('--map-source', required=True)
    prepare.add_argument('--source-root', default='.')
    prepare.add_argument('--output-dir', required=True)
    for command in ('index', 'evaluate'):
        child = commands.add_parser(command)
        child.add_argument('--root', default='.')
        child.add_argument('--sources', required=True)
        if command == 'evaluate':
            child.add_argument('--report', required=True)
    parity = commands.add_parser('compare-android')
    parity.add_argument('--expected', required=True)
    parity.add_argument('--actual', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'prepare':
            report = prepare_dataset(args.sources, args.map_source, args.source_root, args.output_dir)
            print(json.dumps({key: value for key, value in report.items() if key != 'records'}, indent=2))
        elif args.command == 'index':
            index = create_index(args.root, args.sources)
            print(f"Indexed {len(index['references'])} real reference photos; dimension {index['dimension']}")
        elif args.command == 'evaluate':
            report = evaluate(args.root, args.sources)
            write_json(args.report, report)
            print(f"Held-out top-3: {report['top3_correct']}/{report['held_out_count']}; unknown inputs: {report['unknown_count']}")
        else:
            print(json.dumps(compare_android(args.expected, args.actual)))
    except (OSError, ValueError, KeyError, TypeError, ImportError) as error:
        parser.error(str(error))

def read_json(path):
    with Path(path).open(encoding='utf-8') as source:
        return json.load(source)

def fail(message):
    raise ValueError(message)

def keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != set(expected):
        fail(f"{label} must contain exactly: {', '.join(expected)}")

def text(value, label):
    if not isinstance(value, str) or not value.strip():
        fail(f'{label} must be a non-empty string')

def coordinate(lat, lon, label):
    try:
        valid = not isinstance(lat, bool) and (not isinstance(lon, bool)) and isinstance(lat, (int, float)) and isinstance(lon, (int, float)) and math.isfinite(lat) and math.isfinite(lon) and (-90 <= lat <= 90) and (-180 <= lon <= 180)
    except (OverflowError, TypeError, ValueError):
        valid = False
    if not valid:
        fail(f'{label} must be finite [latitude, longitude] coordinates')

def validate(landmarks, embeddings, graph):
    if not isinstance(landmarks, list) or not landmarks:
        fail('landmarks must be a non-empty array')
    landmark_ids = set()
    for item in landmarks:
        keys(item, ('id', 'name', 'lat', 'lon', 'route_node_id'), 'landmark')
        text(item['id'], 'landmark id')
        text(item['name'], f"landmark {item['id']} name")
        text(item['route_node_id'], f"landmark {item['id']} route_node_id")
        coordinate(item['lat'], item['lon'], f"landmark {item['id']}")
        if item['id'] in landmark_ids:
            fail(f"duplicate landmark id: {item['id']}")
        landmark_ids.add(item['id'])
    keys(graph, ('nodes', 'edges'), 'graph')
    if not isinstance(graph['nodes'], list) or not graph['nodes']:
        fail('graph nodes must be a non-empty array')
    nodes = set()
    for node in graph['nodes']:
        keys(node, ('id', 'lat', 'lon'), 'graph node')
        text(node['id'], 'graph node id')
        coordinate(node['lat'], node['lon'], f"graph node {node['id']}")
        if node['id'] in nodes:
            fail(f"duplicate graph node id: {node['id']}")
        nodes.add(node['id'])
    for item in landmarks:
        if item['route_node_id'] not in nodes:
            fail(f"landmark {item['id']} references missing graph node {item['route_node_id']}")
    if not isinstance(graph['edges'], list):
        fail('graph edges must be an array')
    for edge in graph['edges']:
        keys(edge, ('from', 'to', 'length_m', 'geometry'), 'graph edge')
        text(edge['from'], 'graph edge from')
        text(edge['to'], 'graph edge to')
        if edge['from'] not in nodes or edge['to'] not in nodes:
            fail('graph edge references a missing node')
        length = edge['length_m']
        try:
            valid_length = not isinstance(length, bool) and isinstance(length, (int, float)) and math.isfinite(length) and (length > 0)
        except (OverflowError, TypeError, ValueError):
            valid_length = False
        if not valid_length:
            fail('graph edge length_m must be finite and greater than zero')
        geometry = edge['geometry']
        if not isinstance(geometry, list) or len(geometry) < 2:
            fail('graph edge geometry must contain at least two [latitude, longitude] points')
        for point in geometry:
            if not isinstance(point, list) or len(point) != 2:
                fail('graph edge geometry points must be [latitude, longitude]')
            coordinate(point[0], point[1], 'graph edge geometry point')
    keys(embeddings, ('model_id', 'dimension', 'references'), 'embeddings')
    if embeddings['model_id'] != MODEL_ID:
        fail(f'model_id must be {MODEL_ID!r}')
    dimension = embeddings['dimension']
    if isinstance(dimension, bool) or not isinstance(dimension, int) or dimension <= 0:
        fail('embedding dimension must be a positive integer')
    references = embeddings['references']
    if not isinstance(references, list) or not references:
        fail('embedding references must be a non-empty array')
    normalized = []
    for reference in references:
        keys(reference, ('landmark_id', 'image_asset', 'vector'), 'embedding reference')
        text(reference['landmark_id'], 'embedding landmark_id')
        if reference['landmark_id'] not in landmark_ids:
            fail(f"embedding references unknown landmark {reference['landmark_id']!r}")
        text(reference['image_asset'], 'reference image_asset')
        image_path = reference['image_asset']
        parsed_path = PurePosixPath(image_path)
        if not image_path.startswith('assets/images/') or image_path.startswith('/') or '\\' in image_path or ('..' in parsed_path.parts) or (parsed_path.as_posix() != image_path) or (len(parsed_path.parts) < 3):
            fail('reference image_asset must be a canonical relative path under assets/images/')
        vector = reference['vector']
        if not isinstance(vector, list) or len(vector) != dimension:
            fail(f'embedding vector must contain exactly {dimension} values')
        try:
            values = [float(value) for value in vector if not isinstance(value, bool) and isinstance(value, (int, float))]
            if len(values) != len(vector) or any((not math.isfinite(value) for value in values)):
                fail('embedding vector values must be finite numbers')
        except (OverflowError, TypeError, ValueError):
            fail('embedding vector values must be finite numbers')
        scale = max((abs(value) for value in values))
        if scale == 0:
            fail('embedding vector must have a finite, non-zero L2 norm')
        scaled = [value / scale for value in values]
        norm = math.hypot(*scaled)
        normalized.append({**reference, 'vector': [value / norm for value in scaled]})
    return (landmarks, {**embeddings, 'references': normalized}, graph)

def export(landmarks, embeddings, graph, output_dir):
    root = Path(output_dir)
    outputs = {root / 'assets/landmarks/landmarks.json': landmarks, root / 'assets/landmarks/reference_embeddings.json': embeddings, root / 'assets/maps/intramuros_graph.json': graph}
    existing = [str(path) for path in outputs if path.exists()]
    if existing:
        fail('refusing to overwrite existing output(s): ' + ', '.join(existing))
    written = []
    try:
        for path, value in outputs.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('x', encoding='utf-8') as target:
                written.append(path)
                json.dump(value, target, indent=2, ensure_ascii=False, allow_nan=False)
                target.write('\n')
    except Exception:
        for path in written:
            path.unlink(missing_ok=True)
        raise

def map_distance(a, b):
    lat1, lat2 = map(math.radians, (a[0], b[0]))
    dlat, dlon = (lat2 - lat1, math.radians(b[1] - a[1]))
    return 6371009 * 2 * math.asin(min(1, math.sqrt(math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2)))

def walking_graph(source):
    """Keep each actual OSM way segment; pedestrian direction overrides vehicle direction."""
    raw = {str(n['id']): n for n in source['osm_nodes']}
    edges = []
    allowed = {'footway', 'path', 'pedestrian', 'steps', 'living_street', 'residential', 'service', 'unclassified', 'tertiary', 'secondary', 'primary', 'trunk'}
    for way in source['osm_ways']:
        tags = way['tags']
        if tags.get('highway') not in allowed or tags.get('area') == 'yes':
            continue
        if tags.get('foot') in {'no', 'private'} or (tags.get('access') in {'no', 'private'} and tags.get('foot') not in {'yes', 'designated', 'permissive'}):
            continue
        if tags.get('golf') == 'cartpath' and tags.get('foot') not in {'yes', 'designated'}:
            continue
        if any((k in tags for k in ('access:conditional', 'foot:conditional', 'oneway:foot:conditional'))):
            continue
        direction = tags.get('oneway:foot', 'no')
        if 'oneway:foot' not in tags and tags.get('highway') in {'footway', 'path', 'steps', 'pedestrian'} and ('designation' not in tags):
            direction = tags.get('oneway', 'no')
        if direction not in {'yes', '1', 'true', 'no', '0', 'false', '-1'}:
            continue
        for a, b in zip(way['nodes'], way['nodes'][1:]):
            a, b = (str(a), str(b))
            if a not in raw or b not in raw:
                raise ValueError('OSM way references missing node')
            pa, pb = ([raw[a]['lat'], raw[a]['lon']], [raw[b]['lat'], raw[b]['lon']])
            if not all((source['bbox'][1] <= p[0] <= source['bbox'][3] and source['bbox'][0] <= p[1] <= source['bbox'][2] for p in (pa, pb))):
                continue
            if any((raw[n]['tags'].get('access') in {'private', 'no'} or raw[n]['tags'].get('foot') in {'private', 'no'} or raw[n]['tags'].get('barrier') in {'wall', 'fence', 'block', 'retaining_wall'} or (raw[n]['tags'].get('locked') == 'yes') or any((k in raw[n]['tags'] for k in ('access:conditional', 'foot:conditional'))) for n in (a, b))):
                continue
            length = map_distance(pa, pb)
            if length <= 0:
                continue
            if direction != '-1' and tags.get('foot:forward') != 'no':
                edges.append({'from': a, 'to': b, 'length_m': length, 'geometry': [pa, pb]})
            if direction not in {'yes', '1', 'true'} and tags.get('foot:backward') != 'no':
                edges.append({'from': b, 'to': a, 'length_m': length, 'geometry': [pb, pa]})
    used = {e[k] for e in edges for k in ('from', 'to')}
    return {'nodes': [{'id': n, 'lat': raw[n]['lat'], 'lon': raw[n]['lon']} for n in sorted(used, key=int)], 'edges': edges}

def tile_point(lat, lon, zoom):
    n = 2 ** zoom
    return ((lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n)

def render_map_tiles(source_path, output_dir):
    """Render OSM ways in XYZ Web Mercator; output stays in provided directory."""
    from PIL import Image, ImageDraw
    source = json.loads(Path(source_path).read_text())
    raw = {str(n['id']): n for n in source['osm_nodes']}
    root = Path(output_dir)
    west, south, east, north = source['bbox']
    count = 0
    for z in source['tile_zooms']:
        x0, y0 = tile_point(north, west, z)
        x1, y1 = tile_point(south, east, z)
        for x in range(math.floor(x0), math.floor(x1) + 1):
            for y in range(math.floor(y0), math.floor(y1) + 1):
                canvas = Image.new('RGB', (256, 256), '#f4f0e6')
                draw = ImageDraw.Draw(canvas)
                for layer in ('areas', 'roads', 'barriers'):
                    for way in source['osm_ways']:
                        tags = way['tags']
                        ids = [str(v) for v in way['nodes']]
                        if any((v not in raw for v in ids)):
                            continue
                        points = [tuple(((v - o) * 256 for v, o in zip(tile_point(raw[i]['lat'], raw[i]['lon'], z), (x, y)))) for i in ids]
                        if len(points) < 2 or max((p[0] for p in points)) < -20 or min((p[0] for p in points)) > 276 or (max((p[1] for p in points)) < -20) or (min((p[1] for p in points)) > 276):
                            continue
                        if layer == 'areas' and ids[0] == ids[-1]:
                            color = None
                            if tags.get('natural') == 'water' or tags.get('waterway') == 'riverbank':
                                color = '#aacddd'
                            elif tags.get('leisure') in {'park', 'garden', 'golf_course'} or tags.get('landuse') in {'grass', 'recreation_ground'}:
                                color = '#cbd9b3'
                            elif 'building' in tags:
                                color = '#d4ccc1'
                            if color:
                                draw.polygon(points, fill=color)
                        elif layer == 'roads' and 'highway' in tags and (tags.get('area') != 'yes'):
                            foot = tags['highway'] in {'footway', 'path', 'steps', 'pedestrian'}
                            width = max(1, round((2 if foot else 5) * 2 ** (z - 16)))
                            draw.line(points, fill='#d6aa81' if foot else '#ffffff', width=width)
                        elif layer == 'barriers' and tags.get('barrier') in {'wall', 'city_wall', 'fence'}:
                            draw.line(points, fill='#857263', width=max(1, round(2 ** (z - 16))))
                if z >= 17:
                    occupied = []
                    for landmark in source.get('landmarks', []):
                        px, py = tile_point(landmark['lat'], landmark['lon'], z)
                        px, py = ((px - x) * 256, (py - y) * 256)
                        if 0 <= px < 256 and 0 <= py < 256:
                            label = landmark['name'].split(' — ')[0]
                            if label == 'Baluarte de San Diego':
                                label = 'Baluarte San Diego'
                            if label == 'San Agustin Church':
                                label = 'San Agustin'
                            draw.ellipse((px - 3, py - 3, px + 3, py + 3), fill='#446b58')
                            box = draw.textbbox((0, 0), label)
                            tx = max(2, min(px + 5, 254 - box[2]))
                            ty = max(2, min(py - 15, 240))
                            draw.text((tx, ty), label, fill='#30483d', stroke_width=1, stroke_fill='#f4f0e6')
                            occupied.append((tx, ty, tx + box[2], ty + box[3]))
                    seen = set()
                    if z >= 18:
                        for way in source['osm_ways']:
                            tags = way['tags']
                            name = tags.get('name')
                            if not name or name in seen or tags.get('highway') not in {'tertiary', 'residential', 'pedestrian', 'service'}:
                                continue
                            mid = raw.get(str(way['nodes'][len(way['nodes']) // 2]))
                            if mid is None:
                                continue
                            px, py = tile_point(mid['lat'], mid['lon'], z)
                            px, py = ((px - x) * 256, (py - y) * 256)
                            label = name.replace(' Street', ' St').replace('General ', 'Gen. ')
                            box = draw.textbbox((0, 0), label)
                            w, h = (box[2], box[3])
                            if 2 <= px <= 254 - w and 2 <= py <= 254 - h and (not any((px < b[2] and px + w > b[0] and (py < b[3]) and (py + h > b[1]) for b in occupied))):
                                draw.text((px, py), label, fill='#66625b', stroke_width=1, stroke_fill='#f4f0e6')
                                seen.add(name)
                                occupied.append((px, py, px + w, py + h))
                path = root / str(z) / str(x) / f'{y}.png'
                path.parent.mkdir(parents=True, exist_ok=True)
                if path.exists():
                    raise ValueError(f'refusing to overwrite tile: {path}')
                canvas.save(path, optimize=True)
                count += 1
    return count

def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv and argv[0] in ('prepare', 'index', 'evaluate', 'compare-android'):
        return dataset_main(argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--landmarks', required=True)
    parser.add_argument('--embeddings', required=True)
    parser.add_argument('--graph', required=True)
    parser.add_argument('--output-dir', required=True)
    args = parser.parse_args(argv)
    try:
        data = validate(read_json(args.landmarks), read_json(args.embeddings), read_json(args.graph))
        export(*data, args.output_dir)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        parser.error(str(error))
if __name__ == '__main__':
    main()
