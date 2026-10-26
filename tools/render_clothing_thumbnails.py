"""Run with Blender --background --factory-startup --python ... -- jobs.json.
The app's fast mode draws actual geometry with approximate colour hints using
Workbench. The offline icon builder can still request source-textured renders.
Studio lighting differs from the game's lighting and tone mapping.
"""
import json, sys, re, types, itertools, traceback, os
from pathlib import Path
import bpy
from mathutils import Vector

streaming = '--stream' in sys.argv
jobs = (json.loads(line) for line in sys.stdin if line.strip()) if streaming else iter(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
first_job = next(jobs)
if first_job.get('mode') != 'fast':
    addon = Path(first_job['addonSource'])
    assert (addon/'material_types/multilayered.py').is_file(), 'Official Blender material importer is missing'
    # Load only the shader modules. Do not install/register the add-on or load its
    # unrelated physics and UI modules into the user's Blender preferences.
    package = types.ModuleType('i_scene_cp77_gltf')
    package.__path__ = [str(addon)]
    package.bl_info = {'version': (2,0,0)}
    sys.modules[package.__name__] = package
    from i_scene_cp77_gltf.material_types.multilayered import Multilayered
    from i_scene_cp77_gltf.material_types.metalbase import MetalBase
    from i_scene_cp77_gltf.material_types.meshdecal import MeshDecal
    from i_scene_cp77_gltf.material_types.glass import Glass
    from i_scene_cp77_gltf.jsontool import JSONTool

def read_material_json(filepath, errorMessages=None):
    # The add-on's general loader requires interactive add-on preferences even
    # for these plain material documents. Keep its path normalization and
    # version validation, and restrict this headless adapter to the two formats
    # used by the shader. No preferences are installed or saved.
    assert str(filepath).endswith(('.mlsetup.json','.mltemplate.json'))
    data=JSONTool.load_json(filepath)
    assert JSONTool.json_ver_validate(data), 'Invalid material JSON version'
    return data


if first_job.get('mode') != 'fast': JSONTool.jsonload=staticmethod(read_material_json)


def build_material(name, spec, depot):
    material = bpy.data.materials.new(name)
    if 'color' in spec:
        material.diffuse_color = spec['color']
        return material
    material.use_nodes = True
    material['AddonVersion'] = '2.0.0'
    base = str(Path(depot)) + '/'
    shader = {
        'engine/materials/multilayered.mt': lambda: Multilayered(base,'png',base),
        'engine/materials/metal_base.remt': lambda: MetalBase(base,'png',base,spec['enableMask']),
        'base/materials/mesh_decal.mt': lambda: MeshDecal(base,'png',base,spec['enableMask']),
        'base/materials/glass.mt': lambda: Glass(base,'png',base),
    }
    assert spec['template'] in shader, 'Unsupported clothing preview shader: '+spec['template']
    shader[spec['template']]().create(spec['data'], material)
    return material


def render(job):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for mesh in job['meshes']:
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=mesh['glb'])
        bpy.context.view_layer.update()
        visible=[]
        for obj in set(bpy.context.scene.objects)-before:
            if obj.type!='MESH' or not obj.name.startswith('submesh_'):continue
            if not any(p.area>1e-10 for p in obj.data.polygons):continue
            index=int(re.match(r'submesh_(\d+)',obj.name)[1])
            assert index<len(mesh['chunks']), 'Missing chunk material assignment'
            visible.append((obj,mesh['chunks'][index]))
        used={name for _,name in visible}
        materials={name:build_material(name,mesh['materials'][name],job['depot']) for name in used}
        for obj,name in visible:
            obj.data.materials.clear()
            obj.data.materials.append(materials[name])
    for image in bpy.data.images:
        if image.source=='FILE':
            assert Path(bpy.path.abspath(image.filepath)).is_file(), 'Missing material image: '+image.filepath
            image.reload()
            assert min(image.size)>0, 'Material image could not be read: '+image.filepath
    bpy.context.view_layer.update()
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH'
               and o.name.startswith('submesh_') and not o.hide_render
               and any(p.area > 1e-10 for p in o.data.polygons)]
    if not objects:
        raise RuntimeError('Garment has no mesh geometry')
    # glTF exporter maps REDengine Z-up into Blender's native frame on import.
    corners = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    low = Vector(tuple(min(c[i] for c in corners) for i in range(3)))
    high = Vector(tuple(max(c[i] for c in corners) for i in range(3)))
    center = (low + high) / 2
    height = max(high.z - low.z, .1)
    width = max(high.x - low.x, .1)
    print('GARMENT_BOUNDS', tuple(low), tuple(high), flush=True)
    bpy.ops.object.camera_add(location=center + Vector((0.18, -1.0, 0.12)).normalized() * max(height, width) * 4)
    camera = bpy.context.object
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = max(height, width) * 1.30
    scene = bpy.context.scene
    scene.camera = camera
    # A neutral studio environment gives chrome something to reflect and keeps
    # dark fabrics readable against the app's dark inventory background.
    scene.world = bpy.data.worlds.new('Studio environment')
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get('Background')
    background.inputs['Color'].default_value = (.3,.3,.3,1)
    background.inputs['Strength'].default_value = .6
    for delta, energy, size in [((2,-3,4), 350, 4), ((-3,-1,2), 220, 3), ((1,2,3), 400, 3)]:
        bpy.ops.object.light_add(type='AREA', location=center + Vector(delta) * max(height, width))
        light = bpy.context.object
        light.data.energy = energy * max(height, width) ** 2
        light.data.shape = 'DISK'
        light.data.size = size * max(height, width)
        light.rotation_euler = (center-light.location).to_track_quat('-Z','Y').to_euler()
    fast = job.get('mode') == 'fast'
    if fast:
        try:
            scene.render.engine = 'BLENDER_WORKBENCH'
            shading = scene.display.shading
            shading.light = 'STUDIO'
            shading.color_type = 'MATERIAL'
            shading.show_shadows = False
            shading.show_cavity = False
            shading.show_specular_highlight = False
            scene.display.render_aa = '5'
        except TypeError:
            scene.render.engine = 'BLENDER_EEVEE'
            scene.eevee.taa_render_samples = 4
            scene.eevee.use_raytracing = False
            scene.eevee.use_shadows = False
    else:
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 16
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 2 if fast else min(8, max(1, (os.cpu_count() or 2) // 2))
    scene.render.resolution_x = 160 if fast else 256
    scene.render.resolution_y = 160 if fast else 256
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.filepath = job['png']
    scene.view_settings.view_transform = 'Standard'
    bpy.ops.render.render(write_still=True)
    print('CYBERMAC_THUMBNAIL', job['png'], flush=True)


for job in itertools.chain([first_job], jobs):
    try:
        render(job)
        result = dict(ok=True)
    except Exception as error:
        if not streaming:
            raise
        traceback.print_exc()
        result = dict(ok=False, error=str(error))
    if job.get('ack'):
        target = Path(job['ack'])
        temporary = target.with_suffix('.tmp')
        temporary.write_text(json.dumps(result))
        temporary.replace(target)
