class_name SimLevel
extends Node3D
## 模拟模式关卡：从 Game.pending_machine 装配物理机器，运行驱动与视角。
## T 返回建造。keys 是按键状态表（_input 写入，录像 bot 可直接注入）。

const KEY_RETURN := KEY_T

@onready var sim_root: Node3D = $SimRoot
@onready var cam: ChaseCamera = $ChaseCamera
@onready var hud: SimHUD = $UI

var keys := {}                 # physical_keycode(int) -> bool
var result := {}               # 装配结果
var root_body: RigidBody3D = null
var projectiles: Node3D = null
var machine_forward := Vector3.ZERO
var reverse_forward := false   # 行驶方向翻转（建造界面设置，进模拟时读取）
var _arrow: Node3D = null
signal player_fired(pos: Vector3)
var level_mode := ""           # "" 沙盒 | "battle" 平原战场
var machine_cells := {}        # RigidBody3D -> Array[Vector3i] 存活方块
var prev_vels := {}            # RigidBody3D -> Vector3 上帧速度（撞击检测）
var cell_shapes := {}          # cell -> CollisionShape3D
var cell_vis := {}             # cell -> Node3D
var mobs: Array = []


func _spawn_forward_arrow() -> void:
	if machine_forward.is_zero_approx() or root_body == null:
		return
	_arrow = Node3D.new()
	_arrow.name = "ForwardArrow"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.1)
	mat.emission_energy_multiplier = 2.0
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.08, 0.08, 0.9)
	shaft_mesh.material = mat
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0, 0, -0.45)
	_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.16
	cone.height = 0.35
	cone.material = mat
	head.mesh = cone
	head.position = Vector3(0, 0, -1.05)
	head.rotation.x = -PI / 2.0
	_arrow.add_child(head)
	sim_root.add_child(_arrow)


func _process(_delta: float) -> void:
	if _arrow and is_instance_valid(root_body):
		_arrow.global_position = root_body.global_position + Vector3.UP * 1.4
		if not machine_forward.is_zero_approx():
			var mf := machine_forward
			var zz := -mf
			var xx := Vector3.UP.cross(zz).normalized()
			if xx.length() < 0.01:
				xx = Vector3(1, 0, 0)
			var yy := zz.cross(xx).normalized()
			_arrow.global_basis = Basis(xx, yy, zz)


func _physics_process(delta: float) -> void:
	# 空中转向：A/D 偏航（仅离地时生效，扭矩按质量整定、自带阻尼）
	if root_body == null:
		return
	var yaw := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		yaw += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		yaw -= 1.0
	var w := root_body.angular_velocity.y
	if yaw == 0.0:
		if absf(w) > 0.05:
			root_body.apply_torque(Vector3.UP * -w * root_body.mass * 2.0)
		return
	if not _airborne():
		return
	var target_w := yaw * 1.2
	root_body.apply_torque(Vector3.UP * (target_w - w) * root_body.mass * 2.5)
	_check_impact_damage()
	_check_battle_win()


## 撞击/坠落散架：单帧速度突降超过阈值 → 震落方块
func _check_impact_damage() -> void:
	for body in machine_cells.keys():
		if not is_instance_valid(body):
			machine_cells.erase(body)
			continue
		var cur: Vector3 = body.linear_velocity
		if prev_vels.has(body):
			var dv: float = (prev_vels[body] - cur).length()
			if dv > 6.0 and not machine_cells.get(body, []).is_empty():
				var n: int = 1 + int((dv - 6.0) / 4.0)
				damage_machine_block(body, Vector3.INF, n)
				print("[Dmg] impact dv=%.1f kill %d" % [dv, n])
		prev_vels[body] = cur


## 散架：从机器上击落方块（近处优先）
func damage_machine_block(body: RigidBody3D, near: Vector3, amount: int) -> void:
	var cells: Array = machine_cells.get(body, [])
	if cells.is_empty() or amount <= 0:
		return
	for i in range(amount):
		if cells.is_empty():
			break
		var pick: Vector3i = cells.pick_random()
		if near.is_finite():
			var best: Vector3i = cells[0]
			var best_d := 1e9
			for c in cells:
				var wp: Vector3 = body.to_global(Vector3(c) * Machine.CELL)
				var d := wp.distance_squared_to(near)
				if d < best_d:
					best_d = d
					best = c
			pick = best
		_kill_block(body, pick)
		cells.erase(pick)


func _kill_block(body: RigidBody3D, cell: Vector3i) -> void:
	var info: Dictionary = result.cell_map.get(cell, {})
	if info.is_empty():
		return
	var kind: int = int(info.kind)
	# 世界位置（取该格碰撞体/视觉的全局位置，最贴近当前姿态）
	var at: Vector3 = body.global_position
	var cs: CollisionShape3D = cell_shapes.get(cell)
	if cs and is_instance_valid(cs):
		at = cs.global_position
	# 1) 轮子：松开铰链 → 整轮脱落滚走
	if kind == BlockDB.Kind.WHEEL:
		for beh in result.behaviors:
			if beh is WheelBehavior and beh.cell == cell and is_instance_valid(beh.joint):
				beh.joint.queue_free()
				beh.process_mode = Node.PROCESS_MODE_DISABLED
		spawn_debris(at, 2, Color(0.15, 0.13, 0.12))
		print("[Dmg] wheel fell off ", cell)
		return
	# 2) 铰链/活塞：整个执行器连附属件一起散架
	if kind == BlockDB.Kind.HINGE or kind == BlockDB.Kind.PISTON:
		for beh in result.behaviors:
			if beh.cell == cell:
				beh.process_mode = Node.PROCESS_MODE_DISABLED
		for m in result.movers:
			if m.name.begins_with("Mover_%d_%d_%d" % [cell.x, cell.y, cell.z]):
				spawn_debris(m.global_position, 3, Color(0.35, 0.28, 0.2))
				m.queue_free()
				break
		spawn_debris(at, 2, Color(0.15, 0.13, 0.12))
		print("[Dmg] hinge/piston broke off ", cell)
		return
	# 3) 普通底盘块：移除碰撞形与视觉，掉落碎块
	var vis: Node3D = cell_vis.get(cell)
	if vis and is_instance_valid(vis):
		at = vis.global_position
		vis.queue_free()
	var cs2: CollisionShape3D = cell_shapes.get(cell)
	if cs2 and is_instance_valid(cs2):
		cs2.queue_free()
	var wdef: Dictionary = BlockDB.get_def(str(info.get("type", "wood_block")))
	body.mass = maxf(body.mass - float(wdef.get("mass", 2.0)), 1.0)
	for beh in result.behaviors:
		if beh.cell == cell:
			beh.process_mode = Node.PROCESS_MODE_DISABLED
	spawn_debris(at, 2, Color(0.42, 0.30, 0.18))
	print("[Dmg] block broke off ", cell, " remaining=", machine_cells.get(body, []).size())


func spawn_debris(pos: Vector3, n: int, color: Color) -> void:
	for i in range(n):
		var d := RigidBody3D.new()
		d.mass = 0.5
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.12, 0.28)
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		bm.material = m
		mi.mesh = bm
		d.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.1
		cs.shape = sh
		d.add_child(cs)
		d.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0, 0.3), randf_range(-0.2, 0.2))
		d.linear_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(2.0, 5.0), randf_range(-2.5, 2.5))
		d.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		sim_root.add_child(d)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(d):
				d.queue_free())


## 离地检测：机器质心下方短距离内无地面接触
func _airborne() -> bool:
	var space := root_body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		root_body.global_position, root_body.global_position + Vector3.DOWN * 1.6)
	var ex: Array[RID] = []
	for b in result.bodies:
		ex.append(b.get_rid())
	for m in result.movers:
		if m is CollisionObject3D:
			ex.append(m.get_rid())
	q.exclude = ex
	return space.intersect_ray(q).is_empty()


func spawn_cannon_ball(pos: Vector3, dir: Vector3, speed: float) -> void:
	if projectiles:
		projectiles.add_child(ProjectileBall.create(pos, dir, speed))
	player_fired.emit(pos)


func spawn_rocket(pos: Vector3, dir: Vector3) -> void:
	if projectiles:
		projectiles.add_child(Rocket.create(pos, dir))
	player_fired.emit(pos)


func spawn_hostile_ball(pos: Vector3, dir: Vector3, speed: float) -> void:
	if projectiles:
		var b := ProjectileBall.create(pos, dir, speed, true)
		projectiles.add_child(b)


var _victory_shown := false


func _check_battle_win() -> void:
	if level_mode != "battle" or _victory_shown:
		return
	var alive := 0
	for m in mobs:
		if is_instance_valid(m):
			alive += 1
	if not mobs.is_empty() and alive == 0:
		_victory_shown = true
		hud.show_toast("战场清空！所有敌方炮台已摧毁")
		Sfx.play(self, "explosion", root_body.global_position if root_body else Vector3.ZERO)


func play_sfx(name: String, pos: Vector3) -> void:
	Sfx.play(self, name, pos)


## 水池：视觉半透明水体 + 浮力区域
func _spawn_pool() -> void:
	var vol := WaterVolume.new()
	vol.surface_y = 0.55
	vol.position = Vector3(-6, 0.05, -15)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(20, 1.0, 12)
	cs.shape = sh
	vol.add_child(cs)
	sim_root.add_child(vol)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(20, 1.0, 12)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.58, 0.60, 0.50)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.3
	bm.material = m
	mesh.mesh = bm
	mesh.position = Vector3(-6, 0.05, -15)
	sim_root.add_child(mesh)


func _ready() -> void:
	# 调试/验收：--load-slot=名字 直接从存档载入机器
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--load-slot="):
			var tmp: Machine = load("res://scripts/core/machine.gd").new()
			var err: int = SaveManager.load_machine(tmp, a.get_slice("=", 1))
			print("[Sim] load-slot ", a.get_slice("=", 1), " err=", err,
				" blocks=", tmp.block_count())
			Game.pending_machine = tmp.serialize()

	# 录像 bot 可以在装配前改写 Game.pending_machine
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--record-bot"):
			var bot := RecordBot.new()
			bot.phase = int(a.get_slice("=", 1)) if "=" in a else 1
			bot.mode = "sim"
			add_child(bot)

	var pending: Dictionary = Game.pending_machine
	reverse_forward = Game.reverse_forward
	level_mode = Game.level_mode
	if OS.get_cmdline_user_args().has("--battle"):
		level_mode = "battle"
	if pending.is_empty() or (pending.get("blocks", []) as Array).is_empty():
		hud.show_toast("没有可模拟的机器")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	result = MachineAssembler.assemble(_grid_from_pending(pending), sim_root)
	root_body = result.root_body
	for beh in result.behaviors:
		beh.sim = self
	cam.target = root_body
	hud.set_key_hints(_build_key_hint_text(pending))

	# 调试：车顶红色箭头 = 第一个轮子按 ↑ 时的滚动方向（摩擦力推进方向）
	for beh in result.behaviors:
		if beh is WheelBehavior:
			machine_forward = beh.roll_direction()
			break
	_spawn_forward_arrow()

	# 登记机器存活方块（损伤/散架系统）
	cell_shapes = result.cell_shapes
	cell_vis = result.cell_vis
	for cell in result.cell_map:
		var body: RigidBody3D = result.cell_map[cell].body
		if not machine_cells.has(body):
			machine_cells[body] = []
			prev_vels[body] = body.linear_velocity
		machine_cells[body].append(cell)

	# 平原战场：刷敌方炮台
	if level_mode == "battle":
		var mob_spots := [
			Vector3(-9, 0.3, -6), Vector3(10, 0.3, -9),
			Vector3(-12, 0.3, -16), Vector3(8, 0.3, -18),
		]
		for spot in mob_spots:
			var mob := EnemyTurret.create(spot, root_body)
			sim_root.add_child(mob)
			mobs.append(mob)
		hud.show_toast("平原战场：摧毁 %d 座敌方炮台！" % mobs.size())

	# 弹药容器 + 靶场（木塔 + 铁墙）
	projectiles = Node3D.new()
	projectiles.name = "Projectiles"
	sim_root.add_child(projectiles)
	# 靶场：路径上的两座塔（可撞可轰）+ 水池外的一组
	DestructibleTarget.spawn_tower(sim_root, Vector3(-2.0, -0.45, -7.0), 3)
	DestructibleTarget.spawn_tower(sim_root, Vector3(2.0, -0.45, -8.5), 3)
	# 靶场放在水池（x -16..4, z -21..-9）之外
	DestructibleTarget.spawn_tower(sim_root, Vector3(9.0, -0.45, -10.0), 4)
	DestructibleTarget.spawn_tower(sim_root, Vector3(13.0, -0.45, -13.0), 3)
	DestructibleTarget.spawn_wall(sim_root, Vector3(11.0, -0.45, -18.0), 5, 3)
	_spawn_pool()

	print("[Sim] bodies=%d movers=%d behaviors=%d root=%s" % [
		result.bodies.size(), result.movers.size(), result.behaviors.size(), root_body.name])
	hud.show_toast("模拟开始（%d 个刚体 / %d 个执行器）" % [result.bodies.size(), result.movers.size()])


func _grid_from_pending(pending: Dictionary) -> Dictionary:
	var grid := {}
	for b in pending.get("blocks", []):
		var c: Array = b.c
		var k: Dictionary = b.get("k", {})
		if k.is_empty():
			k = BlockDB.default_bindings(str(b.t))  # 车库"直接出击"等路径：未绑定时套默认按键
		grid[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = {
			"type": str(b.t), "facing": int(b.f), "k": k
		}
	return grid


## 汇总机器上的按键绑定，生成左上角提示文本
func _build_key_hint_text(pending: Dictionary) -> String:
	var entries := {}   # "label" -> "键名"（去重）
	for b in pending.get("blocks", []):
		var type: String = str(b.t)
		var def := BlockDB.get_def(type)
		var k: Dictionary = b.get("k", {})
		for action in k:
			var label := ""
			for a in def.get("actions", []):
				if str(a.id) == str(action):
					label = "%s·%s" % [def.name, str(a.label)]
					break
			if label == "":
				continue
			var arr: Array = k[action]
			var pos_name := _key_name(int(arr[0]))
			var text := pos_name if arr.size() < 2 or int(arr[1]) == 0 \
				else "%s/%s" % [pos_name, _key_name(int(arr[1]))]
			if not entries.has(label):
				entries[label] = text
	if entries.is_empty():
		return "（本机没有绑定任何按键）"
	var parts: PackedStringArray = []
	for label in entries:
		parts.append("%s %s" % [entries[label], label])
	return "  ·  ".join(parts)


func _key_name(k: int) -> String:
	if k == 0:
		return "无"
	return OS.get_keycode_string(k as Key)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		keys[event.physical_keycode] = event.pressed


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_RETURN:
			get_tree().change_scene_to_file(_return_scene())


## 关卡内容（靶场/水池），子类可覆盖
func _spawn_level_content() -> void:
	if Game.puzzle_mode:
		return
	DestructibleTarget.spawn_tower(sim_root, Vector3(-2.0, -0.45, -7.0), 3)
	DestructibleTarget.spawn_tower(sim_root, Vector3(2.0, -0.45, -8.5), 3)
	DestructibleTarget.spawn_tower(sim_root, Vector3(9.0, -0.45, -10.0), 4)
	DestructibleTarget.spawn_tower(sim_root, Vector3(13.0, -0.45, -13.0), 3)
	DestructibleTarget.spawn_wall(sim_root, Vector3(11.0, -0.45, -18.0), 5, 3)
	_spawn_pool()


## 退出模拟时返回的场景，子类可覆盖
func _return_scene() -> String:
	return "res://scenes/puzzle_build.tscn" if Game.puzzle_mode else "res://scenes/build_level.tscn"
