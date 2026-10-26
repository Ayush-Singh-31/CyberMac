#!/usr/bin/env python3
"""Add three pinned Jinguji garments to the verified isolated Lucy bundle.

Uses the existing Lucy archive/CR2W tooling. Only small selected resources are
extracted; no game files are modified and no game archives are copied here.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import zipfile

import prepare_lucy_assets as a

RECIPES = [
    dict(key='corset', label='CyberMac Jinguji Corset - Black Silver', source='Items.TShirt_06_basic_01',
         record='Items.CyberMac_Jinguji_Corset', folder='torso', app='t1_tshirt_06',
         entity='player_inner_torso_item', prefix='t1_tshirt_06_basic_01_',
         entry='JingujiAllInOne/Corset Top/Jinguji_MuscleTankToCorsetBlackSilver.archive',
         sha256='892d84a512e8124a62518829fb375c0d7de3390146921eb21f95769905fcb7cb'),
    dict(key='pants', label='CyberMac Jinguji Judy Pants - Black', source='Items.Pants_10_basic_01',
         record='Items.CyberMac_Jinguji_Pants', folder='legs', app='l1_pants_10',
         entity='player_legs_item', prefix='l1_pants_10_basic_01_',
         entry='JingujiAllInOne/Judy Pants/Jinguji_ShinosToJudyPantsBlack.archive',
         sha256='6316f0a15d4f04cb7bd040527a680bcf026f003164c49f69222fcd7f9801d18e'),
    dict(key='heels', label='CyberMac Jinguji Chrome Heels', source='Items.Boots_05_basic_01',
         record='Items.CyberMac_Jinguji_Heels', folder='feet', app='s1_boots_05',
         entity='player_feet_item', prefix='s1_boots_05_basic_01_',
         entry='JingujiAllInOne/Chrome Heels/Jinguji_FleetsToChromeHeels.archive',
         sha256='4cac455d865db1b6a91dffb603d9793132d0bc43cb6ebffe4c21a888b505fe4c'),
]
LUCY_SHA = 'c5e7ac0a4c4d45ade29c93b36192a6fd1405f06711f661a0285806b0d195ceb2'


def nodes(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from nodes(child)
    elif isinstance(value, list):
        for child in value:
            yield from nodes(child)


def select_mesh_appearance(value, mesh_path, appearance):
    """Update both compiled components and their name-addressed part overrides.

    Jinguji's meshes expose their chosen colour as `default`; leaving the donor's
    grey/camo/leather appearance would select a name absent from these meshes.
    Shadow components and unrelated part overrides must retain their settings.
    """
    components = set()
    for node in nodes(value):
        if node.get('mesh', {}).get('DepotPath', {}).get('$value') == mesh_path:
            a.require('meshAppearance' in node and 'name' in node, 'Unexpected garment component')
            components.add(node['name']['$value'])
            node['meshAppearance']['$value'] = appearance
    a.require(components, 'Selected appearance does not contain its replacement mesh')
    for node in nodes(value):
        if node.get('$type') == 'appearancePartComponentOverrides' and node['componentName']['$value'] in components:
            node['meshAppearance']['$value'] = appearance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game-app', 'jinguji-zip', 'lucy-assets', 'wolvenkit-dll', 'dotnet', 'kraken', 'out']:
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    game, out = args.game_app.resolve(), args.out.resolve()
    a.require(not out.exists() and not out.is_relative_to(game), 'Use a new workspace outside the game')
    lucy_manifest = json.loads(args.lucy_assets.read_text())
    lucy_path = args.lucy_assets.parent / lucy_manifest['archive']
    a.require(lucy_manifest['version'] == 2 and a.sha(lucy_path) == LUCY_SHA == lucy_manifest['archiveSHA256'], 'Use the verified Lucy v2 bundle')
    lucy = a.Archive(lucy_path)
    a.require(len(lucy.rows) == 42, 'Unexpected Lucy inventory')
    codec = a.Codec(args.kraken.resolve())
    out.mkdir(parents=True)
    folders = {n: out / n for n in ['extracted', 'decoded', 'edits', 'rebuilt', 'checked', 'sources']}
    for path in folders.values():
        path.mkdir()

    def convert(mode, source, destination):
        result = subprocess.run([str(args.dotnet), str(args.wolvenkit_dll.resolve()), 'convert', mode,
                                 str(source), '-o', str(destination)],
                                env=dict(os.environ, DOTNET_ROLL_FORWARD='Major'), capture_output=True,
                                text=True, timeout=120)
        (out / f'{mode}-{source.name}.log').write_text(result.stdout + result.stderr)
        a.require(result.returncode == 0, f'WolvenKit {mode} failed; see log')

    official = {}
    for path in sorted((game / 'Contents/Data/archive/Mac').rglob('*.archive')):
        archive = a.Archive(path)
        for key in archive.rows:
            official.setdefault(key, []).append(archive)

    def extract(path):
        owners = official.get(a.fnv(path), [])
        a.require(len(owners) == 1, 'Missing/ambiguous official resource: ' + path)
        dest = folders['extracted'] / Path(path.replace('\\', '/')).name
        a.require(not dest.exists(), 'Extraction basename collision')
        dest.write_bytes(owners[0].extract(a.fnv(path), codec))

    recipes = copy.deepcopy(RECIPES)
    # Decode the factory from the pinned bundle, not an editable intermediate
    # JSON left by an earlier build.
    (folders['extracted'] / 'clothing.csv').write_bytes(lucy.extract(a.fnv(a.FACTORY), codec))
    with zipfile.ZipFile(args.jinguji_zip) as package:
        for recipe in recipes:
            info = package.getinfo(recipe['entry'])
            a.require(info.file_size <= 1024 * 1024, 'Unexpected Jinguji archive size')
            path = folders['sources'] / (recipe['key'] + '.archive')
            path.write_bytes(package.read(info))
            a.require(a.sha(path) == recipe['sha256'], 'Unsupported Jinguji variant')
            recipe['archive'] = a.Archive(path)
            a.require(len(recipe['archive'].rows) == 1, 'Expected one replacement mesh')
            recipe['meshHash'] = next(iter(recipe['archive'].rows))
            recipe['entityPath'] = 'base\\gameplay\\items\\equipment\\' + recipe['folder'] + '\\' + recipe['entity'] + '.ent'
            recipe['appPath'] = 'base\\characters\\appearances\\player\\items\\' + recipe['folder'] + '\\' + recipe['app'] + '.app'
            recipe['entityName'] = 'cybermac_jinguji_' + recipe['key']
            recipe['appearanceName'] = recipe['entityName'] + '_'
            recipe['newEntity'] = 'cybermac\\jinguji\\' + recipe['key'] + '.ent'
            recipe['newApp'] = 'cybermac\\jinguji\\' + recipe['key'] + '.app'
            extract(recipe['entityPath']); extract(recipe['appPath'])
    convert('serialize', folders['extracted'], folders['decoded'])

    def read(path):
        return json.loads((folders['decoded'] / (Path(path.replace('\\', '/')).name + '.json')).read_text())

    for recipe in recipes:
        entity, app = read(recipe['entityPath']), read(recipe['appPath'])
        entity['Data']['RootChunk']['appearances'] = [e for e in entity['Data']['RootChunk']['appearances']
                                                     if e['name']['$value'].startswith(recipe['prefix'] + '&Female')]
        a.require(entity['Data']['RootChunk']['appearances'], 'No feminine donor selectors')
        names = {e['appearanceName']['$value'] for e in entity['Data']['RootChunk']['appearances']}
        app['Data']['RootChunk']['appearances'] = [e for e in app['Data']['RootChunk']['appearances'] if e['Data']['name']['$value'] in names]
        a.require({e['Data']['name']['$value'] for e in app['Data']['RootChunk']['appearances']} == names, 'Missing appearance definitions')
        meshes = {p for p in a.depot_paths(app) if a.fnv(p) == recipe['meshHash']}
        a.require(len(meshes) == 1, 'Replacement mesh does not resolve in chosen donor')
        recipe['mesh'] = meshes.pop()
        recipe['parts'] = sorted({p for p in a.depot_paths(app) if p.endswith('.ent')})
        a.require(recipe['parts'], 'No garment part entities')
        for path in recipe['parts']:
            extract(path)
        a.isolate_appearance_names(entity, app, recipe['prefix'], recipe['appearanceName'])
        select_mesh_appearance(app, recipe['mesh'], 'default')
        recipe['entityJSON'], recipe['appJSON'] = entity, app
    convert('serialize', folders['extracted'], folders['decoded'])

    generated = {}

    def edit(path, value, mappings):
        a.remap(value, mappings)
        value['Data']['RootChunk']['cookingPlatform'] = 'PLATFORM_PC'
        filename = Path(path.replace('\\', '/')).name + '.json'
        a.require(filename not in generated, 'Generated filename collision')
        generated[filename] = (path, value)
        (folders['edits'] / filename).write_text(json.dumps(value, indent=2))

    resources = {key: lucy.stored(key) for key in lucy.rows}
    factory = read(a.FACTORY)
    for recipe in recipes:
        mappings = {recipe['appPath']: recipe['newApp'], recipe['mesh']: 'cybermac\\jinguji\\' + recipe['key'] + '.mesh'}
        for path in recipe['parts']:
            mappings[path] = 'cybermac\\jinguji\\' + recipe['key'] + '_' + f'{a.fnv(path):016x}' + '.ent'
        edit(recipe['newEntity'], recipe.pop('entityJSON'), mappings)
        edit(recipe['newApp'], recipe.pop('appJSON'), mappings)
        for path in recipe['parts']:
            part = read(path)
            select_mesh_appearance(part, recipe['mesh'], 'default')
            edit(mappings[path], part, mappings)
        key = a.fnv(mappings[recipe['mesh']])
        a.require(key not in resources and key not in official, 'Mesh alias collision')
        resources[key] = recipe.pop('archive').stored(recipe['meshHash'])
        for field in ['data', 'compiledData']:
            rows = factory['Data']['RootChunk'][field]
            a.require(not any(row[0] == recipe['entityName'] for row in rows), 'Factory key collision')
            rows.append([recipe['entityName'], recipe['newEntity'], 'true'])
    edit(a.FACTORY, factory, {})
    convert('deserialize', folders['edits'], folders['rebuilt'])
    convert('serialize', folders['rebuilt'], folders['checked'])
    for filename, (path, expected) in generated.items():
        actual = json.loads((folders['checked'] / filename).read_text())
        a.require(a.canonical_graph(actual['Data']) == a.canonical_graph(expected['Data']), 'Semantic round trip failed: ' + filename)
        data = (folders['rebuilt'] / filename.removesuffix('.json')).read_bytes()
        if path == a.FACTORY:
            data = a.mac_factory(data)
            (folders['rebuilt'] / filename.removesuffix('.json')).write_bytes(data)
        else:
            a.require(a.fnv(path) not in official and a.fnv(path) not in resources, 'Generated resource collision')
        resources[a.fnv(path)] = a.resource_record(path, data)
    # Re-read the relocated Mac factory after restoring its cooking marker.
    convert('serialize', folders['rebuilt'], folders['checked'])
    reread_factory = json.loads((folders['checked'] / 'clothing.csv.json').read_text())['Data']['RootChunk']
    for field in ['data', 'compiledData']:
        a.require(reread_factory[field] == factory['Data']['RootChunk'][field], 'Mac factory rows changed during relocation')
    original_meshes = set(lucy_manifest['originalMeshHashes']) | {f'0x{r["meshHash"]:016x}' for r in recipes}
    a.require(not {int(h, 16) for h in original_meshes}.intersection(resources), 'Original mesh would be overwritten')
    a.require(set(resources).intersection(official) == {a.fnv(a.FACTORY)}, 'Unexpected original replacement')
    for _, _, deps in resources.values():
        a.require(all(d in official or d in resources for d in deps), 'Unresolved asset dependency')
    # Lucy payloads/metadata/dependencies are reused verbatim, apart from the factory's extra rows.
    for key in lucy.rows:
        if key != a.fnv(a.FACTORY):
            a.require(resources[key] == lucy.stored(key), 'Lucy resource changed')
    archive = out / 'wardrobe-isolated.archive'
    a.write_archive(archive, resources)
    manifest = dict(version=1, kind='lucy-jinguji', archive=archive.name, archiveSHA256=a.sha(archive),
                    lucyArchiveSHA256=LUCY_SHA, recipes=recipes,
                    resourceHashes=[f'0x{k:016x}' for k in sorted(resources)], originalMeshHashes=sorted(original_meshes),
                    gameplay='unverified Jinguji; feminine V; Lucy payloads preserved; donor icons')
    (out / 'wardrobe-assets.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared:', out / 'wardrobe-assets.json')


if __name__ == '__main__':
    main()
