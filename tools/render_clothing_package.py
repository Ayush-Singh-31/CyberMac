#!/usr/bin/env python3
"""Render lightweight garment shapes on demand; never modifies the game.

Uses the existing WolvenKit geometry exporter and Blender Workbench at 160px.
Colours are hints from variant labels, not full textured material simulations.
Geometry is cached across colours; only requested rows are rendered.
"""
import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import struct
import subprocess
import time
import zipfile

import numpy as np
from PIL import Image
import prepare_lucy_assets as a

VERSION = 1

def approximate_color(name):
    """Low-cost colour hint from the author's variant label, not fake textures."""
    palette = [('black',(0.10,0.10,0.12)),('white',(.82,.82,.80)),('chrome',(.62,.65,.68)),
               ('silver',(.58,.60,.63)),('gold',(.65,.40,.10)),('red',(.55,.04,.06)),
               ('blue',(.04,.15,.50)),('green',(.06,.32,.14)),('purple',(.30,.07,.43)),
               ('pink',(.65,.15,.35)),('yellow',(.73,.57,.05)),('orange',(.65,.22,.04)),
               ('brown',(.23,.11,.06)),('gray',(.25,.27,.29)),('grey',(.25,.27,.29)),
               ('beige',(.55,.44,.29)),('denim',(.09,.20,.36))]
    words = {word.lower() for word in re.findall(r'[A-Z]?[a-z]+|[A-Z]+(?![a-z])', Path(name).stem)}
    return next((list(color)+[1] for word,color in palette if word in words), [.34,.36,.40,1])


def requested_paths(entries, requested):
    wanted = set(requested or entries[:4])
    return set([path for path in entries if path in wanted][:6])


def atomic_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value))
    temporary.replace(path)


def metadata(path):
    return any(p == '__MACOSX' or p.startswith('._') or p == '.DS_Store' for p in path.split('/'))


def safe_depot(path):
    path = path.replace('\\', '/').lower()
    a.require(not Path(path).is_absolute() and '..' not in Path(path).parts and '\0' not in path,
              'Unsafe material dependency path')
    return path


def visible_chunks(path):
    """Ignore empty exporter chunks before requesting their unused materials."""
    data = path.read_bytes()
    a.require(data[:4] == b'glTF' and len(data) < 128 * 1024 * 1024, 'Invalid exported model')
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + length])
    binary = data[28 + length:]
    def accessor(index):
        item = doc['accessors'][index]; view = doc['bufferViews'][item['bufferView']]
        dtype = {5121:'u1', 5123:'<u2', 5125:'<u4', 5126:'<f4'}[item['componentType']]
        width = {'SCALAR':1, 'VEC3':3}[item['type']]
        a.require(item['count'] <= 5_000_000, 'Exported geometry is too large')
        offset = view.get('byteOffset', 0) + item.get('byteOffset', 0)
        return np.ndarray((item['count'], width), dtype=dtype, buffer=binary, offset=offset,
                          strides=(view.get('byteStride', np.dtype(dtype).itemsize * width), np.dtype(dtype).itemsize))
    result = set()
    for mesh in doc['meshes']:
        name = re.match(r'submesh_(\d+)', mesh.get('name', ''))
        if not name: continue
        for primitive in mesh['primitives']:
            positions = accessor(primitive['attributes']['POSITION'])
            indices = accessor(primitive['indices']).ravel() if 'indices' in primitive else np.arange(len(positions))
            if not len(indices) or len(indices) % 3: continue
            triangles = positions[indices].reshape(-1, 3, 3)
            area = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
            if np.any(np.linalg.norm(area, axis=1) > 1e-10): result.add(int(name[1]))
    return result



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request', type=Path, required=True)
    args = parser.parse_args()
    request = json.loads(args.request.read_text())
    fast = True
    a.require(request.get('mode','fast') == 'fast', 'This renderer supports lightweight previews only')
    if fast:
        try: os.nice(10)
        except OSError: pass
    out = Path(request['output']).resolve(); game = Path(request['gameApp']).resolve()
    a.require(out != game and not out.is_relative_to(game), 'Preview output must be outside the game')
    out.mkdir(parents=True, exist_ok=True)
    batch_lock = (out/'python.lock').open('a')
    fcntl.flock(batch_lock, fcntl.LOCK_EX)
    images = out/'images'; images.mkdir(exist_ok=True)
    geometry_cache = out/'geometry'; geometry_cache.mkdir(exist_ok=True)
    work = out/'work'; shutil.rmtree(work, ignore_errors=True); work.mkdir()
    progress_file = out/'progress.json'
    package = Path(request['package'])
    a.require(package.stat().st_size <= 500*1024*1024 and a.sha(package) == request['packageSHA256'], 'The clothing ZIP changed')
    tools = request['tools']
    codec = a.Codec(Path(tools['kraken']))
    env = dict(os.environ, DOTNET_ROLL_FORWARD='Major', DOTNET_PROCESSOR_COUNT='2', OMP_NUM_THREADS='2', OPENBLAS_NUM_THREADS='1')
    processes = []
    active_name = ''
    def stop(signum, frame):
        for process in processes:
            if process.poll() is None: process.terminate()
        raise SystemExit(130)
    signal.signal(signal.SIGTERM, stop); signal.signal(signal.SIGINT, stop)
    try: os.setpgrp()
    except OSError: pass
    log = (out/'renderer.log').open('a')
    def run(command, name, timeout=90):
        if active_name:
            progress['current'] = active_name+' · '+('Preparing garment shape…' if name == 'mesh-export' else 'Reading garment shape…')
            atomic_json(progress_file, progress)
        with (work/(name+'.log')).open('w') as capture:
            process = subprocess.Popen([str(x) for x in command], env=env, stdout=capture, stderr=subprocess.STDOUT)
            processes.append(process)
            try: status = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(); raise ValueError('Preview export timed out: '+name)
            finally: processes.remove(process)
        a.require(status == 0, 'Preview export failed: '+name)
    def convert(mode, source, destination):
        destination.mkdir(exist_ok=True, parents=True)
        run([tools['dotnet'],tools['wolvenkit'],'convert',mode,source,'-o',destination], mode+'-'+source.name)

    previous = {}
    resume_file = out/'resume.json'
    previous_file = resume_file if resume_file.exists() else progress_file
    if previous_file.exists():
        try: previous = {x['archivePath']:x for x in json.loads(previous_file.read_text()).get('results', [])}
        except (ValueError, KeyError): pass
    progress = dict(version=VERSION, state='loading', total=0, completed=0, failed=0,
                    current='Reading clothing package…', results=[])
    atomic_json(progress_file, progress)
    worker = None
    try:
        with zipfile.ZipFile(package) as zip_:
            infos = zip_.infolist()
            a.require(len(infos) <= 50_000 and sum(x.file_size for x in infos) <= 1024*1024*1024, 'ZIP exceeds preview limits')
            entries = sorted([x for x in infos if not x.is_dir() and x.filename.lower().endswith('.archive') and not metadata(x.filename)], key=lambda x:x.filename)
            requested = requested_paths([x.filename for x in entries],request.get('archivePaths'))
            progress['total'] = len(entries); atomic_json(progress_file, progress)
            depot = work/'depot'; depot.mkdir()
            for index, entry in enumerate(entries):
                active_name = entry.filename
                progress['state'] = 'rendering'; progress['current'] = entry.filename
                atomic_json(progress_file, progress)
                result = dict(archivePath=entry.filename, status='failed')
                current = work/'current'; shutil.rmtree(current, ignore_errors=True); current.mkdir()
                try:
                    a.require(entry.file_size <= 80*1024*1024, 'Garment archive exceeds the preview limit')
                    source = current/'source.archive'; source.write_bytes(zip_.read(entry))
                    digest = a.sha(source); result['sourceSHA256'] = digest
                    image = images/(digest+'.png')
                    cached = previous.get(entry.filename)
                    if cached and cached.get('sourceSHA256') == digest and cached.get('status') == 'ready' and image.is_file() and a.sha(image) == cached.get('previewSHA256'):
                        result = cached
                    elif entry.filename not in requested:
                        continue
                    else:
                        bundle = a.Archive(source); extracted = current/'meshes'; extracted.mkdir()
                        keys = []
                        for key in bundle.rows:
                            payload = bundle.extract(key, codec)
                            if b'CMesh\0' in payload:
                                (extracted/(f'{key:016x}.mesh')).write_bytes(payload); keys.append(key)
                        a.require(keys, 'No renderable garment mesh was found in this archive')
                        decoded = current/'decoded'; convert('serialize', extracted, decoded)
                        edits = current/'geometry'; edits.mkdir()
                        roots, embedded, header, cached_geometry = {}, {}, None, {}
                        actual_keys = []
                        for key in keys:
                            doc = json.loads((decoded/(f'{key:016x}.mesh.json')).read_text())
                            if doc['Data']['RootChunk']['$type'] != 'CMesh': continue
                            header = doc['Header']
                            for e in doc['Data'].get('EmbeddedFiles', []): embedded[safe_depot(e['FileName']['$value'])] = e['Content']
                            roots[key] = doc['Data']['RootChunk']; actual_keys.append(key)
                            mesh_root = roots[key]
                            geometry = {k:mesh_root.get(k) for k in ['renderResourceBlob','boneNames','boneRigMatrices','boundingBox','lodLevelInfo']}
                            geometry_key = hashlib.sha256(json.dumps(geometry,sort_keys=True).encode()).hexdigest()
                            cached_geometry[key] = geometry_cache/(geometry_key+'.glb')
                            clean = copy.deepcopy(doc); clean['Data']['EmbeddedFiles'] = []
                            if not cached_geometry[key].is_file(): (edits/(f'{key:016x}.mesh.json')).write_text(json.dumps(clean))
                        a.require(actual_keys, 'No renderable clothing geometry was found')
                        missing = [key for key in actual_keys if not cached_geometry[key].is_file()]
                        if missing:
                            rebuilt = current/'rebuilt'; convert('deserialize', edits, rebuilt)
                            model_archive = current/'geometry.archive'
                            records = {key:a.resource_record(f'{key:016x}.mesh',(rebuilt/(f'{key:016x}.mesh')).read_bytes()) for key in missing}
                            for key, (row, pieces, deps) in list(records.items()):
                                row = bytearray(row); struct.pack_into('<Q',row,0,key); records[key] = (bytes(row),pieces,deps)
                            a.write_archive(model_archive, records)
                            raw = current/'raw'; native = current/'native'
                            run([tools['dotnet'],tools['wolvenkit'],'uncook',model_archive,'--outpath',native,'--raw',raw,'--mesh-export-type','MeshOnly','--mesh-export-lod-filter'], 'mesh-export')
                            exported = sorted(raw.rglob('*.glb'))
                            a.require(len(exported) == len(missing), 'The mesh exporter could not produce all garment parts')
                            for glb in exported:
                                key = a.fnv(str(glb.relative_to(raw).with_suffix('.mesh')))
                                if key not in missing and len(missing) == 1: key = missing[0]
                                a.require(key in missing, 'Exported garment identity is ambiguous')
                                shutil.copyfile(glb,cached_geometry[key])
                        glbs = [cached_geometry[key] for key in actual_keys]
                        root_paths = {f'preview/{key:016x}.mesh':roots[key] for key in actual_keys}
                        mesh_materials = []
                        for key,glb in zip(actual_keys,glbs):
                            chunks = visible_chunks(glb)
                            spec = dict(glb=str(glb),chunks=['preview']*(max(chunks,default=0)+1),materials={'preview':dict(color=approximate_color(entry.filename))})
                            mesh_materials.append(spec)
                        if worker is None:
                            worker = subprocess.Popen([tools['blender'],'--background','--factory-startup','-t','2','--python-exit-code','1','--python',str(Path(__file__).with_name('render_clothing_thumbnails.py')),'--','--stream'], stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT, text=True, env=env)
                            processes.append(worker)
                        ack = current/'render-done.json'
                        job = dict(png=str(image),meshes=mesh_materials,depot=str(depot),addonSource=tools['addonSource'],ack=str(ack),mode='fast' if fast else 'full')
                        worker.stdin.write(json.dumps(job)+'\n'); worker.stdin.flush()
                        deadline = time.monotonic()+(30 if fast else 120)
                        while not ack.exists():
                            a.require(worker.poll() is None, 'The preview renderer stopped unexpectedly')
                            if time.monotonic()>=deadline:
                                worker.kill(); worker.wait(); processes.remove(worker); worker = None
                                raise ValueError('Garment preview timed out')
                            time.sleep(.1)
                        rendered = json.loads(ack.read_text()); a.require(rendered['ok'], rendered.get('error','Preview rendering failed'))
                        a.require(image.is_file(), 'Renderer produced no garment image')
                        with Image.open(image) as png: a.require(png.size == ((160,160) if fast else (256,256)), 'Invalid preview dimensions')
                        result.update(status='ready',preview='images/'+image.name,previewSHA256=a.sha(image))
                except Exception as error:
                    if worker is not None and worker.poll() is not None:
                        processes.remove(worker); worker = None
                    result.update(status='failed',error=str(error))
                    log.write(entry.filename+': '+str(error)+'\n'); log.flush()
                progress['results'].append(result)
                progress['completed'] = len(progress['results'])
                progress['failed'] += int(result['status'] != 'ready')
                atomic_json(progress_file, progress)
            a.require(a.sha(package) == request['packageSHA256'], 'The clothing ZIP changed during rendering')
            progress['state'] = 'finished'; progress['current'] = 'Previews ready'; atomic_json(progress_file,progress)
    except BaseException as error:
        progress['state'] = 'cancelled' if isinstance(error,SystemExit) else 'failed'
        progress['current'] = str(error); atomic_json(progress_file,progress)
        if not isinstance(error,SystemExit): raise
    finally:
        for process in processes:
            if process.poll() is None:
                try:
                    if process is worker: process.stdin.close(); process.wait(timeout=5)
                    else: process.terminate(); process.wait(timeout=5)
                except (OSError,subprocess.TimeoutExpired): process.kill(); process.wait()
        shutil.rmtree(work,ignore_errors=True)
        log.close()


if __name__ == '__main__': main()
