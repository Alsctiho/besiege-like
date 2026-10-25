extends SceneTree

var failures := 0
var checks := 0
var player: JourneyPlayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	player = JourneyPlayer.new()
	fixture.add_child(player)
	player.loadout.acquire("fixture_rotor", "rotor")
	var bindings := {"left": [KEY_Q, KEY_LEFT], "right": [KEY_E, KEY_RIGHT], "top": [KEY_UP, KEY_SPACE], "bottom": [KEY_DOWN], "front": [KEY_Z], "back": [KEY_X]}
	for face: String in JourneyCatalog.FACES:
		for direction: String in JourneyCatalog.FACES:
			player.loadout.install(face, "fixture_rotor", direction)
			player.rotation.y = 0.0
			player.yaw_velocity = 0.0
			player.position = Vector3.ZERO
			player.velocity = Vector3.ZERO
			player.energy = 1
			for key: Key in bindings[face]:
				_key(key, true)
				await process_frame
				await physics_frame
				await physics_frame
				_check(player.active_faces.get(face, false), "binding_" + face + "_" + str(key))
				var output: Vector3 = player.output_axes.get(face, Vector3.ZERO)
				var expected := {"front":Vector3.BACK, "back":Vector3.FORWARD, "left":Vector3.RIGHT, "right":Vector3.LEFT, "top":Vector3.UP, "bottom":Vector3.DOWN}
				_check(output.distance_to(player.global_basis * expected[direction]) < 0.001, "rotor_thrust_" + face + "_" + direction)
				_key(key, false)
				await process_frame
				await physics_frame
				await physics_frame
				_check(not player.active_faces.get(face, true), "released_" + face)
	player.loadout.install("back", "fixture_rotor", "front")
	player.rotation.y = PI / 2
	_key(KEY_X, true)
	await physics_frame
	await physics_frame
	var rotated_axis: Vector3 = player.global_basis * Vector3.BACK
	_check(player.output_axes.get("back", Vector3.ZERO).distance_to(rotated_axis) < 0.001, "axis_follows_core_rotation")
	_key(KEY_X, false)
	await process_frame
	player.loadout.install("top", "fixture_rotor", "top")
	player.energy = 1.0
	_key(KEY_SPACE, true)
	await process_frame
	await physics_frame
	await physics_frame
	var trigger_start: int = player.trigger_counts.get("top", 0)
	_key(KEY_UP, true)
	await process_frame
	await physics_frame
	await physics_frame
	_check(int(player.trigger_counts.get("top", 0)) == trigger_start, "space_up_no_duplicate_trigger")
	_key(KEY_SPACE, false)
	await process_frame
	await physics_frame
	await physics_frame
	_check(player.active_faces.get("top", false), "up_still_active_after_space_release")
	_key(KEY_UP, false)
	await process_frame
	await physics_frame
	await physics_frame
	_check(not player.active_faces.get("top", true), "last_top_alias_release_stops")
	player.loadout.install("back", "fixture_rotor", "front")
	player.loadout.install("bottom", "starter_wheels", "bottom")
	JourneyGeometry.box(fixture, Vector3(0, -0.65, 0), Vector3(30, 1.3, 30), JourneyGeometry.material(Color.GRAY), true)
	for heading: float in [0.0, PI / 2, PI, -PI / 4]:
		for key: Key in [KEY_W, KEY_S, KEY_A, KEY_D]:
			player.position = Vector3(0, 0.98, 0)
			player.velocity = Vector3.ZERO
			player.rotation.y = heading
			player.yaw_velocity = 0.0
			for _frame in range(30): await physics_frame
			_check(player.is_on_floor() and player.wheel_grip == 1.0, "drive_fixture_has_real_ground_contact")
			var start := player.position
			_key(key, true)
			await process_frame
			for _frame in range(30): await physics_frame
			_key(key, false)
			await process_frame
			var displacement := player.position - start
			var forward := Basis(Vector3.UP, heading) * Vector3.FORWARD
			var turn := angle_difference(heading, player.rotation.y)
			var label := str(heading) + "_" + str(key)
			if key in [KEY_W, KEY_S]:
				var travel := forward if key == KEY_W else -forward
				_check(displacement.dot(travel) > 0.5, "body_relative_drive_"+label+" displacement="+str(displacement)+" grip="+str(player.wheel_grip))
				_check(absf(turn) < 0.001 and absf(displacement.dot(forward.cross(Vector3.UP))) < 0.01, "drive_does_not_snap_to_world_heading_"+label)
			else:
				_check(turn > 0.3 if key == KEY_A else turn < -0.3, "body_relative_steering_"+label)
				_check(Vector2(displacement.x, displacement.z).length() < 0.01, "steering_does_not_strafe_"+label)
			_check(player.world_axis("back").dot(-player.global_basis.z) > 0.999, "equipment_follows_current_body_"+label)
			for _frame in range(120): await physics_frame
			_check(absf(player.yaw_velocity) < 0.001, "ground_steering_inertia_settles_"+label)
			var stopped_heading := player.rotation.y
			for _frame in range(5): await physics_frame
			_check(absf(angle_difference(stopped_heading, player.rotation.y)) < 0.001, "retain_heading_when_stopped_"+label)
	fixture.queue_free()
	await process_frame
	print("JOURNEY_INPUT_COMPLETE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("JourneyInputTest: " + label)
