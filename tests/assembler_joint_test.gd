extends SceneTree
## 最小复现：按 MachineAssembler._make_hinge 的方式创建关节，验证约束是否成立。
## godot --headless --path . --script res://tests/assembler_joint_test.gd

var count := 0
var ready_done := false
var body_a: RigidBody3D
var body_b: RigidBody3D
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

	# A：车架（悬空高度，由轮子撑地）
	body_a = RigidBody3D.new()
	body_a.position = Vector3(0, 0.2, 0)
	body_a.mass = 20.0
	body_a.can_sleep = false
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(0.5, 0.3, 2.0)
	acs.shape = ash
	body_a.add_child(acs)
	root3d.add_child(body_a)

	# B：轮子（圆柱轴沿 -X），底面恰好触地：center y = -0.45+0.45 = 0
	body_b = RigidBody3D.new()
	body_b.position = Vector3(-0.5, 0.0, 0)
	body_b.mass = 3.0
	body_b.can_sleep = false
	var bcs := CollisionShape3D.new()
	var bsh := CylinderShape3D.new()
	bsh.radius = 0.45
	bsh.height = 0.2
	bcs.shape = bsh
	bcs.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))  # 局部 Y = -X
	bcs.position = Vector3.ZERO
	body_b.add_child(bcs)
	root3d.add_child(body_b)

	joint = HingeJoint3D.new()
	joint.position = Vector3(-0.5, 0.0, 0) - body_a.position
	# 轮轴沿 -X：局部 Z = -X
	var zz := Vector3(-1, 0, 0)
	var xx := Vector3.UP.cross(zz).normalized()
	var yy := zz.cross(xx).normalized()
	joint.basis = Basis(xx, yy, zz)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -16.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 10.0)
	body_a.add_child(joint)
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	var gb := joint.global_basis
	print("[T] want z=(-1,0,0); got basis cols: x=%s y=%s z=%s" % [gb.x, gb.y, gb.z])
	print("[T] joint global_pos=", joint.global_position)
	print("[T] joint created, a=", body_a.position, " b=", body_b.position)


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 30 == 0:
		print("[T] f=%d a=%s b=%s b_ang=%s b_local=%s" % [count,
			body_a.global_position, body_b.global_position,
			body_b.angular_velocity, body_b.position - body_a.position])
	if count >= 181:
		quit()
