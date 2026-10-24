class_name DestructibleTarget
extends RefCounted
## 可破坏靶场：松散方块堆（纯物理倒塌，无需伤害系统）。
## 方块间留 2mm 间隙避免初始穿透抖动。

const GAP := 0.002


static func spawn_tower(parent: Node3D, base_center: Vector3, layers: int = 3) -> void:
	# 金字塔：第 i 层 (layers-i) 个方块
	for row in layers:
		var count := layers - row
		var y: float = base_center.y + Machine.CELL / 2.0 + row * (Machine.CELL + GAP)
		for i in range(count):
			var x: float = base_center.x + (i - (count - 1) / 2.0) * (Machine.CELL + GAP)
			_spawn_block(parent, Vector3(x, y, base_center.z), "wood_block")


static func spawn_wall(parent: Node3D, base_center: Vector3, cols: int, rows: int) -> void:
	for row in rows:
		var y: float = base_center.y + Machine.CELL / 2.0 + row * (Machine.CELL + GAP)
		for i in range(cols):
			var x: float = base_center.x + (i - (cols - 1) / 2.0) * (Machine.CELL + GAP)
			_spawn_block(parent, Vector3(x, y, base_center.z), "metal_block")


static func _spawn_block(parent: Node3D, pos: Vector3, kind := "wood_block") -> void:
	var body := RigidBody3D.new()
	body.mass = 2.0
	body.can_sleep = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("destructible")
	if kind == "metal_block":
		body.set_meta("no_float", true)  # 金属入水下沉
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3.ONE * Machine.CELL * 0.98
	cs.shape = sh
	body.add_child(cs)
	var ps: PackedScene = load(BlockDB.get_def(kind).model)
	if ps:
		body.add_child(ps.instantiate())
	body.position = pos
	parent.add_child(body)
