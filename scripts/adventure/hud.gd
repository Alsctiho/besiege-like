class_name JourneyHUD
extends CanvasLayer

const KeyboardCueScript = preload("res://scripts/adventure/keyboard_cue.gd")

signal save_requested
signal load_requested
signal restart_requested
signal sound_requested(key: String)
signal volume_requested(kind: String, value: float)
var journey_menu: Control
var _menu_was_paused := false
var player: JourneyPlayer
var world: JourneyWorld
var root: Control
var menu_icon: Button
var hint: Label
var toast: Label
var keyboard: KeyboardCueScript
var assembly: Control
var draft := JourneyLoadout.new()
var selected_face := "top"
var selected_direction := "top"
var selected_item := ""
var inventory_list: GridContainer
var lesson_image: TextureRect
var ghost: Node3D
var ghost_valid := false
var ghost_error := ""
var _ghost_material: StandardMaterial3D
var _invalid_material: StandardMaterial3D
var description: Label
var viewport: SubViewport
var preview_container: TextureRect
var preview_root: Node3D
var preview_camera: Camera3D
var face_buttons: Dictionary = {}
var direction_buttons: Dictionary = {}
var _toast_left := 0.0
var _paper := Color("e7dfcc")
var _ink := Color("675344")
var _accent := Color("b6aa83")

func _ready() -> void:
	name = "HUD"
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 17
	var normal := _style(Color("d8ccb7"), Color("a08768"))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", _style(_accent, Color("729d94")))
	theme.set_stylebox("pressed", "Button", _style(Color("659c8f"), _paper))
	theme.set_color("font_color", "Button", _ink)
	theme.set_color("font_hover_color", "Button", _ink)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_color", "Label", _paper)
	root.theme = theme
	menu_icon = _button(root, "旅程 / Esc", open_journey_menu)
	menu_icon.name = "JourneyMenuIcon"
	menu_icon.text = ""
	menu_icon.icon = JourneyPictograms.texture("gate")
	menu_icon.expand_icon = true
	menu_icon.add_theme_constant_override("icon_max_width", 28)
	menu_icon.position = Vector2(24, 20)
	menu_icon.size = Vector2(52, 52)
	var menu_style := _style(_paper, _ink)
	menu_style.set_corner_radius_all(14)
	menu_style.set_border_width_all(2)
	menu_icon.add_theme_stylebox_override("normal", menu_style)
	keyboard = KeyboardCueScript.new()
	root.add_child(keyboard)
	keyboard.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	keyboard.offset_left = -208
	keyboard.offset_right = -28
	keyboard.offset_top = 24
	keyboard.offset_bottom = 126
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-390, -54)
	hint.size = Vector2(780, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_shadow_color", Color("15242a"))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(hint)
	toast = Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-350, 106)
	toast.size = Vector2(700, 30)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color", Color("132329"))
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(toast)
	_build_assembly()
	_build_journey_menu()
	player.loadout.changed.connect(refresh_status)
	refresh_status()

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color = background
	value.border_color = border
	value.set_border_width_all(1)
	value.set_corner_radius_all(8)
	value.content_margin_left = 12
	value.content_margin_right = 12
	value.content_margin_top = 8
	value.content_margin_bottom = 8
	return value

func _label(parent: Node, text: String, size := 17) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", size)
	parent.add_child(value)
	return value

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var value := Button.new()
	value.text = text
	value.tooltip_text = text
	value.custom_minimum_size.y = 37
	value.pressed.connect(func() -> void: sound_requested.emit("ui_click"))
	value.pressed.connect(callback)
	parent.add_child(value)
	return value

func _icon(parent: Node, kind: String, size: Vector2) -> TextureRect:
	var value := TextureRect.new()
	value.texture = JourneyPictograms.texture(kind)
	value.custom_minimum_size = size
	value.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	value.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(value)
	return value

func _paper_panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(_paper, _ink)
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.16, 0.12, 0.08, 0.18)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var grain := TextureRect.new()
	grain.texture = JourneyPictograms.paper()
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_TILE
	grain.modulate.a = 0.48
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grain)
	return panel

func _build_assembly() -> void:
	assembly = Control.new()
	assembly.name = "Assembly"
	assembly.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(assembly)
	var dim := ColorRect.new()
	dim.color = Color(0.22, 0.17, 0.14, 0.24)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assembly.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 26)
	assembly.add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var header := _paper_panel(outer)
	var header_row := HBoxContainer.new()
	header.add_child(header_row)
	_icon(header_row, "core", Vector2(28, 28))
	var title := _label(header_row, "自由组装", 23)
	title.add_theme_color_override("font_color", _ink)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 22)
	outer.add_child(columns)
	preview_container = TextureRect.new()
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_container.stretch_mode = TextureRect.STRETCH_SCALE
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(preview_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(480, 480)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	preview_container.add_child(viewport)
	preview_container.texture = viewport.get_texture()
	preview_container.resized.connect(_update_preview_resolution)
	get_viewport().size_changed.connect(_update_preview_resolution)
	preview_root = Node3D.new()
	viewport.add_child(preview_root)
	var camera := Camera3D.new()
	preview_camera = camera
	camera.position = Vector3(2.5, 1.8, -3.3)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	preview_root.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 2.0
	preview_root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 145, 0)
	fill.light_energy = 0.7
	preview_root.add_child(fill)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("15262b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("97ada7")
	env.environment.ambient_light_energy = 0.65
	preview_root.add_child(env)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 490
	panel.add_theme_constant_override("separation", 12)
	columns.add_child(panel)
	var inventory := _paper_panel(panel)
	var inventory_content := VBoxContainer.new()
	inventory.add_child(inventory_content)
	var inventory_title := _label(inventory_content, "组件", 17)
	inventory_title.add_theme_color_override("font_color", _ink)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 80
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_content.add_child(scroll)
	inventory_list = GridContainer.new()
	inventory_list.columns = 5
	inventory_list.add_theme_constant_override("h_separation", 8)
	inventory_list.add_theme_constant_override("v_separation", 6)
	scroll.add_child(inventory_list)
	var selection := _paper_panel(panel)
	var selectors := HBoxContainer.new()
	selectors.add_theme_constant_override("separation", 16)
	selection.add_child(selectors)
	var faces := VBoxContainer.new()
	selectors.add_child(faces)
	var face_title := _label(faces, "安装位置", 15)
	face_title.add_theme_color_override("font_color", _ink)
	var face_grid := GridContainer.new()
	face_grid.columns = 3
	faces.add_child(face_grid)
	for face: String in JourneyCatalog.FACES:
		var button := _button(face_grid, str(JourneyCatalog.LABELS[face]) + "  " + str(JourneyCatalog.KEYS[face]), _select_face.bind(face))
		button.text = str(JourneyCatalog.LABELS[face]) + " " + ("Q" if face == "left" else "E" if face == "right" else "␣/↑" if face == "top" else str(JourneyCatalog.KEYS[face]))
		button.custom_minimum_size = Vector2(66, 35)
		button.add_theme_font_size_override("font_size", 14)
		face_buttons[face] = button
	var directions := VBoxContainer.new()
	selectors.add_child(directions)
	var direction_title := _label(directions, "工作朝向", 15)
	direction_title.add_theme_color_override("font_color", _ink)
	var direction_grid := GridContainer.new()
	direction_grid.columns = 3
	directions.add_child(direction_grid)
	for direction: String in JourneyCatalog.FACES:
		var button := _button(direction_grid, "朝" + str(JourneyCatalog.LABELS[direction]), _select_direction.bind(direction))
		button.custom_minimum_size = Vector2(55, 35)
		button.add_theme_font_size_override("font_size", 14)
		direction_buttons[direction] = button
	var lesson_panel := _paper_panel(panel)
	lesson_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lesson_content := VBoxContainer.new()
	lesson_panel.add_child(lesson_content)
	description = _label(lesson_content, "选择组件", 15)
	description.add_theme_color_override("font_color", _ink)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(460, 32)
	lesson_image = TextureRect.new()
	lesson_image.custom_minimum_size = Vector2(420, 148)
	lesson_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lesson_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lesson_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lesson_content.add_child(lesson_image)
	var actions := HBoxContainer.new()
	panel.add_child(actions)
	var remove := _button(actions, "卸下此面零件", stage_remove)
	remove.text = "卸下"
	remove.icon = JourneyPictograms.texture("remove")
	var confirm := _button(actions, "确认组装", commit)
	confirm.text = "确认"
	confirm.icon = JourneyPictograms.texture("check")
	for button: Button in [remove, confirm]:
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 23)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
	_ghost_material = _make_ghost_material(Color(0.33, 0.83, 0.74, 0.48))
	_invalid_material = _make_ghost_material(Color(0.90, 0.34, 0.22, 0.48))
	assembly.hide()

func _build_journey_menu() -> void:
	journey_menu = Control.new()
	journey_menu.name = "JourneyMenu"
	journey_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(journey_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.09, 0.07, 0.48)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journey_menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journey_menu.add_child(center)
	var paper := _paper_panel(center)
	paper.custom_minimum_size = Vector2(440, 240)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	paper.add_child(content)
	var title := _label(content, "风蚀高架 · 旅程", 24)
	title.add_theme_color_override("font_color", _ink)
	var state := _label(content, "继续会保留已拾取零件和已开启机关。", 16)
	state.add_theme_color_override("font_color", _ink)
	_button(content, "继续旅程", close_journey_menu)
	var restart := _button(content, "重新开始这一关", func() -> void: restart_requested.emit())
	restart.tooltip_text = "直接重开并自动备份存档，重置零件和机关"
	_volume_slider(content, "音乐", "music", 72)
	_volume_slider(content, "音效", "sfx", 70)
	journey_menu.hide()

func _volume_slider(parent: Node, text: String, kind: String, initial: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, text, 16)
	label.add_theme_color_override("font_color", _ink)
	label.custom_minimum_size.x = 65
	var slider := HSlider.new()
	slider.name = "Volume_" + kind
	slider.max_value = 100
	slider.step = 1
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void: volume_requested.emit(kind, value / 100.0))

func open_journey_menu() -> void:
	if assembly.visible: return
	_menu_was_paused = get_tree().paused
	journey_menu.show()
	get_tree().paused = true

func close_journey_menu() -> void:
	journey_menu.hide()
	get_tree().paused = _menu_was_paused

func refresh_status() -> void:
	keyboard.refresh(player.loadout)

func _update_preview_resolution() -> void:
	if viewport == null or not assembly.visible or preview_container.size.x <= 0 or preview_container.size.y <= 0:
		return
	var logical_size := get_viewport().get_visible_rect().size
	var pixel_size := Vector2(get_window().size)
	var display_scale := pixel_size / logical_size.max(Vector2.ONE)
	var target_size := Vector2i((preview_container.size * display_scale).ceil())
	target_size = target_size.max(Vector2i.ONE)
	if viewport.size != target_size:
		viewport.size = target_size

func open_assembly() -> void:
	if not player.is_on_floor():
		show_toast("先停在安全平台上再组装")
		return
	draft.restore(player.loadout.snapshot())
	if not draft.items.has(selected_item):
		selected_item = ""
	elif not draft.equipped_face(selected_item).is_empty():
		selected_face = draft.equipped_face(selected_item)
		selected_direction = draft.direction_at(selected_face)
	player.assembly_open = true
	assembly.show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().paused = true
	_refresh_editor()
	call_deferred("_update_preview_resolution")

func _select_face(face: String) -> void:
	selected_face = face
	selected_direction = draft.direction_at(face)
	if selected_item.is_empty() and draft.slots.has(face):
		selected_item = draft.slots[face].id
	preview_camera.position = Vector3(-2.5 if face == "left" else 2.5, 1.8, 3.3 if face == "back" else -3.3)
	preview_camera.look_at(Vector3.ZERO)
	_refresh_editor()

func _select_direction(direction: String) -> void:
	selected_direction = direction
	_refresh_editor()

func _select_item(identifier: String) -> void:
	if selected_item != identifier:
		_remember_candidate()
	selected_item = identifier
	_refresh_editor()

func _refresh_editor() -> void:
	for child in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.queue_free()
	for identifier: String in draft.items:
		var kind: String = draft.items[identifier]
		var equipped := draft.equipped_face(identifier)
		var suffix := " · 背包" if equipped.is_empty() else " · " + str(JourneyCatalog.LABELS[equipped]) + "面"
		var value := _button(inventory_list, str(JourneyCatalog.DEFINITIONS[kind].name) + suffix, _select_item.bind(identifier))
		value.text = ""
		value.icon = JourneyPictograms.texture(kind)
		value.expand_icon = true
		value.add_theme_constant_override("icon_max_width", 46)
		value.custom_minimum_size = Vector2(78, 65)
		value.set_meta("item_id", identifier)
		value.modulate = _accent if selected_item == identifier else Color.WHITE
		if not equipped.is_empty():
			value.text = str(JourneyCatalog.LABELS[equipped])
			value.add_theme_font_size_override("font_size", 12)
	for face: String in face_buttons:
		face_buttons[face].modulate = _accent if face == selected_face else Color.WHITE
	for direction: String in direction_buttons:
		direction_buttons[direction].modulate = _accent if direction == selected_direction else Color.WHITE
	var selected_kind: String = str(draft.items.get(selected_item, ""))
	description.text = "选择组件" if selected_kind.is_empty() else "%s  ·  %s面 %s  ·  朝%s" % [JourneyCatalog.DEFINITIONS[selected_kind].name, JourneyCatalog.LABELS[selected_face], JourneyCatalog.KEYS[selected_face], JourneyCatalog.LABELS[selected_direction]]
	if selected_kind == "rotor" or selected_kind == "booster":
		description.text += " · 推力向" + JourneyCatalog.thrust_label(selected_kind, selected_direction)
	lesson_image.texture = JourneyPictograms.lesson(selected_kind) if not selected_kind.is_empty() else JourneyPictograms.texture("core")
	description.tooltip_text = str(JourneyCatalog.DEFINITIONS[selected_kind].hint) if not selected_kind.is_empty() else "点击组件图标，再选择安装面和工作朝向"
	for child in preview_root.get_children():
		if child.has_meta("preview_model"):
			preview_root.remove_child(child)
			child.queue_free()
	var model := JourneyGeometry.model("core")
	model.set_meta("preview_model", true)
	preview_root.add_child(model)
	ghost = null
	ghost_valid = false
	ghost_error = ""
	var candidate := JourneyLoadout.new()
	candidate.restore(draft.snapshot())
	if not selected_kind.is_empty():
		ghost_error = candidate.install(selected_face, selected_item, selected_direction)
		if ghost_error.is_empty(): ghost_error = player.validate_loadout(candidate)
		ghost_valid = ghost_error.is_empty()
	for face: String in draft.slots:
		if not selected_kind.is_empty() and (face == selected_face or draft.slots[face].id == selected_item):
			continue
		var module := JourneyGeometry.mounted_module(draft.kind_at(face), face, draft.direction_at(face))
		model.add_child(module)
	if not selected_kind.is_empty():
		ghost = JourneyGeometry.mounted_module(selected_kind, selected_face, selected_direction)
		ghost.name = "InstallationGhost"
		ghost.set_meta("item_id", selected_item)
		ghost.set_meta("face", selected_face)
		ghost.set_meta("direction", selected_direction)
		model.add_child(ghost)
		for mesh: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = _ghost_material if ghost_valid else _invalid_material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not ghost_valid: description.text = ghost_error

func _make_ghost_material(color: Color) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	value.albedo_color = color
	value.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	value.cull_mode = BaseMaterial3D.CULL_DISABLED
	return value

func _remember_candidate() -> void:
	if selected_item.is_empty(): return
	var candidate := JourneyLoadout.new()
	candidate.restore(draft.snapshot())
	if not candidate.install(selected_face, selected_item, selected_direction).is_empty(): return
	if not player.validate_loadout(candidate).is_empty(): return
	draft.restore(candidate.snapshot())

func stage_remove() -> void:
	if draft.slots.has(selected_face): sound_requested.emit("unequip")
	draft.remove(selected_face)
	selected_item = ""
	_refresh_editor()

func commit() -> void:
	var candidate := JourneyLoadout.new()
	candidate.restore(draft.snapshot())
	if not selected_item.is_empty():
		var install_error := candidate.install(selected_face, selected_item, selected_direction)
		if not install_error.is_empty():
			description.text = install_error
			return
	var error := player.validate_loadout(candidate)
	if not error.is_empty():
		description.text = error
		return
	var changed := player.loadout.snapshot() != candidate.snapshot()
	player.loadout.restore(candidate.snapshot())
	if changed: sound_requested.emit("equip")
	_close()
	show_toast("组装完成：按所在面的键使用道具")
	save_requested.emit()

func cancel() -> void:
	_close()

func _close() -> void:
	assembly.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_tree().paused = false
	player.assembly_open = false
	refresh_status()

func show_toast(message: String) -> void:
	toast.text = message
	_toast_left = 3.5

func _input(event: InputEvent) -> void:
	if journey_menu.visible and event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			close_journey_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and assembly.visible and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		preview_camera.position = preview_camera.position.rotated(Vector3.UP, -event.relative.x * 0.008)
		preview_camera.look_at(Vector3.ZERO)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				if assembly.visible: cancel()
				else: open_assembly()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if assembly.visible: cancel()
				else: open_journey_menu()
				get_viewport().set_input_as_handled()
			KEY_R:
				if assembly.visible:
					var index := JourneyCatalog.FACES.find(selected_direction)
					_select_direction(JourneyCatalog.FACES[(index + 1) % 6])
			KEY_F5: save_requested.emit()
			KEY_F9: load_requested.emit()

func _process(delta: float) -> void:
	_toast_left -= delta
	toast.visible = _toast_left > 0 and not assembly.visible
	keyboard.visible = not assembly.visible
	hint.visible = not assembly.visible
	menu_icon.visible = not assembly.visible
	keyboard.update_pressed(not get_tree().paused and not assembly.visible)
	var nearest := world.nearest_pickup(player.global_position)
	hint.text = "F  ·  %s" % str(JourneyCatalog.DEFINITIONS[world.pickups[nearest].kind].name) if not nearest.is_empty() else ""
	if ghost != null and is_instance_valid(ghost):
		var tint := Color(0.33, 0.83, 0.74, 0.43 + sin(Time.get_ticks_msec() * 0.003) * 0.07) if ghost_valid else Color(0.90, 0.34, 0.22, 0.48)
		_ghost_material.albedo_color = tint if ghost_valid else _ghost_material.albedo_color
