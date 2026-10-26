import json
from pathlib import Path
import struct
import tempfile
import unittest
from render_clothing_package import approximate_color, metadata, requested_paths, safe_depot, visible_chunks


class PreviewTests(unittest.TestCase):
    def test_only_a_small_requested_batch_is_rendered(self):
        entries = [f'Clothes/{n}.archive' for n in range(214)]
        self.assertEqual(len(requested_paths(entries, None)), 4)
        self.assertEqual(len(requested_paths(entries, entries)), 6)
        self.assertEqual(requested_paths(entries, [entries[100]]), {entries[100]})

    def test_colour_tokens_do_not_confuse_tattered_with_red(self):
        self.assertEqual(approximate_color('Jinguji_TatteredTankToBandeauBraBlue.archive'), [.04,.15,.50,1])
        self.assertEqual(approximate_color('Jinguji_TatteredTankToBandeauBraCarol.archive'), [.34,.36,.40,1])
        self.assertEqual(approximate_color('Jinguji_DressSequinGold.archive'), [.65,.40,.10,1])

    def test_metadata_is_not_a_second_garment(self):
        self.assertTrue(metadata('__MACOSX/Clothes/._bra.archive'))
        self.assertFalse(metadata('Clothes/bra.archive'))

    def test_material_paths_cannot_escape_the_workspace(self):
        for path in ['../outside', '/outside', 'base/../../outside', 'base/\0bad']:
            with self.assertRaises(ValueError): safe_depot(path)

    def test_empty_submeshes_are_not_rendered_as_clothing(self):
        doc = dict(bufferViews=[dict(byteOffset=0,byteLength=36),dict(byteOffset=36,byteLength=6)],
                   accessors=[dict(bufferView=0,componentType=5126,count=3,type='VEC3'),dict(bufferView=1,componentType=5123,count=3,type='SCALAR')],
                   meshes=[dict(name='submesh_00_LOD_1',primitives=[dict(attributes=dict(POSITION=0),indices=1)])])
        header = json.dumps(doc).encode(); header += b' '*((-len(header))%4)
        def model(vertices):
            blob = struct.pack('<9f3H',*vertices,0,1,2)
            return b'glTF'+struct.pack('<II',2,28+len(header)+len(blob))+struct.pack('<I4s',len(header),b'JSON')+header+struct.pack('<I4s',len(blob),b'BIN\0')+blob
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'mesh.glb'
            path.write_bytes(model([0]*9)); self.assertEqual(visible_chunks(path),set())
            path.write_bytes(model([0,0,0,1,0,0,0,1,0])); self.assertEqual(visible_chunks(path),{0})


if __name__ == '__main__': unittest.main()
