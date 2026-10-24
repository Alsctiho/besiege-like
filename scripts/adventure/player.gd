class_name JourneyPlayer
extends CharacterBody3D

const EffectsScript = preload("res://scripts/adventure/player_effects.gd")
const AssemblyCollision = preload("res://scripts/adventure/assembly_collision.gd")

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
var effects: EffectsScript
var blower_reaction := Vector3.ZERO
var wheel_grip := 0.0
var body_mass := 4.0
var yaw_inertia := 18.0
var yaw_velocity := 0.0
var component_forces: Dictionary = {}
var total_component_force := Vector3.ZERO
var total_component_torque := Vector3.ZERO
var drill_extensions: Dictionary = {}
var module_rest_positions: Dictionary = {}
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
	effects = EffectsScript.new()
	add_child(effects)
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
	drill_extensions.clear()
	module_rest_positions.clear()
	for face: String in loadout.slots:
		var kind := loadout.kind_at(face)
		var module := JourneyGeometry.mounted_module(kind, face, loadout.direction_at(face))
		module.name = "Module_" + face
		module.set_meta("component_kind", kind)
		visual.add_child(module)
		modules[face] = module
		module_rest_positions[face] = (module.get_child(0) as Node3D).position
		var rotors := module.find_children("Rotor", "Node3D", true, false)
		if not rotors.is_empty():
			rotor_nodes[face] = rotors[0]
	effects.configure(modules)

func world_axis(face: String) -> Vector3:
	return (global_basis * JourneyCatalog.AXES[loadout.direction_at(face)]).normalized()

func thrust_axis(face: String) -> Vector3:
	return (global_basis * JourneyCatalog.thrust_axis(loadout.kind_at(face), loadout.direction_at(face))).normalized()

func _update_drill(face: String, active: bool, delta: float) -> void:
	var extension := move_toward(float(drill_extensions.get(face, 0.0)), 0.18 if active else 0.0, delta * 1.2)
	drill_extensions[face] = extension
	var model := modules[face].get_child(0) as Node3D
	model.position = module_rest_positions[face] + JourneyCatalog.AXES[loadout.direction_at(face)] * extension
	if active: model.rotate_object_local(Vector3.UP, delta * 24.0)

func _component_force(face: String, force: Vector3, point: Vector3) -> void:
	var arm := point - global_position
	var torque := arm.cross(force)
	component_forces[face] = {"point":point, "force":force, "torque":torque}
	total_component_force += force
	total_component_torque += torque

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if assembly_open:
		return
	var moving := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): moving.z -= 1
	if Input.is_physical_key_pressed(KEY_S): moving.z += 1
	if Input.is_physical_key_pressed(KEY_A): moving.x -= 1
	if Input.is_physical_key_pressed(KEY_D): moving.x += 1
	rotation.y = wrapf(rotation.y + yaw_velocity * delta, -PI, PI)
	var steering_acceleration := 0.0
	if not moving.is_zero_approx():
		var facing_yaw := atan2(-moving.x, -moving.z)
		steering_acceleration = angle_difference(rotation.y, facing_yaw) * 120.0 - yaw_velocity * 20.0
	component_forces.clear()
	total_component_force = Vector3.ZERO
	total_component_torque = Vector3.ZERO
	blower_reaction = Vector3.ZERO
	for face: String in JourneyCatalog.FACES:
		if loadout.kind_at(face) == "blower" and JourneyCatalog.face_down(face):
			var reaction := -world_axis(face) * 1.6
			blower_reaction += reaction
			var mount_distance := 0.526 + JourneyCatalog.mount_clearance(face, loadout.direction_at(face), "blower")
			var point: Vector3 = global_position + global_basis * (JourneyCatalog.AXES[face] * mount_distance) + world_axis(face) * 0.4
			_component_force(face, -world_axis(face) * 12.8, point)
	blower_reaction = blower_reaction.limit_length(3.0)
	var has_wheels := loadout.kind_at("bottom") == "wheel"
	wheel_grip = effects.grip_ratio(self) if has_wheels and is_on_floor() else 0.0
	if wheel_grip > 0.0 or (not has_wheels and is_on_floor()):
		var speed := 4.8 if has_wheels else 1.25
		var traction := wheel_grip if has_wheels else 1.0
		var desired := moving.normalized() * speed
		if moving.is_zero_approx() and not component_forces.is_empty():
			velocity.x *= exp(-2.0 * traction * delta)
			velocity.z *= exp(-2.0 * traction * delta)
		else:
			velocity.x = move_toward(velocity.x, desired.x, delta * 10.0 * traction)
			velocity.z = move_toward(velocity.z, desired.z, delta * 10.0 * traction)
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
			if modules.has(face) and loadout.kind_at(face) == "drill": _update_drill(face, false, delta)
			continue
		var kind := loadout.kind_at(face)
		var direction := world_axis(face)
		output_axes[face] = direction
		if not previous:
			trigger_counts[face] = int(trigger_counts.get(face, 0)) + 1
		var mount_distance := 0.526 + JourneyCatalog.mount_clearance(face, loadout.direction_at(face), kind)
		var origin: Vector3 = global_position + global_basis * (JourneyCatalog.AXES[face] * mount_distance) + direction * 0.4
		if kind == "drill":
			_update_drill(face, true, delta)
			origin += direction * float(drill_extensions[face])
		if kind == "rotor" or kind == "booster":
			var force_axis := thrust_axis(face)
			output_axes[face] = force_axis
			if energy > 0.01:
				_component_force(face, force_axis * (80.0 if kind == "rotor" else 152.0), origin)
				spending = true
				if rotor_nodes.has(face): rotor_nodes[face].rotate_y(delta * 32)
		elif kind != "wheel":
			var continuous := kind != "fireball"
			var tool_ready := kind != "drill" or float(drill_extensions.get(face, 0.0)) >= 0.12
			if tool_ready and (continuous or (not previous and float(cooldowns[face]) <= 0.0)):
				tool_used.emit(face, kind, origin, direction, continuous)
				if not continuous: cooldowns[face] = 0.28
			if kind == "rod" and modules.has(face):
				var rod_model: Node3D = modules[face].get_child(0)
				rod_model.scale.y = lerpf(rod_model.scale.y, 3.0, minf(delta * 8, 1))
	velocity += total_component_force / body_mass * delta
	var yaw_acceleration := total_component_torque.y / yaw_inertia + steering_acceleration
	yaw_velocity += yaw_acceleration * delta
	yaw_velocity *= exp(-(3.5 * wheel_grip + 0.6) * delta)
	yaw_velocity = clampf(yaw_velocity, -4.0, 4.0)
	energy = clampf(energy + delta * (-0.13 if spending else 0.22), 0, 1)
	velocity.x = clampf(velocity.x, -12, 12)
	velocity.z = clampf(velocity.z, -12, 12)
	velocity.y = clampf(velocity.y, -22, 6)
	move_and_slide()
	effects.update_effects(self, loadout, active_faces, yaw_velocity)
	for node: Node3D in effects.wheel_nodes.values():
		var contact_velocity := velocity + (Vector3.UP * yaw_velocity).cross(node.global_position - global_position)
		var rolling_speed := contact_velocity.dot(-global_basis.z)
		if not is_on_floor(): rolling_speed = moving.length() * 4.8
		node.rotate_x(-delta * rolling_speed * 1.25)
	if global_position.y < -18:
		respawn()

func respawn() -> void:
	global_position = checkpoint
	velocity = Vector3.ZERO
	yaw_velocity = 0.0
	component_forces.clear()
	total_component_force = Vector3.ZERO
	total_component_torque = Vector3.ZERO
	energy = 1.0
	blower_reaction = Vector3.ZERO
	effects.stop_all()
	respawned.emit()

func is_busy() -> bool:
	return assembly_open

func validate_loadout(candidate: JourneyLoadout) -> String:
	var occupied: Dictionary = {}
	for face: String in candidate.slots:
		var kind := candidate.kind_at(face)
		if kind == "wheel": continue
		var node := JourneyGeometry.mounted_module(kind, face, candidate.direction_at(face))
		visual.add_child(node)
		var parts := AssemblyCollision.parts(node)
		visual.remove_child(node)
		node.free()
		for part: Dictionary in parts:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = part.shape
			query.transform = part.transform
			query.margin = 0.001
			query.collision_mask = 1
			query.exclude = [get_rid()]
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				return "%s面组件与场景碰撞，请移动到更宽阔的位置" % str(JourneyCatalog.LABELS[face])
		for other: String in occupied:
			if AssemblyCollision.intersects(parts, occupied[other]):
				return "%s面与%s面组件空间重叠，请改变朝向" % [JourneyCatalog.LABELS[face], JourneyCatalog.LABELS[other]]
		occupied[face] = parts
	return ""
