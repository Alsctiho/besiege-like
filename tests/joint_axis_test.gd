extends SceneTree
## 关节轴向标定测试（无头）：
##   godot --headless --path . --script res://tests/joint_axis_test.gd
## 输出 HingeJoint3D 马达的实际作用轴与 SliderJoint3D 的滑动轴。

var count := 0
var ready_done := false
var root3d: Node3D
var hinge_b: RigidBody3D
var slider_b: RigidBody3D


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _setup() -> void:
	root3d = Node3D.new()
	root.add_child(root3d)

	# ---- Hinge 标定：锚点在 B 中心，观察 B 自转轴 ----
	var ha := StaticBody3D.new()
	ha.position = Vector3.ZERO
	ha.add_child(_box_shape())
	root3d.add_child(ha)

	hinge_b = RigidBody3D.new()
	hinge_b.position = Vector3(3, 0, 0)
	hinge_b.can_sleep = false
	hinge_b.add_child(_box_shape())
	root3d.add_child(hinge_b)

	var hinge := HingeJoint3D.new()
	root3d.add_child(hinge)
	hinge.global_position = Vector3(3, 0, 0)
	hinge.node_a = ha.get_path()
	hinge.node_b = hinge_b.get_path()
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 3.0)
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 50.0)

	# ---- Slider 标定 ----
	var sa := StaticBody3D.new()
	sa.position = Vector3(0, -60, 0)
	sa.add_child(_box_shape())
	root3d.add_child(sa)

	slider_b = RigidBody3D.new()
	slider_b.position = Vector3(2, -60, 0)
	slider_b.can_sleep = false
	slider_b.add_child(_box_shape())
	root3d.add_child(slider_b)

	var slider := SliderJoint3D.new()
	root3d.add_child(slider)
	slider.global_position = Vector3(2, -60, 0)
	slider.node_a = sa.get_path()
	slider.node_b = slider_b.get_path()
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, 2.0)
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, -2.0)
	slider.set_param(SliderJoint3D.PARAM_ANGULAR_LIMIT_UPPER, 0.0)
	slider.set_param(SliderJoint3D.PARAM_ANGULAR_LIMIT_LOWER, 0.0)


func _box_shape() -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.8, 0.8, 0.8)
	cs.shape = sh
	return cs


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	var t := count - 5
	# 前 60 帧沿 +Z 推，后 60 帧沿 +X 推，看滑杆允许哪个方向
	if t <= 60:
		slider_b.apply_central_force(Vector3(0, 0, 50))
	else:
		slider_b.apply_central_force(Vector3(50, 0, 0))
	if t == 60:
		print("MID(+Z push) slider lin_vel=", slider_b.linear_velocity)
	if t == 120:
		print("RESULT hinge_ang_vel=", hinge_b.angular_velocity)
		print("RESULT slider_pos=", slider_b.position, " lin_vel=", slider_b.linear_velocity)
		quit()
