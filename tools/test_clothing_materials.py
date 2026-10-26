import unittest
from clothing_materials import Materials,mesh_appearances


def name(s):return {'$value':s}
def ref(s):return {'DepotPath':name(s)}


class MaterialSelectionTests(unittest.TestCase):
    def test_component_selectors_are_preserved_and_conflicts_rejected(self):
        component={'mesh':ref('cybermac\\lucy\\top.mesh'),'meshAppearance':name('blue_moro')}
        self.assertEqual(mesh_appearances({'components':[component,component]}),{'cybermac\\lucy\\top.mesh':'blue_moro'})
        other=dict(component,meshAppearance=name('different'))
        with self.assertRaisesRegex(ValueError,'Conflicting'):mesh_appearances([component,other])

    def test_lucy_sole_replacement_material_ignores_stale_donor_indices(self):
        path='cybermac/lucy/example.mesh'
        instance={'baseMaterial':ref('engine/materials/multilayered.mt'),'enableMask':0,
                  'values':[{'$type':'rRef:Multilayer_Setup','MultilayerSetup':ref('base/lucy.mlsetup')}]}
        mesh={'localMaterialBuffer':{'materials':[instance]},'appearances':[{
            'Data':{'name':name('donor_skin'),'chunkMaterials':[name('old'),name('old')]}}]}
        m=object.__new__(Materials);m.cache={path:mesh}
        result=m.mesh(path)
        self.assertEqual(result['chunks'],['garment','garment'])
        self.assertEqual(result['materials']['garment']['data']['MultilayerSetup'],'base/lucy.mlsetup')

    def test_unknown_jinguji_selector_fails_instead_of_guessing(self):
        path='cybermac/jinguji/example.mesh'
        mesh={'localMaterialBuffer':{'materials':[]},'appearances':[]}
        m=object.__new__(Materials);m.cache={path:mesh}
        with self.assertRaisesRegex(ValueError,'Missing selected mesh appearance'):m.mesh(path,'absent')


if __name__=='__main__':unittest.main()
