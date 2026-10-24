class_name BuildCamera
extends Camera3D
## 建造模式轨道相机：中键拖拽旋转，滚轮缩放，WASD 平移。

var target := Vector3(0, 0, 1.0)
var dist := 6.0
var yaw := -0.8
var pitch := -0.45

var _orbiting := false


func _ready() -> void:
	apply()


func apply() -> void:
	var off := Vector3(0, 0, 1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw) * dist
	position = target + off
	look_at(target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist * 0.9, 1.8, 30.0)
			apply()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist * 1.1, 1.8, 30.0)
			apply()
	elif event is InputEventMouseMotion and _orbiting:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch - event.relative.y * 0.006, -1.45, -0.08)
		apply()


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		pan.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		pan.y -= 1.0
	if Input.is_physical_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		var fwd := -Vector3(sin(yaw), 0, cos(yaw)).normalized()  # 相机指向目标的水平方向
		var right := Vector3(-fwd.z, 0, fwd.x)
		target += (fwd * pan.y + right * pan.x) * delta * dist * 0.8
		apply()
