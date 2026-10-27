import copy
import hashlib
import io
from pathlib import Path
import tempfile
import unittest
import zipfile

import prepare_clothing_additions as c


class ClothingAdditionsTests(unittest.TestCase):
    def material_graph(self, sizes=(941, 919)):
        materials = [{'$type': 'CMaterialInstance', 'path': f'material-{i}.mlsetup'} for i in range(len(sizes))]
        offset, headers = 0, []
        for size in sizes:
            headers.append({'$type': 'meshLocalMaterialHeader', 'offset': offset, 'size': size})
            offset += size
        return {'RootChunk': {'$type': 'CMesh', 'geometry': 'unchanged', 'localMaterialBuffer': {
            '$type': 'meshMeshMaterialBuffer', 'materials': materials, 'rawDataHeaders': headers,
            'rawData': {'Data': {'Files': [{'RootChunk': copy.deepcopy(m)} for m in materials]}}}}}

    def test_material_path_relocation_allows_only_recalculated_byte_layout(self):
        expected, actual = self.material_graph(), self.material_graph((882, 919))
        original = copy.deepcopy(expected)
        self.assertEqual(c.conversion_graph(expected), c.conversion_graph(actual))
        self.assertEqual(expected, original, 'Validation must not mutate the source graph')
        actual['RootChunk']['geometry'] = 'lost geometry'
        self.assertNotEqual(c.conversion_graph(expected), c.conversion_graph(actual))

    def test_changed_material_contents_are_still_rejected(self):
        expected, actual = self.material_graph(), self.material_graph((882, 919))
        buffer = actual['RootChunk']['localMaterialBuffer']
        buffer['materials'][0]['path'] = 'wrong.mlsetup'
        with self.assertRaises(ValueError): c.conversion_graph(actual)
        buffer['rawData']['Data']['Files'][0]['RootChunk']['path'] = 'wrong.mlsetup'
        self.assertNotEqual(c.conversion_graph(expected), c.conversion_graph(actual))

    def test_invalid_material_offsets_and_missing_materials_are_rejected(self):
        for change in ['gap', 'negative_size', 'missing_header', 'missing_buffer_material']:
            doc = self.material_graph()
            buffer = doc['RootChunk']['localMaterialBuffer']
            if change == 'gap': buffer['rawDataHeaders'][1]['offset'] += 1
            elif change == 'negative_size': buffer['rawDataHeaders'][0]['size'] = -1
            elif change == 'missing_header': buffer['rawDataHeaders'].pop()
            else: buffer['rawData']['Data']['Files'].pop()
            with self.assertRaises(ValueError, msg=change): c.conversion_graph(doc)

    def test_one_archive_can_expose_two_garments_for_the_same_slot(self):
        def template(prefix, mesh):
            return dict(root='feet', prefix=prefix, appPath=prefix + '.app', meshes=[mesh])
        templates = [template('boots_basic_01_', 'boots.mesh'), template('boots_basic_02_', 'boots.mesh'), template('shoes_basic_01_', 'shoes.mesh')]
        chosen = c.matching_templates(templates, {c.a.fnv('boots.mesh'), c.a.fnv('shoes.mesh')})
        self.assertEqual([x['prefix'] for x in chosen], ['boots_basic_01_', 'shoes_basic_01_'])

    def test_colour_alternatives_get_independent_item_and_factory_identities(self):
        pink = c.identity(hashlib.sha256(b'pink mesh').hexdigest(), 'feet', 'boots_')
        gold = c.identity(hashlib.sha256(b'gold mesh').hexdigest(), 'feet', 'boots_')
        self.assertNotEqual(pink, gold)
        self.assertEqual(pink, c.identity(hashlib.sha256(b'pink mesh').hexdigest(), 'feet', 'boots_'))

    def test_resource_references_and_embedded_file_names_are_namespaced_together(self):
        def path(value): return {'$type': 'ResourcePath', '$storage': 'string', '$value': value}
        doc = {'mesh': {'DepotPath': path('original.mesh')},
               'EmbeddedFiles': [{'FileName': path('material.mi'), 'Content': {'normal': {'DepotPath': path('vanilla.xbm')}}}]}
        c.namespace_paths(doc, {c.a.fnv('original.mesh'): 'cybermac/new.mesh', c.a.fnv('material.mi'): 'cybermac/material.mi'})
        self.assertEqual(doc['mesh']['DepotPath']['$value'], 'cybermac/new.mesh')
        self.assertEqual(doc['EmbeddedFiles'][0]['FileName']['$value'], 'cybermac/material.mi')
        self.assertEqual(doc['EmbeddedFiles'][0]['Content']['normal']['DepotPath']['$value'], 'vanilla.xbm')

    def test_material_names_support_wolvenkit_handles(self):
        self.assertEqual(c.material_names({'appearances': [{'HandleId': '0', 'Data': {'name': {'$value': 'default'}}}]}), {'default'})

    def test_numeric_resource_paths_are_relocated(self):
        for value in [123, '123', '0x7b']:
            doc = {'$type': 'ResourcePath', '$storage': 'uint64', '$value': value}
            c.namespace_paths(doc, {123: 'cybermac/private.mesh'})
            self.assertEqual(doc['$value'], 'cybermac/private.mesh')
            self.assertEqual(doc['$storage'], 'string')

    def test_duplicate_zip_paths_are_rejected_before_reading_the_selection(self):
        data = io.BytesIO()
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            with zipfile.ZipFile(data, 'w') as z:
                z.writestr('Clothes/Pink.archive', b'first')
                z.writestr('Clothes/Pink.archive', b'second')
        with zipfile.ZipFile(io.BytesIO(data.getvalue())) as z:
            with self.assertRaises(ValueError): c.validate_zip(z)

    def test_zip_path_traversal_and_symlinks_are_rejected(self):
        for name, mode in [('../evil.archive', None), ('link.archive', 0o120777)]:
            data = io.BytesIO()
            with zipfile.ZipFile(data, 'w') as z:
                entry = zipfile.ZipInfo(name)
                if mode: entry.external_attr = mode << 16
                z.writestr(entry, b'test')
            with zipfile.ZipFile(io.BytesIO(data.getvalue())) as z:
                with self.assertRaises(ValueError): c.validate_zip(z)

    def test_finder_metadata_is_not_a_second_garment(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as z:
            z.writestr('Clothes/Pink.archive', b'test')
            z.writestr('__MACOSX/Clothes/._Pink.archive', b'metadata')
        with zipfile.ZipFile(io.BytesIO(data.getvalue())) as z:
            self.assertEqual([x.filename for x in c.validate_zip(z)], ['Clothes/Pink.archive'])

    def test_template_cache_compacts_json_without_changing_graph(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root/'decoded').mkdir()
            doc = {'Data': {'RootChunk': {'type': 'entity'}}}
            import json
            (root/'decoded/test.json').write_text(json.dumps(doc))
            templates = [{'entityJSON': 'decoded/test.json', 'appJSON': 'decoded/test.json'}]
            c.compact_templates(root, templates)
            self.assertFalse((root/'decoded/test.json').exists())
            self.assertEqual(c.read_json(root/templates[0]['entityJSON']), doc)


if __name__ == '__main__': unittest.main()
