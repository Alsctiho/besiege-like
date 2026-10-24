class_name JourneyHUD
extends CanvasLayer

signal save_requested
signal load_requested
var player: JourneyPlayer
var world: JourneyWorld
var root: Control
var objective: Label
var hint: Label
var toast: Label
var status: Label
var slot_labels: Dictionary = {}
var assembly: Control
var draft := JourneyLoadout.new()
var selected_face := "top"
var selected_direction := "top"
var selected_item := ""
var inventory_list: VBoxContainer
var description: Label
var viewport: SubViewport
var preview_container: TextureRect
var preview_root: Node3D
var preview_camera: Camera3D
var face_buttons: Dictionary = {}
var direction_buttons: Dictionary = {}
var _toast_left := 0.0
var _paper := Color("e7dfcc")
var _ink := Color("28363a")
var _accent := Color("84c7b8")

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
	var chapter_panel := PanelContainer.new()
	chapter_panel.position = Vector2(28, 22)
	chapter_panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.15, 0.16, 0.82), Color("867f6a")))
	root.add_child(chapter_panel)
	var chapter := VBoxContainer.new()
	chapter_panel.add_child(chapter)
	_label(chapter, "核 心 漫 游", 26)
	_label(chapter, "01  /  风蚀高架", 16)
	objective = _label(chapter, "寻找遗迹中的组件", 17)
	objective.modulate = Color("c7c9b8")
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-354, -94)
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	for face: String in JourneyCatalog.FACES:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(110, 66)
		card.add_theme_stylebox_override("panel", _style(Color(0.14, 0.18, 0.18, 0.86), Color("867f6a")))
		bottom.add_child(card)
		var text := _label(card, "", 14)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_labels[face] = text
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-390, -125)
	hint.size = Vector2(780, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_shadow_color", Color("15242a"))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(hint)
	var status_panel := PanelContainer.new()
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_panel.offset_top = -28
	status_panel.add_theme_stylebox_override("panel", _style(Color(0.10, 0.14, 0.15, 0.85), Color(0.2, 0.25, 0.24, 0.4)))
	root.add_child(status_panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status_panel.add_child(status)
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
	value.custom_minimum_size.y = 37
	value.pressed.connect(callback)
	parent.add_child(value)
	return value

func _build_assembly() -> void:
	assembly = Control.new()
	assembly.name = "Assembly"
	assembly.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(assembly)
	var dim := ColorRect.new()
	dim.color = Color(0.055, 0.08, 0.085, 0.95)
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
	_label(outer, "核心组装  /  六面接口", 27)
	_label(outer, "安装面决定按键 · 工作朝向决定作用 · 不切换工具", 16)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 22)
	outer.add_child(columns)
	var inventory := PanelContainer.new()
	inventory.custom_minimum_size.x = 245
	inventory.add_theme_stylebox_override("panel", _style(_paper, Color("9e8768")))
	columns.add_child(inventory)
	var list_container := VBoxContainer.new()
	inventory.add_child(list_container)
	var inventory_title := _label(list_container, "零件背包", 22)
	inventory_title.modulate = _ink
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_container.add_child(scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_list)
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
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	panel.custom_minimum_size.x = 330
	columns.add_child(panel)
	_label(panel, "1  选择安装面", 21)
	var face_grid := GridContainer.new()
	face_grid.columns = 3
	panel.add_child(face_grid)
	for face: String in JourneyCatalog.FACES:
		face_buttons[face] = _button(face_grid, str(JourneyCatalog.LABELS[face]) + "  " + str(JourneyCatalog.KEYS[face]), _select_face.bind(face))
	_label(panel, "2  选择工作朝向", 21)
	var direction_grid := GridContainer.new()
	direction_grid.columns = 3
	panel.add_child(direction_grid)
	for direction: String in JourneyCatalog.FACES:
		direction_buttons[direction] = _button(direction_grid, "朝" + str(JourneyCatalog.LABELS[direction]), _select_direction.bind(direction))
	description = _label(panel, "选择背包里的零件", 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(330, 100)
	_button(panel, "安装到所选面", stage_install)
	_button(panel, "卸下此面零件", stage_remove)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(spacer)
	_button(panel, "确认组装", commit)
	_button(panel, "取消  /  Tab", cancel)
	_label(outer, "Q / ← 左    E / → 右    ↑ 上    ↓ 下    Z 前    X 后  |  可同时使用", 16)
	assembly.hide()

func refresh_status() -> void:
	for face: String in JourneyCatalog.FACES:
		var kind := player.loadout.kind_at(face)
		var component := "空接口" if kind.is_empty() else str(JourneyCatalog.DEFINITIONS[kind].name)
		slot_labels[face].text = str(JourneyCatalog.LABELS[face]) + "  " + str(JourneyCatalog.KEYS[face]) + "\n" + component

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
	selected_item = ""
	player.assembly_open = true
	assembly.show()
	get_tree().paused = true
	_refresh_editor()
	call_deferred("_update_preview_resolution")

func _select_face(face: String) -> void:
	selected_face = face
	selected_direction = draft.direction_at(face)
	preview_camera.position = Vector3(-2.5 if face == "left" else 2.5, 1.8, 3.3 if face == "back" else -3.3)
	preview_camera.look_at(Vector3.ZERO)
	_refresh_editor()

func _select_direction(direction: String) -> void:
	selected_direction = direction
	_refresh_editor()

func _select_item(identifier: String) -> void:
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
		var value := _button(inventory_list, str(JourneyCatalog.DEFINITIONS[kind].icon) + "  " + str(JourneyCatalog.DEFINITIONS[kind].name) + suffix, _select_item.bind(identifier))
		value.modulate = _accent if selected_item == identifier else Color.WHITE
	for face: String in face_buttons:
		face_buttons[face].modulate = _accent if face == selected_face else Color.WHITE
	for direction: String in direction_buttons:
		direction_buttons[direction].modulate = _accent if direction == selected_direction else Color.WHITE
	var selected_kind: String = str(draft.items.get(selected_item, ""))
	description.text = "安装面：" + str(JourneyCatalog.LABELS[selected_face]) + "  ·  " + str(JourneyCatalog.KEYS[selected_face]) + "\n工作朝向：" + str(JourneyCatalog.LABELS[selected_direction])
	if not selected_kind.is_empty(): description.text += "\n" + str(JourneyCatalog.DEFINITIONS[selected_kind].hint)
	for child in preview_root.get_children():
		if child.has_meta("preview_model"):
			preview_root.remove_child(child)
			child.queue_free()
	var model := JourneyGeometry.model("core")
	model.set_meta("preview_model", true)
	preview_root.add_child(model)
	for face: String in draft.slots:
		var module := JourneyGeometry.mounted_module(draft.kind_at(face), face, draft.direction_at(face))
		model.add_child(module)
	var axis: Vector3 = JourneyCatalog.AXES[selected_direction]
	var start: Vector3 = JourneyCatalog.AXES[selected_face] * 0.62
	var arrow_material := JourneyGeometry.material(_accent, 0, 1.5)
	var arrow := JourneyGeometry.cylinder(model, start + axis * 0.35, 0.018, 0.6, arrow_material, 8)
	arrow.basis = JourneyGeometry.orientation_for_normal(axis)
	var point := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 0.065
	cone.height = 0.16
	point.mesh = cone
	point.material_override = arrow_material
	model.add_child(point)
	point.position = start + axis * 0.70
	point.basis = JourneyGeometry.orientation_for_normal(axis)

func stage_install() -> void:
	var message := draft.install(selected_face, selected_item, selected_direction)
	if not message.is_empty():
		description.text = message
		return
	_refresh_editor()

func stage_remove() -> void:
	draft.remove(selected_face)
	_refresh_editor()

func commit() -> void:
	var error := player.validate_loadout(draft)
	if not error.is_empty():
		description.text = error
		return
	player.loadout.restore(draft.snapshot())
	_close()
	show_toast("组装完成：按所在面的键使用道具")
	save_requested.emit()

func cancel() -> void:
	_close()

func _close() -> void:
	assembly.hide()
	get_tree().paused = false
	player.assembly_open = false
	refresh_status()

func show_toast(message: String) -> void:
	toast.text = message
	_toast_left = 3.5

func _input(event: InputEvent) -> void:
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
			KEY_F5: save_requested.emit()
			KEY_F9: load_requested.emit()

func _process(delta: float) -> void:
	_toast_left -= delta
	toast.visible = _toast_left > 0
	status.text = "WASD 移动  ·  F 拾取  ·  Tab 组装  ·  V 眺望  ·  F5 保存 / F9 读档  |  动力 %d%%" % int(player.energy * 100)
	for face: String in slot_labels:
		slot_labels[face].modulate = _accent if player.active_faces.get(face, false) else Color.WHITE
	var nearest := world.nearest_pickup(player.global_position)
	hint.text = "F  拾取「%s」" % str(JourneyCatalog.DEFINITIONS[world.pickups[nearest].kind].name) if not nearest.is_empty() else ""
	if world.completed:
		objective.text = "已穿越风蚀高架 · 下一段旅程尚待展开"
	elif not world.rock_broken:
		objective.text = "拾取钻头，朝前安装 · 按所在面的键打开裂岩"
	elif not world.bridge_active:
		objective.text = "点燃桥头热能机关，或用伸缩杆触碰开关"
	else:
		objective.text = "穿过升降桥 · 将旋翼朝上安装，登上高台"
