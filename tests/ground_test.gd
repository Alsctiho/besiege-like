extends SceneTree
## 裸刚体落地测试：验证地面接触/摩擦是否正常。
## godot --headless --path . --script res://tests/ground_test.gd

var count := 0
var ready_done := false
var ball: RigidBody3D
var ground: StaticBody3D


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _setup() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)

	ground = StaticBody3D.new()
	ground.position = Vector3(0, -0.95, 0)
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(120, 1, 120)
	gcs.shape = gsh
	ground.add_child(gcs)
	root3d.add_child(ground)
	print("[G] ground top should be -0.45, actual center=", ground.global_position)

	ball = RigidBody3D.new()
	ball.position = Vector3(0, 1.0, 0)  # 从 1.45m 高处落到地面
	ball.mass = 3.0
	ball.can_sleep = false
	var bcs := CollisionShape3D.new()
	var bsh := CylinderShape3D.new()
	bsh.radius = 0.45
	bsh.height = 0.2
	bcs.shape = bsh
	bcs.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	ball.add_child(bcs)
	root3d.add_child(ball)


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 30 == 0:
		print("[G] f=%d pos=%s lin=%s" % [count, ball.global_position, ball.linear_velocity])
	if count >= 181:
		print("[G] FINAL: bottom=", ball.global_position.y - 0.45, " (should rest at -0.45)")
		quit()
