extends Node3D
## 解密关卡地形：白色岩石峡谷 + 悬崖方碑 + 蜿蜒台阶 + 目标光柱。
## with_grid = 建造阶段显示格线。

@export var with_grid := true


func _ready() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.94, 0.91, 0.85)
	rock.roughness = 1.0
	var rock2 := StandardMaterial3D.new()
	rock2.albedo_color = Color(0.88, 0.82, 0.70)
	rock2.roughness = 1.0

	# 主地面（顶面 y=0）
	_slab(Vector3(0, -0.5, 0), Vector3(90, 1, 90), rock, true)
	# 峡谷崖壁
	_slab(Vector3(-15, 6, -12), Vector3(5, 14, 30), rock2)
	_slab(Vector3(15, 8, -18), Vector3(5, 18, 34), rock2)
	_slab(Vector3(0, 11, -36), Vector3(46, 24, 6), rock2)
	_slab(Vector3(0, 9, 22), Vector3(40, 20, 6), rock2)
	# 目标方碑（顶面 y=7.0）
	_slab(Vector3(-7, 3.0, -15), Vector3(6, 7, 6), rock, true)
	_slab(Vector3(-7, 6.75, -15), Vector3(7.2, 0.5, 7.2), rock2, true)
	# 蜿蜒台阶（装饰）
	var steps := 12
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var x := lerpf(-3.6, -6.2, t)
		var y := 0.15 + t * 6.2
		var z := lerpf(-11.2, -14.6, t)
		_slab(Vector3(x, y, z), Vector3(1.6, 0.3, 1.2), rock2)
	if with_grid:
		var g := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(90, 90)
		var m := StandardMaterial3D.new()
		m.shader = load("res://shaders/grid.gdshader")
		g.mesh = pm
		g.material_override = m
		g.position = Vector3(0, 0.012, 0)
		add_child(g)
	# 目标光柱
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.3
	cyl.height = 9.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.85, 0.45, 0.25)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.8, 0.4)
	bm.emission_energy_multiplier = 1.2
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = bm
	beam.mesh = cyl
	beam.position = Vector3(-7, 11.5, -15)
	add_child(beam)


func _slab(pos: Vector3, size: Vector3, mat: Material, solid := false) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		add_child(sb)
