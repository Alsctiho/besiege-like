class_name MachineAssembler
extends RefCounted
## 把机器网格数据装配为模拟态物理（v2 运动学执行器架构）：
## - 互相刚性连接的方块合并为底盘刚体簇（RigidBody3D, layer 1）
## - 关节组件（轮/铰链/活塞）的可动部分 = AnimatableBody3D（运动学, layer 2），
##   作为可动侧方块（如铰链前端的尖刺）的父节点，由行为脚本驱动；
##   运动学碰撞体在 sync_to_physics 下可正确推动其他刚体
## - 轮子驱动 = 射线悬挂 + 驱动力施加到底盘（raycast car）
## - 不使用 Godot Joint3D（本环境实测会把刚体焊死在关节节点姿态，
##   标定过程见 tests/joint_axis_test.gd 等）
##
## 连接规则：关节组件 mount 侧 = 自身 +Z（backward）；forward 侧方块归属可动部分。

const WHEEL_RADIUS := 0.45
const SPAWN_CLEARANCE := 0.02
const MOVER_FRACTION := {BlockDB.Kind.WHEEL: 1.0, BlockDB.Kind.HINGE: 0.4, BlockDB.Kind.PISTON: 0.4}

const LAYER_WORLD := 1
const LAYER_MOVER := 2

const BASE_PARTS := ["HingeBase", "PistonBody"]
const MOVER_PARTS := ["HingeArm", "PistonRod", "Wheel"]


class DSU:
	var parent := {}

	func add(k: String) -> void:
		parent[k] = k

	func find(k: String) -> String:
		var r := k
		while parent[r] != r:
			r = parent[r]
		while parent[k] != r:
			var nxt: String = parent[k]
			parent[k] = r
			k = nxt
		return r

	func union(a: String, b: String) -> void:
		parent[find(a)] = find(b)


static func is_joint_kind(k: int) -> bool:
	return k == BlockDB.Kind.WHEEL or k == BlockDB.Kind.HINGE or k == BlockDB.Kind.PISTON


static func _nkey(cell: Vector3i, mover: bool) -> String:
	return "%d,%d,%d|%s" % [cell.x, cell.y, cell.z, "m" if mover else "b"]


## 组装。返回 {bodies, movers, behaviors, root_body, cell_map}
static func assemble(grid: Dictionary, sim_root: Node3D) -> Dictionary:
	var fwd := {}
	var kind := {}
	var data := {}
	for cell in grid:
		var d: Dictionary = grid[cell]
		data[cell] = d
		fwd[cell] = Vector3i(Machine.facing_dir(int(d.facing)))
		kind[cell] = int(BlockDB.get_def(str(d.type)).kind)

	# ---------- 1. 并查集划分：底盘簇 / 可动簇 ----------
	var dsu := DSU.new()
	for cell in grid:
		dsu.add(_nkey(cell, false))
		if is_joint_kind(kind[cell]):
			dsu.add(_nkey(cell, true))
	var orphan := {}
	for cell in grid:
		if is_joint_kind(kind[cell]) and not grid.has(cell - fwd[cell]):
			orphan[cell] = true
			dsu.union(_nkey(cell, false), _nkey(cell, true))  # 孤立关节退化为普通块
	for cell in grid:
		for dirn in Machine.NEIGHBORS:
			var other: Vector3i = cell + dirn
			if not grid.has(other):
				continue
			var af: Vector3i = fwd[cell]
			var bf: Vector3i = fwd[other]
			var a_joint := is_joint_kind(kind[cell])
			var b_joint := is_joint_kind(kind[other])
			var a_fwd: bool = a_joint and dirn == af          # other 在 cell 的可动侧
			var a_child_of_b: bool = b_joint and dirn == -bf  # cell 在 other 的可动侧
			if a_fwd and a_child_of_b:
				dsu.union(_nkey(cell, true), _nkey(other, true))
			elif a_fwd:
				dsu.union(_nkey(cell, true), _nkey(other, false))
			elif a_child_of_b:
				dsu.union(_nkey(cell, false), _nkey(other, true))
			else:
				dsu.union(_nkey(cell, false), _nkey(other, false))  # 含 mount 边

	var clusters := {}   # root -> {cells_b, cells_m, has_mover}
	for cell in grid:
		var rb := dsu.find(_nkey(cell, false))
		if not clusters.has(rb):
			clusters[rb] = {"cells_b": [], "cells_m": [], "has_mover": false}
		clusters[rb].cells_b.append(cell)
		if is_joint_kind(kind[cell]) and not orphan.has(cell):
			var rm: String = dsu.find(_nkey(cell, true))
			if not clusters.has(rm):
				clusters[rm] = {"cells_b": [], "cells_m": [], "has_mover": false}
			clusters[rm].cells_m.append(cell)
			clusters[rm].has_mover = true

	# ---------- 2. 底盘刚体簇（非可动簇） ----------
	var body_of := {}    # cluster root -> RigidBody3D
	var cell_shapes := {}   # cell -> CollisionShape3D
	var cell_vis := {}      # cell -> Node3D
	var bodies: Array = []
	var behaviors: Array = []
	var movers: Array = []
	var joints: Array = []
	var idx := 0
	var cell_map := {}
	for rb in clusters:
		var cl: Dictionary = clusters[rb]
		if bool(cl.has_mover):
			continue
		var com := Vector3.ZERO
		var mass := 0.0
		for cell in cl.cells_b:
			var def: Dictionary = BlockDB.get_def(str(data[cell].type))
			var frac := 1.0
			if is_joint_kind(kind[cell]):
				frac = 1.0 - float(MOVER_FRACTION[kind[cell]])
			com += Vector3(cell) * Machine.CELL * float(def.mass) * frac
			mass += float(def.mass) * frac
		if mass <= 0.0:
			mass = 1.0
		com /= mass
		com.y += SPAWN_CLEARANCE
		var body := RigidBody3D.new()
		body.name = "Chassis%d" % idx
		idx += 1
		sim_root.add_child(body)
		body.position = com
		body.mass = mass
		body.can_sleep = false
		body.collision_layer = LAYER_WORLD
		body.collision_mask = LAYER_WORLD
		body.add_to_group("machine")
		var prop_count := 0
		for cell in cl.cells_b:
			if kind[cell] == BlockDB.Kind.PROPELLER:
				prop_count += 1
		body.set_meta("prop_count", maxi(prop_count, 1))
		body_of[rb] = body
		bodies.append(body)
		for cell in cl.cells_b:
			var vis: Node3D = _add_base_visual(body, com, cell, int(data[cell].facing), str(data[cell].type), kind[cell])
			cell_vis[cell] = vis
			if kind[cell] != BlockDB.Kind.WHEEL:
				var cs := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3.ONE * Machine.CELL * 0.999
				cs.shape = shape
				cs.position = Vector3(cell) * Machine.CELL - com
				body.add_child(cs)
				cell_shapes[cell] = cs
			cell_map[cell] = {"body": body, "kind": kind[cell], "type": str(data[cell].type)}
			if kind[cell] == BlockDB.Kind.CANNON or kind[cell] == BlockDB.Kind.ROCKET_LAUNCHER:
				var wbeh: Node = _make_behavior(kind[cell], cell, null, body, Vector3(fwd[cell]),
					data[cell].get("k", {}), behaviors)
				if wbeh:
					sim_root.add_child(wbeh)
			elif kind[cell] == BlockDB.Kind.PROPELLER:
				var p := PropellerBehavior.new()
				p.setup_propeller(body, Vector3(cell) * Machine.CELL, Vector3(fwd[cell]), vis)
				p.setup(cell, data[cell].get("k", {}))
				behaviors.append(p)
				sim_root.add_child(p)
			elif kind[cell] == BlockDB.Kind.BOOSTER:
				var bst := BoosterBehavior.new()
				var bcount: int = maxi(int(body.get_meta("prop_count", 1)), 1)
				bst.setup_booster(body, Vector3(cell) * Machine.CELL, Vector3(fwd[cell]),
					body.mass * 9.8 * 1.6 / bcount)
				bst.setup(cell, data[cell].get("k", {}))
				behaviors.append(bst)
				sim_root.add_child(bst)

	# ---------- 3. 真物理轮子 + 运动学执行器 ----------
	var mover_of := {}   # 可动簇 root -> AnimatableBody3D
	for rb in clusters:
		var cl: Dictionary = clusters[rb]
		if not bool(cl.has_mover):
			continue
		for cell in cl.cells_m:
			if orphan.has(cell):
				continue
			var mount: Vector3i = cell - fwd[cell]
			if not grid.has(mount):
				continue
			var parent_mover: bool = is_joint_kind(kind[mount]) and fwd[mount] == (cell - mount)
			var owner_key: String = dsu.find(_nkey(mount, parent_mover))
			var owner_body: RigidBody3D = body_of.get(owner_key)
			var pivot_world := Vector3(cell) * Machine.CELL + Vector3.UP * SPAWN_CLEARANCE
			if kind[cell] == BlockDB.Kind.WHEEL:
				if owner_body != null:
					# 真物理轮子：独立刚体 + 铰链关节，马达驱动靠摩擦前进
					var wb := _build_wheel_body(cell, fwd[cell], data[cell])
					sim_root.add_child(wb)
					movers.append(wb)
					body_of[dsu.find(_nkey(cell, true))] = wb  # 轮上叠轮时可挂载
					body_of[owner_key + "|wheel"] = wb  # 轮上叠轮（双轮）也可挂载
					var joint := _make_wheel_hinge(owner_body, wb, pivot_world, Vector3(fwd[cell]))
					joints.append(joint)
					var beh := WheelBehavior.new()
					beh.setup_wheel(joint, wb, owner_body, cell, data[cell].get("k", {}), Vector3(fwd[cell]))
					behaviors.append(beh)
					sim_root.add_child(beh)
					cell_map[cell] = {"body": wb, "kind": kind[cell], "type": str(data[cell].type)}
				else:
					# 轮子装在铰链臂等运动学部件上：随动轮（带碰撞，不提供动力）
					var om: AnimatableBody3D = mover_of.get(owner_key)
					if om == null:
						push_warning("[Assembler] 轮子无有效安装面，跳过：" + str(cell))
						continue
					var kw := _build_wheel_kinematic(cell, mount, fwd[cell], data, om)
					movers.append(kw)
					push_warning("[Assembler] 轮子装在运动学部件上，作为随动轮：" + str(cell))
					cell_map[cell] = {"body": om, "kind": kind[cell], "type": str(data[cell].type)}
			else:
				var owner_kin: AnimatableBody3D = mover_of.get(owner_key)
				if owner_body == null and owner_kin == null:
					push_warning("[Assembler] 关节无有效安装体，跳过：" + str(cell))
					continue
				var host: Node3D = owner_body if owner_body != null else owner_kin
				var host_pos: Vector3 = host.position
				var mover := _build_kinematic_mover(cl, cell, kind[cell], fwd[cell], data, host, host_pos)
				movers.append(mover)
				mover_of[rb] = mover
				var beh := _make_behavior(kind[cell], cell, mover,
					owner_body if owner_body != null else owner_kin,
					Vector3(fwd[cell]), data[cell].get("k", {}), behaviors)
				if beh:
					sim_root.add_child(beh)

	# 应用风之旅人风格着色器（按原材质名匹配暖色调）
	JourneyPalette.apply_tree(sim_root)

	return {"bodies": bodies, "movers": movers, "joints": joints, "behaviors": behaviors,
		"root_body": _heaviest(bodies), "cell_map": cell_map,
		"cell_shapes": cell_shapes, "cell_vis": cell_vis}


## 随动轮：装在铰链臂等运动学部件上的轮子（视觉+碰撞，随动不驱动）
static func _build_wheel_kinematic(cell: Vector3i, pivot_cell: Vector3i, fwd_dir: Vector3i,
		data: Dictionary, parent: AnimatableBody3D) -> AnimatableBody3D:
	var kw := AnimatableBody3D.new()
	kw.name = "WheelK_%d_%d_%d" % [cell.x, cell.y, cell.z]
	kw.sync_to_physics = false
	kw.collision_layer = LAYER_MOVER
	kw.collision_mask = LAYER_WORLD | LAYER_MOVER
	parent.add_child(kw)
	kw.position = (Vector3(cell) - Vector3(pivot_cell)) * Machine.CELL
	kw.basis = Machine.facing_basis(int(data[cell].facing))
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.2
	cs.shape = shape
	cs.basis = _basis_y(Vector3(fwd_dir))
	kw.add_child(cs)
	var ps: PackedScene = load(BlockDB.get_def(str(data[cell].type)).model)
	if ps:
		kw.add_child(ps.instantiate())
	return kw


## 真物理轮子刚体：高摩擦圆柱碰撞体 + 轮模型（随物理自然滚动，无手动自转）
static func _build_wheel_body(cell: Vector3i, fwd_dir: Vector3i, data: Dictionary) -> RigidBody3D:
	var wb := RigidBody3D.new()
	wb.name = "Wheel_%d_%d_%d" % [cell.x, cell.y, cell.z]
	wb.mass = 3.0
	wb.can_sleep = false
	wb.collision_layer = LAYER_WORLD
	wb.collision_mask = LAYER_WORLD
	wb.add_to_group("machine")
	var pm := PhysicsMaterial.new()
	pm.friction = 2.0
	pm.bounce = 0.05
	wb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.2
	cs.shape = shape
	cs.basis = _basis_y(Vector3(fwd_dir))  # 圆柱局部 Y = 轮轴
	wb.add_child(cs)
	var ps: PackedScene = load(BlockDB.get_def(str(data.type)).model)
	if ps:
		wb.add_child(ps.instantiate())
	wb.position = Vector3(cell) * Machine.CELL + Vector3.UP * SPAWN_CLEARANCE
	wb.basis = Machine.facing_basis(int(data.facing))
	return wb


## 轮子铰链：轴 = 轮子 forward，马达由 WheelBehavior 驱动
static func _make_wheel_hinge(owner_body: RigidBody3D, wheel_body: RigidBody3D,
		pivot: Vector3, axle: Vector3) -> HingeJoint3D:
	var j := HingeJoint3D.new()
	j.position = pivot - owner_body.position
	j.basis = _basis_z(axle)
	j.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	j.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	j.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
	j.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 30.0)
	owner_body.add_child(j)
	j.node_a = owner_body.get_path()
	j.node_b = wheel_body.get_path()
	return j


static func _heaviest(bodies: Array) -> RigidBody3D:
	var best: RigidBody3D = null
	for b in bodies:
		if best == null or b.mass > best.mass:
			best = b
	return best


static func _basis_y(y: Vector3) -> Basis:
	var yy := y.normalized()
	var helper := Vector3.UP if absf(yy.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var xx := helper.cross(yy).normalized()
	var zz := xx.cross(yy).normalized()
	return Basis(xx, yy, zz)


## 局部 Z = axis（HingeJoint3D 绕关节局部 Z 旋转）
static func _basis_z(z: Vector3) -> Basis:
	var zz := z.normalized()
	var helper := Vector3.UP if absf(zz.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var xx := helper.cross(zz).normalized()
	var yy := zz.cross(xx).normalized()
	return Basis(xx, yy, zz)


## 构建运动学执行器（挂到所属底盘簇或上级执行器下），可动侧普通块作为其子节点
static func _build_kinematic_mover(cl: Dictionary, cell: Vector3i, k: int, fwd_dir: Vector3i,
		data: Dictionary, parent: Node3D, parent_pos: Vector3) -> AnimatableBody3D:
	var pivot_world := Vector3(cell) * Machine.CELL
	var mover := AnimatableBody3D.new()
	mover.name = "Mover_%d_%d_%d" % [cell.x, cell.y, cell.z]
	# sync_to_physics 必须关闭：实测开启时，挂在动态底盘下的运动学体会把父体钉死在空中
	mover.sync_to_physics = false
	mover.collision_layer = LAYER_MOVER
	mover.collision_mask = LAYER_WORLD | LAYER_MOVER
	parent.add_child(mover)
	mover.position = pivot_world - parent_pos
	mover.basis = Machine.facing_basis(int(data[cell].facing))

	var cs := CollisionShape3D.new()
	match k:
		BlockDB.Kind.HINGE:
			var lug := BoxShape3D.new()
			lug.size = Vector3(0.3, 0.3, 0.3)
			cs.shape = lug
			cs.position = Vector3(fwd_dir) * 0.05
		BlockDB.Kind.PISTON:
			var rod := BoxShape3D.new()
			rod.size = Vector3(0.14, 0.14, 0.55)
			cs.shape = rod
	mover.add_child(cs)

	# 关节格的可动侧 visuals
	var ps: PackedScene = load(BlockDB.get_def(str(data[cell].type)).model)
	if ps:
		var inst: Node3D = ps.instantiate()
		for child in inst.get_children():
			if child is not Node3D:
				continue
			var cname := String(child.name)
			var want := cname in MOVER_PARTS
			if want:
				inst.remove_child(child)
				mover.add_child(child)
		inst.queue_free()

	# 可动侧普通方块（cl.cells_b，如铰链前端的尖刺）：visual + 碰撞
	for other in cl.cells_b:
		var def: Dictionary = BlockDB.get_def(str(data[other].type))
		var vps: PackedScene = load(def.model)
		if vps:
			var v: Node3D = vps.instantiate()
			v.position = Vector3(other) * Machine.CELL - pivot_world
			v.rotation.y = float(data[other].facing) * PI / 2.0
			mover.add_child(v)
		var ocs := CollisionShape3D.new()
		var osh := BoxShape3D.new()
		osh.size = Vector3.ONE * Machine.CELL * 0.999
		ocs.shape = osh
		ocs.position = Vector3(other) * Machine.CELL - pivot_world
		ocs.rotation.y = float(data[other].facing) * PI / 2.0
		mover.add_child(ocs)
	return mover


static func _make_behavior(k: int, cell: Vector3i, mover: AnimatableBody3D,
		chassis: RigidBody3D, fwd_dir: Vector3, binding: Dictionary,
		out_behaviors: Array) -> Node:
	var beh: Node = null
	match k:
		BlockDB.Kind.HINGE:
			var h := HingeBehavior.new()
			h.setup_hinge(mover)
			h.setup(cell, binding)
			beh = h
		BlockDB.Kind.PISTON:
			var p := PistonBehavior.new()
			p.setup_piston(mover)
			p.setup(cell, binding)
			beh = p
		BlockDB.Kind.CANNON, BlockDB.Kind.ROCKET_LAUNCHER:
			var dir_world := Vector3(fwd_dir)
			if k == BlockDB.Kind.CANNON:
				var c := CannonBehavior.new()
				c.setup_weapon(chassis, Vector3(cell) * Machine.CELL, dir_world)
				c.setup(cell, binding)
				beh = c
			else:
				var r := RocketLauncherBehavior.new()
				r.setup_weapon(chassis, Vector3(cell) * Machine.CELL, dir_world)
				r.setup(cell, binding)
				beh = r
	if beh:
		out_behaviors.append(beh)
	return beh


## 底盘侧视觉：非关节格整块；关节格取 glb 的 base 部件。返回创建的视觉根节点。
static func _add_base_visual(body: RigidBody3D, body_pos: Vector3, cell: Vector3i,
		facing: int, type: String, k: int) -> Node3D:
	var ps: PackedScene = load(BlockDB.get_def(type).model)
	if ps == null:
		return null
	var cell_xform := Transform3D(Machine.facing_basis(facing),
		Vector3(cell) * Machine.CELL - body_pos)
	if not is_joint_kind(k):
		var inst: Node3D = ps.instantiate()
		inst.transform = cell_xform
		body.add_child(inst)
		return inst
	var result: Node3D = null
	var inst2: Node3D = ps.instantiate()
	for child in inst2.get_children():
		if child is not Node3D:
			continue
		var cname := String(child.name)
		var goes_base := cname in BASE_PARTS
		if k == BlockDB.Kind.WHEEL or not goes_base:
			continue
		inst2.remove_child(child)
		child.transform = cell_xform * child.transform
		body.add_child(child)
		if result == null:
			result = child
	inst2.queue_free()
	return result
