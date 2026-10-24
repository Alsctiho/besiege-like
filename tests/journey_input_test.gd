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
	var bindings := {"left": [KEY_Q, KEY_LEFT], "right": [KEY_E, KEY_RIGHT], "top": [KEY_UP], "bottom": [KEY_DOWN], "front": [KEY_Z], "back": [KEY_X]}
	for face: String in JourneyCatalog.FACES:
		for direction: String in JourneyCatalog.FACES:
			player.loadout.install(face, "fixture_rotor", direction)
			player.rotation.y = 0.0
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
				_check(output.distance_to(JourneyCatalog.AXES[direction]) < 0.001, "axis_" + face + "_" + direction)
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
	var rotated_axis: Vector3 = player.global_basis * Vector3.FORWARD
	_check(player.output_axes.get("back", Vector3.ZERO).distance_to(rotated_axis) < 0.001, "axis_follows_core_rotation")
	_key(KEY_X, false)
	await physics_frame
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
