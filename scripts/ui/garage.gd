extends Control
## 车库：选择机器（内置示例 + 玩家存档），右侧 3D 旋转预览。
## ▶ 直接出击 = 进模拟；🔧 去建造改装 = 进建造模式（机器已载入）。

var selected_data: Dictionary = {}
var selected_name := ""

var _preview_viewport: SubViewport
var _preview_cam: Camera3D
var _preview_root: Node3D
var _preview_machine: Node3D = null
var _orbit_t := 0.0
var _center := Vector3.ZERO
var _dist := 3.0
var _info_label: Label
var _list_buttons := {}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.10, 0.13)
	add_child(bg)

	var title := Label.new()
	title.text = "车 库 · 选择你的机器"
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(24, 16)
	add_child(title)

	# ---- 左侧：机器列表 ----
	var list_panel := PanelContainer.new()
	list_panel.position = Vector2(24, 70)
	list_panel.custom_minimum_size = Vector2(260, 420)
	list_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(list_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	list_panel.add_child(vb)
	vb.add_child(_label("内置示例", 16, Color(1, 1, 0.7)))
	for preset_name in Presets.ALL:
		_add_list_button(vb, preset_name, Presets.get_preset(preset_name))
	vb.add_child(_label("我的存档", 16, Color(1, 1, 0.7)))
	var user_slots := SaveManager.list_slots()
	if user_slots.is_empty():
		vb.add_child(_label("（还没有存档）", 13, Color(1, 1, 1, 0.5)))
	for slot in user_slots:
		_add_list_button(vb, slot, SaveManager.load_slot_data(slot))

	# ---- 右侧：3D 预览 ----
	var preview_panel := PanelContainer.new()
	preview_panel.position = Vector2(310, 70)
	preview_panel.custom_minimum_size = Vector2(560, 420)
	preview_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(preview_panel)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(540, 400)
	preview_panel.add_child(svc)
	_preview_viewport = SubViewport.new()
	_preview_viewport.own_world_3d = true
	_preview_viewport.transparent_bg = true
	_preview_viewport.msaa_3d = Viewport.MSAA_2X
	svc.add_child(_preview_viewport)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.5, 0)
	light.light_energy = 1.3
	_preview_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.4, -2.2, 0)
	fill.light_energy = 0.5
	_preview_viewport.add_child(fill)
	_preview_cam = Camera3D.new()
	_preview_viewport.add_child(_preview_cam)
	_preview_root = Node3D.new()
	_preview_viewport.add_child(_preview_root)

	# ---- 底部：信息 + 按钮 ----
	_info_label = _label("", 16, Color(1, 1, 0.8))
	_info_label.position = Vector2(310, 500)
	add_child(_info_label)

	var btn_bar := HBoxContainer.new()
	btn_bar.add_theme_constant_override("separation", 14)
	btn_bar.position = Vector2(310, 536)
	add_child(btn_bar)
	var go_btn := Button.new()
	go_btn.text = "▶ 直接出击"
	go_btn.custom_minimum_size = Vector2(170, 46)
	go_btn.add_theme_font_size_override("font_size", 19)
	go_btn.pressed.connect(func() -> void: _launch(true))
	btn_bar.add_child(go_btn)
	var build_btn := Button.new()
	build_btn.text = "🔧 去建造改装"
	build_btn.custom_minimum_size = Vector2(180, 46)
	build_btn.add_theme_font_size_override("font_size", 19)
	build_btn.pressed.connect(func() -> void: _launch(false))
	btn_bar.add_child(build_btn)
	var war_btn := Button.new()
	war_btn.text = "⚔ 出征战场"
	war_btn.custom_minimum_size = Vector2(180, 46)
	war_btn.add_theme_font_size_override("font_size", 19)
	if Game.battle_intent:
		war_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	war_btn.pressed.connect(func() -> void: _launch(true, "battle"))
	btn_bar.add_child(war_btn)
	var back := Button.new()
	back.text = "← 返回主菜单"
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	btn_bar.add_child(back)

	# 默认选中第一台
	if not Presets.ALL.is_empty():
		var first: String = Presets.ALL.keys()[0]
		_select(first, Presets.get_preset(first))


func _select(name: String, data: Dictionary) -> void:
	selected_name = name
	selected_data = data.duplicate(true)
	_rebuild_preview()
	var count: int = (data.get("blocks", []) as Array).size()
	_info_label.text = "已选择：%s（%d 个组件）" % [name, count]


func _add_list_button(vb: VBoxContainer, name: String, data: Dictionary) -> void:
	var b := Button.new()
	b.text = name
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void:
		_select(name, data)
		for other in _list_buttons:
			_list_buttons[other].button_pressed = other == name)
	vb.add_child(b)
	_list_buttons[name] = b


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	return l


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.11, 0.14, 0.9)
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


## 用 Machine 的建造视觉系统在预览视口里重建机器
func _rebuild_preview() -> void:
	if _preview_machine:
		_preview_root.remove_child(_preview_machine)
		_preview_machine.queue_free()
		_preview_machine = null
	for n in _preview_root.get_children():
		if n.name.begins_with("PreviewHelper"):
			n.queue_free()
	if selected_data.is_empty():
		return
	_preview_machine = Machine.new()
	_preview_machine.deserialize(selected_data)
	_preview_root.add_child(_preview_machine)
	# 计算包围盒中心与尺寸（用于相机对准）
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for cell: Vector3i in _preview_machine.grid:
		var w: Vector3 = _preview_machine.cell_to_world(cell)
		lo = lo.min(w - Vector3.ONE * 0.3)
		hi = hi.max(w + Vector3.ONE * 0.3)
	_center = (lo + hi) / 2.0
	_dist = maxf((hi - lo).length() * 1.5, 2.5)


func _launch(to_sim: bool, mode: String = "") -> void:
	if selected_data.is_empty():
		return
	Game.puzzle_mode = false
	Game.level_mode = mode
	Game.battle_intent = false
	Game.pending_machine = selected_data
	if to_sim and mode == "battle":
		get_tree().change_scene_to_file("res://scenes/battle_level.tscn")
	elif to_sim:
		get_tree().change_scene_to_file("res://scenes/sim_level.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/build_level.tscn")


func _process(delta: float) -> void:
	_orbit_t += delta * 0.5
	if _preview_cam == null:
		return
	var off := Vector3(sin(_orbit_t), 0.45, cos(_orbit_t)) * _dist
	_preview_cam.position = _center + off
	_preview_cam.look_at(_center + Vector3.UP * 0.1, Vector3.UP)
