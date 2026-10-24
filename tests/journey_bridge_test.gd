extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("JourneyBridgeTest requires isolated progress mode")
		quit(1)
		return
	var level := CoreJourney.new()
	root.add_child(level)
	level.player.loadout.acquire("bridge_test_rod", "rod")
	level.player.loadout.install("front", "bridge_test_rod", "front")
	level.player.position = Vector3(1.3, 0.98, -24.8)
	level.player.rotation = Vector3.ZERO
	for _frame in range(10): await physics_frame
	_key(KEY_Z, true)
	for _frame in range(20): await physics_frame
	_key(KEY_Z, false)
	await process_frame
	_check(not level.world.bridge_active, "rod_does_not_ignite_orange_receiver")
	level.player.position = Vector3(-1.7, 0.98, -24.8)
	level.player.velocity = Vector3.ZERO
	for _frame in range(10): await physics_frame
	_key(KEY_Z, true)
	await process_frame
	for _frame in range(20): await physics_frame
	_key(KEY_Z, false)
	await process_frame
	_check(level.world.bridge_active, "rod_contacts_white_switch_and_raises_bridge")
	await create_timer(2.2).timeout
	_check(absf(level.world.bridge.position.y + 0.35) < 0.05, "rod_bridge_reaches_walkable_height")
	level.queue_free()
	await process_frame
	print("JOURNEY_BRIDGE_COMPLETE failures=", failures)
	quit(0 if failures == 0 else 1)

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(passed: bool, label: String) -> void:
	print("JOURNEY_BRIDGE ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("JourneyBridgeTest: " + label)
