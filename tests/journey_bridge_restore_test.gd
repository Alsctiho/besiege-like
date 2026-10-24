extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for active in [false, true]:
		var world := JourneyWorld.new()
		root.add_child(world)
		world.restore_progress({"bridge_active":active}, {})
		for _frame in range(8): await physics_frame
		_check_bridge(world, active, "startup_restore_" + str(active))
		if not active:
			var signals := {"started":0, "arrived":0}
			world.bridge_started.connect(func() -> void: signals.started += 1)
			world.bridge_arrived.connect(func() -> void: signals.arrived += 1)
			world.activate_bridge()
			_check(not world.bridge_ready and signals.started == 1 and signals.arrived == 0, "bridge_started_not_yet_ready", signals)
			await create_timer(0.3).timeout
			_check(world.bridge.position.y > -8.0 and world.bridge.position.y < -0.35 and absf(world.bridge.position.z + 34.5) < 0.01, "bridge_ascends_in_gap", world.bridge.position)
			await create_timer(2.0).timeout
			_check(world.bridge_ready and signals.arrived == 1, "arrival_after_real_animation", signals)
			_check_bridge(world, true, "activation_after_restore")
			world.activate_bridge()
			_check(signals.started == 1 and signals.arrived == 1, "repeated_activation_does_not_replay", signals)
		world.restore_progress({"bridge_active":false}, {})
		for _frame in range(8): await physics_frame
		_check_bridge(world, false, "reset_after_activation_" + str(active))
		world.restore_progress({"bridge_active":true}, {})
		for _frame in range(8): await physics_frame
		_check_bridge(world, true, "repeat_active_restore_" + str(active))
		world.queue_free()
		await process_frame
	print("JOURNEY_BRIDGE_RESTORE_COMPLETE failures=", failures)
	quit(0 if failures == 0 else 1)

func _check_bridge(world: JourneyWorld, active: bool, tag: String) -> void:
	var expected := Vector3(0, -0.35 if active else -8.0, -34.5)
	var physics_transform: Transform3D = PhysicsServer3D.body_get_state(world.bridge.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_check(world.bridge.position.distance_to(expected) < 0.01, tag + "_full_position", world.bridge.position)
	_check(physics_transform.origin.distance_to(expected) < 0.01, tag + "_physics_position", physics_transform.origin)
	var mesh := world.bridge.get_child(0).get_child(0) as MeshInstance3D
	var bounds: AABB = mesh.global_transform * mesh.get_aabb()
	_check(mesh.is_visible_in_tree() and absf(bounds.position.z + 41) < 0.01 and absf(bounds.end.z + 28) < 0.01, tag + "_visible_span", bounds)
	if active:
		for z_value in [-28.1, -34.5, -40.9]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(0, 2, z_value), Vector3(0, -1, z_value), 1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			_check(not hit.is_empty() and hit.collider == world.bridge and absf(hit.position.y) < 0.01, tag + "_walkable_" + str(z_value), hit)

func _check(passed: bool, tag: String, actual: Variant) -> void:
	print("JOURNEY_BRIDGE_RESTORE ", "PASS " if passed else "FAIL ", tag, " ", actual)
	if not passed:
		failures += 1
