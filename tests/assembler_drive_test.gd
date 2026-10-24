extends SceneTree
## 用 MachineAssembler 装配最小轮车并测试行驶。
## godot --headless --path . --script res://tests/assembler_drive_test.gd

var count := 0
var ready_done := false
var root3d: Node3D
var fake_sim: Node


class FakeSim extends Node:
	var keys := {4194320: true, 4194322: false}
	var reverse_forward := false


func _initialize() -> void:
	physics_frame.connect(_on_physics_frame)


func _setup() -> void:
	root3d = Node3D.new()
	root.add_child(root3d)

	var ground := StaticBody3D.new()
	ground.position = Vector3(0, -0.45, 0)
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(40, 0.1, 40)
	gcs.shape = gsh
	ground.add_child(gcs)
	root3d.add_child(ground)

	var blocks := [
		{"c": [0, 0, 0], "t": "wood_block", "f": 0},
		{"c": [1, 0, 0], "t": "wood_block", "f": 0},
		{"c": [0, 0, 1], "t": "wood_block", "f": 0},
		{"c": [1, 0, 1], "t": "wood_block", "f": 0},
		{"c": [-1, 0, 0], "t": "wheel", "f": 1, "k": {"spin": [4194320, 4194322]}},
		{"c": [2, 0, 0], "t": "wheel", "f": 3, "k": {"spin": [4194320, 4194322]}},
		{"c": [-1, 0, 1], "t": "wheel", "f": 1, "k": {"spin": [4194320, 4194322]}},
		{"c": [2, 0, 1], "t": "wheel", "f": 3, "k": {"spin": [4194320, 4194322]}},
	]
	var grid := {}
	for b in blocks:
		var c: Array = b.c
		grid[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = {"type": str(b.t), "facing": int(b.f), "k": b.get("k", {})}

	var res: Dictionary = MachineAssembler.assemble(grid, root3d)
	fake_sim = FakeSim.new()
	root3d.add_child(fake_sim)
	for beh in res.behaviors:
		beh.sim = fake_sim
	print("[A] assembled: bodies=%d movers=%d behaviors=%d" % [
		res.bodies.size(), res.movers.size(), res.behaviors.size()])
	print("[A] root=", res.root_body.name, " pos=", res.root_body.global_position)


func _on_physics_frame() -> void:
	count += 1
	if count == 5:
		_setup()
		ready_done = true
		return
	if not ready_done:
		return
	if count % 30 == 0:
		var rb: RigidBody3D = null
		for n in root3d.get_children():
			if n.name.begins_with("Chassis"):
				rb = n
		if rb:
			print("[A] f=%d chassis=%s" % [count, rb.global_position])
		for n in root3d.get_children():
			if n.name.begins_with("Wheel"):
				print("[A]   ", n.name, " pos=", n.global_position, " ang=", n.angular_velocity,
					" contacts=", n.get_contact_count())
	if count >= 181:
		quit()
