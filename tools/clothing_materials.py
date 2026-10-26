"""Bounded material dependency export for the validated clothing preview builder.

Only selected mesh appearances and their material dependencies are extracted.
WolvenKit reads CR2W; the renderer handles image decoding without DirectXTex.
"""
import json
from pathlib import Path
import prepare_lucy_assets as a


def value(v):
    if isinstance(v, dict):
        if 'DepotPath' in v:
            return v['DepotPath']['$value'].replace('\\', '/')
        if '$value' in v:
            return v['$value']
    return v


def mesh_appearances(definition):
    result = {}
    def visit(node):
        if isinstance(node, dict):
            if 'mesh' in node and 'meshAppearance' in node:
                path = node['mesh']['DepotPath']['$value']
                if path.startswith('cybermac\\'):
                    appearance = value(node['meshAppearance'])
                    a.require(path not in result or result[path] == appearance,
                              'Conflicting preview material selectors: ' + path)
                    result[path] = appearance
            for child in node.values():visit(child)
        elif isinstance(node,list):
            for child in node:visit(child)
    visit(definition)
    return result


class Materials:
    def __init__(self, game, bundle, codec, out, convert):
        self.bundle, self.codec, self.out, self.convert = bundle, codec, out, convert
        self.owners, self.cache, self.provenance = {}, {}, []
        self.native, self.decoded, self.depot = [out / n for n in ['material-native', 'material-json', 'depot']]
        for p in [self.native, self.decoded, self.depot]:
            p.mkdir()
        self.total = 0
        for p in sorted((game / 'Contents/Data/archive/Mac').rglob('*.archive')):
            ar = a.Archive(p)
            for key in ar.rows:
                self.owners.setdefault(key, []).append(ar)

    def read(self, path):
        path = path.replace('\\', '/').lower()
        if path in self.cache:
            return self.cache[path]
        a.require(len(self.cache) < 256, 'Preview material dependency limit exceeded')
        key = a.fnv(path)
        owners = [self.bundle] if key in self.bundle.rows else self.owners.get(key, [])
        a.require(len(owners) == 1, 'Missing or ambiguous material dependency: ' + path)
        payload = owners[0].extract(key, self.codec)
        self.total += len(payload)
        a.require(self.total <= 384 * 1024 * 1024, 'Preview dependencies exceed 384 MB')
        native = self.native / (f'{key:016x}' + Path(path).suffix)
        native.write_bytes(payload)
        self.convert('serialize', native, self.decoded)
        doc = json.loads((self.decoded / (native.name + '.json')).read_text())
        dest = self.depot / (path + '.json')
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(doc))
        root = doc['Data']['RootChunk']
        self.cache[path] = root
        self.provenance.append(dict(path=path, source=str(owners[0].path), sha256=a.sha(native), bytes=len(payload)))
        return root

    def material(self, mi):
        chain, seen = [mi], set()
        path = value(mi['baseMaterial'])
        while Path(path).suffix not in ['.mt', '.remt']:
            a.require(path not in seen and len(seen) < 16, 'Cyclic material inheritance')
            seen.add(path)
            parent = self.read(path)
            a.require(parent['$type'] == 'CMaterialInstance', 'Unexpected material parent')
            chain.insert(0, parent)
            path = value(parent['baseMaterial'])
        data = {}
        # Cooked Mac archives omit shader templates. All material instances in
        # the pinned garments supply their resource references and overrides;
        # retain those rather than inventing unavailable template parameters.
        for item in chain:
            for entry in item['values']:
                for k, v in entry.items():
                    if k != '$type':
                        data[k] = value(v)
        return dict(template=path, data=data, enableMask=bool(mi['enableMask']))

    def mesh(self, path, appearance='default'):
        mesh = self.read(path)
        local = mesh['localMaterialBuffer']['materials']
        # The pinned Lucy replacements retain the donor's skin appearance table,
        # but replace its local material buffer with one garment material. This
        # is also the sole material used by the confirmed in-game replacement.
        if path.replace('\\', '/').startswith('cybermac/lucy/') and len(local) == 1:
            count = max(len(x['Data']['chunkMaterials']) for x in mesh['appearances'])
            return dict(path=path, chunks=['garment'] * count, materials={'garment': self.material(local[0])})
        appearances = [x['Data'] for x in mesh['appearances'] if value(x['Data']['name']) == appearance]
        if not appearances and path.replace('\\','/').startswith('cybermac/lucy/'):
            # These pinned replacements leave the donor component selectors in
            # place. Their actual replacement textures are on the default mesh
            # appearance (the same authored setup confirmed in-game).
            appearances = [x['Data'] for x in mesh['appearances'] if value(x['Data']['name']) == 'default']
        a.require(len(appearances) == 1, 'Missing selected mesh appearance: ' + path + ':' + appearance)
        names = [value(n) for n in appearances[0]['chunkMaterials']]
        entries = {value(e['name']): e for e in mesh['materialEntries']}
        mats = {}
        for name in dict.fromkeys(names):
            entry = entries[name]
            if entry['isLocalInstance']:
                mi = mesh['localMaterialBuffer']['materials'][entry['index']]
            else:
                mi = self.read(value(mesh['externalMaterials'][entry['index']]))
            mats[name] = self.material(mi)
        return dict(path=path, requestedAppearance=appearance, resolvedAppearance=value(appearances[0]['name']), chunks=names, materials=mats)

    def dependencies(self, meshes):
        queue = []
        for mesh in meshes:
            for mat in mesh['materials'].values():
                queue.extend(v for v in mat['data'].values() if isinstance(v, str) and Path(v).suffix in ['.xbm', '.mlsetup', '.mlmask'])
        done = set()
        while queue:
            path = queue.pop()
            if path in done:
                continue
            done.add(path)
            root = self.read(path)
            if Path(path).suffix in ['.mlsetup', '.mltemplate']:
                queue.extend(p.replace('\\', '/') for p in a.depot_paths(root)
                             if Path(p).suffix in ['.xbm', '.mltemplate'])
        manifest = self.out / 'material-resources.json'
        manifest.write_text(json.dumps(dict(depot=str(self.depot), resources=sorted(done), provenance=self.provenance), indent=2))
        return manifest
