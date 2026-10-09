import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import prepare_dataset


def sample():
    landmarks = [{"id": "l1", "name": "Place", "area_id": "intramuros", "lat": 14.59, "lon": 120.97, "route_node_id": "n1"}]
    embeddings = {"model_id": prepare_dataset.MODEL_ID, "model_sha256": "a" * 64,
                  "preprocessing_version": prepare_dataset.PREPROCESSING_VERSION,
                  "dimension": 2, "references": [
        {"landmark_id": "l1", "image_asset": "assets/images/place.jpg", "vector": [3, 4]}]}
    graph = {"nodes": [{"id": "n1", "lat": 14.59, "lon": 120.97}, {"id": "n2", "lat": 14.591, "lon": 120.971}],
             "edges": [{"from": "n1", "to": "n2", "length_m": 10, "geometry": [[14.59, 120.97], [14.591, 120.971]]}]}
    return landmarks, embeddings, graph


class PrepareDatasetTest(unittest.TestCase):
    def test_valid_data_normalizes_and_exports_three_contract_files(self):
        data = prepare_dataset.validate(*sample())
        self.assertEqual(data[1]["references"][0]["vector"], [0.6, 0.8])
        with tempfile.TemporaryDirectory() as temp:
            prepare_dataset.export(*data, temp)
            paths = [Path(temp) / "assets/landmarks/landmarks.json",
                     Path(temp) / "assets/landmarks/reference_embeddings.json",
                     Path(temp) / "assets/maps/intramuros_graph.json"]
            self.assertTrue(all(path.is_file() for path in paths))
            self.assertEqual(json.loads(paths[1].read_text())["references"][0]["vector"], [0.6, 0.8])

    def test_rejects_missing_route_node_and_bad_edge_length(self):
        landmarks, embeddings, graph = sample()
        landmarks[0]["route_node_id"] = "missing"
        with self.assertRaisesRegex(ValueError, "missing graph node"):
            prepare_dataset.validate(landmarks, embeddings, graph)
        landmarks, embeddings, graph = sample()
        graph["edges"][0]["length_m"] = float("nan")
        with self.assertRaisesRegex(ValueError, "finite and greater than zero"):
            prepare_dataset.validate(landmarks, embeddings, graph)

    def test_rejects_unknown_embedding_and_zero_vector(self):
        landmarks, embeddings, graph = sample()
        embeddings["references"][0]["landmark_id"] = "missing"
        with self.assertRaisesRegex(ValueError, "unknown landmark"):
            prepare_dataset.validate(landmarks, embeddings, graph)
        landmarks, embeddings, graph = sample()
        embeddings["references"][0]["vector"] = [0, 0]
        with self.assertRaisesRegex(ValueError, "non-zero"):
            prepare_dataset.validate(landmarks, embeddings, graph)

    def test_normalizes_large_finite_values_without_overflow(self):
        landmarks, embeddings, graph = sample()
        embeddings["references"][0]["vector"] = [1e308, 1e308]
        normalized = prepare_dataset.validate(landmarks, embeddings, graph)[1]["references"][0]["vector"]
        self.assertAlmostEqual(normalized[0], 2 ** -0.5)
        self.assertAlmostEqual(normalized[1], 2 ** -0.5)

    def test_rejects_unsafe_image_path_and_oversized_integer(self):
        landmarks, embeddings, graph = sample()
        embeddings["references"][0]["image_asset"] = "assets/images/../secret.jpg"
        with self.assertRaisesRegex(ValueError, "canonical relative path"):
            prepare_dataset.validate(landmarks, embeddings, graph)
        landmarks, embeddings, graph = sample()
        landmarks[0]["lat"] = 10 ** 10000
        with self.assertRaisesRegex(ValueError, "finite"):
            prepare_dataset.validate(landmarks, embeddings, graph)
        landmarks, embeddings, graph = sample()
        embeddings["references"][0]["vector"] = [10 ** 10000, 1]
        with self.assertRaisesRegex(ValueError, "finite numbers"):
            prepare_dataset.validate(landmarks, embeddings, graph)

    def test_refuses_existing_outputs_without_changing_them(self):
        landmarks, embeddings, graph = prepare_dataset.validate(*sample())
        with tempfile.TemporaryDirectory() as temp:
            existing = Path(temp) / "assets/landmarks/landmarks.json"
            existing.parent.mkdir(parents=True)
            existing.write_text("keep", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "refusing to overwrite"):
                prepare_dataset.export(landmarks, embeddings, graph, temp)
            self.assertEqual(existing.read_text(encoding="utf-8"), "keep")
            self.assertFalse((Path(temp) / "assets/maps/intramuros_graph.json").exists())


if __name__ == "__main__":
    unittest.main()
