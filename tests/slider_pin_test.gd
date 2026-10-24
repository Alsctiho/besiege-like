extends SceneTree
## 滑杆关节隔离测试：双动态体 + SliderJoint3D（限位+角锁定），应一起自由落体。
## godot --headless --path . --script res://tests/slider_pin_test.gd

var count := 0
var ready_done := false
var body_a: RigidBody3D
var body_b: RigidBody3D


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _setup() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)

	body_a = RigidBody3D.new()
	body_a.position = Vector3(0, 2, 0)
	body_a.mass = 20.0
	body_a.can_sleep = false
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(0.5, 0.5, 0.5)
	acs.shape = ash
	body_a.add_child(acs)
	root3d.add_child(body_a)

	body_b = RigidBody3D.new()
	body_b.position = Vector3(0, 2, 1.0)
	body_b.mass = 1.0
	body_b.can_sleep = false
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(0.14, 0.14, 0.5)
	bcs.shape = bsh
	body_b.add_child(bcs)
	root3d.add_child(body_b)

	var j := SliderJoint3D.new()
	j.position = Vector3(0, 2, 1.0) - body_a.position
	var xx := Vector3(0, 0, 1)  # 滑轴 = +Z
	var helper := Vector3.UP
	var yy := helper.cross(xx).normalized()
	var zz := xx.cross(yy).normalized()
	j.basis = Basis(xx, yy, zz)
	j.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.36)
	j.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, -0.02)
	j.set_param(SliderJoint3D.PARAM_ANGULAR_LIMIT_UPPER, 0.0)
	j.set_param(SliderJoint3D.PARAM_ANGULAR_LIMIT_LOWER, 0.0)
	body_a.add_child(j)
	j.node_a = body_a.get_path()
	j.node_b = body_b.get_path()
	print("[S] slider created")


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 20 == 0:
		print("[S] f=%d a_y=%.3f b_y=%.3f (spawned 2.0, should fall together)" % [
			count, body_a.global_position.y, body_b.global_position.y])
	if count >= 121:
		quit()
