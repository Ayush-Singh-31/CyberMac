#!/usr/bin/env python3
"""Prepare feminine Unique V assets from the installed Mac files. Never installs."""
import argparse
import copy
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

import prepare_lucy_assets as a
from body_asset_codec import canonical, nodes, paths, prepare_mac_write, remap_paths, restore_mac_platform

BASE = 'base\\characters\\base_entities\\woman_base\\deformations_rigs\\'
FIRST_PERSON = 'base\\characters\\entities\\player\\deformations_rigs_wa\\player_woman_base_deformations.rig'
MAPPING = {BASE + 'woman_base_deformations.' + ext: BASE + 'female_plr_deformations.' + ext for ext in ['rig', 'animgraph']}
FEMALE_ENTITIES = {'1c77c037bb303ec1', '33897e69b7c93465', '33ad3ad818aca033', '55e919f317f9d55e',
                   '765e50b58bda6537', '969e1b776584b2cc', 'b0bb924c7f54b5e7', 'ee42aaa3659741ec'}


def apply_authored_preset(root, overrides):
    indexes = {bone['$value']: i for i, bone in enumerate(root['boneNames'])}
    a.require(overrides and set(overrides).issubset(indexes), 'The authored preset has bones missing from this Mac rig')
    for bone, transforms in overrides.items():
        for transform, axes in transforms.items():
            a.require(transform in ['Scale', 'Translation'], 'Unsupported authored transform')
            for axis, value in axes.items():
                a.require(axis in ['X', 'Y', 'Z'] and isinstance(value, (int, float)), 'Invalid authored transform value')
                # Preset values are absolute, not multipliers.
                root['boneTransforms'][indexes[bone]][transform][axis] = value


def equivalent(left, right):
    left, right = canonical(left), canonical(right)
    pending = [(left, right)]
    while pending:
        x, y = pending.pop()
        if isinstance(x, (int, float)) and isinstance(y, (int, float)):
            if isinstance(x, float) or isinstance(y, float):
                if struct.pack('<f', x) != struct.pack('<f', y): return False
            elif x != y: return False
        elif type(x) is not type(y): return False
        elif isinstance(x, dict):
            if x.keys() != y.keys(): return False
            pending.extend((x[k], y[k]) for k in x)
        elif isinstance(x, list):
            if len(x) != len(y): return False
            pending.extend(zip(x, y))
        elif x != y: return False
    return True


def build(request):
    a.require(request['variant'] in ['neutral', 'shoulders', 'lethal'], 'Unknown body preset')
    shared = request.get('scope') == 'shared'
    first_person = (request.get('preset') or {}).get('firstPersonBones')
    output = Path(request['output'])
    output.mkdir(parents=True, exist_ok=True)
    raw, decoded, edits, rebuilt, mac, checked = [output / name for name in ['raw', 'decoded', 'edits', 'rebuilt', 'mac', 'checked']]
    for folder in [raw, decoded, edits, rebuilt, mac, checked]: folder.mkdir(exist_ok=True)
    tools = request['tools']; codec = a.Codec(tools['kraken'])

    def convert(mode, source, destination):
        run = subprocess.run([tools['dotnet'], tools['wolvenkit'], 'convert', mode, str(source), '-o', str(destination)],
            capture_output=True, text=True, timeout=120,
            env=dict(os.environ, DOTNET_ROLL_FORWARD='Major', DOTNET_PROCESSOR_COUNT='2'))
        (output / (mode + '-' + source.name + '.log')).write_text(run.stdout + run.stderr)
        a.require(run.returncode == 0, 'Body asset conversion failed; see conversion log')

    entities = []
    seen = set()
    for index, target in enumerate(request['targets']):
        source = Path(target['source'])
        a.require(a.sha(source) == target['sourceSHA256'], 'Body source archive changed')
        archive = a.Archive(source)
        for hash_ in target['replacementHashes']:
            if first_person and hash_ == f'{a.fnv(FIRST_PERSON):016x}':
                continue
            if shared:
                a.require(hash_ == f'{a.fnv(BASE + "woman_base_deformations.rig"):016x}', 'Unexpected shared rig target')
                continue
            a.require(hash_ in FEMALE_ENTITIES, 'Unknown player template in body recipe')
            name = f'{index}-{hash_}.ent'
            (raw / name).write_bytes(archive.extract(int(hash_, 16), codec))
            entities.append((index, hash_, name)); seen.add(hash_)
    a.require(shared or seen == FEMALE_ENTITIES, 'The Mac game is missing required player templates')
    rig_archive = a.Archive(Path(request['rigSource']))
    for original, private in MAPPING.items():
        if shared and private.endswith('.animgraph'): continue
        (raw / private.split('\\')[-1]).write_bytes(rig_archive.extract(a.fnv(original), codec))
    if first_person:
        (raw / FIRST_PERSON.split('\\')[-1]).write_bytes(rig_archive.extract(a.fnv(FIRST_PERSON), codec))
    convert('serialize', raw, decoded)

    expected = {}
    for file in raw.iterdir():
        doc = json.loads((decoded / (file.name + '.json')).read_text())
        root = doc['Data']['RootChunk']
        a.require(root.get('cookingPlatform') == 'PLATFORM_None', 'Expected native Mac cooking metadata')
        if file.suffix == '.ent':
            a.require(root['$type'] == 'entEntityTemplate', 'Expected a player entity')
            count = remap_paths(root, MAPPING)
            # A repeated install already contains the private paths.
            a.require(count >= 2 or set(MAPPING.values()).issubset(set(paths(root))), 'Player rig references missing')
        elif file.suffix == '.animgraph':
            a.require(root['$type'] == 'animAnimGraph', 'Expected a deformation graph')
            # The framework renames the graph resource but leaves its
            # staticCommandsRig pointing to the original neutral rig. Mapping
            # that reference to the edited rig changes the graph's reference
            # data as well as the player's deformation rig.
            a.require(root['staticCommandsRig']['DepotPath']['$value'] == BASE + 'woman_base_deformations.rig',
                      'Expected the deformation graph to retain its base-rig reference')
        else:
            a.require(root['$type'] == 'animRig', 'Expected a deformation rig')
            if request['variant'] == 'shoulders':
                indexes = [i for i, bone in enumerate(root['boneNames']) if bone['$value'] in ['LeftShoulder', 'RightShoulder']]
                a.require(len(indexes) == 2, 'The rig has no recognizable shoulder bones')
                for index in indexes:
                    for axis in ['X', 'Y', 'Z']: root['boneTransforms'][index]['Scale'][axis] *= 1.2
            if request['variant'] == 'lethal':
                overrides = first_person if file.name == FIRST_PERSON.split('\\')[-1] else request['preset']['bones']
                apply_authored_preset(root, overrides)
        expected[file.name] = copy.deepcopy(root)
        (edits / (file.name + '.json')).write_text(json.dumps(prepare_mac_write(doc)))
    convert('deserialize', edits, rebuilt)
    for file in raw.iterdir():
        (mac / file.name).write_bytes(restore_mac_platform((rebuilt / file.name).read_bytes()))
    convert('serialize', mac, checked)
    for name, wanted in expected.items():
        actual = json.loads((checked / (name + '.json')).read_text())['Data']['RootChunk']
        a.require(equivalent(wanted, actual), 'Rebuilt body resource changed unrelated Mac data: ' + name)

    donors = []
    private_resources = {a.fnv(p): a.resource_record(p, (mac / p.split('\\')[-1]).read_bytes())
                         for p in MAPPING.values() if not shared or p.endswith('.rig')}
    for index, target in enumerate(request['targets']):
        resources = {}
        if shared:
            path = BASE + 'woman_base_deformations.rig'
            resources[a.fnv(path)] = a.resource_record(path, (mac / 'female_plr_deformations.rig').read_bytes())
        if first_person and f'{a.fnv(FIRST_PERSON):016x}' in target['replacementHashes']:
            resources[a.fnv(FIRST_PERSON)] = a.resource_record(FIRST_PERSON, (mac / FIRST_PERSON.split('\\')[-1]).read_bytes())
        for owner, hash_, name in entities:
            if owner != index: continue
            row, segments, _ = a.resource_record('placeholder.ent', (mac / name).read_bytes())
            resources[int(hash_, 16)] = (row, segments, [])
        insertions = []
        if target['insertPrivateResources']:
            resources.update(private_resources)
            insertions = [f'{key:016x}' for key in sorted(private_resources)]
        donor = output / f'body-{index}.archive'
        a.write_archive(donor, resources)
        donors.append(dict(relativePath=target['relativePath'], archive=str(donor), sha256=a.sha(donor),
                           replacements=target['replacementHashes'], privateResources=insertions))
    result = dict(version=1, variant=request['variant'], archives=donors, verifiedResources=len(expected), gameplayVerified=False)
    (output / 'body-assets.json').write_text(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    sys.setrecursionlimit(10000)
    parser = argparse.ArgumentParser(); parser.add_argument('--request', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = build(json.loads(args.request.read_text()))
        print(json.dumps(result))
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr); sys.exit(1)
