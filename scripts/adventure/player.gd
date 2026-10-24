class_name JourneyPlayer
extends CharacterBody3D

signal tool_used(face: String, kind: String, origin: Vector3, direction: Vector3, continuous: bool)
signal respawned
var loadout := JourneyLoadout.new()
var assembly_open := false
var checkpoint := Vector3(0, 0.95, 6)
var active_faces: Dictionary = {}
var trigger_counts: Dictionary = {}
var output_axes: Dictionary = {}
var modules: Dictionary = {}
var cooldowns: Dictionary = {}
var energy := 1.0
var visual: Node3D
var rotor_nodes: Dictionary = {}
var core_visual: Node3D
var _elapsed := 0.0

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.92, 1.50, 0.92)
	collision.shape = shape
	collision.position.y = -0.22
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	core_visual = JourneyGeometry.model("core")
	visual.add_child(core_visual)
	loadout.changed.connect(rebuild_modules)
	loadout.acquire("starter_wheels", "wheel")
	loadout.install("bottom", "starter_wheels", "bottom")

func rebuild_modules() -> void:
	for node: Node3D in modules.values():
		node.queue_free()
	modules.clear()
	rotor_nodes.clear()
	active_faces.clear()
	cooldowns.clear()
	for face: String in loadout.slots:
		var kind := loadout.kind_at(face)
		var module := JourneyGeometry.mounted_module(kind, face, loadout.direction_at(face))
		module.name = "Module_" + face
		visual.add_child(module)
		modules[face] = module
		var rotors := module.find_children("Rotor", "Node3D", true, false)
		if not rotors.is_empty():
			rotor_nodes[face] = rotors[0]

func world_axis(face: String) -> Vector3:
	return (global_basis * JourneyCatalog.AXES[loadout.direction_at(face)]).normalized()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if assembly_open:
		return
	var moving := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): moving.z -= 1
	if Input.is_physical_key_pressed(KEY_S): moving.z += 1
	if Input.is_physical_key_pressed(KEY_A): moving.x -= 1
	if Input.is_physical_key_pressed(KEY_D): moving.x += 1
	var speed := 4.8 if loadout.kind_at("bottom") == "wheel" else 1.25
	var desired := moving.normalized() * speed
	velocity.x = move_toward(velocity.x, desired.x, delta * 10.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 10.0)
	velocity.y -= 13.0 * delta
	var spending := false
	output_axes.clear()
	for face: String in JourneyCatalog.FACES:
		var down := JourneyCatalog.face_down(face)
		var previous: bool = active_faces.get(face, false)
		active_faces[face] = down
		cooldowns[face] = maxf(float(cooldowns.get(face, 0.0)) - delta, 0.0)
		if not down or not loadout.slots.has(face):
			if modules.has(face) and loadout.kind_at(face) == "rod":
				var rod_visual: Node3D = modules[face].get_child(0)
				rod_visual.scale.y = lerpf(rod_visual.scale.y, 1.0, minf(delta * 10, 1))
			continue
		var kind := loadout.kind_at(face)
		var direction := world_axis(face)
		output_axes[face] = direction
		if not previous:
			trigger_counts[face] = int(trigger_counts.get(face, 0)) + 1
		var mount_distance := 0.526 + JourneyCatalog.mount_clearance(face, loadout.direction_at(face), kind)
		var origin: Vector3 = global_position + global_basis * (JourneyCatalog.AXES[face] * mount_distance) + direction * 0.4
		if kind == "rotor" or kind == "booster":
			if energy > 0.01:
				velocity += direction * (20.0 if kind == "rotor" else 38.0) * delta
				spending = true
				if rotor_nodes.has(face): rotor_nodes[face].rotate_y(delta * 32)
		elif kind != "wheel":
			var continuous := kind != "fireball"
			if continuous or (not previous and float(cooldowns[face]) <= 0.0):
				tool_used.emit(face, kind, origin, direction, continuous)
				if not continuous: cooldowns[face] = 0.28
			if kind == "rod" and modules.has(face):
				var rod_model: Node3D = modules[face].get_child(0)
				rod_model.scale.y = lerpf(rod_model.scale.y, 3.0, minf(delta * 8, 1))
			if kind == "drill" and modules.has(face):
				modules[face].get_child(0).rotate_object_local(Vector3.UP, delta * 16)
	energy = clampf(energy + delta * (-0.13 if spending else 0.22), 0, 1)
	velocity.x = clampf(velocity.x, -12, 12)
	velocity.z = clampf(velocity.z, -12, 12)
	velocity.y = clampf(velocity.y, -22, 6)
	move_and_slide()
	for node: Node in visual.find_children("*Wheel*Mesh*", "Node3D", true, false):
		node.rotate_x(delta * moving.z * 6)
	if global_position.y < -18:
		respawn()

func respawn() -> void:
	global_position = checkpoint
	velocity = Vector3.ZERO
	energy = 1.0
	respawned.emit()

func is_busy() -> bool:
	return assembly_open

func validate_loadout(candidate: JourneyLoadout) -> String:
	var bounds: Dictionary = {}
	for face: String in candidate.slots:
		var kind := candidate.kind_at(face)
		if kind == "wheel": continue
		var node := JourneyGeometry.mounted_module(kind, face, candidate.direction_at(face))
		visual.add_child(node)
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		var box_bounds := AABB()
		var initialized := false
		for mesh: MeshInstance3D in meshes:
			var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
			box_bounds = box_bounds.merge(mesh_bounds) if initialized else mesh_bounds
			initialized = true
		visual.remove_child(node)
		node.free()
		if not initialized: continue
		var shape := BoxShape3D.new()
		shape.size = box_bounds.size.max(Vector3.ONE * 0.01)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, box_bounds.get_center())
		query.collision_mask = 1
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return "%s面组件与场景碰撞，请移动到更宽阔的位置" % str(JourneyCatalog.LABELS[face])
		for other: String in bounds:
			if box_bounds.grow(-0.02).intersects(bounds[other]):
				return "%s面与%s面组件空间重叠，请改变朝向" % [JourneyCatalog.LABELS[face], JourneyCatalog.LABELS[other]]
		bounds[face] = box_bounds
	return ""
