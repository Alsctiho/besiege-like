extends SceneTree
## apply_torque 隔离测试：悬空刚体施加绕 X 扭矩，应产生角速度。
## godot --headless --path . --script res://tests/torque_test.gd

var count := 0
var ready_done := false
var body: RigidBody3D


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _setup() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	body = RigidBody3D.new()
	body.position = Vector3(0, 2, 0)
	body.mass = 3.0
	body.can_sleep = false
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.45
	sh.height = 0.2
	cs.shape = sh
	cs.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	body.add_child(cs)
	root3d.add_child(body)


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	body.apply_torque(Vector3(10, 0, 0))
	if count % 30 == 0:
		print("[T] f=%d ang=%s mode=%s freeze=%s" % [count, body.angular_velocity,
			PhysicsServer3D.body_get_mode(body.get_rid()), body.freeze])
	if count >= 121:
		quit()
