extends SceneTree
## 关节父节点对比实验：3 体 2 关节网络。
## 用法1（默认）：关节挂动态体下（复现 sim 方式）
## 追加参数 parent=root：关节挂根节点下（全局变换）——对照
## godot --headless --path . --script res://tests/network_test.gd -- parent=root

var count := 0
var ready_done := false
var bodies: Array = []
var joints: Array = []
var mode := "body"


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _setup() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "parent=root":
			mode = "root"
	var root3d := Node3D.new()
	root.add_child(root3d)

	var cells := [Vector3(0, 2, 0), Vector3(-0.5, 2, 0), Vector3(-1.0, 2, 0)]
	for i in range(3):
		var b := RigidBody3D.new()
		b.position = cells[i]
		b.mass = 5.0
		b.can_sleep = false
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.4, 0.4, 0.4)
		cs.shape = sh
		b.add_child(cs)
		root3d.add_child(b)
		bodies.append(b)

	# B2: 轮状体
	var w := RigidBody3D.new()
	w.position = Vector3(-1.0, 1.6, 0)
	w.mass = 2.0
	w.can_sleep = false
	var wcs := CollisionShape3D.new()
	var wsh := CylinderShape3D.new()
	wsh.radius = 0.4
	wsh.height = 0.2
	wcs.shape = wsh
	wcs.basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	w.add_child(wcs)
	root3d.add_child(w)
	bodies.append(w)

	for spec in [[0, 1, Vector3(-0.5, 2, 0)], [1, 2, Vector3(-1.0, 2, 0)], [2, 3, Vector3(-1.0, 1.6, 0)]]:
		var pa: RigidBody3D = bodies[spec[0]]
		var pb: RigidBody3D = bodies[spec[1]]
		var pos: Vector3 = spec[2]
		var j := HingeJoint3D.new()
		j.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
		j.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
		if mode == "body":
			j.position = pos - pa.position
			pa.add_child(j)
		else:
			root3d.add_child(j)
			j.global_position = pos
		j.node_a = pa.get_path()
		j.node_b = pb.get_path()
		joints.append(j)
	print("[N] mode=", mode, " joints=", joints.size())


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 30 == 0:
		var ys := ""
		for b in bodies:
			ys += "%.2f " % b.global_position.y
		print("[N] f=%d mode=%s ys=%s (spawned 2.0/1.6)" % [count, mode, ys])
	if count >= 121:
		quit()
