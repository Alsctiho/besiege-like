extends SceneTree

var failures := 0
var checks := 0
var level: CoreJourney
var output := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mechanics-output="): output = argument.trim_prefix("--mechanics-output=")
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("JourneyMechanicsTest requires isolated progress mode")
		quit(1)
		return
	level = CoreJourney.new()
	root.add_child(level)
	await _hold(0.3)
	var player := level.player
	player.position = Vector3(0, 0.98, -9.7)
	player.rotation = Vector3.ZERO
	player.loadout.acquire("test_drill", "drill")
	player.loadout.install("front", "test_drill", "front")
	if not output.is_empty():
		level.camera.set_process(false)
		level.camera.position = Vector3(4.5, 3.5, -6.3)
		level.camera.look_at(Vector3(0, 0.8, -10.7))
	await _hold(0.25)
	var model := player.modules.front.get_child(0) as Node3D
	var start := model.position
	var orientation := model.basis.get_rotation_quaternion()
	_key(KEY_Z, true)
	await _hold(0.06)
	_check(not level.world.rock_broken and float(player.drill_extensions.front) > 0.0, "drill_extends_before_contact_activation")
	await _hold(0.2)
	_check(model.position.distance_to(start) > 0.15, "drill_reaches_forward_extension")
	_check(orientation.angle_to(model.basis.get_rotation_quaternion()) > 0.1, "drill_has_rotation_animation")
	_check(level.world.rock_broken and is_instance_valid(level.world.collapse), "real_drill_spawns_collapse")
	_check(level.world.collapse.pieces.size() == 24, "collapse_preserves_visible_fragments")
	_check(not level.world.interact(level.world.blocker, "drill"), "repeated_drill_does_not_duplicate_collapse")
	await _capture("01-drilling-collapse.png")
	_key(KEY_Z, false)
	await _hold(0.2)
	_check(model.position.distance_to(start) < 0.01, "released_drill_retracts")
	var shard := level.world.collapse.pieces[0]
	var shard_start := shard.global_position
	var shard_rotation := shard.global_basis.get_rotation_quaternion()
	await _hold(0.25)
	_check(shard.global_position.distance_to(shard_start) > 0.1, "shards_move_instead_of_disappearing")
	_check(shard_rotation.angle_to(shard.global_basis.get_rotation_quaternion()) > 0.01, "shards_tumble")
	_check(shard.collision_layer == 0, "shards_do_not_block_player_or_trigger_exit")
	await _hold(3.0)
	_check(not is_instance_valid(level.world.collapse), "collapse_cleans_up_after_animation")
	level.world.restore_progress({}, player.loadout.items)
	_check(level.world.blocker.visible, "readback_restores_unbroken_barrier_without_debris")
	player.loadout.remove("front")
	player.respawn()
	await _hold(0.3)
	_check(player.wheel_grip == 1.0, "four_wheels_have_ground_traction")
	var ground_start := player.position
	_key(KEY_W, true)
	await _hold(0.45)
	_key(KEY_W, false)
	_check(player.position.z < ground_start.z - 0.5, "ground_wheels_drive")
	await _hold(0.6)
	player.position = Vector3(0, 6, 3)
	player.velocity = Vector3.ZERO
	await _hold(0.03)
	var wheel := player.effects.wheel_nodes.values()[0] as Node3D
	var wheel_angle := wheel.basis.get_rotation_quaternion()
	_key(KEY_W, true)
	await _hold(0.3)
	_key(KEY_W, false)
	_check(player.wheel_grip == 0.0 and not player.is_on_floor(), "airborne_wheels_have_zero_traction")
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 0.001, "wasd_cannot_accelerate_airborne_wheels")
	_check(wheel_angle.angle_to(wheel.basis.get_rotation_quaternion()) > 0.1, "airborne_wheels_still_spin")
	player.position = Vector3(0, 6, 3)
	player.velocity = Vector3(1, 0, -2)
	_key(KEY_S, true)
	await _hold(0.15)
	_key(KEY_S, false)
	_check(Vector2(player.velocity.x, player.velocity.z).distance_to(Vector2(1, -2)) < 0.001, "airborne_wasd_does_not_brake_or_reverse_inertia")
	player.loadout.acquire("test_rotor", "rotor")
	var expected := {"front":Vector3.BACK, "back":Vector3.FORWARD, "left":Vector3.RIGHT, "right":Vector3.LEFT, "top":Vector3.UP, "bottom":Vector3.DOWN}
	var keys := {"front":KEY_Z, "back":KEY_X, "left":KEY_Q, "right":KEY_E, "top":KEY_SPACE, "bottom":KEY_DOWN}
	for face: String in JourneyCatalog.FACES:
		player.loadout.install(face, "test_rotor", face)
		player.position = Vector3(0, 6, 3)
		player.velocity = Vector3.ZERO
		player.rotation = Vector3.ZERO
		player.yaw_velocity = 0.0
		player.energy = 1.0
		await _hold(0.03)
		_key(keys[face], true)
		await _hold(0.12)
		_key(keys[face], false)
		var axis: Vector3 = player.output_axes.get(face, Vector3.ZERO)
		_check(axis.distance_to(expected[face]) < 0.001, "mounted_rotor_thrust_" + face)
		if face in ["front", "back", "left", "right"]:
			_check(player.velocity.dot(expected[face]) > 1.0, "airborne_rotor_accelerates_" + face)
		elif face == "top":
			_check(player.velocity.y > 0.0, "top_rotor_overcomes_gravity")
		else:
			_check(player.velocity.y < -2.5, "bottom_rotor_pushes_down")
		await _hold(0.03)
	player.loadout.install("top", "test_rotor", "top")
	player.loadout.acquire("test_booster", "booster")
	player.loadout.install("back", "test_booster", "front")
	player.position = Vector3(0, 6, 3)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.energy = 1.0
	if not output.is_empty():
		level.camera.position = player.position + Vector3(4.5, 3.0, 5)
		level.camera.look_at(player.position)
	_key(KEY_X, true)
	await _hold(0.2)
	_key(KEY_X, false)
	_check(player.velocity.z < -5.0 and player.wheel_grip == 0.0, "booster_supplies_airborne_horizontal_power")
	await _capture("02-component-powered-flight.png")
	level.queue_free()
	await process_frame
	print("JOURNEY_MECHANICS_COMPLETE checks=", checks, " failures=", failures)
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("mechanics-report.json"), FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"all_passed":failures == 0}, "\t"))
		file.close()
	quit(0 if failures == 0 else 1)

func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _capture(filename: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK, "screenshot_" + filename)

func _check(passed: bool, label: String) -> void:
	checks += 1
	print("JOURNEY_MECHANICS ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("JourneyMechanicsTest: " + label)
