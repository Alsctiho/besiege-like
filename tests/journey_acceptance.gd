extends Node

var level: CoreJourney
var checks: Array[Dictionary] = []
var screenshots: Array[String] = []
var output := ""
var _frames := 0

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--verify-output="):
			output = argument.trim_prefix("--verify-output=")
	if output.is_empty():
		push_error("JourneyAcceptance: output directory required")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _process(_delta: float) -> void:
	_frames += 1

func _run() -> void:
	get_tree().current_scene = null
	var error := get_tree().change_scene_to_file("res://scenes/core_journey.tscn")
	_check(error == OK, "load_adventure")
	await get_tree().process_frame
	await get_tree().process_frame
	level = get_tree().current_scene as CoreJourney
	if level == null:
		_check(false, "adventure_scene_exists")
		_finish()
		return
	await _hold(0.6)
	_verify_world_layout()
	await _capture("00-ground-teaching.png", false)
	_check(level.world.has_node("ControlsInStone") and level.world.get_node("ControlsInStone").get_meta("world_teaching", false), "teaching_is_world_geometry")
	level.camera.vista = true
	await _hold(0.7)
	await _capture("01-monumental-world.png")
	level.camera.vista = false
	if not await _walk(Vector3(-7.2, 0, 3)):
		_finish()
		return
	await _tap(KEY_F)
	_check(level.player.loadout.items.has("ruin_drill"), "real_pickup_drill")
	_check(not level.world.take_pickup("ruin_drill", level.player.loadout), "duplicate_pickup_rejected")
	await _tap(KEY_TAB)
	_check(level.hud.assembly.visible and get_tree().paused, "assembly_pauses_world")
	var before_invalid := level.player.loadout.snapshot()
	_click("轮足", true)
	_click("上  " + str(JourneyCatalog.KEYS.top))
	_check(level.hud.ghost != null and not level.hud.ghost_valid, "invalid_wheel_mount_has_rejection_ghost")
	_click("确认组装", false, false)
	_check(level.player.loadout.snapshot() == before_invalid, "rejected_ghost_preserves_live_inventory")
	_click("钻头 · 背包", true)
	_click("左  Q / ←")
	_click("朝上")
	_check(level.hud.ghost != null and level.hud.ghost.get_meta("direction") == "top", "ghost_updates_to_vertical_direction")
	_check(level.hud.draft.kind_at("left").is_empty() and level.player.loadout.kind_at("left").is_empty(), "ghost_does_not_commit_equipment")
	_click("朝前")
	_check(level.hud.ghost != null and level.hud.ghost_valid and level.hud.ghost.get_meta("item_id") == "ruin_drill", "real_drill_ghost_at_candidate_mount")
	await _capture("02-six-face-assembly.png")
	_check(level.player.loadout.kind_at("left").is_empty(), "ghost_before_direct_confirm_keeps_live_equipment_unchanged")
	var redundant_actions := 0
	for node: Node in level.hud.assembly.find_children("*", "Button", true, false):
		if (node as Button).text in ["暂存", "Tab"]: redundant_actions += 1
	_check(redundant_actions == 0, "assembly_has_no_stage_or_tab_buttons")
	_click("确认组装")
	_check(level.player.loadout.kind_at("left") == "drill" and level.player.loadout.direction_at("left") == "front", "left_mount_independent_front_direction")
	_key(KEY_Q, true)
	await _hold(0.1)
	var trigger_start: int = level.player.trigger_counts.get("left", 0)
	_key(KEY_LEFT, true)
	await _hold(0.1)
	_check(int(level.player.trigger_counts.get("left", 0)) == trigger_start, "left_alias_no_double_trigger")
	_key(KEY_Q, false)
	await _hold(0.1)
	_check(level.player.active_faces.get("left", false), "left_alias_release_one_keeps_active")
	_key(KEY_LEFT, false)
	await _hold(0.1)
	_check(not level.player.active_faces.get("left", true), "left_alias_release_last_stops")
	if not await _walk(Vector3(7.2, 0, -4)):
		_finish()
		return
	await _tap(KEY_F)
	_check(level.player.loadout.items.has("ruin_fireball"), "real_pickup_fireball")
	if not await _walk(Vector3(0, 0, -9.4)):
		_finish()
		return
	_key(KEY_W, true)
	await _hold(0.25)
	_key(KEY_W, false)
	await _hold(0.2)
	_check((-level.player.global_basis.z).dot(Vector3.FORWARD) > 0.98, "face_barrier_after_side_pickup")
	_key(KEY_Q, true)
	await _hold(0.22)
	_check(is_instance_valid(level.world.collapse) and level.world.collapse.pieces.size() == 24, "real_drilling_produces_rock_fragments")
	await _capture("08-rock-collapse.png", false)
	await _hold(0.28)
	_key(KEY_Q, false)
	_check(level.world.rock_broken, "drill_real_contact_opens_barrier")
	if not await _walk(Vector3(1.6, 0, -19)):
		_finish()
		return
	await _tap(KEY_F)
	_check(level.player.loadout.items.has("ruin_rotor"), "real_pickup_rotor")
	await _tap(KEY_TAB)
	_click("火球 · 背包", true)
	_click("前  Z")
	_click("朝前")
	_click("旋翼 · 背包", true)
	_check(level.hud.draft.kind_at("front") == "fireball" and level.player.loadout.kind_at("front").is_empty(), "switching_item_preserves_only_uncommitted_candidate")
	_click("右  E / →")
	_click("朝后")
	_click("确认组装")
	_check(level.player.loadout.direction_at("right") == "back", "right_rotor_rear_axis_for_forward_thrust")
	_key(KEY_E, true)
	await _hold(0.5)
	var right_count: int = level.player.trigger_counts.get("right", 0)
	_key(KEY_RIGHT, true)
	await _hold(0.1)
	_check(int(level.player.trigger_counts.get("right", 0)) == right_count, "right_alias_no_double_trigger")
	_check(level.player.output_axes.get("right", Vector3.ZERO).distance_to(-level.player.global_basis.z) < 0.001, "horizontal_rotor_axis_follows_turning_core")
	_check(absf(level.player.yaw_velocity) > 0.1, "single_side_rotor_generates_turning_moment")
	_check(level.player.velocity.z < -1.0 and level.player.position.y < 1.3, "horizontal_rotor_accelerates_without_lift")
	_key(KEY_E, false)
	await _hold(0.1)
	_check(level.player.active_faces.get("right", false), "right_alias_release_one_keeps_active")
	_key(KEY_RIGHT, false)
	await _hold(0.1)
	if not await _walk(Vector3(-0.5, 0, -22)):
		_finish()
		return
	await _tap(KEY_TAB)
	_click("旋翼", true)
	_click("上  " + str(JourneyCatalog.KEYS.top))
	_click("朝上")
	_check(level.hud.ghost != null and level.hud.ghost_valid, "rotor_direct_confirmation_candidate")
	_click("确认组装")
	_check(level.player.loadout.equipped_face("ruin_rotor") == "top" and level.player.loadout.items.size() == 4, "same_rotor_moved_without_duplication")
	await _tap(KEY_TAB)
	_check(level.hud.selected_item == "ruin_rotor" and level.hud.selected_face == "top" and level.hud.selected_direction == "top", "reopening_keeps_selected_rotor_and_mount")
	_check(level.hud.ghost != null and level.hud.ghost.get_meta("item_id") == "ruin_rotor", "reopened_rotor_keeps_preview")
	await _capture("09-remembered-rotor.png", false)
	_click("卸下此面零件")
	await _tap(KEY_TAB)
	_check(level.player.loadout.equipped_face("ruin_rotor") == "top", "cancel_does_not_change_live_equipment")
	if not await _walk(Vector3(1.3, 0, -21)):
		_finish()
		return
	if not await _walk(Vector3(1.3, 0, -24.5)):
		_finish()
		return
	_key(KEY_W, true)
	await _hold(0.25)
	_key(KEY_W, false)
	await _hold(0.2)
	_check((-level.player.global_basis.z).dot(Vector3.FORWARD) > 0.98, "face_receiver_by_real_movement", {"position":level.player.position,"forward":-level.player.global_basis.z})
	_key(KEY_Z, true)
	await _hold(0.5)
	_key(KEY_Z, false)
	await _hold(2.1)
	_check(level.world.bridge_ready and level.world.bridge.position.distance_to(Vector3(0, -0.35, -34.5)) < 0.05, "real_fireball_activates_lift_bridge")
	_check(level.hud.toast.text == "升降桥已到位 · 可以通行", "bridge_prompt_reports_actual_arrival")
	await _capture("03-bridge-activated.png")
	if not await _walk(Vector3(0, 0, -46)):
		_finish()
		return
	_check(level.player.checkpoint.z < -40, "checkpoint_reached_by_traversal")
	if not await _walk(Vector3(5.3, 0, -44)):
		_finish()
		return
	await _tap(KEY_F)
	_check(level.player.loadout.items.has("ruin_blower"), "real_pickup_blower")
	await _tap(KEY_TAB)
	_click("吹风 · 背包", true)
	_click("后  X")
	_click("朝后")
	_click("确认组装")
	_key(KEY_W, true)
	await _hold(0.2)
	_key(KEY_W, false)
	await _hold(0.25)
	var wind_start := level.player.position
	_key(KEY_X, true)
	await _hold(0.8)
	_check(level.player.effects.wind_emitters.back.emitting, "installed_blower_has_real_wind_effect")
	_check(level.player.position.z < wind_start.z - 0.4, "blower_reaction_moves_player_without_wasd")
	var dust_count := 0
	for emitter: GPUParticles3D in level.player.effects.wheel_emitters.values():
		if emitter.emitting: dust_count += 1
	_check(dust_count == 4, "four_wheels_independently_emit_dust_during_recoil")
	await _capture("07-wind-and-wheel-dust.png", false)
	_key(KEY_X, false)
	await _hold(0.8)
	_check(not level.player.effects.wind_emitters.back.emitting, "blower_release_stops_new_wind")
	if not await _walk(Vector3(5.3, 0, -48)):
		_finish()
		return
	await _tap(KEY_F)
	_check(level.player.loadout.items.has("ruin_booster"), "real_pickup_flight_booster")
	await _tap(KEY_TAB)
	_click("推进 · 背包", true)
	_click("后  X")
	_click("朝前")
	_click("确认组装")
	if not await _walk(Vector3(0, 0, -46.0)):
		_finish()
		return
	if not await _walk(Vector3(0, 0, -48.7)):
		_finish()
		return
	_key(KEY_W, true)
	await _hold(0.2)
	_key(KEY_W, false)
	await _hold(0.35)
	var start_height := level.player.position.y
	_key(KEY_SPACE, true)
	await _hold(1.0)
	_check(level.player.position.y > start_height + 0.8 and level.player.velocity.y > 0, "top_rotor_real_lift")
	_check(level.player.wheel_grip == 0.0, "airborne_wheels_have_no_grip")
	_key(KEY_X, true)
	await _hold(0.2)
	_key(KEY_X, false)
	await _capture("04-vertical-flight.png")
	_key(KEY_SPACE, false)
	await _hold(1.8)
	_check(level.player.position.z < -54 and level.player.position.z > -75 and level.player.position.y > 3 and level.player.is_on_floor(), "crossed_gap_and_landed_on_high_deck")
	if not await _walk(Vector3(0, 3, -70)):
		_finish()
		return
	if not await _walk(Vector3(0, 3, -72)):
		_finish()
		return
	_check(level.world.completed, "exit_reached_by_player")
	await _capture("05-journey-complete.png")
	await _tap(KEY_TAB)
	await _capture("06-final-loadout.png")
	await _tap(KEY_TAB)
	_finish()

func _verify_world_layout() -> void:
	var diagrams: Array[Rect2] = []
	for node: Node in level.world.get_children():
		if node is MeshInstance3D and node.get_meta("world_teaching", false):
			var mesh := node as MeshInstance3D
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			diagrams.append(Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)))
	for identifier: String in level.world.pickups:
		var item: Dictionary = level.world.pickups[identifier]
		var model := item.node.get_child(0) as Node3D
		var original_rotation := model.rotation
		var clear := true
		for angle in [0.0, PI / 2, PI, PI * 1.5]:
			model.rotation.y = angle
			for node: Node in item.node.find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				var bounds: AABB = mesh.global_transform * mesh.get_aabb()
				var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(0.1)
				for diagram: Rect2 in diagrams:
					if footprint.intersects(diagram): clear = false
		model.rotation = original_rotation
		_check(clear, "pickup_clear_of_teaching_" + identifier)
	for node: Node in level.world.get_children():
		if not str(node.name).begins_with("UndersideArch_"): continue
		var clear := true
		for child: Node in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			if bounds.end.y >= -1.3: clear = false
		_check(clear, "decorative_arch_below_deck_" + str(node.name))

func _walk(target: Vector3) -> bool:
	for _index in range(900):
		var position := level.player.position
		var difference := Vector2(target.x - position.x, target.z - position.z)
		if difference.length() < 0.30 and level.player.is_on_floor() and absf(position.y - (target.y + 0.97)) < 0.5:
			_key(KEY_W, false)
			_key(KEY_S, false)
			_key(KEY_A, false)
			_key(KEY_D, false)
			await _hold(0.15)
			_check(true, "walk_" + str(target))
			return true
		_key(KEY_W, difference.y < -0.12)
		_key(KEY_S, difference.y > 0.12)
		_key(KEY_A, difference.x < -0.12)
		_key(KEY_D, difference.x > 0.12)
		await get_tree().process_frame
	_check(false, "walk_timeout_" + str(target), level.player.position)
	return false

func _key(key: Key, pressed: bool) -> void:
	if Input.is_physical_key_pressed(key) == pressed: return
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(key: Key) -> void:
	_key(key, true)
	await get_tree().process_frame
	_key(key, false)
	await get_tree().process_frame

func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

func _click(text: String, partial := false, expect_commit := true) -> bool:
	var button := _find_button(level.hud.root, text, partial)
	if not _check(button != null, "button_" + text): return false
	button.emit_signal("pressed")
	if text == "确认组装":
		return _check((not level.hud.assembly.visible) == expect_commit, "assembly_commit" if expect_commit else "invalid_assembly_rejected", {"detail": level.hud.description.text, "position": level.player.position, "slots": level.player.loadout.slots})
	return true

func _find_button(node: Node, text: String, partial: bool) -> Button:
	if node is Button and node.is_visible_in_tree() and (node.text == text or node.tooltip_text == text or (partial and (node.text.contains(text) or node.tooltip_text.contains(text)))):
		return node
	for child in node.get_children():
		var found := _find_button(child, text, partial)
		if found != null: return found
	return null

func _capture(filename: String, primary := true) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output.path_join(filename))
	var saved := _check(error == OK, "screenshot_" + filename)
	if saved and primary: screenshots.append(filename)

func _check(passed: bool, label: String, actual: Variant = null) -> bool:
	checks.append({"name": label, "passed": passed, "actual": str(actual), "frame": _frames})
	print("[JOURNEY_VERIFY] ", "PASS " if passed else "FAIL ", label, " ", actual)
	return passed

func _finish() -> void:
	get_tree().paused = false
	var passed := not checks.is_empty()
	for check in checks: passed = passed and check.passed
	var file := FileAccess.open(output.path_join("game-report.json"), FileAccess.WRITE)
	if file == null:
		push_error("JourneyAcceptance: failed to write report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({"all_passed": passed, "checks": checks, "screenshots": screenshots, "frames": _frames, "godot_version": Engine.get_version_info().string}, "\t"))
	file.close()
	print("[JOURNEY_VERIFY] COMPLETE all_passed=", passed)
	get_tree().quit(0 if passed else 1)
