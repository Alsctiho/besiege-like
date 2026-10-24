extends SceneTree
## 引擎级最小测试：RigidBody3D 挂一个 AnimatableBody3D 子节点后还会不会正常下落？
## godot --headless --path . --script res://tests/kinematic_child_test.gd

var count := 0
var ready_done := false
var rig: RigidBody3D
var mover: AnimatableBody3D


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

	rig = RigidBody3D.new()
	rig.position = Vector3(0, 1.5, 0)
	rig.mass = 5.0
	rig.can_sleep = false
	var rcs := CollisionShape3D.new()
	var rsh := BoxShape3D.new()
	rsh.size = Vector3.ONE * 0.4
	rcs.shape = rsh
	rig.add_child(rcs)
	root3d.add_child(rig)

	mover = AnimatableBody3D.new()
	mover.sync_to_physics = false
	var mcs := CollisionShape3D.new()
	var msh := BoxShape3D.new()
	msh.size = Vector3.ONE * 0.2
	mcs.shape = msh
	mover.add_child(mcs)
	mover.position = Vector3(0, 0.4, 0)
	rig.add_child(mover)  # 关键：运动学体挂在动态体下


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 30 == 0:
		print("[K] f=%d rig_y=%.3f vy=%.2f (spawned 1.5, ground top -0.45 -> rest at -0.25)" % [
			count, rig.global_position.y, rig.linear_velocity.y])
	if count >= 121:
		quit()
