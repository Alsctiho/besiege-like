import bpy
import bmesh
import json
import math
import time
from pathlib import Path
from mathutils import Matrix

START = time.perf_counter()
PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / 'assets/adventure/models'
OUTPUT.mkdir(parents=True, exist_ok=True)
assert bpy.data.objects.get('Core') is not None, 'Start Blender with core_robot.blend before this script'
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')


def export_tree(root_name, filename):
    value = bpy.data.objects[root_name]
    original = value.matrix_world.copy()
    value.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    value.select_set(True)
    for child in value.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = value
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / filename), export_format='GLB', use_selection=True, export_extras=True, export_cameras=False, export_lights=False, export_animations=False)
    value.matrix_world = original
    bpy.context.view_layer.update()


export_tree('Core', 'core.glb')
export_tree('Mobility_Module', 'mobility.glb')
export_tree('Flight_Module', 'rotor.glb')
materials = {mat.name: mat for mat in bpy.data.materials}
metal = materials['Machined titanium']
dark = materials['Graphite structural frame']
cream = materials['Ceramic warm white']
lime = materials['Shell - warm citron enamel']
gold = materials['Safety markings - ochre']
cyan = materials['Status - cyan']


def primitive(name, location, radius, depth, mat, cone=False, segments=12):
    if cone:
        bpy.ops.mesh.primitive_cone_add(vertices=segments, radius1=radius, radius2=0.012, depth=depth, location=location)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Edge bevel', 'BEVEL')
    bevel.width = 0.009
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def box(name, location, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Edge bevel', 'BEVEL')
    bevel.width = 0.012
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


report = {}
for kind in ['drill', 'fireball', 'blower', 'rod', 'booster']:
    module = bpy.data.objects.new(kind.title(), None)
    bpy.context.scene.collection.objects.link(module)
    parts = [primitive('Universal plug', (0, 0, 0.035), 0.09, 0.07, metal, segments=8), primitive('Mount flange', (0, 0, 0.08), 0.16, 0.045, dark, segments=8)]
    if kind == 'drill':
        parts += [primitive('Motor', (0, 0, 0.18), 0.19, 0.18, lime), primitive('Drill cone', (0, 0, 0.45), 0.18, 0.39, metal, True)]
        for index in range(5):
            height = 0.28 + index * 0.055
            parts.append(primitive('Drill cutting edge', (0, 0, height), 0.18 - index * 0.029, 0.027, dark))
    elif kind in ['fireball', 'booster']:
        parts += [primitive('Enamel body', (0, 0, 0.23), 0.18, 0.28, lime), primitive('Ceramic muzzle', (0, 0, 0.39), 0.225, 0.065, cream), primitive('Muzzle recess', (0, 0, 0.427), 0.17, 0.009, dark), primitive('Status port', (0, 0, 0.433), 0.08, 0.01, gold)]
        for index in range(4):
            angle = index * math.tau / 4
            parts.append(box('Body brace', (math.cos(angle)*0.17, math.sin(angle)*0.17, 0.25), (0.065, 0.065, 0.19), dark))
    elif kind == 'blower':
        parts += [primitive('Fan body', (0, 0, 0.20), 0.255, 0.22, dark), primitive('Fan lining', (0, 0, 0.315), 0.23, 0.02, cream), primitive('Inner fan', (0, 0, 0.33), 0.19, 0.012, dark), primitive('Fan hub', (0, 0, 0.35), 0.05, 0.024, cyan)]
        for index in range(5):
            angle = index * math.tau / 5
            obj = box('Fan blade', (math.cos(angle)*0.105, math.sin(angle)*0.105, 0.346), (0.15, 0.043, 0.013), lime)
            obj.rotation_euler.z = angle
            parts.append(obj)
    else:
        parts += [primitive('Actuator body', (0,0,0.19), 0.15,0.21,lime), primitive('Outer sleeve',(0,0,0.35),0.09,0.15,dark), primitive('Telescopic shaft',(0,0,0.51),0.06,0.22,metal), primitive('Contact tip',(0,0,0.66),0.115,0.08,gold,segments=8)]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    mesh_obj = bpy.context.object
    mesh_obj.name = kind + '_Mesh'
    mesh_obj.parent = module
    mesh_obj.data.calc_loop_triangles()
    report[kind] = len(mesh_obj.data.loop_triangles)
    export_tree(module.name, kind + '.glb')
    module.location.x = 3 + len(report)

bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).parent / 'adventure_components.blend'))
report['build_seconds'] = round(time.perf_counter() - START, 3)
report['source_axis'] = 'Blender +Z -> Godot +Y; mesh origin is connection plug'
(OUTPUT / 'asset_metrics.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('ADVENTURE_ASSETS ' + json.dumps(report))
