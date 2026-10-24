class_name ChaseCamera
extends Camera3D
## 模拟模式相机：默认跟随机身主体（轨道），C 切换自由模式（WASD 平移 + R/F 升降）。
## 注意：绝不写 target 的 transform（会干扰物理服务端的刚体积分）。

var target: Node3D = null
var dist := 7.0
var yaw := -0.7
var pitch := -0.35
var follow := true

var _orbiting := false
var _free_center := Vector3(0, 1, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist * 0.9, 2.0, 60.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist * 1.1, 2.0, 60.0)
	elif event is InputEventMouseMotion and _orbiting:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch - event.relative.y * 0.006, -1.45, -0.05)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			follow = not follow
			if not follow and target != null:
				_free_center = target.global_position


func _process(delta: float) -> void:
	if follow and target != null:
		_free_center = target.global_position
	else:
		# 自由模式：WASD 平移（相对视角），R/F 升降
		var move := Vector3.ZERO
		var fwd := -Vector3(sin(yaw) * cos(pitch), 0, cos(yaw) * cos(pitch)).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x)
		if Input.is_physical_key_pressed(KEY_W):
			move += fwd
		if Input.is_physical_key_pressed(KEY_S):
			move -= fwd
		if Input.is_physical_key_pressed(KEY_A):
			move -= right
		if Input.is_physical_key_pressed(KEY_D):
			move += right
		if Input.is_physical_key_pressed(KEY_R):
			move += Vector3.UP
		if Input.is_physical_key_pressed(KEY_F):
			move -= Vector3.UP
		_free_center += move * delta * dist * 0.8
	var off := Vector3(0, 0, 1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw) * dist
	position = _free_center + off
	look_at(_free_center, Vector3.UP)
