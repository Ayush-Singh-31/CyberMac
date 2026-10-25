#!/usr/bin/env python3
"""Build isolated Lucy assets from the user's two pinned ZIPs. Never installs files.

Requires Python 3.11+, WolvenKit CLI 8.18.0 and an ARM64 Kraken library beside its
DLL. Outputs contain game/mod data and must remain in an ignored workspace.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import zipfile
import zlib

JACKET_SHA = '85a010c28a0ca96c689f5fde2f97ec6f3e5be583f7cc9fd2e89b93a3c73db9ab'
CLOTHES_SHA = 'c8d434ce62e2f5eca2d2ec0c4274f7acca3a48c35db45035d19f7cb22a0a1c8f'
FACTORY = r'base\gameplay\factories\items\clothing.csv'
PIECES = [
    ('Jacket', 'torso/player_outer_torso_item.ent', 'torso/t2_vest_08.app', 't2_vest_08_basic_01_'),
    ('Top', 'torso/player_inner_torso_item.ent', 'torso/t1_shirt_01.app', 't1_shirt_01_basic_01_'),
    ('Pants', 'legs/player_legs_item.ent', 'legs/l1_pants_09.app', 'l1_pants_09_basic_01_'),
    ('Boots', 'feet/player_feet_item.ent', 'feet/s1_boots_01.app', 's1_boots_01_basic_01_'),
]

def require(condition, message):
    if not condition:
        raise ValueError(message)

def fnv(path):
    value = 0xcbf29ce484222325
    for byte in path.lower().replace('/', '\\').encode():
        value = ((value ^ byte) * 0x100000001b3) & 0xffffffffffffffff
    return value

def sha(path):
    with open(path, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def crc64(data):
    table = []
    for n in range(256):
        for _ in range(8):
            n = (n >> 1) ^ (0xc96c5795d7870f42 if n & 1 else 0)
        table.append(n)
    crc = 0xffffffffffffffff
    for byte in data:
        crc = (crc >> 8) ^ table[(crc ^ byte) & 255]
    return crc ^ 0xffffffffffffffff

class Codec:
    def __init__(self, path):
        self.lib = ctypes.CDLL(str(path))
        self.lib.Kraken_Decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
        self.lib.Kraken_Decompress.restype = ctypes.c_int

    def decode(self, data, size):
        if len(data) == size:
            return data
        require(0 < size <= 32 * 1024 * 1024, 'Resource metadata exceeds 32 MB')
        require(data[:4] == b'KARK' and struct.unpack_from('<I', data, 4)[0] == size, 'Invalid KARK header')
        destination = ctypes.create_string_buffer(size + 64)
        written = self.lib.Kraken_Decompress(data[8:], len(data) - 8, destination, size)
        require(written == size, 'Kraken decompression failed')
        return destination.raw[:size]

class Archive:
    def __init__(self, path):
        self.path = path
        with open(path, 'rb') as stream:
            header = stream.read(52)
            require(len(header) == 52 and header[:8] == b'RDAR\x0c\0\0\0', 'Unsupported archive')
            position, size = struct.unpack_from('<QI', header, 8)
            require(28 <= size <= 128 * 1024 * 1024 and position + size <= path.stat().st_size, 'Invalid archive index bounds')
            stream.seek(position)
            index = stream.read(size)
        count, segments, deps = struct.unpack_from('<III', index, 16)
        require(28 + count * 56 + segments * 16 + deps * 8 == size, 'Invalid archive table lengths')
        # Swift's NativeArchive independently validates CRC64 when staging.
        self.rows = {}
        for i in range(count):
            row = index[28 + i * 56:28 + (i + 1) * 56]
            key = struct.unpack_from('<Q', row)[0]
            if key in self.rows:
                # Official archives can contain duplicates; reject ambiguous payloads on extraction.
                self.rows[key] = None
            else:
                self.rows[key] = row
        self.segments = [struct.unpack_from('<QII', index, 28 + count * 56 + i * 16) for i in range(segments)]
        at = 28 + count * 56 + segments * 16
        self.dependencies = list(struct.unpack_from(f'<{deps}Q', index, at))

    def stored(self, key):
        row = self.rows[key]
        require(row is not None, f'Ambiguous resource: {key:016x}')
        start, end, first_dep, last_dep = struct.unpack_from('<IIII', row, 20)
        require(start < end <= len(self.segments) and first_dep <= last_dep <= len(self.dependencies), 'Invalid resource ranges')
        pieces = []
        with open(self.path, 'rb') as stream:
            for offset, compressed, size in self.segments[start:end]:
                require(offset >= 52 and offset + compressed <= self.path.stat().st_size, 'Invalid segment bounds')
                stream.seek(offset)
                data = stream.read(compressed)
                require(len(data) == compressed, 'Truncated archive segment')
                pieces.append((data, size))
        return row, pieces, self.dependencies[first_dep:last_dep]

    def extract(self, key, codec):
        _, parts, _ = self.stored(key)
        # CR2W buffer offsets address their stored (already KARK compressed) bytes.
        return codec.decode(*parts[0]) + b''.join(data for data, _ in parts[1:])

def depot_paths(value):
    if isinstance(value, dict):
        path = value.get('DepotPath')
        if isinstance(path, dict) and path.get('$storage') == 'string':
            yield path['$value']
        for child in value.values():
            yield from depot_paths(child)
    elif isinstance(value, list):
        for child in value:
            yield from depot_paths(child)

def remap(value, mappings):
    if isinstance(value, dict):
        path = value.get('DepotPath')
        if isinstance(path, dict) and path.get('$storage') == 'string':
            old = path['$value']
            if old in mappings:
                path['$value'] = mappings[old]
        for child in value.values():
            remap(child, mappings)
    elif isinstance(value, list):
        for child in value:
            remap(child, mappings)

def canonical_graph(value):
    """Compare complete values and reference relationships despite ID renumbering.

    Removing unused appearances makes WKit renumber handles/buffers. References
    must still resolve to the same definitions; simply dropping IDs would hide
    a broken graph.
    """
    handles, buffers = {}, {}
    def definitions(node):
        if isinstance(node, dict):
            for key, mapping in [('HandleId', handles), ('BufferId', buffers)]:
                if key in node:
                    mapping.setdefault(node[key], str(len(mapping)))
            for child in node.values():
                definitions(child)
        elif isinstance(node, list):
            for child in node:
                definitions(child)
    definitions(value)
    def normalize(node):
        if isinstance(node, dict):
            result = {}
            for key, child in node.items():
                mapping = handles if key in ['HandleId', 'HandleRefId'] else buffers if key in ['BufferId', 'BufferRefId'] else None
                if mapping is not None:
                    require(child in mapping, 'Unresolved generated object/buffer reference')
                    result[key] = mapping[child]
                else:
                    result[key] = normalize(child)
            return result
        if isinstance(node, list):
            return [normalize(child) for child in node]
        return node
    return normalize(value)

def mac_factory(data):
    """Restore the Mac cooking marker lost by WKit 8.18's older enum schema.

    Only handles a single-chunk C2dArray without imports/buffers/embedded files.
    Rebuilds the string/name offsets, chunk offset and their CRCs; payload stays
    byte identical. Header CRC follows CR2WWriter.CalculateHeaderCRC32.
    """
    data = bytearray(data)
    require(data[:4] == b'CR2W' and len(data) >= 160, 'Invalid generated factory')
    tables = [list(struct.unpack_from('<III', data, 40 + i * 12)) for i in range(10)]
    require(tables[4][1] == 1 and all(tables[i][1] == 0 for i in [2, 5, 6, 7, 8, 9]), 'Unexpected factory layout')
    start, length, _ = tables[0]
    pool = bytes(data[start:start + length])
    marker = b'PLATFORM_PC\0'
    require(pool.count(marker) == 1, 'Expected one PC cooking marker')
    at = pool.index(marker)
    replacement = b'PLATFORM_Mac\0'
    delta = len(replacement) - len(marker)
    data[start + at:start + at + len(marker)] = replacement
    for table in tables[1:]:
        if table[0]:
            table[0] += delta
    tables[0][1] += delta
    tables[0][2] = zlib.crc32(data[start:start + tables[0][1]])
    name_start, name_count, _ = tables[1]
    mac_hash = 0xcbf29ce484222325
    for byte in b'PLATFORM_Mac':
        mac_hash = ((mac_hash ^ byte) * 0x100000001b3) & 0xffffffffffffffff
    for i in range(name_count):
        offset, name_hash = struct.unpack_from('<II', data, name_start + i * 8)
        if offset == at:
            name_hash = (mac_hash >> 32) ^ (mac_hash & 0xffffffff)
        elif offset > at:
            offset += delta
        struct.pack_into('<II', data, name_start + i * 8, offset, name_hash)
    tables[1][2] = zlib.crc32(data[name_start:name_start + name_count * 8])
    chunk = tables[4][0]
    struct.pack_into('<I', data, chunk + 12, struct.unpack_from('<I', data, chunk + 12)[0] + delta)
    tables[4][2] = zlib.crc32(data[chunk:chunk + 24])
    for position in [24, 28]:
        struct.pack_into('<I', data, position, struct.unpack_from('<I', data, position)[0] + delta)
    for i, table in enumerate(tables):
        struct.pack_into('<III', data, 40 + i * 12, *table)
    struct.pack_into('<I', data, 32, 0xdeadbeef)
    struct.pack_into('<I', data, 32, zlib.crc32(data[:160]))
    return bytes(data)

def resource_record(path, data):
    require(data[:4] == b'CR2W' and len(data) >= 160, 'Generated resource is not CR2W')
    objects_end, buffers_end = struct.unpack_from('<II', data, 24)
    require(160 <= objects_end <= buffers_end == len(data), 'Generated CR2W length mismatch')
    buffer_offset, buffer_count, _ = struct.unpack_from('<III', data, 100)
    segments = [(data[:objects_end], objects_end)]
    cursor = objects_end
    for i in range(buffer_count):
        offset, disk, memory = struct.unpack_from('<III', data, buffer_offset + i * 24 + 8)
        require(offset == cursor and offset + disk <= len(data), 'Noncontiguous generated CR2W buffers')
        segments.append((data[offset:offset + disk], memory))
        cursor += disk
    require(cursor == len(data), 'Unaccounted CR2W bytes')
    row = struct.pack('<QQIIIII', fnv(path), 0, max(0, buffer_count - 1), 0, 0, 0, 0)
    return row + hashlib.sha1(data).digest(), segments, []

def write_archive(path, resources):
    records, segments, dependencies = [], [], []
    with open(path, 'xb') as stream:
        stream.write(bytes(52))
        for key, (row, payloads, deps) in sorted(resources.items()):
            row = bytearray(row)
            struct.pack_into('<Q', row, 0, key)
            struct.pack_into('<IIII', row, 20, len(segments), len(segments) + len(payloads), len(dependencies), len(dependencies) + len(deps))
            for payload, size in payloads:
                segments.append((stream.tell(), len(payload), size))
                stream.write(payload)
            dependencies.extend(deps)
            records.append(bytes(row))
        body = struct.pack('<III', len(records), len(segments), len(dependencies))
        body += b''.join(records) + b''.join(struct.pack('<QII', *s) for s in segments)
        body += b''.join(struct.pack('<Q', d) for d in dependencies)
        index = struct.pack('<IIQ', 8, len(body) + 8, crc64(body)) + body
        position = (stream.tell() + 4095) // 4096 * 4096
        stream.write(bytes(position - stream.tell()))
        stream.write(index)
        length = (stream.tell() + 4095) // 4096 * 4096
        stream.write(bytes(length - stream.tell()))
        header = bytearray(52)
        struct.pack_into('<4sIQI', header, 0, b'RDAR', 12, position, len(index))
        struct.pack_into('<Q', header, 32, length)
        stream.seek(0)
        stream.write(header)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ['game-app', 'jacket-zip', 'clothes-zip', 'wolvenkit-dll', 'dotnet', 'kraken', 'out']:
        parser.add_argument('--' + arg, required=True, type=Path)
    args = parser.parse_args()
    args.out = args.out.resolve()
    game = args.game_app.resolve()
    require(not args.out.is_relative_to(game) and not args.out.exists(), 'Use a new output folder outside the game')
    codec = Codec(args.kraken.resolve())
    seals = plistlib.loads((game / 'Contents/_CodeSignature/CodeResources').read_bytes())['files2']
    for name in ['basegame_4_appearance.archive', 'basegame_4_gamedata.archive']:
        relative = 'Data/archive/Mac/content/' + name
        require(sha(game / 'Contents' / relative) == seals[relative]['hash2'].hex(), 'Restore original game archives first')
    args.out.mkdir(parents=True)
    extracted = args.out / 'extracted'; decoded = args.out / 'decoded'
    edits = args.out / 'edits'; rebuilt = args.out / 'rebuilt'; checked = args.out / 'checked'
    for folder in [extracted, decoded, edits, rebuilt, checked]:
        folder.mkdir()
    def convert(mode, source, destination):
        command = [str(args.dotnet), str(args.wolvenkit_dll.resolve()), 'convert', mode, str(source), '-o', str(destination)]
        result = subprocess.run(command, env=dict(os.environ, DOTNET_ROLL_FORWARD='Major'), capture_output=True, text=True, timeout=120)
        (args.out / f'{mode}-{source.name}.log').write_text(result.stdout + result.stderr)
        require(result.returncode == 0, f'WolvenKit {mode} failed; see preparation log')
    mods = {}
    for name, zip_path, expected in [('jacket', args.jacket_zip, JACKET_SHA), ('clothes', args.clothes_zip, CLOTHES_SHA)]:
        with zipfile.ZipFile(zip_path) as package:
            names = [n for n in package.namelist() if n.endswith('.archive')]
            require(len(names) == 1 and package.getinfo(names[0]).file_size <= 80 * 1024 * 1024, 'Unexpected Lucy package')
            archive_path = args.out / (name + '.archive')
            archive_path.write_bytes(package.read(names[0]))
        require(sha(archive_path) == expected, 'Unsupported Lucy archive version')
        archive = Archive(archive_path)
        for key in archive.rows:
            require(key not in mods, 'Overlapping Lucy archives')
            mods[key] = archive
    official = {}
    for path in sorted((game / 'Contents/Data/archive/Mac').rglob('*.archive')):
        archive = Archive(path)
        for key in archive.rows:
            official.setdefault(key, []).append(path)
    def extract(path):
        owners = official.get(fnv(path), [])
        require(len(owners) == 1, 'Resource owner missing or ambiguous: ' + path)
        archive = Archive(owners[0])
        output = extracted / Path(path.replace('\\', '/')).name
        require(not output.exists(), 'Extraction basename collision')
        output.write_bytes(archive.extract(fnv(path), codec))
        return output
    recipes = []
    extract(FACTORY)
    for piece, entity, app, prefix in PIECES:
        entity = 'base\\gameplay\\items\\equipment\\' + entity.replace('/', '\\')
        app = 'base\\characters\\appearances\\player\\items\\' + app.replace('/', '\\')
        extract(entity); extract(app)
        recipes.append(dict(piece=piece, entity=entity, app=app, prefix=prefix,
            newEntity='cybermac\\lucy\\' + piece.lower() + '.ent',
            newApp='cybermac\\lucy\\' + piece.lower() + '.app', entityName='cybermac_lucy_' + piece.lower()))
    convert('serialize', extracted, decoded)
    def read(path):
        return json.loads((decoded / (Path(path.replace('\\', '/')).name + '.json')).read_text())
    mappings = {}
    parts = set()
    meshes = set()
    for recipe in recipes:
        entity = read(recipe['entity']); app = read(recipe['app'])
        entity['Data']['RootChunk']['appearances'] = [a for a in entity['Data']['RootChunk']['appearances']
            if a['name']['$value'].startswith(recipe['prefix'] + '&Female')]
        require(entity['Data']['RootChunk']['appearances'], 'Missing female entity appearance')
        names = {a['appearanceName']['$value'] for a in entity['Data']['RootChunk']['appearances']}
        app['Data']['RootChunk']['appearances'] = [a for a in app['Data']['RootChunk']['appearances'] if a['Data']['name']['$value'] in names]
        require({a['Data']['name']['$value'] for a in app['Data']['RootChunk']['appearances']} == names, 'Incomplete female appearances')
        for path in depot_paths(app):
            if path.endswith('.ent'):
                parts.add(path)
            if fnv(path) in mods:
                meshes.add(path)
        recipe['entityJSON'] = entity; recipe['appJSON'] = app
        mappings[recipe['app']] = recipe['newApp']
    require(len(meshes) == 8 and all(p.endswith('.mesh') for p in meshes), 'Expected eight Lucy replacement meshes')
    for path in sorted(meshes | parts):
        mappings[path] = 'cybermac\\lucy\\' + f'{fnv(path):016x}' + ('.mesh' if path in meshes else '.ent')
    for path in sorted(parts):
        extract(path)
    # The second pass includes the newly extracted garment entities.
    convert('serialize', extracted, decoded)
    generated = {}
    def edit(path, value):
        remap(value, mappings)
        value['Data']['RootChunk']['cookingPlatform'] = 'PLATFORM_PC'
        filename = Path(path.replace('\\', '/')).name + '.json'
        require(filename not in generated, 'Generated basename collision')
        generated[filename] = (path, value)
        (edits / filename).write_text(json.dumps(value, indent=2))
    for recipe in recipes:
        edit(recipe['newEntity'], recipe.pop('entityJSON'))
        edit(recipe['newApp'], recipe.pop('appJSON'))
    for path in sorted(parts):
        edit(mappings[path], read(path))
    factory = read(FACTORY)
    for field in ['compiledData', 'data']:
        rows = factory['Data']['RootChunk'][field]
        for recipe in recipes:
            require(not any(row[0] == recipe['entityName'] for row in rows), 'Factory key already exists')
            rows.append([recipe['entityName'], recipe['newEntity'], 'true'])
    edit(FACTORY, factory)
    convert('deserialize', edits, rebuilt)
    convert('serialize', rebuilt, checked)
    for filename, (_, expected) in generated.items():
        actual = json.loads((checked / filename).read_text())
        require(canonical_graph(actual['Data']) == canonical_graph(expected['Data']), 'Generated resource failed semantic round trip: ' + filename)
    resources = {}
    original_mesh_hashes = {fnv(p) for p in meshes}
    # Re-key the eight mesh payloads. Keep the mod's already unique materials and textures.
    for key, archive in mods.items():
        new_key = fnv(mappings[next(p for p in meshes if fnv(p) == key)]) if key in original_mesh_hashes else key
        require(new_key not in official, 'Custom asset collides with an official resource')
        resources[new_key] = archive.stored(key)
    entries = []
    for filename, (path, _) in generated.items():
        file = rebuilt / filename.removesuffix('.json')
        data = file.read_bytes()
        if path == FACTORY:
            data = mac_factory(data)
            file.write_bytes(data)
        resources[fnv(path)] = resource_record(path, data)
        entries.append(dict(path=path, hash=f'0x{fnv(path):016x}', sha256=hashlib.sha256(data).hexdigest()))
    # All original mesh hashes must remain absent from the new archive.
    require(not original_mesh_hashes.intersection(resources), 'Original garment mesh would be overwritten')
    require(set(resources).intersection(official) == {fnv(FACTORY)}, 'Unexpected original resource replacement')
    for _, _, dependencies in resources.values():
        require(all(d in official or d in resources for d in dependencies), 'Unresolved asset dependency')
    archive_path = args.out / 'lucy-isolated.archive'
    write_archive(archive_path, resources)
    manifest = dict(version=1, archive=archive_path.name, archiveSHA256=sha(archive_path),
        jacketSHA256=JACKET_SHA, clothesSHA256=CLOTHES_SHA, recipes=recipes, generated=entries,
        tooling=dict(wolvenkitDLLSHA256=sha(args.wolvenkit_dll), krakenSHA256=sha(args.kraken)),
        resourceHashes=[f'0x{k:016x}' for k in sorted(resources)],
        originalMeshHashes=[f'0x{k:016x}' for k in sorted(original_mesh_hashes)],
        gameplay='unverified; feminine V; original inventory icons retained')
    (args.out / 'lucy-assets.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared isolated Lucy outfit assets:', args.out / 'lucy-assets.json', flush=True)

if __name__ == '__main__':
    main()
