import bpy
import bmesh
import json
import math
import sys
import time
from mathutils import Vector
from pathlib import Path

STARTED = time.perf_counter()
OUTPUT = Path(__file__).resolve().parent
OUTPUT.mkdir(parents=True, exist_ok=True)
ROOTS = {}
PARTS = {}
MATERIALS = {}
MODEL_CENTER = Vector((0.0, 0.0, 0.98))


def material(name, color, metal=0.0, roughness=0.5, emission=0.0):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1.0)
    value.use_nodes = True
    shader = value.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1.0)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = roughness
    if emission:
        shader.inputs['Emission Color'].default_value = (*color, 1.0)
        shader.inputs['Emission Strength'].default_value = emission
    MATERIALS[name] = value
    return value


def root(name, location=(0, 0, 0), parent=None):
    value = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(value)
    value.location = location
    value.empty_display_type = 'PLAIN_AXES'
    value.empty_display_size = 0.10
    if parent:
        value.parent = parent
    ROOTS[name] = value
    PARTS[name] = []
    return value


def finish_mesh(value, name, group, mat, bevel=0.0):
    value.name = name
    value.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = value.modifiers.new('Machined edge', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    value.parent = ROOTS[group]
    PARTS[group].append(value)
    return value


def box(name, location, size, group, mat, bevel=0.008, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    value = bpy.context.object
    value.scale = size
    if rotation:
        value.rotation_euler = rotation
    return finish_mesh(value, name, group, mat, bevel)


def cylinder(name, location, radius, depth, group, mat, axis=(0, 0, 1), vertices=12, bevel=0.004):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    value = bpy.context.object
    value.rotation_mode = 'QUATERNION'
    value.rotation_quaternion = Vector(axis).to_track_quat('Z', 'Y')
    return finish_mesh(value, name, group, mat, bevel)


def ring(name, location, outer, inner, depth, group, mat, axis=(0, 0, 1), segments=8):
    points = []
    for height in (-depth / 2, depth / 2):
        for radius in (outer, inner):
            points.extend((radius * math.cos(index * math.tau / segments), radius * math.sin(index * math.tau / segments), height) for index in range(segments))
    faces = []
    for index in range(segments):
        following = (index + 1) % segments
        faces.extend([
            (index, following, 2 * segments + following, 2 * segments + index),
            (segments + index, 3 * segments + index, 3 * segments + following, segments + following),
            (index, segments + index, segments + following, following),
            (2 * segments + index, 2 * segments + following, 3 * segments + following, 3 * segments + index),
        ])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    value = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(value)
    value.location = location
    value.rotation_mode = 'QUATERNION'
    value.rotation_quaternion = Vector(axis).to_track_quat('Z', 'Y')
    return finish_mesh(value, name, group, mat)


def line_box(name, start, end, width, group, mat):
    start, end = Vector(start), Vector(end)
    middle = (start + end) / 2
    value = box(name, middle, (width, width, (end - start).length), group, mat, bevel=width * 0.12)
    value.rotation_mode = 'QUATERNION'
    value.rotation_quaternion = (end - start).to_track_quat('Z', 'Y')
    return value


def extruded_blade(name, points, thickness, group, mat):
    count = len(points)
    vertices = [(x, y, height) for height in (-thickness / 2, thickness / 2) for x, y in points]
    faces = [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, following + count, index + count))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    value = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(value)
    return finish_mesh(value, name, group, mat, 0.002)


def join_group(group):
    objects = PARTS[group]
    if not objects:
        return
    bpy.ops.object.select_all(action='DESELECT')
    for value in objects:
        value.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = group + '_Mesh'
    joined.data.name = group + '_Geometry'
    mesh = bmesh.new()
    mesh.from_mesh(joined.data)
    bmesh.ops.recalc_face_normals(mesh, faces=mesh.faces)
    mesh.to_mesh(joined.data)
    mesh.free()
    material_lookup = {}
    remapping = {}
    compact = []
    for index, mat in enumerate(joined.data.materials):
        if mat.name not in material_lookup:
            material_lookup[mat.name] = len(compact)
            compact.append(mat)
        remapping[index] = material_lookup[mat.name]
    indices = [remapping[polygon.material_index] for polygon in joined.data.polygons]
    joined.data.materials.clear()
    for mat in compact:
        joined.data.materials.append(mat)
    for polygon, index in zip(joined.data.polygons, indices):
        polygon.material_index = index
        polygon.use_smooth = False
    PARTS[group] = [joined]


def text_object(body, location, size, mat, rotation=(math.pi / 2, 0, 0)):
    curve = bpy.data.curves.new(body, type='FONT')
    curve.body = body
    curve.align_x = 'CENTER'
    curve.align_y = 'CENTER'
    curve.size = size
    curve.extrude = 0.0002
    value = bpy.data.objects.new(body, curve)
    bpy.context.scene.collection.objects.link(value)
    value.location = location
    value.rotation_euler = rotation
    value.data.materials.append(mat)
    return value


def aim(value, target):
    value.rotation_euler = (Vector(target) - value.location).to_track_quat('-Z', 'Y').to_euler()


def area_light(name, location, power, color, size, target):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = power
    data.color = color
    data.shape = 'DISK'
    data.size = size
    value = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(value)
    value.location = location
    aim(value, target)
    return value


def render(name, camera_location, target, scale):
    camera = bpy.context.scene.camera
    camera.location = camera_location
    aim(camera, target)
    camera.data.ortho_scale = scale
    bpy.context.scene.render.filepath = str(OUTPUT / name)
    before = time.perf_counter()
    bpy.ops.render.render(write_still=True)
    return round(time.perf_counter() - before, 3)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Core Robot - modular low poly prototype'
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
lime = material('Shell - warm citron enamel', (0.58, 0.66, 0.11), metal=0.12, roughness=0.46)
yellow = material('Safety markings - ochre', (0.95, 0.65, 0.12), roughness=0.55)
graphite = material('Graphite structural frame', (0.067, 0.093, 0.107), metal=0.35, roughness=0.46)
silver = material('Machined titanium', (0.33, 0.40, 0.41), metal=0.68, roughness=0.42)
rubber = material('Rubber - charcoal', (0.026, 0.037, 0.039), roughness=0.84)
cream = material('Ceramic warm white', (0.72, 0.69, 0.55), metal=0.05, roughness=0.54)
black = material('Display smoked glass', (0.010, 0.031, 0.032), metal=0.15, roughness=0.30)
cyan = material('Status - cyan', (0.10, 0.72, 0.67), roughness=0.30, emission=2.1)
stone = material('Display stone', (0.19, 0.235, 0.25), roughness=0.86)
floor_mat = material('Studio backdrop', (0.055, 0.077, 0.086), roughness=0.93)
robot = root('Robot_Assembly')
core = root('Core', parent=robot)
core['role'] = 'player_core'
core['socket_count'] = 6
core['dimensions_m'] = '1.0 x 1.0 x 1.0'
box('Main enclosure', MODEL_CENTER, (1.0, 1.0, 1.0), 'Core', lime, 0.055)
box('Lower chassis band', (0, 0, 0.535), (0.972, 0.976, 0.090), 'Core', graphite, 0.018)
box('Top lid seam', (0, 0, 1.435), (0.973, 0.976, 0.035), 'Core', graphite, 0.009)
box('Top lid', (0, 0, 1.463), (0.954, 0.950, 0.052), 'Core', lime, 0.016)
for horizontal_sign in (-1, 1):
    for depth_sign in (-1, 1):
        for height in (0.59, 1.367):
            x, y = horizontal_sign * 0.46, depth_sign * 0.46
            box('Corner X armor', (x - horizontal_sign * 0.029, y, height), (0.150, 0.072, 0.055), 'Core', graphite, 0.007)
            box('Corner Y armor', (x, y - depth_sign * 0.029, height), (0.072, 0.150, 0.055), 'Core', graphite, 0.007)
            box('Corner vertical armor', (x, y, height), (0.070, 0.070, 0.165), 'Core', graphite, 0.007)
box('Face bezel', (0, -0.510, 1.225), (0.73, 0.076, 0.34), 'Core', graphite, 0.022)
box('Inset face screen', (0, -0.552, 1.229), (0.635, 0.025, 0.249), 'Core', black, 0.014)
for x in (-0.172, 0.172):
    box('Expression eye', (x, -0.569, 1.235), (0.094, 0.008, 0.117), 'Core', cyan, 0.012)
box('Expression mouth', (0, -0.570, 1.155), (0.085, 0.008, 0.018), 'Core', cyan, 0.006)
box('Face insignia stripe', (-0.375, -0.510, 1.01), (0.025, 0.027, 0.110), 'Core', cream, 0.003)
box('Face insignia stripe', (0.375, -0.510, 1.01), (0.025, 0.027, 0.110), 'Core', cream, 0.003)
for normal in [Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 1, 0))]:
    center = MODEL_CENTER + normal * 0.506
    panel = box('Service panel', center, (0.64, 0.59, 0.030), 'Core', graphite, 0.016)
    panel.rotation_mode = 'QUATERNION'
    panel.rotation_quaternion = normal.to_track_quat('Z', 'Y')
    insert = box('Enamel inset', center + normal * 0.021, (0.579, 0.532, 0.023), 'Core', lime, 0.016)
    insert.rotation_mode = 'QUATERNION'
    insert.rotation_quaternion = normal.to_track_quat('Z', 'Y')
    basis = normal.to_track_quat('Z', 'Y')
    for slot in range(4):
        position = center + normal * 0.038 + basis @ Vector((-0.19 + slot * 0.128, 0.191, 0))
        vent = box('Vent recess', position, (0.071, 0.019, 0.005), 'Core', black, 0.002)
        vent.rotation_mode = 'QUATERNION'
        vent.rotation_quaternion = basis

socket_axes = {
    'Front': (0, -1, 0), 'Back': (0, 1, 0),
    'Right': (1, 0, 0), 'Left': (-1, 0, 0),
    'Top': (0, 0, 1), 'Bottom': (0, 0, -1),
}
for name, coordinates in socket_axes.items():
    normal = Vector(coordinates)
    center = MODEL_CENTER + normal * 0.526
    socket = root('Socket_' + name, center, core)
    socket.rotation_mode = 'QUATERNION'
    socket.rotation_quaternion = normal.to_track_quat('Z', 'Y')
    socket['mount_axis'] = '+Z outward'
    socket['interface_diameter_m'] = 0.28
    ring('Socket armor flange', center, 0.182, 0.082, 0.045, 'Core', graphite, normal)
    ring('Silver bayonet lock', center + normal * 0.027, 0.142, 0.090, 0.025, 'Core', silver, normal)
    cylinder('Socket recess', center + normal * 0.022, 0.090, 0.009, 'Core', black, normal, 8)
    ring('Socket status band', center + normal * 0.042, 0.103, 0.091, 0.008, 'Core', cyan, normal)
    basis = normal.to_track_quat('Z', 'Y')
    for index in range(4):
        angle = math.pi / 4 + index * math.pi / 2
        fastener = center + basis @ Vector((0.154 * math.cos(angle), 0.154 * math.sin(angle), 0.026))
        cylinder('Captive bolt', fastener, 0.014, 0.013, 'Core', silver, normal, 6, 0.001)

wheel_module = root('Mobility_Module', parent=robot)
wheel_module['role'] = 'detachable_bottom_module'
box('Axle cradle', (0, 0, 0.350), (0.50, 0.64, 0.10), 'Mobility_Module', graphite, 0.018)
cylinder('Bottom coupling', (0, 0, 0.430), 0.096, 0.080, 'Mobility_Module', silver, vertices=8)
for side in (-1, 1):
    for depth in (-0.335, 0.335):
        wheel_name = ('Left' if side < 0 else 'Right') + ('Front' if depth < 0 else 'Rear') + '_Wheel'
        wheel_root = root(wheel_name, parent=wheel_module)
        cylinder('Cross axle', (side * 0.285, depth, 0.217), 0.065, 0.185, 'Mobility_Module', silver, (1, 0, 0))
        line_box('Trailing suspension link', (side * 0.20, depth * 0.69, 0.37), (side * 0.39, depth, 0.217), 0.078, 'Mobility_Module', graphite)
        for x in (side * 0.30, side * 0.375):
            ring('Suspension bushing', (x, depth, 0.217), 0.080, 0.062, 0.017, 'Mobility_Module', yellow, (1, 0, 0))
        cylinder('Faceted tire', (side * 0.465, depth, 0.217), 0.207, 0.178, wheel_name, rubber, (1, 0, 0), 16, 0.012)
        ring('Outer sidewall ridge', (side * 0.565, depth, 0.217), 0.175, 0.135, 0.008, wheel_name, graphite, (1, 0, 0), 16)
        cylinder('Wheel rim', (side * 0.570, depth, 0.217), 0.132, 0.015, wheel_name, silver, (1, 0, 0), 12)
        ring('Rim accent', (side * 0.581, depth, 0.217), 0.115, 0.094, 0.008, wheel_name, yellow, (1, 0, 0), 12)
        cylinder('Wheel hub', (side * 0.593, depth, 0.217), 0.044, 0.021, wheel_name, graphite, (1, 0, 0), 8)
        for index in range(8):
            angle = index * math.tau / 8
            position = (side * 0.595, depth + math.cos(angle) * 0.078, 0.217 + math.sin(angle) * 0.078)
            cylinder('Wheel rim bolt', position, 0.009, 0.005, wheel_name, graphite, (1, 0, 0), 6, 0)
        for index in range(16):
            angle = index * math.tau / 16
            tread = box('Tire tread', (side * 0.465, depth + math.sin(angle) * 0.206, 0.217 + math.cos(angle) * 0.206), (0.123, 0.047, 0.009), wheel_name, graphite, 0.002)
            tread.rotation_euler.x = -angle

flight = root('Flight_Module', parent=robot)
flight['role'] = 'detachable_flight_component'
cylinder('Flight locking plug', (0, 0, 1.563), 0.089, 0.12, 'Flight_Module', silver, vertices=8)
cylinder('Motor base', (0, 0, 1.613), 0.177, 0.071, 'Flight_Module', graphite, vertices=12)
cylinder('Motor enamel', (0, 0, 1.665), 0.133, 0.072, 'Flight_Module', lime, vertices=12)
ring('Motor copper bearing', (0, 0, 1.708), 0.131, 0.080, 0.022, 'Flight_Module', yellow, segments=12)
cylinder('Rotor mast', (0, 0, 1.797), 0.045, 0.161, 'Flight_Module', silver)
for index in range(3):
    angle = math.tau * index / 3
    cylinder('Motor clamp screw', (math.cos(angle) * 0.118, math.sin(angle) * 0.118, 1.657), 0.012, 0.046, 'Flight_Module', silver, vertices=6, bevel=0.001)
rotor = root('Rotor', parent=flight)
rotor['rotation_axis'] = 'local Z; animate independently'
blade_outline = [(0.07, -0.035), (0.20, -0.068), (0.60, -0.115), (0.76, -0.035), (0.738, 0.056), (0.42, 0.100), (0.11, 0.032)]
tip_outline = [(0.63, -0.077), (0.753, -0.030), (0.732, 0.043), (0.617, 0.061)]
for index in range(3):
    angle = math.tau * index / 3 + 0.25
    blade = extruded_blade('Airfoil blade', blade_outline, 0.024, 'Rotor', cream)
    blade.location = (0, 0, 1.895)
    blade.rotation_euler.z = angle
    blade.rotation_euler.x = 0.06
    tip = extruded_blade('Safety blade tip', tip_outline, 0.003, 'Rotor', yellow)
    tip.location = (0, 0, 1.910)
    tip.rotation_euler.z = angle
cylinder('Rotor hub', (0, 0, 1.888), 0.117, 0.078, 'Rotor', graphite, vertices=12)
cylinder('Rotor cap', (0, 0, 1.937), 0.071, 0.026, 'Rotor', yellow, vertices=12)
cylinder('Rotor spindle bolt', (0, 0, 1.955), 0.025, 0.009, 'Rotor', silver, vertices=6, bevel=0.001)

for group in list(PARTS):
    join_group(group)

pivots = {'Core': MODEL_CENTER, 'Mobility_Module': Vector((0, 0, 0.454)), 'Flight_Module': Vector((0, 0, 1.526)), 'Rotor': Vector((0, 0, 1.895))}
for side in (-1, 1):
    for depth in (-0.335, 0.335):
        wheel_name = ('Left' if side < 0 else 'Right') + ('Front' if depth < 0 else 'Rear') + '_Wheel'
        pivots[wheel_name] = Vector((side * 0.465, depth, 0.217))
for name, pivot in pivots.items():
    value = ROOTS[name]
    transforms = {child: child.matrix_world.copy() for child in value.children}
    value.location = pivot
    if value.parent:
        value.location = value.parent.matrix_world.inverted() @ pivot
    bpy.context.view_layer.update()
    for child, transform in transforms.items():
        child.matrix_world = transform
    bpy.context.view_layer.update()

asset_collection = bpy.data.collections.new('EXPORT - robot and independent modules')
scene.collection.children.link(asset_collection)
asset_objects = list(ROOTS.values()) + [value for group in PARTS.values() for value in group]
for value in asset_objects:
    for collection in list(value.users_collection):
        collection.objects.unlink(value)
    asset_collection.objects.link(value)

model_stats = {}
for name, objects in PARTS.items():
    triangles = 0
    polygons = 0
    vertices = 0
    materials_used = 0
    for value in objects:
        value.data.calc_loop_triangles()
        triangles += len(value.data.loop_triangles)
        polygons += len(value.data.polygons)
        vertices += len(value.data.vertices)
        materials_used += len(value.data.materials)
    if objects:
        model_stats[name] = {'vertices': vertices, 'polygons': polygons, 'triangles': triangles, 'material_slots': materials_used}

bpy.ops.object.select_all(action='DESELECT')
for value in asset_objects:
    value.select_set(True)
bpy.context.view_layer.objects.active = PARTS['Core'][0]
export_start = time.perf_counter()
bpy.ops.export_scene.gltf(filepath=str(OUTPUT / 'core_robot.glb'), export_format='GLB', use_selection=True, export_yup=True, export_cameras=False, export_lights=False, export_animations=False, export_extras=True)
export_duration = time.perf_counter() - export_start

stage = root('Studio_Only')
cylinder('Exhibition platform', (0, 0, -0.080), 1.20, 0.17, 'Studio_Only', stone, vertices=64, bevel=0.017)
ring('Platform trim', (0, 0, -0.032), 1.208, 1.181, 0.011, 'Studio_Only', silver, segments=64)
box('Studio floor', (0, 0, -0.185), (200, 200, 0.050), 'Studio_Only', floor_mat, 0)
area_light('Key - warm softbox', (-3.5, -4.0, 6.5), 950, (1.0, 0.86, 0.67), 4.0, (0, 0, 0.85))
area_light('Fill - cool softbox', (4.5, -1.2, 3.0), 720, (0.60, 0.86, 1.0), 4.0, (0, 0, 0.9))
area_light('Rim - top', (0.5, 3.0, 4.8), 1200, (0.87, 1.0, 0.98), 3.0, (0, 0, 0.9))
world = bpy.data.worlds.new('Studio atmosphere')
world.use_nodes = True
world.node_tree.nodes.get('Background').inputs[0].default_value = (0.17, 0.21, 0.235, 1)
world.node_tree.nodes.get('Background').inputs[1].default_value = 0.4
scene.world = world
camera_data = bpy.data.cameras.new('Camera')
camera_data.type = 'ORTHO'
camera = bpy.data.objects.new('Camera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.cycles.diffuse_bounces = 3
scene.cycles.glossy_bounces = 3
try:
    preferences = bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type = 'OPTIX'
    preferences.get_devices()
    available = False
    for device in preferences.devices:
        device.use = device.type == 'OPTIX'
        available = available or device.use
    if available:
        scene.cycles.device = 'GPU'
except Exception:
    scene.cycles.device = 'CPU'
scene.render.resolution_x = 1536
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.render.film_transparent = False
scene.render.image_settings.color_mode = 'RGB'
scene.camera.location = (3.1, -4.5, 3.2)
aim(scene.camera, (0, 0, 0.94))
scene.camera.data.ortho_scale = 4.25
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_distance = 4.0
            area.spaces.active.region_3d.view_location = Vector((0, 0, 0.9))
            area.spaces.active.shading.color_type = 'MATERIAL'
            area.spaces.active.overlay.show_overlays = False
            area.spaces.active.region_3d.view_rotation = camera.rotation_euler.to_quaternion()

build_duration = time.perf_counter() - STARTED
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / 'core_robot.blend'))
render_times = {}
render_times['hero'] = render('hero.png', (3.1, -4.5, 3.2), (0, 0, 0.94), 4.25)
render_times['rear'] = render('rear.png', (3.3, 4.5, 2.9), (0, 0, 0.96), 4.25)
flight.location.z += 0.58
wheel_module.location.z -= 0.18
core.location.z += 0.13
for value in PARTS['Studio_Only']:
    value.hide_render = True
for value in scene.objects:
    if value.type == 'FONT':
        value.hide_render = True
scene.render.film_transparent = False
render_times['exploded'] = render('exploded.png', (3.1, -4.5, 3.0), (0, 0, 1.15), 4.45)
flight.location.z -= 0.58
wheel_module.location.z += 0.18
core.location.z -= 0.13
scene['asset_statistics'] = json.dumps(model_stats)
report = {
    'asset': 'K-01 modular core robot', 'method': 'Local procedural Blender modeling; no cloud generation',
    'blender': bpy.app.version_string, 'render_engine': 'Cycles', 'device': scene.cycles.device,
    'build_seconds': round(build_duration, 3), 'glb_export_seconds': round(export_duration, 3),
    'render_seconds': render_times, 'total_script_seconds': round(time.perf_counter() - STARTED, 3),
    'modules': model_stats, 'total_triangles': sum(value['triangles'] for value in model_stats.values()),
    'total_vertices': sum(value['vertices'] for value in model_stats.values()),
    'mesh_objects': sum(len(objects) for objects in PARTS.values()) - len(PARTS['Studio_Only']),
    'six_sockets': list(socket_axes), 'cloud_generation_calls': 0,
    'files': {name: (OUTPUT / name).stat().st_size for name in ['core_robot.blend', 'core_robot.glb', 'hero.png', 'rear.png', 'exploded.png']},
}
(OUTPUT / 'metrics.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('ROBOT_BUILD_COMPLETE ' + json.dumps(report, ensure_ascii=False))
