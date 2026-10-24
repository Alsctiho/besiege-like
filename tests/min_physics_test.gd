extends SceneTree
## 最小机 1:1 纯物理复现：木块(底) + 轮簇(轮+配重, 原点=关节点) + 延迟建关节 + 6cm 抬升。
## 应整体下落 6cm 停在轮上。可控开关（命令行 user args）：
##   sameframe  关节与刚体同帧创建
##   nolift     不抬升
##   nomotor    不设置任何马达参数
## godot --headless --path . --script res://tests/min_physics_test.gd -- sameframe

var count := 0
var ready_done := false
var body_a: RigidBody3D   # 木块
var body_b: RigidBody3D   # 轮簇
var joint: HingeJoint3D
var opts := {}


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _make_body(pos: Vector3, mass: float, shapes: Array) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.position = pos
	b.mass = mass
	b.can_sleep = false
	for s in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = s[0]
		cs.position = s[1]
		cs.basis = s[2]
		b.add_child(cs)
	return b


func _setup() -> void:
	for a in OS.get_cmdline_user_args():
		opts[a] = true
	var root3d := Node3D.new()
	root.add_child(root3d)

	if not opts.has("noground"):
		var ground := StaticBody3D.new()
		ground.position = Vector3(0, -0.95, 0)
		var gcs := CollisionShape3D.new()
		var gsh := BoxShape3D.new()
		gsh.size = Vector3(120, 1, 120)
		gcs.shape = gsh
		ground.add_child(gcs)
		root3d.add_child(ground)

	var lift := 0.0 if opts.has("nolift") else 0.06
	# 木块：cell (0,0,0) → world (0,0,0)
	body_a = _make_body(Vector3(0, lift, 0), 2.0, [
		[BoxShape3D.new(), Vector3.ZERO, Basis()],
	])
	root3d.add_child(body_a)
	# 轮簇：wheel cell (−1,0,0) → world (−0.5,0,0)，原点=关节点；配重 (−2,0,0)→(−1,0,0)
	var wheel_shape := CylinderShape3D.new()
	wheel_shape.radius = 0.45
	wheel_shape.height = 0.2
	var wb := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	var b_shapes: Array = [[wheel_shape, Vector3.ZERO, wb]]
	if not opts.has("oneshape"):
		var box_off := Vector3.ZERO if opts.has("centermetal") else Vector3(-0.5, 0, 0)
		b_shapes.append([BoxShape3D.new(), box_off, Basis()])
	body_b = _make_body(Vector3(-0.5, lift, 0), 7.0, b_shapes)
	root3d.add_child(body_b)

	joint = HingeJoint3D.new()
	joint.position = Vector3(-0.5, 0, 0) - body_a.position  # body_a 局部
	joint.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))  # 轴 = +X
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	if not opts.has("nomotor"):
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 10.0)
	if opts.has("sameframe") or opts.has("jroot"):
		if opts.has("jroot"):
			root3d.add_child(joint)
			joint.global_position = Vector3(-0.5, lift, 0)
		else:
			body_a.add_child(joint)
		joint.node_a = body_a.get_path()
		joint.node_b = body_b.get_path()
		_finish()
	print("[M] setup done opts=", opts)


func _finish() -> void:
	print("[M] joint built")


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		if opts.has("sameframe") or opts.has("jroot"):
			ready_done = true
		return
	if not ready_done:
		if count == 8 and not opts.has("sameframe") and not opts.has("jroot"):
			body_a.add_child(joint)
			joint.node_a = body_a.get_path()
			joint.node_b = body_b.get_path()
			_finish()
			ready_done = true
		return
	if count % 30 == 0:
		print("[M] f=%d a=(%.3f, %.3f, %.3f) b=(%.3f, %.3f, %.3f) b_ang=%s" % [
			count, body_a.global_position.x, body_a.global_position.y, body_a.global_position.z,
			body_b.global_position.x, body_b.global_position.y, body_b.global_position.z,
			body_b.angular_velocity])
	if count >= 121:
		print("[M] FINAL a_pos=", body_a.global_position, " a_basis_x=", body_a.global_basis.x, " a_basis_y=", body_a.global_basis.y)
		print("[M] FINAL b_pos=", body_b.global_position, " b_basis_x=", body_b.global_basis.x, " b_basis_y=", body_b.global_basis.y)
		print("[M] FINAL a_contacts=", body_a.get_contact_count(), " b_contacts=", body_b.get_contact_count())
		for i in range(body_a.get_contact_count()):
			var c: Object = body_a.get_contact_collider_object(i)
			print("[M] a contact ", i, " with ", c, " at ", body_a.get_contact_collider_position(i))
		for i in range(body_b.get_contact_count()):
			var c2: Object = body_b.get_contact_collider_object(i)
			print("[M] b contact ", i, " with ", c2, " at ", body_b.get_contact_collider_position(i))
		quit()
