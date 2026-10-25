extends SceneTree

var level: CoreJourney
var failures := 0
var checks := 0
var output := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--driving-output="): output = argument.trim_prefix("--driving-output=")
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("Driving test requires isolated progress mode")
		quit(1)
		return
	level = CoreJourney.new()
	root.add_child(level)
	var player := level.player
	await _hold(0.3)
	player.rotation.y = PI / 2
	var facing := -player.global_basis.z
	var start := player.position
	_key(KEY_W, true)
	await _hold(0.45)
	_key(KEY_W, false)
	_check((player.position-start).dot(facing) > 0.7, "rotated_robot_drives_along_its_own_front")
	_check(absf(angle_difference(PI/2, player.rotation.y)) < 0.001, "w_does_not_reset_heading")
	await _capture("01-relative-forward.png")
	await _hold(0.6)
	start = player.position
	_key(KEY_S, true)
	await _hold(0.45)
	_key(KEY_S, false)
	_check((player.position-start).dot(-facing) > 0.7, "s_reverses_without_turning_around")
	_check(absf(angle_difference(PI/2, player.rotation.y)) < 0.001, "reverse_preserves_heading")
	await _hold(0.6)
	player.respawn()
	player.rotation.y = 0
	_key(KEY_A, true)
	await _hold(0.65)
	_check(player.rotation.y > 0.4, "a_turns_left_from_current_facing")
	_check(player.position.distance_to(player.checkpoint) < 0.1, "a_turns_in_place_without_sideways_drive")
	await _capture("02-left-steering.png")
	_key(KEY_A, false)
	await _hold(0.6)
	start = player.position
	facing = -player.global_basis.z
	_key(KEY_W, true)
	await _hold(0.4)
	_key(KEY_W, false)
	_check((player.position-start).dot(facing) > 0.5, "forward_after_turn_uses_new_heading")
	await _hold(0.7)
	var heading := player.rotation.y
	_key(KEY_D, true)
	await _hold(0.65)
	_key(KEY_D, false)
	_check(angle_difference(heading, player.rotation.y) < -0.4, "d_turns_right_from_current_facing")
	await _capture("03-right-steering.png")
	await _hold(0.7)
	player.respawn()
	player.rotation.y = 0
	_key(KEY_W, true)
	_key(KEY_A, true)
	await _hold(0.6)
	_key(KEY_W, false)
	_key(KEY_A, false)
	_check(player.rotation.y > 0.4 and player.position.x < -0.2 and player.position.z < player.checkpoint.z-0.4, "w_and_a_drive_a_left_curve")
	await _capture("04-left-driving-curve.png")
	player.respawn()
	player.rotation.y = PI/2
	_key(KEY_W, true)
	_key(KEY_S, true)
	_key(KEY_A, true)
	_key(KEY_D, true)
	await _hold(0.15)
	_check(player.velocity.length() < 0.01 and absf(player.yaw_velocity) < 0.001, "opposite_drive_and_steering_keys_cancel")
	for key: Key in [KEY_W, KEY_S, KEY_A, KEY_D]: _key(key, false)
	player.position = Vector3(0,8,3)
	player.velocity = Vector3(1,0,-2)
	_key(KEY_S, true)
	_key(KEY_D, true)
	await _hold(0.2)
	for key: Key in [KEY_S, KEY_D]: _key(key, false)
	_check(not player.is_on_floor() and player.wheel_grip == 0, "airborne_wheels_have_no_grip")
	_check(Vector2(player.velocity.x,player.velocity.z).distance_to(Vector2(1,-2)) < 0.001, "airborne_steering_does_not_add_or_brake_horizontal_speed")
	_check(angle_difference(PI/2,player.rotation.y) < -0.1, "airborne_d_only_changes_heading")
	player.loadout.acquire("drive_booster","booster")
	player.loadout.install("back","drive_booster","front")
	player.rotation.y = PI/2
	player.yaw_velocity = 0
	player.velocity = Vector3.ZERO
	facing = -player.global_basis.z
	_key(KEY_X,true)
	await _hold(0.15)
	_key(KEY_X,false)
	_check(player.velocity.dot(facing) > 2, "mounted_booster_provides_real_body_relative_airborne_thrust")
	level.audio.shutdown()
	await _hold(0.2)
	level.queue_free()
	await process_frame
	print("JOURNEY_DRIVING_COMPLETE checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func _capture(filename: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK,"screenshot_"+filename)

func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame
	await process_frame

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(passed: bool, label: String) -> void:
	checks += 1
	print("JOURNEY_DRIVING ","PASS " if passed else "FAIL ",label)
	if not passed:
		failures += 1
		push_error("JourneyDrivingTest: "+label)
