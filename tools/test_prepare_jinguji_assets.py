import copy
import unittest

import prepare_jinguji_assets as j


class JingujiAssetsTests(unittest.TestCase):
    def test_material_selection_updates_compiled_and_part_overrides_only_for_garment(self):
        def mesh(name, path, appearance):
            return {'$type': 'entGarmentSkinnedMeshComponent', 'name': {'$value': name},
                    'mesh': {'DepotPath': {'$value': path}}, 'meshAppearance': {'$value': appearance}}
        garment = mesh('corset', 'donor.mesh', 'grey')
        shadow = mesh('shadow', 'shadow.mesh', 'shadow')
        override = {'$type': 'appearancePartComponentOverrides', 'componentName': {'$value': 'corset'},
                    'meshAppearance': {'$value': 'grey'}, 'chunkMask': '127'}
        other = copy.deepcopy(override)
        other['componentName']['$value'] = 'another'
        value = {'compiledData': {'Chunks': [garment, shadow]}, 'overrides': [override, other]}
        j.select_mesh_appearance(value, 'donor.mesh', 'default')
        self.assertEqual(garment['meshAppearance']['$value'], 'default')
        self.assertEqual(override['meshAppearance']['$value'], 'default')
        self.assertEqual(override['chunkMask'], '127')
        self.assertEqual(shadow['meshAppearance']['$value'], 'shadow')
        self.assertEqual(other['meshAppearance']['$value'], 'grey')

    def test_wrong_donor_mesh_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'does not contain'):
            j.select_mesh_appearance({'compiledData': {'Chunks': []}}, 'missing.mesh', 'default')


if __name__ == '__main__':
    unittest.main()
