import struct
import unittest
import zlib

from body_asset_codec import canonical, remap_paths, restore_mac_platform
from prepare_body_mod import apply_authored_preset


def fixture():
    pool = b'PLATFORM_PC\0body\\rig.rig\0entEntityTemplate\0'
    header = bytearray(160)
    header[:4] = b'CR2W'
    struct.pack_into('<I', header, 4, 195)
    data = header + pool
    tables = [[160, len(pool), zlib.crc32(pool)]] + [[0, 0, 0] for _ in range(9)]
    for table, payload, count in [(1, struct.pack('<IIII', 0, 0, 24, 0), 2),
                                   (2, struct.pack('<IHH', 12, 1, 0), 1),
                                   (3, bytes(16), 1)]:
        tables[table] = [len(data), count, zlib.crc32(payload)]
        data.extend(payload)
    tables[4] = [len(data), 2, 0]; data.extend(bytes(48))
    tables[5] = [len(data), 1, 0]; data.extend(bytes(24))
    for index, payload in enumerate([b'player component', b'Mac component']):
        pos = tables[4][0] + index * 24
        struct.pack_into('<II', data, pos + 8, len(payload), len(data))
        struct.pack_into('<I', data, pos + 16, zlib.crc32(payload))
        data.extend(payload)
    struct.pack_into('<I', data, 24, len(data))
    payload = b'AM64\0opaque physics buffer'
    struct.pack_into('<IIII', data, tables[5][0] + 8, len(data), len(payload), len(payload), zlib.crc32(payload))
    data.extend(payload)
    struct.pack_into('<I', data, 28, len(data))
    for index, table in enumerate(tables): struct.pack_into('<III', data, 40 + index * 12, *table)
    return bytes(data)


class BodyCodecTests(unittest.TestCase):
    def test_authored_values_are_absolute_and_keep_unrelated_mac_rig_data(self):
        root = {'boneNames': [{'$value': 'l_thigh_0_JNT'}], 'cookingPlatform': 'PLATFORM_None',
                'boneTransforms': [{'Scale': {'X': 1.5, 'Y': 1, 'Z': 1}, 'Translation': {'X': 0.14, 'Y': 0, 'Z': 0}}],
                'aPoseLS': ['unchanged reference pose']}
        apply_authored_preset(root, {'l_thigh_0_JNT': {'Scale': {'X': 2}, 'Translation': {'X': 0.2}}})
        self.assertEqual(root['boneTransforms'][0]['Scale'], {'X': 2, 'Y': 1, 'Z': 1})
        self.assertEqual(root['boneTransforms'][0]['Translation']['X'], 0.2)
        self.assertEqual(root['aPoseLS'], ['unchanged reference pose'])
        self.assertEqual(root['cookingPlatform'], 'PLATFORM_None')

    def test_preset_with_missing_bone_is_rejected_before_editing(self):
        root = {'boneNames': [{'$value': 'known'}], 'boneTransforms': []}
        with self.assertRaisesRegex(ValueError, 'missing'): apply_authored_preset(root, {'unknown': {'Scale': {'X': 2}}})

    def test_platform_relocation_preserves_all_chunk_and_buffer_payloads_and_import(self):
        original = fixture(); result = restore_mac_platform(original)
        self.assertIn(b'PLATFORM_Mac\0', result)
        for table, stride, offset_field, size_field in [(4, 24, 12, 8), (5, 24, 8, 12)]:
            before, count, _ = struct.unpack_from('<III', original, 40 + table * 12)
            after, new_count, crc = struct.unpack_from('<III', result, 40 + table * 12)
            self.assertEqual(count, new_count)
            self.assertEqual(crc, zlib.crc32(result[after:after + count * stride]))
            for i in range(count):
                old_offset = struct.unpack_from('<I', original, before + i * stride + offset_field)[0]
                new_offset = struct.unpack_from('<I', result, after + i * stride + offset_field)[0]
                size = struct.unpack_from('<I', original, before + i * stride + size_field)[0]
                self.assertEqual(original[old_offset:old_offset + size], result[new_offset:new_offset + size])
        imports = struct.unpack_from('<I', result, 64)[0]
        path_offset = struct.unpack_from('<I', result, imports)[0]
        self.assertEqual(result[160 + path_offset:].split(b'\0')[0], b'body\\rig.rig')
        header = bytearray(result[:160]); expected = struct.unpack_from('<I', header, 32)[0]
        struct.pack_into('<I', header, 32, 0xdeadbeef)
        self.assertEqual(expected, zlib.crc32(header))

    def test_unsupported_embedded_resource_is_rejected(self):
        data = bytearray(fixture()); struct.pack_into('<I', data, 40 + 6 * 12 + 4, 1)
        with self.assertRaisesRegex(ValueError, 'Embedded'): restore_mac_platform(data)

    def test_remap_reaches_compiled_components_without_changing_other_data(self):
        path = lambda value: {'DepotPath': {'$storage': 'string', '$value': value}}
        doc = {'component': path('shared.rig'), 'compiledData': {'Chunks': [path('shared.rig')]}, 'physics': 'AM64'}
        self.assertEqual(remap_paths(doc, {'shared.rig': 'player.rig'}), 2)
        self.assertEqual(doc['component'], path('player.rig'))
        self.assertEqual(doc['compiledData']['Chunks'], [path('player.rig')])
        self.assertEqual(doc['physics'], 'AM64')

    def test_graph_comparison_keeps_reference_relationships(self):
        first = [{'HandleId': '1'}, {'HandleId': '2', 'ref': {'HandleRefId': '1'}}]
        same = [{'HandleId': '8'}, {'HandleId': '4', 'ref': {'HandleRefId': '8'}}]
        different = [{'HandleId': '8'}, {'HandleId': '4', 'ref': {'HandleRefId': '4'}}]
        self.assertEqual(canonical(first), canonical(same))
        self.assertNotEqual(canonical(first), canonical(different))


if __name__ == '__main__': unittest.main()
