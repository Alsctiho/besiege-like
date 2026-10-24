extends Node

var _output_dir := ""
var _checks: Array[Dictionary] = []
var _screenshots: Array[String] = []
var _frame_number := 0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--verify-output="):
			_output_dir = argument.trim_prefix("--verify-output=")
	if _output_dir.is_empty():
		push_error("SelfVerify: --verify-output is required")
		get_tree().quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(_output_dir) != OK:
		push_error("SelfVerify: cannot create output directory")
		get_tree().quit(1)
		return
	call_deferred("_run")


func _process(_delta: float) -> void:
	_frame_number += 1


func _run() -> void:
	seed(20261024)
	get_tree().current_scene = null
	if not await _open_scene("res://scenes/main_menu.tscn", "MainMenu"):
		_finish()
		return
	_check(_has_text(get_tree().current_scene, "BLOCK SIEGE"), "main_menu_title")
	await _hold(1.0)
	await _capture("01-main-menu.png")
	if not _click("开始建造") or not await _wait_scene("BuildLevel"):
		_finish()
		return
	var build_level := get_tree().current_scene as BuildLevel
	_check(build_level.machine.block_count() == 0, "initial_machine_empty")
	if not _click("示例:突击车"):
		_finish()
		return
	var expected_blocks: int = Presets.ASSAULT_CART.blocks.size()
	var loaded_blocks: int = build_level.machine.block_count()
	_check(loaded_blocks == expected_blocks, "preset_block_count", loaded_blocks)
	await _hold(1.5)
	await _capture("02-build-preset.png")
	if not _click("开始模拟", true) or not await _wait_scene("SimLevel"):
		_finish()
		return
	var sim_level := get_tree().current_scene as SimLevel
	if not _check(is_instance_valid(sim_level.root_body), "physics_root_exists"):
		_finish()
		return
	await _hold(1.5)
	await _capture("03-sim-before-drive.png")
	var start_position: Vector3 = sim_level.root_body.global_position
	_send_key(KEY_UP, true)
	await _hold(1.5)
	_send_key(KEY_UP, false)
	var end_position: Vector3 = sim_level.root_body.global_position
	var distance := Vector2(start_position.x, start_position.z).distance_to(Vector2(end_position.x, end_position.z))
	_check(end_position.is_finite() and distance > 0.1, "real_input_drives_machine", {
		"distance": distance, "start": str(start_position), "end": str(end_position),
	})
	await _capture("04-sim-after-drive.png")
	await _hold(0.8)
	_send_key(KEY_T, true)
	await get_tree().process_frame
	_send_key(KEY_T, false)
	if not await _wait_scene("BuildLevel"):
		_finish()
		return
	build_level = get_tree().current_scene as BuildLevel
	_check(build_level.machine.block_count() == loaded_blocks, "machine_preserved_after_sim", build_level.machine.block_count())
	await _hold(0.8)
	await _capture("05-build-return.png")
	if not _click("主菜单") or not await _wait_scene("MainMenu"):
		_finish()
		return
	_check(_has_text(get_tree().current_scene, "BLOCK SIEGE"), "returned_main_menu")
	await _hold(0.8)
	await _capture("06-main-menu-return.png")
	_finish()


func _open_scene(scene_path: String, expected_name: String) -> bool:
	var result := get_tree().change_scene_to_file(scene_path)
	if not _check(result == OK, "load_scene", scene_path):
		return false
	return await _wait_scene(expected_name)


func _wait_scene(expected_name: String) -> bool:
	for _frame_index in range(300):
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and str(scene.name) == expected_name and scene.is_node_ready():
			await get_tree().process_frame
			return _check(true, "scene_" + expected_name)
	return _check(false, "scene_" + expected_name, "timeout")


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _click(button_text: String, partial := false) -> bool:
	var button := _find_button(get_tree().current_scene, button_text, partial)
	if not _check(button != null, "button_" + button_text):
		return false
	button.emit_signal("pressed")
	return true


func _find_button(node: Node, button_text: String, partial: bool) -> Button:
	if node is Button and node.is_visible_in_tree():
		if node.text == button_text or (partial and node.text.contains(button_text)):
			return node
	for child in node.get_children():
		var found := _find_button(child, button_text, partial)
		if found != null:
			return found
	return null


func _has_text(node: Node, expected_text: String) -> bool:
	if node is Label and node.is_visible_in_tree() and node.text == expected_text:
		return true
	for child in node.get_children():
		if _has_text(child, expected_text):
			return true
	return false


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join(filename)
	var result := image.save_png(path) if image != null else ERR_CANT_CREATE
	if _check(result == OK, "screenshot_" + filename):
		_screenshots.append(filename)


func _check(passed: bool, label: String, actual: Variant = null) -> bool:
	_checks.append({"name": label, "passed": passed, "actual": actual, "frame": _frame_number})
	print("[SELFVERIFY] ", "PASS " if passed else "FAIL ", label, " ", actual)
	return passed


func _finish() -> void:
	var passed := not _checks.is_empty()
	for check in _checks:
		passed = passed and check.passed
	var report := {
		"all_passed": passed, "checks": _checks, "screenshots": _screenshots,
		"frames": _frame_number, "godot_version": Engine.get_version_info().string,
	}
	var file := FileAccess.open(_output_dir.path_join("game-report.json"), FileAccess.WRITE)
	if file == null:
		push_error("SelfVerify: could not write game report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[SELFVERIFY] COMPLETE all_passed=", passed)
	get_tree().quit(0 if passed else 1)
