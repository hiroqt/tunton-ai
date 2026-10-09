"""Backend map checks against the acquired OSM source, never synthetic route evidence."""
import collections
import json
import math
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]


def project(lat, lon, z):
    return (lon+180)/360*2**z, (1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**z


class PreparedMapTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=json.loads((ROOT/'test/datasets/map_source.json').read_text())
        cls.graph=json.loads((ROOT/'assets/maps/intramuros_graph.json').read_text())
        cls.catalog=json.loads((ROOT/'assets/landmarks/landmarks.json').read_text())
        cls.nodes={n['id']:n for n in cls.graph['nodes']}

    def test_graph_segments_match_actual_osm_nodes_and_way_geometry(self):
        self.assertEqual(self.graph,self.source['graph'])
        raw={n['id']:n for n in self.source['osm_nodes']}
        pairs=set()
        for way in self.source['osm_ways']:
            if 'highway' in way['tags']:
                for a,b in zip(way['nodes'],way['nodes'][1:]):pairs.add((a,b));pairs.add((b,a))
        for edge in self.graph['edges']:
            self.assertIn((edge['from'],edge['to']),pairs)
            expected=[[raw[n]['lat'],raw[n]['lon']] for n in (edge['from'],edge['to'])]
            self.assertEqual(edge['geometry'],expected)
            self.assertGreater(edge['length_m'],0)
            self.assertTrue(math.isfinite(edge['length_m']))

    def test_six_landmarks_have_connected_real_endpoints_and_explicit_access_evidence(self):
        self.assertEqual(len(self.catalog),6)
        adj=collections.defaultdict(list)
        for edge in self.graph['edges']:adj[edge['from']].append(edge['to'])
        targets={l['route_node_id'] for l in self.catalog}
        for start in targets:
            seen={start};pending=[start]
            while pending:
                for node in adj[pending.pop()]:
                    if node not in seen:seen.add(node);pending.append(node)
            self.assertTrue(targets <= seen)
        evidence={e['landmark_id']:e for e in self.source['catalog_evidence']}
        for landmark in self.catalog:
            self.assertIn(landmark['route_node_id'],self.nodes)
            self.assertTrue(evidence[landmark['id']]['mapping_verified'])
            self.assertFalse(evidence[landmark['id']]['field_accessibility_verified'])
        for ident in ('san-agustin','baluarte-san-diego'):
            item=next(l for l in self.catalog if l['id']==ident)
            self.assertIn('exterior public street approach',item['name'])
            self.assertGreater(evidence[ident]['marker_to_route_offset_m'],0)

    def test_tiles_cover_full_bounds_and_real_markers_in_xyz_projection(self):
        west,south,east,north=self.source['bbox']
        expected=set()
        for z in self.source['tile_zooms']:
            x0,y0=project(north,west,z);x1,y1=project(south,east,z)
            for x in range(math.floor(x0),math.floor(x1)+1):
                for y in range(math.floor(y0),math.floor(y1)+1):expected.add(f'{z}/{x}/{y}.png')
            for landmark in self.catalog:
                x,y=project(landmark['lat'],landmark['lon'],z)
                self.assertIn(f'{z}/{math.floor(x)}/{math.floor(y)}.png',expected)
        actual={p.relative_to(ROOT/'assets/tiles').as_posix() for p in (ROOT/'assets/tiles').rglob('*.png')}
        self.assertEqual(actual,expected)
        for tile in actual:
            data=(ROOT/'assets/tiles'/tile).read_bytes()
            self.assertEqual(data[:8],b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack('>II',data[16:24]),(256,256))

    def test_source_license_and_unmapped_private_gate_exclusion(self):
        self.assertEqual(self.source['metadata']['license'],'ODbL-1.0')
        self.assertIn('OpenStreetMap',self.source['metadata']['attribution'])
        self.assertNotIn('9834302097',self.nodes)
        self.assertNotIn('9834302096',self.nodes)
        self.assertNotIn('3049956960',self.nodes)
        self.assertTrue(any(n['id']=='3049956960' for n in self.source['osm_nodes']))
        components=[];adj=collections.defaultdict(set)
        for e in self.graph['edges']:adj[e['from']].add(e['to']);adj[e['to']].add(e['from'])
        remaining=set(self.nodes)
        while remaining:
            start=next(iter(remaining));seen={start};pending=[start]
            while pending:
                for n in adj[pending.pop()]:
                    if n not in seen:seen.add(n);pending.append(n)
            remaining-=seen;components.append(seen)
        self.assertGreater(len(components),1,'Real disconnected pairs must be available for routing error checks')


if __name__=='__main__':unittest.main()
