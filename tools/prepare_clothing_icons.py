#!/usr/bin/env python3
"""Render the seven validated garments, then build their native icon atlas.

All work is bounded to selected mesh/material dependencies and a 1024x512 atlas.
Real source textures and material overrides are rendered with the official
Blender shader importer. No game files or existing icon output are modified.
"""
import argparse, base64, copy, json, os, subprocess, shutil
from pathlib import Path
import prepare_lucy_assets as a
from clothing_materials import Materials, mesh_appearances
from clothing_texture_decode import export_images

ATLAS = r'cybermac\ui\clothing.inkatlas'
TEXTURE = r'cybermac\ui\clothing.xbm'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ['workspace', 'assets', 'templates', 'game-app', 'wolvenkit-dll', 'dotnet', 'kraken', 'blender', 'addon-source', 'out']:
        p.add_argument('--'+key, type=Path, required=True)
    p.add_argument('--keep-intermediates', action='store_true', help='Keep extracted textures/models for shader debugging')
    args = p.parse_args();out=args.out.resolve();game=args.game_app.resolve()
    a.require(not out.exists() and not out.is_relative_to(game), 'Use a new icon workspace outside the game')
    try:
        prepare(args,out,game)
    finally:
        if not args.keep_intermediates:
            for name in ['templates','decoded','models','raw','rebuilt','checked','edits',
                         'material-native','material-json','depot']:
                folder=out/name
                if folder.is_dir():shutil.rmtree(folder)


def prepare(args,out,game):
    manifest=json.loads((args.workspace/'clothing.json').read_text())
    assets=json.loads(args.assets.read_text());bundle_path=args.assets.parent/assets['archive']
    a.require(assets['kind']=='lucy-jinguji' and a.sha(bundle_path)==assets['archiveSHA256'], 'Asset bundle integrity failed')
    bundle=a.Archive(bundle_path);codec=a.Codec(args.kraken.resolve());out.mkdir(parents=True)
    for name in ['templates','decoded','models','raw','previews','rebuilt','checked']:(out/name).mkdir()
    def run(cmd, name, timeout=120):
        r=subprocess.run([str(c) for c in cmd], env=dict(os.environ,DOTNET_ROLL_FORWARD='Major'), capture_output=True,text=True,timeout=timeout)
        (out/(name+'.log')).write_text(r.stdout+r.stderr)
        a.require(r.returncode==0, 'Preparation failed; see '+name+'.log')
    def convert(mode,source,dest):run([args.dotnet,args.wolvenkit_dll.resolve(),'convert',mode,source,'-o',dest],mode+'-'+source.name)
    # Copy only the small UI template resources. Read the atlas via its original
    # UIIcon.ItemIcon ResourceRef; no reliance on an unverified guessed path.
    for f in ['template.inkatlas','template.xbm']:
        a.require((args.templates/f).is_file(), 'UI templates missing: '+f)
        (out/'templates'/f).write_bytes((args.templates/f).read_bytes())
    convert('serialize',out/'templates',out/'decoded')
    for item in manifest['items']:
        identity=item['entityName'];collection='jinguji' if '_jinguji_' in identity else 'lucy';key=identity.split('_')[-1]
        for ext in ['ent','app']:
            depot=f'cybermac\\{collection}\\{key}.{ext}'
            (out/'templates'/(identity+'.'+ext)).write_bytes(bundle.extract(a.fnv(depot),codec))
    convert('serialize',out/'templates',out/'decoded')
    materials=Materials(game,bundle,codec,out,convert)
    jobs=[];records=[];material_meshes=[]
    for item in manifest['items']:
        identity=item['entityName'];collection='jinguji' if '_jinguji_' in identity else 'lucy';key=identity.split('_')[-1]
        root=json.loads((out/'decoded'/(identity+'.ent.json')).read_text())['Data']['RootChunk']
        app=json.loads((out/'decoded'/(identity+'.app.json')).read_text())['Data']['RootChunk']
        selector=next(e for e in root['appearances'] if e['name']['$value']==root['defaultAppearance']['$value'])
        definition=next(e for e in app['appearances'] if e['Data']['name']['$value']==selector['appearanceName']['$value'])
        paths=sorted({s for s in a.depot_paths(definition) if s.endswith('.mesh') and s.startswith('cybermac\\')})
        appearances=mesh_appearances(definition)
        a.require(paths, 'No custom garment meshes')
        resources={};mesh_materials=[]
        for path in paths:
            old=next(r['meshHash'] for r in assets['recipes'] if r['key']==key) if collection=='jinguji' else int(Path(path.replace('\\','/')).stem,16)
            mat=materials.mesh(path,appearances[path]);mat['exportHash']=old;mesh_materials.append(mat)
            resources[old]=bundle.stored(a.fnv(path))
        archive=out/'models'/(identity+'.archive');a.write_archive(archive,resources)
        raw=out/'raw'/identity;raw.mkdir()
        run([args.dotnet,args.wolvenkit_dll.resolve(),'uncook',archive,'--outpath',out/'models','--raw',raw,'--mesh-export-type','MeshOnly','--mesh-export-lod-filter'],identity+'-export')
        glbs=sorted(raw.rglob('*.glb'));a.require(len(glbs)==len(paths),'Missing exported garment geometry')
        for mat in mesh_materials:
            matches=[g for g in glbs if a.fnv(str(g.relative_to(raw).with_suffix('.mesh')))==mat['exportHash']]
            a.require(len(matches)==1,'Exported mesh identity did not match material source')
            mat['glb']=str(matches[0])
        png=out/'previews'/(identity+'.png')
        material_meshes.extend(mesh_materials)
        jobs.append(dict(glbs=[str(g) for g in glbs],png=str(png),collection=collection,meshes=mesh_materials,
                         depot=str(materials.depot),addonSource=str(args.addon_source.resolve())))
        records.append(dict(record=item['record'],iconName='CyberMac_'+item['record'].split('.')[-1],part=identity,
                            preview='previews/'+png.name,meshHashes=[f'0x{a.fnv(s):016x}' for s in paths]))
    export_images(materials.dependencies(material_meshes))
    (out/'jobs.json').write_text(json.dumps(jobs,indent=2))
    run([args.blender,'--background','--factory-startup','--python-exit-code','1','--python',Path(__file__).with_name('render_clothing_thumbnails.py').resolve(),'--',out/'jobs.json'], 'render',300)
    build_atlas(args,out,records,run,convert)


def build_atlas(args,out,records,run,convert):
    # Build RGBA bytes and the PNG atlas with Blender's existing image API; no
    # additional image library is installed. PNG rows map to top-left atlas UVs.
    compose=out/'compose.py'
    compose.write_text('''import bpy,json\nfrom pathlib import Path\nr=Path(__file__).parent\njobs=json.loads((r/'jobs.json').read_text());w,h=1024,512;rgba=bytearray(w*h*4)\nfor i,job in enumerate(jobs):\n image=bpy.data.images.load(job['png'],check_existing=False);px=list(image.pixels);assert tuple(image.size)==(256,256)\n color=(30,210,230,255) if job['collection']=='lucy' else (185,100,235,255)\n for y in range(256):\n  for x in range(256):\n   dst=(((i//4)*256+y)*w+(i%4)*256+x)*4;src=((255-y)*256+x)*4\n   rgba[dst:dst+4]=bytes(color if y>=244 else [min(255,max(0,round(v*255))) for v in px[src:src+4]])\n(r/'atlas.rgba').write_bytes(rgba)\nimage=bpy.data.images.new('CyberMac icons',width=w,height=h,alpha=True)\nimage.pixels=[v/255 for y in range(h-1,-1,-1) for v in rgba[y*w*4:(y+1)*w*4]]\nimage.filepath_raw=str(r/'atlas.png');image.file_format='PNG';image.save()\n''')
    run([args.blender,'--background','--factory-startup','--python-exit-code','1','--python',compose], 'compose')
    atlas=json.loads((out/'decoded/template.inkatlas.json').read_text());root=atlas['Data']['RootChunk']
    root['cookingPlatform']='PLATFORM_PC';root['isSingleTextureMode']=1
    template=copy.deepcopy(root['slots']['Elements'][0]);template['texture']['DepotPath']['$value']=TEXTURE
    template['parts']=[];template['slices']=[]
    for i,item in enumerate(records):
        template['parts'].append({'$type':'inkTextureAtlasMapper','clippingRectInPixels':{'$type':'Rect','bottom':0,'left':0,'right':0,'top':0},
           'clippingRectInUVCoords':{'$type':'RectF','Left':(i%4)/4,'Right':(i%4+1)/4,'Top':(i//4)/2,'Bottom':(i//4+1)/2},
           'partName':{'$type':'CName','$storage':'string','$value':item['part']}})
    root['slots']['Elements']=[copy.deepcopy(template) for _ in range(3)]
    texture=json.loads((out/'decoded/template.xbm.json').read_text());root=texture['Data']['RootChunk'];root['cookingPlatform']='PLATFORM_PC'
    root['width']=1024;root['height']=512;root['setup']['compression']='TCM_None';root['setup']['isGamma']=0;root['setup']['hasMipchain']=0
    blob=root['renderTextureResource']['renderResourceBlobPC']['Data'];header=blob['header'];size=1024*512*4
    header['sizeInfo'].update(width=1024,height=512,depth=1);header['textureInfo'].update(mipCount=1,sliceCount=1,sliceSize=size,textureDataSize=size)
    header['mipMapInfo']=[{'$type':'rendRenderTextureBlobMipMapInfo','layout':{'$type':'rendRenderTextureBlobMemoryLayout','rowPitch':4096,'slicePitch':size},'placement':{'$type':'rendRenderTextureBlobPlacement','offset':0,'size':size}}]
    blob['textureData']['Bytes']=base64.b64encode((out/'atlas.rgba').read_bytes()).decode()
    edits=out/'edits';edits.mkdir()
    for name,data in [('clothing.inkatlas',atlas),('clothing.xbm',texture)]:
        (edits/(name+'.json')).write_text(json.dumps(data))
    convert('deserialize',edits,out/'rebuilt');convert('serialize',out/'rebuilt',out/'checked')
    for name,data in [('clothing.inkatlas',atlas),('clothing.xbm',texture)]:
        actual=json.loads((out/'checked'/(name+'.json')).read_text())
        a.require(a.canonical_graph(actual['Data'])==a.canonical_graph(data['Data']), 'Icon resource round trip failed')
    resources={a.fnv(path):a.resource_record(path,(out/'rebuilt'/Path(path.replace('\\','/')).name).read_bytes()) for path in [ATLAS,TEXTURE]}
    target=out/'clothing-icons.archive';a.write_archive(target,resources)
    for item in records:item['sha256']=a.sha(out/item['preview'])
    result=dict(version=1,archive=target.name,archiveSHA256=a.sha(target),atlasPath=ATLAS,texturePath=TEXTURE,
                previewStyle='Source garment textures and material colours rendered in Blender studio lighting',items=records)
    (out/'icons.json').write_text(json.dumps(result,indent=2)+'\n');print('Prepared',out/'icons.json')

if __name__=='__main__':main()
