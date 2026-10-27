#!/usr/bin/env python3
"""Locate existing conversion tools. Blender and image tools are not required."""
import argparse
import json
from pathlib import Path
from configure_clothing_previews import discover

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    found = discover(Path(__file__).resolve().parent.parent)
    tools = {key: found[key] for key in ['python', 'dotnet', 'wolvenkit', 'kraken']}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(tools, indent=2))
    missing = [key for key, value in tools.items() if not value]
    print('Clothing conversion tools: ' + ('missing ' + ', '.join(missing) if missing else 'ready') + '. Live previews paused.')
