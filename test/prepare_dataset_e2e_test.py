"""End-to-end CLI checks using temporary schema fixtures, never product assets."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "prepare_dataset.py"


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")


class PrepareDatasetEndToEndTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.inputs = self.root / "input"
        self.output = self.root / "output"
        self.sources = {
            "landmarks": self.inputs / "landmarks.json",
            "embeddings": self.inputs / "embeddings.json",
            "graph": self.inputs / "graph.json",
        }
        write_json(self.sources["landmarks"], [{
            "id": "test-place", "name": "Fixture Place", "lat": 14.59,
            "lon": 120.97, "route_node_id": "node-a",
        }])
        write_json(self.sources["embeddings"], {
            "model_id": "bundled-mobilenetv3-small-embedder",
            "dimension": 2,
            "references": [{
                "landmark_id": "test-place",
                "image_asset": "assets/images/fixture.jpg",
                "vector": [3, 4],
            }],
        })
        write_json(self.sources["graph"], {
            "nodes": [
                {"id": "node-a", "lat": 14.59, "lon": 120.97},
                {"id": "node-b", "lat": 14.591, "lon": 120.971},
            ],
            "edges": [{
                "from": "node-a", "to": "node-b", "length_m": 10,
                "geometry": [[14.59, 120.97], [14.591, 120.971]],
            }],
        })

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self):
        return subprocess.run(
            [sys.executable, str(SCRIPT),
             "--landmarks", str(self.sources["landmarks"]),
             "--embeddings", str(self.sources["embeddings"]),
             "--graph", str(self.sources["graph"]),
             "--output-dir", str(self.output)],
            capture_output=True, text=True, check=False,
        )

    def test_cli_exports_normalized_ard_assets_without_mutating_inputs(self):
        original = {key: path.read_bytes() for key, path in self.sources.items()}

        result = self.run_cli()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertEqual({key: path.read_bytes() for key, path in self.sources.items()}, original)
        landmarks = self.output / "assets/landmarks/landmarks.json"
        embeddings = self.output / "assets/landmarks/reference_embeddings.json"
        graph = self.output / "assets/maps/intramuros_graph.json"
        self.assertEqual(json.loads(landmarks.read_text(encoding="utf-8"))[0]["route_node_id"], "node-a")
        self.assertEqual(json.loads(embeddings.read_text(encoding="utf-8"))["references"][0]["vector"], [0.6, 0.8])
        self.assertEqual(json.loads(graph.read_text(encoding="utf-8"))["edges"][0]["length_m"], 10)

    def test_invalid_input_fails_visibly_without_partial_export(self):
        landmarks = json.loads(self.sources["landmarks"].read_text(encoding="utf-8"))
        landmarks[0]["route_node_id"] = "missing-node"
        write_json(self.sources["landmarks"], landmarks)

        result = self.run_cli()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing graph node", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse(self.output.exists())

    def test_cli_refuses_to_overwrite_an_existing_asset(self):
        target = self.output / "assets/landmarks/landmarks.json"
        target.parent.mkdir(parents=True)
        target.write_text("preserve this file", encoding="utf-8")

        result = self.run_cli()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing to overwrite", result.stderr)
        self.assertEqual(target.read_text(encoding="utf-8"), "preserve this file")
        self.assertFalse((self.output / "assets/maps/intramuros_graph.json").exists())


if __name__ == "__main__":
    unittest.main()
