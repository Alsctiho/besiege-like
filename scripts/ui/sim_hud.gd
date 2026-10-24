class_name SimHUD
extends CanvasLayer
## 模拟模式 HUD：提示与 toast。

var _toast_label: Label
var _toast_tween: Tween
var _keys_label: Label


func _ready() -> void:
	var hint := Label.new()
	hint.text = "模拟模式 · T 返回建造 · A/D 空中转向 · 中键旋转视角 · 滚轮缩放 · C 跟随/自由相机"
	hint.add_theme_font_size_override("font_size", 14)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -36.0
	hint.offset_bottom = -12.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.75)
	add_child(hint)

	# 左上角：当前机器的按键绑定提示
	_keys_label = Label.new()
	_keys_label.add_theme_font_size_override("font_size", 15)
	_keys_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_keys_label.position = Vector2(14, 12)
	_keys_label.modulate = Color(1, 1, 0.75)
	add_child(_keys_label)

	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)


func set_key_hints(text: String) -> void:
	_keys_label.text = text


func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.7)
