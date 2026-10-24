class_name JourneyPlayerEffects
extends Node3D

var wind_emitters: Dictionary = {}
var wheel_emitters: Dictionary = {}
var wheel_nodes: Dictionary = {}
var wind_axes: Dictionary = {}
var _puff_mesh: QuadMesh

func _ready() -> void:
	name = "PlayerEffects"
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.65, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = texture
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2.ONE
	_puff_mesh.material = material

func configure(modules: Dictionary) -> void:
	for node: Node in get_children():
		node.queue_free()
	wind_emitters.clear()
	wheel_emitters.clear()
	wheel_nodes.clear()
	wind_axes.clear()
	for face: String in modules:
		var module := modules[face] as Node3D
		if module.has_meta("component_kind") and module.get_meta("component_kind") == "blower":
			var emitter := _emitter("Wind_" + face, true)
			wind_emitters[face] = emitter
		for node: Node in module.find_children("*Wheel*Mesh*", "MeshInstance3D", true, false):
			var key := str(node.name)
			wheel_nodes[key] = node
			wheel_emitters[key] = _emitter("Dust_" + key, false)

func _emitter(name_value: String, wind: bool) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = name_value
	emitter.emitting = false
	emitter.local_coords = false
	emitter.amount = 64 if wind else 20
	emitter.lifetime = 0.65 if wind else 0.75
	emitter.randomness = 0.35
	emitter.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	emitter.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 8, 10))
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.draw_pass_1 = _puff_mesh
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12 if wind else 0.05
	process.direction = Vector3.UP
	process.spread = 9.0 if wind else 30.0
	process.gravity = Vector3.ZERO if wind else Vector3(0, 0.2, 0)
	process.initial_velocity_min = 3.6 if wind else 0.45
	process.initial_velocity_max = 5.2 if wind else 0.9
	process.scale_min = 0.32 if wind else 0.17
	process.scale_max = 0.58 if wind else 0.29
	var size_curve := Curve.new()
	size_curve.max_value = 2.0
	size_curve.add_point(Vector2(0, 0.35))
	size_curve.add_point(Vector2(0.35, 1.0))
	size_curve.add_point(Vector2(1, 1.8))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = size_curve
	process.scale_curve = scale_texture
	var color := Color(0.90, 0.96, 1.0) if wind else Color(0.87, 0.76, 0.60)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
	fade.colors = PackedColorArray([Color(color, 0), Color(color, 0.32 if wind else 0.48), Color(color, 0.20 if wind else 0.32), Color(color, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	emitter.process_material = process
	add_child(emitter)
	return emitter

func wheel_contact(body: CharacterBody3D, wheel: Node3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(wheel.global_position + Vector3.UP * 0.15, wheel.global_position - Vector3.UP * 0.28, body.collision_mask)
	query.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() and hit.normal.y > 0.55 else {}

func grip_ratio(body: CharacterBody3D) -> float:
	if wheel_nodes.is_empty(): return 0.0
	var count := 0
	for wheel: Node3D in wheel_nodes.values():
		if not wheel_contact(body, wheel).is_empty(): count += 1
	return float(count) / float(wheel_nodes.size())

func update_effects(body: CharacterBody3D, loadout: JourneyLoadout, active_faces: Dictionary, yaw_speed := 0.0) -> void:
	wind_axes.clear()
	for face: String in wind_emitters:
		var emitter := wind_emitters[face] as GPUParticles3D
		var direction: Vector3 = (body.global_basis * JourneyCatalog.AXES[loadout.direction_at(face)]).normalized()
		var mount_distance := 0.526 + JourneyCatalog.mount_clearance(face, loadout.direction_at(face), "blower")
		var origin: Vector3 = body.global_position + body.global_basis * (JourneyCatalog.AXES[face] * mount_distance) + direction * 0.4
		emitter.global_transform = Transform3D(JourneyGeometry.orientation_for_normal(direction), origin)
		emitter.emitting = bool(active_faces.get(face, false))
		if emitter.emitting: wind_axes[face] = direction
	for key: String in wheel_emitters:
		var emitter := wheel_emitters[key] as GPUParticles3D
		var wheel := wheel_nodes[key] as Node3D
		var point_velocity := body.velocity + (Vector3.UP * yaw_speed).cross(wheel.global_position - body.global_position)
		var horizontal := Vector3(point_velocity.x, 0, point_velocity.z)
		var hit: Dictionary = {}
		if body.is_on_floor() and horizontal.length() > 0.35:
			hit = wheel_contact(body, wheel)
		emitter.emitting = not hit.is_empty() and hit.normal.y > 0.55
		if emitter.emitting:
			emitter.global_transform = Transform3D(Basis.IDENTITY, hit.position + hit.normal * 0.045)
			var process := emitter.process_material as ParticleProcessMaterial
			process.direction = (-horizontal.normalized() + Vector3.UP * 0.25).normalized()
			emitter.amount_ratio = clampf(horizontal.length() / 4.8, 0.2, 1.0)

func stop_all() -> void:
	for emitter: GPUParticles3D in wind_emitters.values(): emitter.emitting = false
	for emitter: GPUParticles3D in wheel_emitters.values(): emitter.emitting = false
	wind_axes.clear()
