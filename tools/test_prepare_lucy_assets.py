import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

import prepare_lucy_assets as assets

class LucyAssetsTests(unittest.TestCase):
    def test_isolated_names_resolve_all_camera_and_partial_variants(self):
        def name(value):
            return {'$value': value}
        selectors = ['&Female&TPP&Full', '&Female&FPP&Full', '&Female&TPP&Part', '&Female&FPP&Part']
        definitions = ['full', 'fpp', 'partial', 'fpp_partial']
        entity = {'Data': {'RootChunk': {'defaultAppearance': name('default'), 'appearances': [
            {'name': name('donor_' + suffix), 'appearanceName': name(appearance)}
            for suffix, appearance in zip(selectors, definitions)]}}}
        app = {'Data': {'RootChunk': {'appearances': [{'Data': {'name': name(n)}} for n in definitions]}}}
        assets.isolate_appearance_names(entity, app, 'donor_', 'lucy_')
        root = entity['Data']['RootChunk']
        self.assertEqual(root['defaultAppearance']['$value'], 'lucy_&Female&TPP&Full')
        lookup = {a['Data']['name']['$value'] for a in app['Data']['RootChunk']['appearances']}
        for selector, entry in zip(selectors, root['appearances']):
            self.assertEqual(entry['name']['$value'], 'lucy_' + selector)
            self.assertIn(entry['appearanceName']['$value'], lookup)
        self.assertTrue(lookup.isdisjoint(definitions))

    def test_reference_renumbering_preserves_aliases_and_detects_retargeting(self):
        before = {'a': {'HandleId': '17', 'Data': {'x': 7}}, 'b': {'HandleId': '28', 'Data': {'x': 8}}, 'ref': {'HandleRefId': '17'}}
        after = {'a': {'HandleId': '0', 'Data': {'x': 7}}, 'b': {'HandleId': '1', 'Data': {'x': 8}}, 'ref': {'HandleRefId': '0'}}
        self.assertEqual(assets.canonical_graph(before), assets.canonical_graph(after))
        after['ref']['HandleRefId'] = '1'
        self.assertNotEqual(assets.canonical_graph(before), assets.canonical_graph(after))
        after['ref']['HandleRefId'] = 'missing'
        with self.assertRaises(ValueError):
            assets.canonical_graph(after)

    def test_archive_preserves_segment_boundaries_and_dependency_ranges(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / 'fixture.archive'
            row = bytes(36) + hashlib.sha1(b'fixture').digest()
            assets.write_archive(file, {7: (row, [(b'first', 5), (b'KARKcompressed', 123)], [42, 43]), 3: (row, [(b'next', 4)], [])})
            archive = assets.Archive(file)
            _, segments, dependencies = archive.stored(7)
            self.assertEqual(segments, [(b'first', 5), (b'KARKcompressed', 123)])
            self.assertEqual(dependencies, [42, 43])
            self.assertEqual(archive.stored(3)[2], [])
            data = file.read_bytes(); position, size = struct.unpack_from('<QI', data, 8)
            index = data[position:position + size]
            self.assertEqual(struct.unpack_from('<Q', index, 8)[0], assets.crc64(index[16:]))

    def test_mac_marker_relocation_preserves_chunk_and_all_checksums(self):
        data = bytearray(160)
        struct.pack_into('<4sI', data, 0, b'CR2W', 195)
        pool = b'\0C2dArray\0PLATFORM_PC\0data\0'
        strings = len(data); data += pool
        names = len(data)
        for offset in [1, 10, 22]:
            data += struct.pack('<II', offset, 0)
        chunk_table = len(data); data += bytes(24)
        chunk_offset = len(data); payload = b'\0unchanged typed factory payload\0'
        data += payload
        struct.pack_into('<II', data, 24, len(data), len(data))
        struct.pack_into('<III', data, 40, strings, len(pool), zlib.crc32(pool))
        struct.pack_into('<III', data, 52, names, 3, 0)
        struct.pack_into('<III', data, 88, chunk_table, 1, 0)
        struct.pack_into('<II', data, chunk_table + 8, len(payload), chunk_offset)
        output = assets.mac_factory(data)
        self.assertIn(b'PLATFORM_Mac\0', output)
        relocated = struct.unpack_from('<I', output, chunk_table + 1 + 12)[0]
        self.assertEqual(output[relocated:], payload)
        for table, stride in [(0, 1), (1, 8), (4, 24)]:
            offset, count, crc = struct.unpack_from('<III', output, 40 + table * 12)
            self.assertEqual(zlib.crc32(output[offset:offset + count * stride]), crc)
        header = bytearray(output[:160]); expected = struct.unpack_from('<I', header, 32)[0]
        struct.pack_into('<I', header, 32, 0xdeadbeef)
        self.assertEqual(zlib.crc32(header), expected)
        with self.assertRaises(ValueError):
            assets.mac_factory(output)

if __name__ == '__main__':
    unittest.main()
