#!/usr/bin/env python3
"""Extract only authored preset data from the Windows builder. Never runs it."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

GROUPS = ['arms', 'buttocks', 'calves', 'chest', 'lower_thighs', 'upper_thighs']


def import_builder(source, output):
    rigs, inputs = {}, []
    with zipfile.ZipFile(source) as archive:
        for rig in ['woman_base', 'player_woman']:
            bones = rigs.setdefault(rig, {})
            for group in GROUPS:
                suffix = f'/_internal/resources/presets/2.1.0/default/{group}/{group}__2__{rig}.json'
                entries = [entry for entry in archive.infolist() if entry.filename.endswith(suffix)]
                if len(entries) != 1 or entries[0].file_size > 64 * 1024:
                    raise ValueError('Missing or ambiguous authored preset: ' + group)
                entry = entries[0]; data = archive.read(entry)
                preset = json.loads(data)
                if not isinstance(preset, dict) or not preset:
                    raise ValueError('Empty authored preset: ' + group)
                for name, transforms in preset.items():
                    for transform, axes in transforms.items():
                        if transform not in ['Scale', 'Translation']:
                            raise ValueError('Unsupported preset transform')
                        values = bones.setdefault(name, {}).setdefault(transform, {})
                        for axis, value in axes.items():
                            if axis not in ['X', 'Y', 'Z'] or not isinstance(value, (int, float)):
                                raise ValueError('Invalid preset axis')
                            if axis in values and values[axis] != value:
                                raise ValueError('Conflicting authored preset values')
                            values[axis] = value
                inputs.append(dict(path=entry.filename, sha256=hashlib.sha256(data).hexdigest()))
    with open(source, 'rb') as stream:
        source_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
    recipe = dict(format='cybermac-body-preset-v1', name='Lethal Curves maximum gameplay',
                  sourceSHA256=source_hash, bones=rigs['woman_base'], firstPersonBones=rigs['player_woman'],
                  inputs=inputs, groups=GROUPS)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('cybermac-body-preset.json', json.dumps(recipe, indent=2))
    return recipe


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('builder', type=Path); parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    recipe = import_builder(args.builder, args.out)
    print(f'Prepared {len(recipe["bones"])} preview and {len(recipe["firstPersonBones"])} gameplay bone overrides: {args.out}')
