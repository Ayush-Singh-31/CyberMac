#!/usr/bin/env python3
"""Record existing local preview tools; no downloads or environment changes."""
import argparse
import json
import os
from pathlib import Path
import shutil


def discover(root):
    def first(*values):
        return next((str(Path(x).resolve()) for x in values if x and Path(x).exists()), '')
    return dict(
        python=first(os.environ.get('CYBERMAC_PREVIEW_PYTHON'), Path.home()/'.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3', shutil.which('python3')),
        dotnet=first(os.environ.get('CYBERMAC_PREVIEW_DOTNET'), shutil.which('dotnet')),
        blender=first(os.environ.get('CYBERMAC_PREVIEW_BLENDER'), '/Applications/Blender.app/Contents/MacOS/Blender'),
        wolvenkit=first(os.environ.get('CYBERMAC_PREVIEW_WOLVENKIT'), root/'.research/lucy-outfit/wolvenkit-local/WolvenKit.CLI.dll'),
        kraken=first(os.environ.get('CYBERMAC_PREVIEW_KRAKEN'), root/'.research/lucy-outfit/libkraken-full.dylib', root/'.research/lucy-outfit/libkraken.dylib'),
        addonSource=first(os.environ.get('CYBERMAC_PREVIEW_ADDON'), root/'.research/material-preview/addon-source/i_scene_cp77_gltf'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    value = discover(root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(value, indent=2))
    missing = [key for key, path in value.items() if not path and key != 'addonSource']
    print('Clothing preview tools: '+('missing '+', '.join(missing) if missing else 'ready'))
