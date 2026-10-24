class_name BuildUI
extends CanvasLayer
## 建造界面：组件库面板、存/读/清空/模拟按钮、按键绑定面板、提示与 toast。
## 控件在代码中构建。

var level: BuildLevel

var _tool_label: Label
var _toast_label: Label
var _palette_buttons := {}
var _toast_tween: Tween

# 绑定面板状态
var _bind_panel: PanelContainer = null
var _selected_cell := Vector3i.ZERO
var _has_selection := false
var _capturing := {}   # {action: String, slot: int} 正在捕获按键时非空


func setup(l: BuildLevel) -> void:
	level = l
	_build()


func _build() -> void:
	# ---- 顶栏 ----
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_stylebox_override("panel", _panel_style())
	add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	top.add_child(hb)
	var title := Label.new()
	title.text = "BLOCK SIEGE · 建造工坊"
	title.add_theme_font_size_override("font_size", 22)
	hb.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	_btn(hb, "保存", _save)
	_btn(hb, "载入", _load)
	_btn(hb, "清空", _clear_all)
	var sim_btn := _btn(hb, "🚀 起飞挑战" if Game.puzzle_mode else "▶ 开始模拟",
		func() -> void: level.start_sim())
	sim_btn.add_theme_font_size_override("font_size", 18)
	_btn(hb, "示例:突击车", func() -> void: level.load_preset("突击车"))
	_btn(hb, "示例:飞行器", func() -> void: level.load_preset("飞行器"))
	var rev_btn := Button.new()
	rev_btn.text = "反转前后"
	rev_btn.toggle_mode = true
	rev_btn.button_pressed = Game.reverse_forward
	rev_btn.toggled.connect(func(on: bool) -> void:
		Game.reverse_forward = on
		show_toast("机器前方已%s（红色箭头 = ↑ 的行驶方向）" % ("反转" if on else "恢复")))
	hb.add_child(rev_btn)
	_btn(hb, "主菜单", func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

	# ---- 左侧组件库 ----
	var left := PanelContainer.new()
	left.position = Vector2(12, 60)
	left.add_theme_stylebox_override("panel", _panel_style())
	add_child(left)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	left.add_child(vb)
	vb.add_child(_label("组件库", 18))
	vb.add_child(_label("（无工具时点击方块=选中）", 12))
	for id in BlockDB.PALETTE_ORDER:
		var def := BlockDB.get_def(id)
		var b := Button.new()
		b.text = "%s · %s" % [def.cat, def.name]
		b.toggle_mode = true
		b.pressed.connect(_on_palette.bind(id))
		vb.add_child(b)
		_palette_buttons[id] = b
	_tool_label = _label("未选择组件", 15)
	_tool_label.modulate = Color(1, 1, 0.6)
	vb.add_child(_tool_label)
	refresh_tool()

	# ---- 底部操作提示 ----
	var hint := _label("左键放置/选中 · 右键删除 · R 旋转 · Ctrl+Z 撤销 · 中键旋转视角 · 滚轮缩放 · WASD 平移", 14)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -36.0
	hint.offset_bottom = -12.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.75)
	add_child(hint)

	# ---- toast ----
	_toast_label = _label("", 24)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)


func refresh_tool() -> void:
	for id in _palette_buttons:
		_palette_buttons[id].button_pressed = (id == level.selected)
	if level.selected == "":
		_tool_label.text = "未选择组件"
	else:
		var facing_name: String
		match level.facing:
			4: facing_name = "朝上"
			5: facing_name = "朝下"
			_:
				facing_name = "朝向 %d°" % (level.facing * 90)
		_tool_label.text = "%s（R 旋转，%s）" % [BlockDB.display_name(level.selected), facing_name]


func show_toast(text: String) -> void:
	if text == "":
		return
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


# ================= 按键绑定面板 =================

func show_binding_panel(cell: Vector3i) -> void:
	_selected_cell = cell
	_has_selection = true
	_rebuild_bind_panel()


func hide_binding_panel() -> void:
	_has_selection = false
	_capturing = {}
	if _bind_panel:
		_bind_panel.queue_free()
		_bind_panel = null


func _rebuild_bind_panel() -> void:
	if _bind_panel:
		_bind_panel.queue_free()
		_bind_panel = null
	if not _has_selection:
		return
	var data := level.machine.get_block(_selected_cell)
	if data.is_empty():
		hide_binding_panel()
		return
	var def := BlockDB.get_def(str(data.type))

	_bind_panel = PanelContainer.new()
	_bind_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bind_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bind_panel.grow_vertical = Control.GROW_DIRECTION_END
	_bind_panel.offset_right = -12.0
	_bind_panel.offset_top = 60.0
	_bind_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_bind_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(280, 0)
	_bind_panel.add_child(vb)
	vb.add_child(_label("选中：%s" % BlockDB.display_name(str(data.type)), 18))
	vb.add_child(_label("格子 @(%d,%d,%d)" % [_selected_cell.x, _selected_cell.y, _selected_cell.z], 13))

	if def.actions.is_empty():
		vb.add_child(_label("（该组件无可绑定动作）", 13))
	for action in def.actions:
		var aid: String = action.id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vb.add_child(row)
		row.add_child(_label(str(action.label), 15))
		var pos_btn := Button.new()
		pos_btn.pressed.connect(_start_capture.bind(aid, 0))
		row.add_child(pos_btn)
		if bool(action.get("analog", false)):
			var neg_btn := Button.new()
			neg_btn.pressed.connect(_start_capture.bind(aid, 1))
			row.add_child(neg_btn)
			_store_btn(aid, 1, neg_btn)
		_store_btn(aid, 0, pos_btn)
	# 面板操作行
	var ops := HBoxContainer.new()
	ops.add_theme_constant_override("separation", 6)
	vb.add_child(ops)
	_btn(ops, "清除绑定", func() -> void:
		level.machine.get_block(_selected_cell).k = {}
		_rebuild_bind_panel())
	_btn(ops, "关闭", hide_binding_panel)
	_refresh_bind_texts()


func _store_btn(aid: String, slot: int, btn: Button) -> void:
	if not _bind_panel.has_meta("btns"):
		_bind_panel.set_meta("btns", {})
	_bind_panel.get_meta("btns")[aid + "|" + str(slot)] = btn


func _start_capture(aid: String, slot: int) -> void:
	_capturing = {"action": aid, "slot": slot}
	_refresh_bind_texts()


func _refresh_bind_texts() -> void:
	if _bind_panel == null or not _bind_panel.has_meta("btns"):
		return
	var btns: Dictionary = _bind_panel.get_meta("btns")
	var b := level.machine.get_binding(_selected_cell)
	for key in btns:
		var parts: PackedStringArray = String(key).split("|")
		var aid := parts[0]
		var slot := int(parts[1])
		var btn: Button = btns[key]
		if _capturing.get("action") == aid and _capturing.get("slot") == slot:
			btn.text = "按任意键…"
		else:
			var arr: Array = b.get(aid, [0, 0])
			btn.text = ("＋ " if slot == 0 else "－ ") + _key_name(int(arr[slot]))
		btn.custom_minimum_size = Vector2(110, 0)


func _key_name(k: int) -> String:
	if k == 0:
		return "无"
	return OS.get_keycode_string(k as Key)


func _input(event: InputEvent) -> void:
	if _capturing.is_empty():
		return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ESCAPE:
			_capturing = {}
		else:
			var aid: String = _capturing.action
			var slot := int(_capturing.slot)
			var b := level.machine.get_binding(_selected_cell)
			var arr: Array = b.get(aid, [0, 0])
			arr[slot] = event.physical_keycode
			b[aid] = arr
			_capturing = {}
		_refresh_bind_texts()
		get_viewport().set_input_as_handled()


# ================= 顶部按钮功能 =================

func _on_palette(id: String) -> void:
	if level.selected == id:
		level.set_selected("")
	else:
		level.set_selected(id)


func _save() -> void:
	var err := SaveManager.save_machine(level.machine, "slot1")
	show_toast("已保存到存档槽 1" if err == OK else "保存失败：%s" % err)


func _load() -> void:
	if not SaveManager.slot_exists("slot1"):
		show_toast("存档槽 1 为空")
		return
	var err := SaveManager.load_machine(level.machine, "slot1")
	if err == OK:
		level.clear_undo()
		hide_binding_panel()
		show_toast("已载入存档槽 1（%d 个组件）" % level.machine.block_count())
	else:
		show_toast("载入失败：%s" % err)


func _clear_all() -> void:
	level.machine.clear()
	level.clear_undo()
	hide_binding_panel()
	show_toast("已清空")


func _btn(parent: Node, text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(fn)
	parent.add_child(b)
	return b


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.11, 0.14, 0.85)
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
