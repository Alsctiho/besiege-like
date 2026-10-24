extends SceneTree
## 动态-动态铰链马达测试：底盘(动态) + 轮子(动态) + HingeJoint 马达。
## 轮子应当旋转；若 ang 恒 0 = 动态-动态马达失效。
## godot --headless --path . --script res://tests/dd_motor_test.gd

var count := 0
var ready_done := false
var chassis: RigidBody3D
var wheel: RigidBody3D
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
	gsh.size = Vector3(40, 1, 40)
	gcs.shape = gsh
	ground.add_child(gcs)
	root3d.add_child(ground)

	chassis = RigidBody3D.new()
	chassis.position = Vector3(0, 0.4, 0)
	chassis.mass = 20.0
	chassis.can_sleep = false
	var ccs := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = Vector3(0.8, 0.4, 1.6)
	ccs.shape = csh
	chassis.add_child(ccs)
	root3d.add_child(chassis)

	wheel = RigidBody3D.new()
	wheel.position = Vector3(-0.7, 0.0, 0)
	wheel.mass = 2.0
	wheel.can_sleep = false
	var pm := PhysicsMaterial.new()
	pm.friction = 1.5
	wheel.physics_material_override = pm
	var wcs := CollisionShape3D.new()
	var wsh := CylinderShape3D.new()
	wsh.radius = 0.4
	wsh.height = 0.2
	wcs.shape = wsh
	wcs.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	wheel.add_child(wcs)
	root3d.add_child(wheel)

	joint = HingeJoint3D.new()
	joint.position = Vector3(-0.7, 0.0, 0) - chassis.position
	joint.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))  # 轴 = -X
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 12.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 30.0)
	chassis.add_child(joint)
	joint.node_a = chassis.get_path()
	joint.node_b = wheel.get_path()
	print("[D] setup done")


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 30 == 0:
		print("[D] f=%d chassis=%s wheel=%s wheel_ang=%s" % [count,
			chassis.global_position, wheel.global_position, wheel.angular_velocity])
	if count >= 181:
		quit()
