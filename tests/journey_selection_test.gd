extends SceneTree

var failures := 0
var checks := 0
var level: CoreJourney

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("JourneySelectionTest requires isolated progress mode")
		quit(1)
		return
	level = CoreJourney.new()
	root.add_child(level)
	await create_timer(0.2).timeout
	level.player.loadout.acquire("selection_rotor_a", "rotor")
	level.player.loadout.acquire("selection_rotor_b", "rotor")
	await _tap(KEY_TAB)
	await _click("旋翼 · 背包")
	var selected := level.hud.selected_item
	await _click("上  " + str(JourneyCatalog.KEYS.top))
	await _click("朝上")
	await _click("确认组装")
	_check(not level.hud.assembly.visible, "first_confirmation_commits")
	var before := level.player.loadout.snapshot()
	for iteration in range(3):
		await _tap(KEY_TAB)
		_check(level.hud.selected_item == selected and level.hud.selected_face == "top" and level.hud.selected_direction == "top", "retain_selection_and_pose_" + str(iteration))
		var highlighted := false
		for node: Node in level.hud.inventory_list.get_children():
			var button := node as Button
			if button.get_meta("item_id", "") == selected:
				highlighted = button.modulate != Color.WHITE
		_check(highlighted, "retained_instance_is_highlighted_" + str(iteration))
		_check(level.hud.ghost != null and level.hud.ghost.get_meta("item_id") == selected, "retained_instance_has_ghost_" + str(iteration))
		_check(level.player.loadout.snapshot() == before, "reopen_does_not_modify_equipment_" + str(iteration))
		await _tap(KEY_TAB)
	await _tap(KEY_TAB)
	await _click("朝后")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_TAB)
	_check(level.hud.selected_item == selected and level.hud.selected_direction == "top", "cancel_keeps_item_but_restores_committed_pose")
	await _tap(KEY_TAB)
	level.player.loadout.install("left", selected, "top")
	await _tap(KEY_TAB)
	_check(level.hud.selected_item == selected and level.hud.selected_face == "left" and level.hud.selected_direction == "top", "retained_item_follows_external_mount_change")
	await _tap(KEY_TAB)
	level.player.loadout.remove("left")
	await _tap(KEY_TAB)
	_check(level.hud.selected_item == selected, "unmounted_owned_item_stays_selected")
	await _tap(KEY_TAB)
	level.restart_progress()
	await create_timer(0.15).timeout
	await _tap(KEY_TAB)
	_check(level.hud.selected_item.is_empty() and level.hud.ghost == null, "restart_clears_selection_of_unowned_item")
	await _tap(KEY_TAB)
	level.queue_free()
	await process_frame
	print("JOURNEY_SELECTION_COMPLETE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _click(text: String) -> void:
	for node: Node in level.hud.root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and (button.text == text or button.tooltip_text == text):
			button.emit_signal("pressed")
			await process_frame
			return
	_check(false, "missing_button_" + text)

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
	checks += 1
	print("JOURNEY_SELECTION ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("JourneySelectionTest: " + label)
