extends SceneTree
## 摩擦测试：给球一个水平初速度，看摩擦是否使其减速停下。
## godot --headless --path . --script res://tests/friction_test.gd

var count := 0
var ready_done := false
var ball: RigidBody3D
var spinner: RigidBody3D
var joint: HingeJoint3D


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _setup() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)

	var ground := StaticBody3D.new()
	ground.position = Vector3(0, -0.95, 0)
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(120, 1, 120)
	gcs.shape = gsh
	ground.add_child(gcs)
	root3d.add_child(ground)

	# 1) 滑动摩擦：方块以 3m/s 滑出
	ball = RigidBody3D.new()
	ball.position = Vector3(0, -0.25, 0)
	ball.mass = 2.0
	ball.can_sleep = false
	ball.linear_velocity = Vector3(0, 0, 3)
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3.ONE * 0.5
	bcs.shape = bsh
	ball.add_child(bcs)
	root3d.add_child(ball)

	# 2) 驱动轮：轮子 + 关节 + 马达，抬高 6cm 让其自然落地产生真实接触
	spinner = RigidBody3D.new()
	spinner.position = Vector3(2, 0.06, 0)
	spinner.mass = 3.0
	spinner.can_sleep = false
	var scs := CollisionShape3D.new()
	var ssh := CylinderShape3D.new()
	ssh.radius = 0.45
	ssh.height = 0.2
	scs.shape = ssh
	scs.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	spinner.add_child(scs)
	root3d.add_child(spinner)

	var anchor := StaticBody3D.new()
	anchor.position = Vector3(2, 0, 0)
	root3d.add_child(anchor)

	joint = HingeJoint3D.new()
	anchor.add_child(joint)  # 关节挂在 anchor 下，局部零点 = 轮心
	joint.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))  # 关节轴(局部Z) = 世界X = 轮轴
	joint.node_a = anchor.get_path()
	joint.node_b = spinner.get_path()
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 8.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 10.0)


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 30 == 0:
		print("[F] f=%d slider_z=%.3f slider_v=%s wheel_z=%.3f wheel_ang=%s" % [
			count, ball.global_position.z, ball.linear_velocity,
			spinner.global_position.z, spinner.angular_velocity])
	if count >= 181:
		quit()
