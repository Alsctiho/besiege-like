extends Control
## 主菜单（控件在代码中构建）。


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.10, 0.13)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "BLOCK SIEGE"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "拼装你的战争机器"
	sub.add_theme_font_size_override("font_size", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(sub)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	vb.add_child(pad)

	var build_btn := Button.new()
	build_btn.text = "开始建造"
	build_btn.custom_minimum_size = Vector2(260, 48)
	build_btn.add_theme_font_size_override("font_size", 22)
	build_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/build_level.tscn"))
	vb.add_child(build_btn)

	var garage_btn := Button.new()
	garage_btn.text = "车库 · 选择机器"
	garage_btn.custom_minimum_size = Vector2(260, 48)
	garage_btn.add_theme_font_size_override("font_size", 22)
	garage_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/garage.tscn"))
	vb.add_child(garage_btn)

	var battle_btn := Button.new()
	battle_btn.text = "⚔ 平原战场"
	battle_btn.custom_minimum_size = Vector2(260, 48)
	battle_btn.add_theme_font_size_override("font_size", 22)
	battle_btn.pressed.connect(func() -> void:
		Game.puzzle_mode = false
		Game.level_mode = "battle"
		Game.battle_intent = true
		if Game.pending_machine.is_empty():
			get_tree().change_scene_to_file("res://scenes/garage.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/battle_level.tscn"))
	vb.add_child(battle_btn)

	var puzzle_btn := Button.new()
	puzzle_btn.text = "⛰ 解密关卡 · 飞上悬崖"
	puzzle_btn.custom_minimum_size = Vector2(260, 48)
	puzzle_btn.add_theme_font_size_override("font_size", 22)
	puzzle_btn.pressed.connect(func() -> void:
		Game.puzzle_mode = true
		get_tree().change_scene_to_file("res://scenes/puzzle_build.tscn"))
	vb.add_child(puzzle_btn)

	var quit_btn := Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(260, 44)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit_btn)
