import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from import_lethal_curves import GROUPS, import_builder


class LethalPresetImportTests(unittest.TestCase):
    def fixture(self, path, include_gameplay=True):
        with zipfile.ZipFile(path, 'w') as archive:
            for rig, value in [('woman_base', 0.2405), ('player_woman', 0.2536)]:
                if rig == 'player_woman' and not include_gameplay:
                    continue
                for group in GROUPS:
                    name = f'builder/_internal/resources/presets/2.1.0/default/{group}/{group}__2__{rig}.json'
                    archive.writestr(name, json.dumps({group + '_bone': {'Translation': {'X': value}}}))

    def test_keeps_authored_gameplay_values_separate_from_preview_values(self):
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / 'builder.zip', Path(folder) / 'preset.zip'
            self.fixture(source)
            recipe = import_builder(source, output)
            self.assertEqual(recipe['bones']['arms_bone']['Translation']['X'], 0.2405)
            self.assertEqual(recipe['firstPersonBones']['arms_bone']['Translation']['X'], 0.2536)
            self.assertEqual(len(recipe['inputs']), 12)
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.namelist(), ['cybermac-body-preset.json'])

    def test_missing_gameplay_preset_does_not_produce_partial_package(self):
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / 'builder.zip', Path(folder) / 'preset.zip'
            self.fixture(source, include_gameplay=False)
            with self.assertRaisesRegex(ValueError, 'Missing'):
                import_builder(source, output)
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
