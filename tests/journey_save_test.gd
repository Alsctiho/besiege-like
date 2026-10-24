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
	await _tap(KEY_F5)
	_check(FileAccess.file_exists(CoreJourney.SAVE_PATH), "F5_writes_save")
	level.player.loadout.acquire("save_test_transient", "rotor")
	await _tap(KEY_F9)
	_check(level.player.loadout.snapshot() == before, "F9_restores_actual_input")
	_check(not paused, "readback_keeps_game_running")
	var inspector: Node = root.get_node_or_null("MCPGameInspector")
	_check(inspector != null and inspector.is_processing(), "inspector_processing_after_readback")
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
