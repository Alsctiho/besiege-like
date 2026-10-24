class_name Explosion
extends Node3D
## 爆炸：半径内所有刚体按距离衰减施加径向冲量 + 火光粒子 + 闪光，2 秒后清理。


static func boom(parent: Node, pos: Vector3, radius: float, power: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var fx := Explosion.new()
	fx.global_position = pos
	parent.add_child(fx)
	fx._apply_blast(pos, radius, power)


func _apply_blast(pos: Vector3, radius: float, power: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	q.shape = sphere
	q.transform = Transform3D(Basis(), pos)
	q.collide_with_bodies = true
	var hits := space.intersect_shape(q, 32)
	for h in hits:
		var body = h.collider
		if body is RigidBody3D:
			var to_body: Vector3 = body.global_position - pos
			var d: float = to_body.length()
			var falloff: float = clampf(1.0 - d / radius, 0.15, 1.0)
			var dir: Vector3 = to_body.normalized() if d > 0.01 else Vector3.UP
			body.apply_central_impulse((dir + Vector3.UP * 0.6).normalized() * power * falloff)
			# 爆炸波及机器：近距离直接震落方块
			if body.is_in_group("machine"):
				var lvl := get_tree().current_scene
				if lvl and lvl.has_method("damage_machine_block"):
					lvl.damage_machine_block(body, pos, 2 if d < radius * 0.5 else 1)
	_spawn_fx(pos, radius)
	if get_tree().current_scene and get_tree().current_scene.has_method("play_sfx"):
		get_tree().current_scene.play_sfx("explosion", pos)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _spawn_fx(pos: Vector3, radius: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 8.0
	light.omni_range = radius * 2.5
	light.position = pos + Vector3.UP * 0.3
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.5)

	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 0.7
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 9.0
	particles.gravity = Vector3(0, -14, 0)
	particles.scale_amount_min = 0.25
	particles.scale_amount_max = 0.6
	particles.position = pos
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1.0, 0.6, 0.25)
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.5, 0.15)
	pm.emission_energy_multiplier = 3.0
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3.ONE * 0.09
	spark_mesh.material = pm
	particles.mesh = spark_mesh
	add_child(particles)
