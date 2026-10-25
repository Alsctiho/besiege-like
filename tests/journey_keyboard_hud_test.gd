extends SceneTree

var checks := 0
var failures := 0
var level: CoreJourney
var output := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--keyboard-output="): output = argument.trim_prefix("--keyboard-output=")
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("Keyboard HUD test requires isolated progress mode")
		quit(1)
		return
	level = CoreJourney.new()
	root.add_child(level)
	await _hold(0.25)
	var hud := level.hud
	var board := hud.keyboard
	_check(hud.menu_icon.text.is_empty() and hud.menu_icon.icon != null, "chapter_is_one_icon_without_text")
	_check(hud.root.find_children("*", "ProgressBar", true, false).is_empty(), "energy_bar_removed")
	_check(board.find_children("*", "Label", true, false).is_empty(), "key_hints_have_no_letters")
	_check(board.caps.size() == 10 and board.get_child_count() == 10 and board.get_class() == "Control", "only_ten_floating_keycaps_without_keyboard_shell")
	_check(board.caps.q.position.y == board.caps.e.position.y and board.caps.q.position.x < board.caps.w.position.x and board.caps.w.position.x < board.caps.e.position.x, "q_w_e_follow_real_top_row")
	_check(board.caps.a.position.x > board.caps.q.position.x and board.caps.z.position.x > board.caps.a.position.x, "letter_rows_are_physically_staggered")
	_check(board.caps.z.position.y == board.caps.x.position.y and board.caps.x.position.x > board.caps.z.position.x, "z_x_follow_real_lower_row")
	_check(board.caps.space.size.x == board.caps.q.size.x * 3 and board.caps.space.position.y == board.caps.z.position.y and board.caps.space.position.x > board.caps.x.position.x, "wide_space_follows_z_x_as_requested")
	_check(not board.caps.has("up") and not board.caps.has("down") and not board.caps.has("left") and not board.caps.has("right"), "no_arrow_key_cluster")
	_check(not board.caps.has("tab") and not board.caps.has("p") and not board.caps.has("shift_left"), "no_unused_context_keys")
	var overlapping := false
	for first: String in board.caps:
		for second: String in board.caps:
			if first == second: continue
			if board.caps[first].get_rect().intersects(board.caps[second].get_rect()): overlapping = true
	_check(not overlapping, "all_keycaps_have_distinct_space")
	var kinds := {"front":"blower", "back":"drill", "left":"rod", "right":"booster", "top":"rotor"}
	for face: String in kinds:
		level.player.loadout.acquire("keyboard_"+face, kinds[face])
		level.player.loadout.install(face, "keyboard_"+face, "top" if face == "top" else face)
	await process_frame
	for key: String in board.FACE_KEYS:
		var face: String = board.FACE_KEYS[key]
		_check(board.icons[key].texture == JourneyPictograms.texture(level.player.loadout.kind_at(face)), "key_icon_matches_actual_slot_"+key)
	await _capture("01-keyboard-layout.png")
	_key(KEY_Q, true)
	await _hold(0.04)
	_check(bool(board.caps.q.get_meta("pressed", false)), "q_highlights_left_component_hint")
	_key(KEY_LEFT, true)
	await _hold(0.04)
	_check(bool(board.caps.q.get_meta("pressed", false)), "aliases_share_one_visible_hint")
	_key(KEY_Q, false)
	await _hold(0.04)
	_check(bool(board.caps.q.get_meta("pressed", false)) and level.player.active_faces.left, "hidden_arrow_alias_keeps_visible_hint_active")
	_key(KEY_LEFT, false)
	_key(KEY_SPACE, true)
	_key(KEY_UP, true)
	await _hold(0.08)
	_check(bool(board.caps.space.get_meta("pressed", false)) and level.player.active_faces.top, "space_and_up_share_visible_top_component_hint")
	await _capture("02-keyboard-pressed.png")
	_key(KEY_SPACE, false)
	_key(KEY_UP, false)
	level.player.loadout.remove("left")
	await process_frame
	_check(board.icons.q.texture == JourneyPictograms.texture("empty"), "unmount_clears_visible_component_icon")
	_check(board.size.x <= 180 and board.size.y <= 102, "hint_cluster_is_compact")
	for resolution in [Vector2i(1152,648), Vector2i(1920,1080), Vector2i(900,900)]:
		root.size = resolution
		await process_frame
		await process_frame
		var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_check(screen.encloses(board.get_global_rect()) and board.get_global_rect().get_center().x > screen.size.x * 0.6 and board.get_global_rect().get_center().y < screen.size.y * 0.4, "keyboard_top_right_and_inside_"+str(resolution))
		_check(not board.get_global_rect().intersects(hud.menu_icon.get_global_rect()), "corner_widgets_do_not_overlap_"+str(resolution))
		await _capture("03-layout-"+str(resolution.x)+"x"+str(resolution.y)+".png")
	root.size = Vector2i(1152,648)
	hud.menu_icon.emit_signal("pressed")
	await process_frame
	_check(hud.journey_menu.visible and paused, "icon_opens_existing_menu")
	hud.close_journey_menu()
	level.player.respawn()
	await _hold(0.2)
	hud.open_assembly()
	await _hold(0.05)
	_check(hud.assembly.visible and not board.visible and not hud.menu_icon.visible, "assembly_hides_exploration_widgets")
	hud.cancel()
	await process_frame
	_check(board.visible and hud.menu_icon.visible, "closing_assembly_restores_widgets")
	level.queue_free()
	await process_frame
	print("JOURNEY_KEYBOARD_HUD_COMPLETE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _capture(filename: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK, "capture_"+filename)

func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame
	await process_frame

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(passed: bool, label: String) -> void:
	checks += 1
	print("KEYBOARD_HUD ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("KeyboardHUDTest: "+label)
