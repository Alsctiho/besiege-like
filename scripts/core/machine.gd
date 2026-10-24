class_name Machine
extends Node3D
## 机器的网格数据模型 + 建造态视觉。
## 网格是唯一数据源；模拟物理由 MachineAssembler 从网格派生。
## 格距 0.5m，格子 (x,y,z) 的世界中心 = cell * CELL。
## 每格数据：{type:String, facing:int, k:{action:[pos_key, neg_key]}}

signal block_added(cell: Vector3i)
signal block_removed(cell: Vector3i)

const CELL := 0.5
const NEIGHBORS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var machine_name := "my_machine"
var grid := {}      # Vector3i -> {type, facing, k}
var visuals := {}   # Vector3i -> Node3D（建造态视觉节点，含静态碰撞体）


func is_empty() -> bool:
	return grid.is_empty()


func can_place(cell: Vector3i) -> bool:
	if cell.y < 0:
		return false
	if grid.has(cell):
		return false
	if grid.is_empty():
		return true
	return has_neighbor(cell)


func has_neighbor(cell: Vector3i) -> bool:
	for n in NEIGHBORS:
		if grid.has(cell + n):
			return true
	return false


func add_block(cell: Vector3i, type: String, facing: int = 0, bindings: Dictionary = {}) -> bool:
	if not can_place(cell):
		return false
	if BlockDB.get_def(type).is_empty():
		return false
	var k := bindings.duplicate(true)
	if k.is_empty():
		k = BlockDB.default_bindings(type)  # 未绑定时自动套用默认按键
	grid[cell] = {"type": type, "facing": posmod(facing, 6), "k": k}
	_spawn_visual(cell)
	block_added.emit(cell)
	return true


func remove_block(cell: Vector3i) -> bool:
	if not grid.has(cell):
		return false
	grid.erase(cell)
	if visuals.has(cell):
		visuals[cell].queue_free()
		visuals.erase(cell)
	block_removed.emit(cell)
	return true


func get_block(cell: Vector3i) -> Dictionary:
	return grid.get(cell, {})


func set_binding(cell: Vector3i, action: String, pos_key: int, neg_key: int) -> void:
	if not grid.has(cell):
		return
	grid[cell].k[action] = [pos_key, neg_key]


func get_binding(cell: Vector3i) -> Dictionary:
	if not grid.has(cell):
		return {}
	return grid[cell].get("k", {})


func block_count() -> int:
	return grid.size()


func clear() -> void:
	for cell in grid.keys():
		remove_block(cell)


func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3(cell) * CELL


func world_to_cell(pos: Vector3) -> Vector3i:
	var v := (pos / CELL).round()
	return Vector3i(int(v.x), int(v.y), int(v.z))


## facing -> 单位朝向向量。0=-Z, 1=-X, 2=+Z, 3=+X（绕 Y 逆时针），4=+Y 上，5=-Y 下。
static func facing_dir(facing: int) -> Vector3i:
	match posmod(facing, 6):
		1: return Vector3i(-1, 0, 0)
		2: return Vector3i(0, 0, 1)
		3: return Vector3i(1, 0, 0)
		4: return Vector3i(0, 1, 0)
		5: return Vector3i(0, -1, 0)
		_: return Vector3i(0, 0, -1)


## facing -> 基（用于模型视觉朝向）
static func facing_basis(facing: int) -> Basis:
	match posmod(facing, 6):
		1: return Basis(Vector3.UP, PI / 2.0)
		2: return Basis(Vector3.UP, PI)
		3: return Basis(Vector3.UP, -PI / 2.0)
		4: return Basis(Vector3.RIGHT, PI / 2.0)   # forward(-Z) -> +Y 上
		5: return Basis(Vector3.RIGHT, -PI / 2.0)  # forward(-Z) -> -Y 下
		_: return Basis()


func serialize() -> Dictionary:
	var blocks: Array = []
	for cell: Vector3i in grid:
		var d: Dictionary = grid[cell]
		blocks.append({"c": [cell.x, cell.y, cell.z], "t": d.type, "f": d.facing, "k": d.k})
	return {"name": machine_name, "version": 1, "blocks": blocks}


func deserialize(data: Dictionary) -> void:
	clear()
	machine_name = str(data.get("name", "my_machine"))
	for b in data.get("blocks", []):
		var c: Array = b.c
		# JSON 解析会把整数变成浮点数，按键码必须转回 int，否则按键查找全部失灵
		var k: Dictionary = {}
		var raw_k: Dictionary = b.get("k", {})
		for action in raw_k:
			var arr: Array = raw_k[action]
			if arr.size() >= 2:
				k[str(action)] = [int(arr[0]), int(arr[1])]
		add_block(Vector3i(int(c[0]), int(c[1]), int(c[2])), str(b.t), int(b.f), k)


func _spawn_visual(cell: Vector3i) -> void:
	var data: Dictionary = grid[cell]
	var root := Node3D.new()
	root.name = "B_%d_%d_%d" % [cell.x, cell.y, cell.z]
	root.position = cell_to_world(cell)
	root.basis = facing_basis(int(data.facing))

	var ps: PackedScene = load(BlockDB.get_def(data.type).model)
	if ps:
		root.add_child(ps.instantiate())

	# 建造态静态碰撞体：供射线拾取（放置/删除）。模拟态由装配器重建。
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("cell", cell)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * CELL * 0.999
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)

	add_child(root)
	visuals[cell] = root
