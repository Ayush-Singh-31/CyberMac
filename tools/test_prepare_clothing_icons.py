import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import prepare_clothing_icons as icons


class IconWorkspaceCleanupTests(unittest.TestCase):
    def arguments(self,root):
        args=['prepare_clothing_icons']
        for key in ['workspace','assets','templates','game-app','wolvenkit-dll','dotnet','kraken','blender','addon-source']:
            args += ['--'+key,str(root/key)]
        return args+['--out',str(root/'output')]

    def test_failed_export_removes_large_intermediates_and_keeps_diagnostics(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            def fail(args,out,game):
                (out/'depot').mkdir(parents=True)
                (out/'depot/large-texture').write_bytes(bytes(1024))
                (out/'failure.log').write_text('The original conversion error')
                raise ValueError('Conversion failed')
            with patch.object(sys,'argv',self.arguments(root)),patch.object(icons,'prepare',side_effect=fail):
                with self.assertRaisesRegex(ValueError,'Conversion failed'):icons.main()
            self.assertFalse((root/'output/depot').exists())
            self.assertEqual((root/'output/failure.log').read_text(),'The original conversion error')

    def test_existing_output_is_rejected_without_removing_its_files(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);(root/'output/depot').mkdir(parents=True)
            file=root/'output/depot/existing';file.write_text('Keep this')
            with patch.object(sys,'argv',self.arguments(root)),patch.object(icons,'prepare') as prepare:
                with self.assertRaisesRegex(ValueError,'new icon workspace'):icons.main()
                prepare.assert_not_called()
            self.assertEqual(file.read_text(),'Keep this')


if __name__=='__main__':unittest.main()
