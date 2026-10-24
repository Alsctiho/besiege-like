extends SceneTree
## 精确复现 sim 场景的关节创建：双动态体 + 关节挂 body_a 下，同帧创建。
## 两个刚体应该一起自由落体。若悬停 = 复现"钉死"bug。
## godot --headless --path . --script res://tests/pin_test.gd

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
	body_b.position = Vector3(-0.5, 2, 0)
	body_b.mass = 3.0
	body_b.can_sleep = false
	var bcs := CollisionShape3D.new()
	var bsh := CylinderShape3D.new()
	bsh.radius = 0.45
	bsh.height = 0.2
	bcs.shape = bsh
	bcs.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	body_b.add_child(bcs)
	root3d.add_child(body_b)

	joint = HingeJoint3D.new()
	joint.position = Vector3(-0.5, 2, 0) - body_a.position
	joint.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))  # 轴 = X
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	body_a.add_child(joint)  # 关键差异：挂在动态体 body_a 下
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	# 物理服务端视角的变换
	var sa: Transform3D = PhysicsServer3D.body_get_state(body_a.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	var sb: Transform3D = PhysicsServer3D.body_get_state(body_b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	print("[P] server a=", sa.origin, " b=", sb.origin)


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 20 == 0:
		print("[P] f=%d a_y=%.3f b_y=%.3f (spawned at 2.0, should fall together)" % [
			count, body_a.global_position.y, body_b.global_position.y])
	if count >= 121:
		quit()
