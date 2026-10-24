extends Node3D
## 平原战场地形：开阔沙地 + 岩石掩体 + 边界。

func _ready() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.94, 0.91, 0.85)
	rock.roughness = 1.0
	var rock2 := StandardMaterial3D.new()
	rock2.albedo_color = Color(0.88, 0.82, 0.70)
	rock2.roughness = 1.0

	# 主地面（顶面 y=0）+ 格线
	_slab(Vector3(0, -0.5, 0), Vector3(90, 1, 90), rock, true)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	var m := StandardMaterial3D.new()
	m.shader = load("res://shaders/grid.gdshader")
	g.mesh = pm
	g.material_override = m
	g.position = Vector3(0, 0.012, 0)
	add_child(g)

	# 边界岩墙（可见矮墙 + 高墙挡飞行）
	_slab(Vector3(0, 1.0, -36), Vector3(76, 3, 3), rock2, true)
	_slab(Vector3(0, 1.0, 30), Vector3(76, 3, 3), rock2, true)
	_slab(Vector3(-36, 1.0, -3), Vector3(3, 3, 72), rock2, true)
	_slab(Vector3(36, 1.0, -3), Vector3(3, 3, 72), rock2, true)
	_slab(Vector3(0, 8, -36), Vector3(76, 12, 3), rock, true)
	_slab(Vector3(0, 8, 30), Vector3(76, 12, 3), rock, true)
	_slab(Vector3(-36, 8, -3), Vector3(3, 12, 72), rock, true)
	_slab(Vector3(36, 8, -3), Vector3(3, 12, 72), rock, true)

	# 掩体岩石（散布中场，可挡弹道）
	var covers := [
		[Vector3(-8, 0.9, -6), Vector3(2.2, 1.8, 1.6), 0.3],
		[Vector3(7, 0.8, -9), Vector3(1.6, 1.6, 2.4), -0.5],
		[Vector3(-3, 0.7, -14), Vector3(2.6, 1.4, 1.4), 0.8],
		[Vector3(4, 1.0, -17), Vector3(1.8, 2.0, 1.8), -0.2],
		[Vector3(-14, 0.8, -18), Vector3(2.0, 1.6, 2.2), 0.5],
		[Vector3(14, 0.9, -20), Vector3(2.4, 1.8, 1.6), -0.7],
		[Vector3(0, 0.8, -24), Vector3(3.0, 1.6, 1.4), 0.1],
	]
	for c in covers:
		_slab(c[0], c[1], rock2, true, c[2])


func _slab(pos: Vector3, size: Vector3, mat: Material, solid := false, yaw := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		sb.rotation.y = yaw
		add_child(sb)
