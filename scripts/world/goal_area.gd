extends Area3D
## 解密目标区：机器落到悬崖平台上即通关。

var _won := false


func _ready() -> void:
	body_entered.connect(_on_body)


func _on_body(body: Node3D) -> void:
	if _won or not body is RigidBody3D:
		return
	_won = true
	get_tree().paused = true
	_show_victory()


func _show_victory() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 20
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.95, 0.82, 0.5, 0.22)
	ui.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)

	var t := Label.new()
	t.text = "🏁  通  关  ！"
	t.add_theme_font_size_override("font_size", 64)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := Label.new()
	s.text = "你造出了飞上悬崖的机器"
	s.add_theme_font_size_override("font_size", 22)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.modulate = Color(1, 1, 1, 0.85)
	vb.add_child(s)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 12)
	vb.add_child(pad)

	var entries := [
		["再飞一次", func() -> void:
			get_tree().paused = false
			get_tree().reload_current_scene()],
		["返回车库", func() -> void:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/garage.tscn")],
		["主菜单", func() -> void:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")],
	]
	for e in entries:
		var b := Button.new()
		b.text = e[0]
		b.custom_minimum_size = Vector2(240, 44)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(e[1])
		vb.add_child(b)

	# 金色庆祝粒子
	var fx := CPUParticles3D.new()
	fx.one_shot = false
	fx.amount = 80
	fx.lifetime = 1.6
	fx.explosiveness = 0.05
	fx.direction = Vector3.UP
	fx.spread = 55.0
	fx.initial_velocity_min = 6.0
	fx.initial_velocity_max = 11.0
	fx.gravity = Vector3(0, -9.0, 0)
	fx.scale_amount_min = 0.2
	fx.scale_amount_max = 0.5
	fx.emitting = true
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.position = global_position + Vector3.UP * 2.0
	add_child(fx)
