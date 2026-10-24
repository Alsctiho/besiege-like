extends SceneTree

var checks := 0
var failures := 0
var level: CoreJourney

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("MultiRotorTest requires isolated progress mode")
		quit(1)
		return
	level = CoreJourney.new()
	root.add_child(level)
	await create_timer(0.2).timeout
	var player := level.player
	player.position = Vector3(0, 0.98, 3)
	var candidate := JourneyLoadout.new()
	candidate.acquire("wheel", "wheel")
	candidate.acquire("rod", "rod")
	candidate.acquire("rotor_a", "rotor")
	candidate.acquire("rotor_b", "rotor")
	candidate.install("bottom", "wheel", "bottom")
	candidate.install("front", "rod", "front")
	candidate.install("left", "rotor_a", "back")
	candidate.install("right", "rotor_b", "bottom")
	for degrees in [0, 15, 30, 45, 60, 90, 135, 180, 225, 270, 315]:
		player.rotation.y = deg_to_rad(degrees)
		var error := player.validate_loadout(candidate)
		_check(error.is_empty(), "two_rotors_and_front_rod_fit_" + str(degrees), error)
	candidate.install("right", "rotor_b", "front")
	player.rotation = Vector3.ZERO
	_check(player.validate_loadout(candidate).is_empty(), "independent_opposite_rotor_orientations_fit", null)
	player.loadout.restore(candidate.snapshot())
	await process_frame
	_key(KEY_Q, true)
	_key(KEY_E, true)
	await create_timer(0.15).timeout
	_check(player.active_faces.get("left", false) and player.active_faces.get("right", false), "both_rotors_activate_independently", null)
	_check(player.output_axes.left.dot(Vector3.FORWARD) > 0.999 and player.output_axes.right.dot(Vector3.BACK) > 0.999, "rotors_keep_their_own_work_axes", player.output_axes)
	_key(KEY_Q, false)
	await create_timer(0.1).timeout
	_check(not player.active_faces.get("left", true) and player.active_faces.get("right", false), "release_one_does_not_stop_other_rotor", null)
	_key(KEY_E, false)
	await process_frame
	_check(player.loadout.items.size() == 4 and player.loadout.equipped_face("rotor_a") == "left" and player.loadout.equipped_face("rotor_b") == "right", "two_owned_instances_remain_distinct", player.loadout.snapshot())
	var module := JourneyGeometry.mounted_module("rotor", "right", "front")
	player.visual.add_child(module)
	var parts := player.AssemblyCollision.parts(module)
	_check(player.AssemblyCollision.intersects(parts, parts), "real_overlapping_shapes_are_rejected", null)
	player.visual.remove_child(module)
	module.free()
	var obstacle := JourneyGeometry.box(level.world, Vector3(0.85, 0.98, 2.64), Vector3(0.4, 0.5, 0.3), JourneyGeometry.material(Color.GRAY), true)
	await physics_frame
	await physics_frame
	_check(not player.validate_loadout(candidate).is_empty(), "real_rotor_obstacle_collision_remains_rejected", null)
	obstacle.queue_free()
	await process_frame
	level.queue_free()
	await process_frame
	print("JOURNEY_MULTI_ROTOR_COMPLETE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(passed: bool, label: String, actual: Variant) -> void:
	checks += 1
	print("MULTI_ROTOR ", "PASS " if passed else "FAIL ", label, " ", actual)
	if not passed:
		failures += 1
		push_error("MultiRotorTest: " + label)
