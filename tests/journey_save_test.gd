extends SceneTree

var failures := 0
var level: CoreJourney
var original_bytes := PackedByteArray()
var had_save := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	had_save = FileAccess.file_exists(CoreJourney.SAVE_PATH)
	if had_save:
		var source := FileAccess.open(CoreJourney.SAVE_PATH, FileAccess.READ)
		original_bytes = source.get_buffer(source.get_length())
		source.close()
	level = CoreJourney.new()
	root.add_child(level)
	await process_frame
	await process_frame
	var before := level.player.loadout.snapshot()
	level.world.restore_progress({}, level.player.loadout.items)
	await _tap(KEY_F5)
	_check(FileAccess.file_exists(CoreJourney.SAVE_PATH), "F5_writes_save")
	level.world.interact(level.world.blocker, "drill")
	level.world.activate_bridge()
	level.world.completed = true
	level.player.loadout.acquire("save_test_transient", "rotor")
	await _tap(KEY_F9)
	_check(level.player.loadout.snapshot() == before, "F9_restores_actual_input")
	_check(not paused, "readback_keeps_game_running")
	var inspector: Node = root.get_node_or_null("MCPGameInspector")
	_check(inspector != null and inspector.is_processing(), "inspector_processing_after_readback")
	_check(level.world.blocker.visible and not level.world.rock_broken, "saved_unbroken_barrier_restored")
	await create_timer(2.2).timeout
	_check(not level.world.bridge_active and absf(level.world.bridge.position.y + 8) < 0.01 and not level.world.completed, "old_bridge_tween_cannot_override_readback")
	await _tap(KEY_ESCAPE)
	_check(level.hud.journey_menu.visible and paused, "journey_menu_pauses")
	await _click("继续旅程")
	_check(not paused and level.player.loadout.snapshot() == before, "continue_preserves_progress")
	await _tap(KEY_ESCAPE)
	await _click("重新开始这一关")
	_check(not paused and not level.hud.journey_menu.visible, "single_restart_click_resumes_game")
	var extra_confirmations := 0
	for node: Node in level.hud.root.find_children("*", "Button", true, false):
		if (node as Button).text in ["确认重新开始", "取消重开"]: extra_confirmations += 1
	_check(extra_confirmations == 0, "no_redundant_restart_confirmation_buttons")
	_check(level.player.loadout.items == {"starter_wheels": "wheel"} and level.world.blocker.visible and not level.world.bridge_active, "restart_restores_initial_loadout_and_world")
	_check(level.world.nearest_pickup(Vector3(-7.2, 0.65, 3)) == "ruin_drill", "restart_restores_first_pickup")
	_check(not level.restart_backup_path.is_empty() and FileAccess.file_exists(level.restart_backup_path), "restart_backs_up_previous_save")
	if not level.restart_backup_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(level.restart_backup_path))
	if had_save:
		var target := FileAccess.open(CoreJourney.SAVE_PATH, FileAccess.WRITE)
		target.store_buffer(original_bytes)
		target.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CoreJourney.SAVE_PATH))
	level.queue_free()
	await process_frame
	print("JOURNEY_SAVE_COMPLETE failures=", failures)
	quit(0 if failures == 0 else 1)

func _click(text: String) -> void:
	for node: Node in level.hud.root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			button.emit_signal("pressed")
			await process_frame
			await process_frame
			return
	_check(false, "missing_menu_button_" + text)

func _tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func _check(passed: bool, label: String) -> void:
	print("JOURNEY_SAVE ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("JourneySaveTest: " + label)
