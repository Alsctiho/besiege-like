extends SceneTree

var failures := 0
var checks := 0
var player: JourneyPlayer
var output := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--effects-output="): output = argument.trim_prefix("--effects-output=")
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var world := JourneyWorld.new()
	fixture.add_child(world)
	player = JourneyPlayer.new()
	fixture.add_child(player)
	player.checkpoint = Vector3(0, 0.98, 3)
	player.respawn()
	var camera := JourneyCamera.new()
	camera.target = player
	fixture.add_child(camera)
	await _hold(0.3)
	_check(player.effects.wheel_emitters.size() == 4, "four_separate_wheel_emitters")
	_check(_dust_count() == 0, "standing_still_has_no_dust")
	_key(KEY_W, true)
	await _hold(0.65)
	_check(_dust_count() == 4, "each_grounded_wheel_emits_dust")
	var positions: Array[Vector3] = []
	for emitter: GPUParticles3D in player.effects.wheel_emitters.values():
		if not positions.has(emitter.global_position): positions.append(emitter.global_position)
		_check(not emitter.local_coords, "dust_remains_in_world_coordinates_" + str(emitter.name))
	_check(positions.size() == 4, "dust_origins_match_four_distinct_contacts")
	await _capture("01-four-wheel-dust.png")
	_key(KEY_W, false)
	await _hold(0.8)
	_check(_dust_count() == 0, "stopping_stops_new_dust")
	player.loadout.acquire("effects_blower", "blower")
	player.loadout.install("front", "effects_blower", "front")
	player.respawn()
	player.rotation = Vector3.ZERO
	await _hold(0.2)
	var start := player.position
	_key(KEY_Z, true)
	await _hold(0.7)
	_check(player.effects.wind_emitters.front.emitting, "blower_emits_wind_when_used")
	_check(player.effects.wind_axes.front.dot(Vector3.FORWARD) > 0.999, "wind_follows_actual_work_axis")
	_check(player.position.z > start.z + 0.35 and player.velocity.z > 1.0, "blower_recoil_moves_robot_opposite_wind")
	_check(player.velocity.length() < 3.0, "blower_recoil_is_weaker_than_wheel_drive")
	_check(_dust_count() == 4, "recoil_ground_motion_also_emits_wheel_dust")
	await _capture("02-blower-wind-and-recoil.png")
	_key(KEY_Z, false)
	await _hold(0.85)
	_check(not player.effects.wind_emitters.front.emitting, "release_stops_new_wind")
	_check(player.blower_reaction.is_zero_approx() and _dust_count() == 0, "released_blower_has_no_residual_drive")
	for direction: String in JourneyCatalog.FACES:
		player.respawn()
		player.rotation = Vector3.ZERO
		player.loadout.install("front", "effects_blower", direction)
		await _hold(0.15)
		_key(KEY_Z, true)
		await _hold(0.15)
		var axis: Vector3 = JourneyCatalog.AXES[direction]
		_check(player.blower_reaction.normalized().dot(-axis) > 0.999, "reaction_axis_" + direction)
		_check(player.effects.wind_emitters.front.global_basis.y.dot(axis) > 0.999, "particle_emission_axis_" + direction)
		_key(KEY_Z, false)
		await _hold(0.1)
	player.position = Vector3(0, 6, 3)
	player.velocity = Vector3.FORWARD * 2
	await _hold(0.1)
	_check(not player.is_on_floor() and _dust_count() == 0, "airborne_wheels_have_no_dust")
	player.loadout.remove("bottom")
	await _hold(0.1)
	_check(player.effects.wheel_emitters.is_empty(), "removed_wheels_remove_dust_emitters")
	player.loadout.remove("front")
	await _hold(0.1)
	_check(player.effects.wind_emitters.is_empty(), "removed_blower_removes_wind_emitter")
	fixture.queue_free()
	await process_frame
	print("JOURNEY_EFFECTS_COMPLETE checks=", checks, " failures=", failures)
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("effects-report.json"), FileAccess.WRITE)
		if file == null:
			push_error("JourneyEffectsTest: cannot write report")
			quit(1)
			return
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "all_passed": failures == 0}, "\t"))
		file.close()
	quit(0 if failures == 0 else 1)

func _dust_count() -> int:
	var count := 0
	for emitter: GPUParticles3D in player.effects.wheel_emitters.values():
		if emitter.emitting: count += 1
	return count

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
	var image := root.get_texture().get_image()
	_check(image.save_png(output.path_join(filename)) == OK, "screenshot_" + filename)

func _check(passed: bool, label: String) -> void:
	checks += 1
	print("JOURNEY_EFFECTS ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("JourneyEffectsTest: " + label)
