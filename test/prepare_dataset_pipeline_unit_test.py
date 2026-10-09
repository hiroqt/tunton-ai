"""Preparation boundary checks; fixtures here are metadata, not product photos."""
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import prepare_dataset as prep


class PipelineBoundaryTest(unittest.TestCase):
    def source(self):
        return {'path': 'assets/images/fixture.png', 'landmark_id': 'fort-santiago',
                'split': 'reference', 'country': 'PH', 'location': 'Intramuros, Manila, Philippines',
                'geographic_evidence': {'url': 'https://commons.wikimedia.org/', 'basis': 'Unit metadata fixture'},
                'page_url': 'https://commons.wikimedia.org/', 'download_url': 'https://upload.wikimedia.org/',
                'author': 'Fixture', 'license': 'CC BY 4.0', 'license_url': 'https://creativecommons.org/licenses/by/4.0/',
                'sha256': 'a' * 64, 'original_sha256': 'b' * 64, 'modifications': 'Unit metadata fixture'}

    def test_missing_or_non_ph_geographic_provenance_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'sources.json'
            for country in (None, 'FR'):
                source = self.source()
                source['country'] = country
                path.write_text(json.dumps({'photos': [source]}))
                with self.assertRaisesRegex(ValueError, 'Philippines'):
                    prep.photo_sources(path)
            source = self.source()
            source.pop('geographic_evidence')
            path.write_text(json.dumps({'photos': [source]}))
            with self.assertRaisesRegex(ValueError, 'geographic source evidence'):
                prep.photo_sources(path)

    def test_reference_and_held_out_cannot_reuse_original_source(self):
        first = self.source()
        second = copy.deepcopy(first)
        second.update(path='test/datasets/held_out/public/fixture.png', split='held_out')
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'sources.json'
            path.write_text(json.dumps({'photos': [first, second]}))
            with self.assertRaisesRegex(ValueError, 'cross-split leakage'):
                prep.photo_sources(path)

    def test_traversal_and_symlink_escape_are_rejected(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as outside:
            with self.assertRaises(ValueError):
                prep.dataset_path(root, '../outside.png')
            (Path(root) / 'escape').symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, 'escapes root'):
                prep.dataset_path(root, 'escape/photo.png')

    def test_numerical_parity_requires_identity_and_finite_numeric_values(self):
        expected = {'model_sha256': prep.MODEL_SHA256, 'image_sha256': 'c' * 64,
                    'embedding': [1.0] + [0.0] * 1023}
        with tempfile.TemporaryDirectory() as temp:
            left, right = Path(temp) / 'expected.json', Path(temp) / 'actual.json'
            left.write_text(json.dumps(expected))
            for invalid in ('missing_identity', 'boolean', 'nonfinite'):
                actual = copy.deepcopy(expected)
                if invalid == 'missing_identity':
                    actual.pop('image_sha256')
                elif invalid == 'boolean':
                    actual['embedding'][0] = True
                else:
                    actual['embedding'][0] = float('nan')
                right.write_text(json.dumps(actual))
                with self.assertRaises(ValueError):
                    prep.compare_android(left, right)


if __name__ == '__main__':
    unittest.main()
