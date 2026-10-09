"""Offline integrity checks for the curated public photo sources."""
import hashlib
import json
from pathlib import Path
import struct
import unittest
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
LANDMARKS = {
    'fort-santiago', 'manila-cathedral', 'san-agustin',
    'casa-manila', 'baluarte-san-diego', 'puerta-real',
    'rizal-park', 'sm-city-manila', 'robinsons-place-manila',
    'lucky-chinatown-mall', 'up-manila', 'dlsu-manila',
    'far-eastern-university', 'quiapo-church', 'binondo-church',
}


class DatasetSourcesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.photos = json.loads((ROOT / 'test/datasets/sources.json').read_text())['photos']

    def test_complete_separate_splits(self):
        self.assertEqual(len(self.photos), 91)
        self.assertEqual(sum(p['split'] == 'reference' for p in self.photos), 51)
        self.assertEqual({p['landmark_id'] for p in self.photos if p['split'] != 'unknown'}, LANDMARKS)
        for landmark in LANDMARKS:
            reference_count = 4 if landmark == 'binondo-church' else 3 if landmark in LANDMARKS - {
                'fort-santiago', 'manila-cathedral', 'san-agustin',
                'casa-manila', 'baluarte-san-diego', 'puerta-real',
            } else 3 if landmark == 'puerta-real' else 4
            for split, count in [('reference', reference_count), ('held_out', 2)]:
                self.assertEqual(sum(p['landmark_id'] == landmark and p['split'] == split for p in self.photos), count)
        unknowns = [p for p in self.photos if p['split'] == 'unknown']
        self.assertEqual(len(unknowns), 10)
        self.assertTrue(all(p['landmark_id'] is None for p in unknowns))
        for field in ('path', 'page_url', 'original_sha256', 'sha256'):
            self.assertEqual(len({p[field] for p in self.photos}), len(self.photos), field)
        for landmark in LANDMARKS:
            references = {p['author'] for p in self.photos if p['landmark_id'] == landmark and p['split'] == 'reference'}
            held_out = {p['author'] for p in self.photos if p['landmark_id'] == landmark and p['split'] == 'held_out'}
            self.assertFalse(references & held_out, landmark)

    def test_bytes_match_manifest_and_lossless_rgb_contract(self):
        for photo in self.photos:
            with self.subTest(path=photo['path']):
                relative = Path(photo['path'])
                self.assertFalse(relative.is_absolute())
                self.assertNotIn('..', relative.parts)
                self.assertEqual(relative.suffix, '.png')
                image = (ROOT / relative).read_bytes()
                self.assertEqual(hashlib.sha256(image).hexdigest(), photo['sha256'])
                self.assertEqual(image[:8], b'\x89PNG\r\n\x1a\n')
                self.assertEqual(image[12:16], b'IHDR')
                width, height, depth, color = struct.unpack('>IIBB', image[16:26])
                self.assertGreater(min(width, height), 0)
                self.assertLessEqual(max(width, height), 1024)
                self.assertEqual((depth, color), (8, 2))
                self.assertIn('lossless PNG', photo['modifications'])
                self.assertRegex(photo['original_sha256'], r'^[0-9a-f]{64}$')
                credits = {}
                offset = 8
                while offset < len(image):
                    size = struct.unpack('>I', image[offset:offset + 4])[0]
                    kind = image[offset + 4:offset + 8]
                    payload = image[offset + 8:offset + 8 + size]
                    if kind == b'tEXt':
                        key, value = payload.split(b'\x00', 1)
                        credits[key.decode('latin-1')] = value.decode('latin-1')
                    elif kind == b'iTXt':
                        key, remainder = payload.split(b'\x00', 1)
                        self.assertEqual(remainder[:2], b'\x00\x00')
                        language, translated, value = remainder[2:].split(b'\x00', 2)
                        credits[key.decode('latin-1')] = value.decode('utf-8')
                    offset += size + 12
                fields = [('Author', 'author'), ('Source', 'page_url'), ('License', 'license'), ('LicenseURL', 'license_url'), ('Modifications', 'modifications')]
                self.assertEqual(list(credits), [key for key, field in fields])
                self.assertEqual(credits, {key: photo[field] for key, field in fields})

    def test_only_manifest_images_remain(self):
        inventory = set()
        for directory in ('assets/images', 'test/datasets/held_out/public', 'test/datasets/unknown'):
            inventory.update(str(p.relative_to(ROOT)) for p in (ROOT / directory).rglob('*') if p.is_file() and p.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp'})
        self.assertEqual(inventory, {p['path'] for p in self.photos})

    def test_explicit_per_file_rights_and_provenance(self):
        for photo in self.photos:
            with self.subTest(path=photo['path']):
                self.assertTrue(photo['author'])
                self.assertEqual(photo['country'], 'PH')
                self.assertTrue(photo['location'].strip())
                self.assertTrue(photo['geographic_evidence']['basis'].strip())
                self.assertEqual(urlparse(photo['geographic_evidence']['url']).hostname, 'commons.wikimedia.org')
                self.assertTrue(photo['source_title'].startswith('File:'))
                self.assertEqual(urlparse(photo['page_url']).hostname, 'commons.wikimedia.org')
                self.assertEqual(urlparse(photo['download_url']).hostname, 'upload.wikimedia.org')
                self.assertIn(photo['license'], {'CC0', 'CC BY 2.0', 'CC BY 2.5', 'CC BY 3.0', 'CC BY 4.0', 'CC BY-SA 2.0', 'CC BY-SA 3.0', 'CC BY-SA 4.0', 'PD-self'})
                if photo['license'] == 'PD-self':
                    self.assertEqual(photo['license_url'], 'https://commons.wikimedia.org/wiki/Template:PD-self')
                    self.assertIn('explicit uploader public-domain release', photo['source_notice'])
                else:
                    self.assertEqual(urlparse(photo['license_url']).hostname, 'creativecommons.org')
                expected = 'assets/images/' if photo['split'] == 'reference' else 'test/datasets/held_out/public/' if photo['split'] == 'held_out' else 'test/datasets/unknown/'
                self.assertTrue(photo['path'].startswith(expected))


if __name__ == '__main__':
    unittest.main()
