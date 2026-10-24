extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var world := JourneyWorld.new()
	fixture.add_child(world)
	var player := JourneyPlayer.new()
	fixture.add_child(player)
	player.set_physics_process(false)
	var camera := JourneyCamera.new()
	camera.target = player
	fixture.add_child(camera)
	camera.set_process(false)
	await physics_frame
	var largest_angle := 0.0
	var largest_step := 0.0
	for route in [0, 1]:
		camera.reset_tracking()
		player.position = Vector3(0, 0.98, -5)
		camera._process(1.0 / 60.0)
		for index in range(720):
			var z_value := -9.0 + sin(float(index) * TAU / 240.0) * 4.0
			player.position = Vector3(0, 0.98, z_value)
			var before := camera.global_basis.get_rotation_quaternion()
			var before_position := camera.global_position
			camera._process(1.0 / 60.0)
			if index > 0:
				largest_angle = maxf(largest_angle, before.angle_to(camera.global_basis.get_rotation_quaternion()))
				largest_step = maxf(largest_step, before_position.distance_to(camera.global_position))
		if route == 0:
			world.interact(world.blocker, "drill")
	_check(largest_angle < deg_to_rad(2.0), "no_one_frame_look_target_cut", rad_to_deg(largest_angle))
	_check(largest_step < 0.5, "continuous_position_across_boundary", largest_step)
	camera.reset_tracking()
	player.position = Vector3(0, 0.98, -9)
	camera._process(1.0 / 60.0)
	var before_vista := camera.global_basis.get_rotation_quaternion()
	camera.vista = true
	camera._process(1.0 / 60.0)
	_check(before_vista.angle_to(camera.global_basis.get_rotation_quaternion()) < deg_to_rad(2.0), "vista_toggle_is_blended", null)
	fixture.queue_free()
	await process_frame
	print("JOURNEY_CAMERA_COMPLETE failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(passed: bool, label: String, actual: Variant) -> void:
	print("JOURNEY_CAMERA ", "PASS " if passed else "FAIL ", label, " ", actual)
	if not passed:
		failures += 1
		push_error("JourneyCameraTest: " + label)
