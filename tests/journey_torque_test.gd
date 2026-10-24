extends SceneTree

var failures := 0
var checks := 0
var level: CoreJourney
var output := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--torque-output="): output = argument.trim_prefix("--torque-output=")
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("Torque test requires isolated progress mode")
		quit(1)
		return
	level = CoreJourney.new()
	root.add_child(level)
	var player := level.player
	player.checkpoint = Vector3(0, 0.98, 3)
	player.loadout.acquire("torque_rotor_a", "rotor")
	player.loadout.acquire("torque_rotor_b", "rotor")
	player.loadout.acquire("torque_booster", "booster")
	player.respawn()
	player.rotation = Vector3.ZERO
	await _hold(0.3)
	level.hud.open_assembly()
	await _choose_item("torque_rotor_a")
	await _click("左  " + str(JourneyCatalog.KEYS.left))
	await _click("朝前")
	await _choose_item("torque_rotor_b")
	await _click("右  " + str(JourneyCatalog.KEYS.right))
	await _click("朝后")
	await _capture("00-two-rotors-assembly.png")
	await _click("确认组装")
	_check(not level.hud.assembly.visible and player.loadout.kind_at("left") == "rotor" and player.loadout.kind_at("right") == "rotor", "two_rotors_commit_through_real_ui")
	_check(player.validate_loadout(player.loadout).is_empty(), "opposing_pair_has_valid_clearance")
	if not output.is_empty():
		level.camera.set_process(false)
		level.camera.position = Vector3(4.5, 3.7, 7.5)
		level.camera.look_at(Vector3(0, 0.6, 3))
	await _capture("00-opposing-rotors.png")
	var start := player.position
	_key(KEY_Q, true)
	_key(KEY_E, true)
	await _hold(0.8)
	_check(player.total_component_force.length() < 0.01, "equal_opposite_forces_cancel_translation")
	_check(player.total_component_torque.y > 100.0 and player.yaw_velocity > 1.0, "separated_forces_create_rotation")
	_check(absf(player.rotation.y) > 0.5, "body_rotates_without_wasd")
	_check(Vector2(player.position.x-start.x, player.position.z-start.z).length() < 0.05, "pure_couple_keeps_center_stationary")
	_check(player.component_forces.left.point.distance_to(player.component_forces.right.point) > 1.6, "forces_originate_at_distinct_component_mounts")
	var expected_torque := Vector3.ZERO
	for force: Dictionary in player.component_forces.values():
		expected_torque += (force.point-player.position).cross(force.force)
	_check(expected_torque.distance_to(player.total_component_torque) < 0.001, "reported_torque_equals_r_cross_force")
	var dust := 0
	for emitter: GPUParticles3D in player.effects.wheel_emitters.values():
		if emitter.emitting: dust += 1
	_check(dust == 4, "rotation_moves_all_four_wheel_contacts")
	await _capture("01-spinning-opposing-rotors.png")
	await _hold(1.0)
	_key(KEY_Q, false)
	await _hold(0.15)
	_check(player.component_forces.size() == 1 and player.component_forces.has("right"), "release_only_removes_one_component_force")
	_key(KEY_E, false)
	await _hold(0.05)
	var residual := absf(player.yaw_velocity)
	_check(residual > 0.1 and player.total_component_torque.is_zero_approx(), "release_retains_angular_inertia_without_new_torque")
	await _hold(1.5)
	_check(absf(player.yaw_velocity) < residual * 0.01, "ground_contact_damps_angular_inertia")
	player.loadout.install("left", "torque_rotor_a", "back")
	player.loadout.install("right", "torque_rotor_b", "front")
	player.respawn()
	player.rotation = Vector3.ZERO
	await _hold(0.2)
	_key(KEY_Q, true)
	_key(KEY_E, true)
	await _hold(0.4)
	_check(player.total_component_torque.y < -100.0 and player.yaw_velocity < -0.8, "reversing_pair_reverses_rotation")
	_key(KEY_Q, false)
	_key(KEY_E, false)
	player.loadout.install("right", "torque_rotor_b", "back")
	player.respawn()
	player.rotation = Vector3.ZERO
	await _hold(0.2)
	_key(KEY_Q, true)
	_key(KEY_E, true)
	await _hold(0.4)
	_check(player.total_component_torque.length() < 0.01 and absf(player.yaw_velocity) < 0.001, "symmetric_parallel_forces_have_no_yaw_torque")
	_check(player.velocity.z < -3.0, "parallel_pair_accelerates_forward")
	_key(KEY_Q, false)
	_key(KEY_E, false)
	player.loadout.remove("right")
	player.respawn()
	player.rotation = Vector3.ZERO
	await _hold(0.2)
	_key(KEY_Q, true)
	await _hold(0.4)
	_check(absf(player.yaw_velocity) > 0.5 and player.total_component_force.length() > 60, "one_off_center_rotor_moves_and_turns")
	_key(KEY_Q, false)
	player.loadout.remove("left")
	player.loadout.install("back", "torque_booster", "front")
	player.respawn()
	player.rotation = Vector3.ZERO
	await _hold(0.2)
	_key(KEY_X, true)
	await _hold(0.3)
	_check(absf(player.yaw_velocity) < 0.001 and player.velocity.z < -5, "centered_jet_has_translation_without_yaw")
	_key(KEY_X, false)
	player.loadout.remove("back")
	player.loadout.install("left", "torque_rotor_a", "front")
	player.loadout.install("right", "torque_rotor_b", "back")
	player.respawn()
	player.rotation = Vector3.ZERO
	player.position = Vector3(0, 6, 3)
	await _hold(0.02)
	_key(KEY_Q, true)
	_key(KEY_E, true)
	await _hold(0.25)
	_check(player.wheel_grip == 0.0 and player.yaw_velocity > 1.0, "component_torque_works_airborne_without_traction")
	_key(KEY_Q, false)
	_key(KEY_E, false)
	player.respawn()
	_check(player.yaw_velocity == 0.0 and player.component_forces.is_empty(), "respawn_clears_angular_inertia_and_forces")
	level.queue_free()
	await process_frame
	print("JOURNEY_TORQUE_COMPLETE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _choose_item(identifier: String) -> void:
	for node: Node in level.hud.inventory_list.get_children():
		var button := node as Button
		if button.get_meta("item_id", "") == identifier and button.is_visible_in_tree():
			button.emit_signal("pressed")
			await process_frame
			return
	_check(false, "missing_item_"+identifier)

func _click(text: String) -> void:
	for node: Node in level.hud.assembly.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and (button.text == text or button.tooltip_text == text):
			button.emit_signal("pressed")
			await process_frame
			return
	_check(false, "missing_button_"+text)

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
	_check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK, "capture_"+filename)

func _check(passed: bool, label: String) -> void:
	checks += 1
	print("TORQUE ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("TorqueTest: "+label)
