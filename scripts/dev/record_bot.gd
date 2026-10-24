class_name RecordBot
extends Node
## 验收录像 bot：由命令行参数 --record-bot=<阶段号> 激活。
## mode="build"（挂在 BuildLevel）演示建造/存读档；
## mode="sim"（挂在 SimLevel）在装配前注入机器数据，再直接驱动 keys 演示驾驶。
## 不模拟输入，Movie Maker 渲染下确定性执行。

var phase := 1
var mode := "build"   # "build" | "sim"

var _t := 0.0
var _steps: Array = []   # {t: float, fn: Callable}
var _idx := 0
var _done_t := 20.0
var _level: Node = null
var _hud: Object = null


func _ready() -> void:
	_level = get_parent()
	_hud = _level.get("ui") if _level is BuildLevel else _level.get("hud")
	match phase:
		1:
			_build_phase1()
		2:
			_setup_sim_phase2()
		3:
			_setup_sim_phase3()
		4:
			_setup_sim_phase4()
		5:
			if mode == "build":
				_build_phase5()
			else:
				_setup_sim_phase5()
		_:
			push_error("[Bot] unknown phase %d" % phase)
			_done_t = 1.0


## 阶段5 建造段：拼装"战斗飞行车"并存档，然后切换到模拟模式（录像跨场景连续）
func _build_phase5() -> void:
	var m: Machine = _level.machine
	var spin := [KEY_UP, KEY_DOWN]
	var throttle := [KEY_I, KEY_K]
	var plan := [
		[1.0, Vector3i(0, 0, 0), "wood_block", 0],
		[1.4, Vector3i(1, 0, 0), "wood_block", 0],
		[1.8, Vector3i(0, 0, 1), "wood_block", 0],
		[2.2, Vector3i(1, 0, 1), "wood_block", 0],
		[2.6, Vector3i(0, 0, 2), "wood_block", 0],
		[3.0, Vector3i(1, 0, 2), "wood_block", 0],
		[3.4, Vector3i(0, 0, 3), "wood_block", 0],
		[3.8, Vector3i(1, 0, 3), "wood_block", 0],
		[4.2, Vector3i(0, 1, 0), "metal_block", 0],
		[4.6, Vector3i(1, 1, 0), "metal_block", 0],
		[5.0, Vector3i(0, 1, 1), "metal_block", 0],
		[5.4, Vector3i(1, 1, 1), "metal_block", 0],
		[5.8, Vector3i(0, 1, 3), "buoy", 0],
		[6.2, Vector3i(1, 1, 3), "buoy", 0],
		[6.6, Vector3i(-1, 0, 1), "wheel", 1],
		[7.0, Vector3i(2, 0, 1), "wheel", 3],
		[7.4, Vector3i(-1, 0, 3), "wheel", 1],
		[7.8, Vector3i(2, 0, 3), "wheel", 3],
		[8.2, Vector3i(0, 2, 0), "cannon", 0],
		[8.6, Vector3i(1, 2, 0), "rocket_launcher", 0],
		[9.0, Vector3i(0, 2, 1), "propeller", 4],
		[9.4, Vector3i(1, 2, 1), "propeller", 4],
		[9.8, Vector3i(0, 2, 2), "propeller", 0],
	]
	for p in plan:
		var cell: Vector3i = p[1]
		var type: String = p[2]
		var facing: int = p[3]
		var bindings := {}
		match type:
			"wheel":
				bindings = {"spin": spin}
			"propeller":
				bindings = {"throttle": throttle}
			"cannon":
				bindings = {"fire": [KEY_SPACE]}
			"rocket_launcher":
				bindings = {"fire": [KEY_G]}
		_steps.append({"t": p[0], "fn": func() -> void:
			if m.add_block(cell, type, facing, bindings):
				print("[Bot] placed ", type, " at ", cell)
			else:
				push_error("[Bot] FAILED place %s at %s" % [type, cell])})
	_steps.append({"t": 10.2, "fn": func() -> void:
		SaveManager.save_machine(m, "war_flyer")
		_level.ui.show_toast("战斗飞行车已完成（%d 个组件）" % m.block_count())
		print("[Bot] built & saved")})
	_steps.append({"t": 11.5, "fn": func() -> void:
		print("[Bot] START SIM")
		_level.start_sim()})
	_done_t = 13.0  # 场景切换后本 bot 会被释放


## 阶段5 模拟段：驾车冲塔开火 → 起飞 → 降落水池
func _setup_sim_phase5() -> void:
	# 不覆盖 Game.pending：使用建造段序列化的机器
	var UP := KEY_UP
	_steps.append({"t": 1.2, "fn": func() -> void:
		_press(KEY_SPACE, true)})
	_steps.append({"t": 1.5, "fn": func() -> void:
		_press(KEY_SPACE, false); print("[Bot] cannon shot at towers")})
	_steps.append({"t": 2.2, "fn": func() -> void:
		_press(KEY_G, true)})
	_steps.append({"t": 2.5, "fn": func() -> void:
		_press(KEY_G, false); print("[Bot] rocket away")})
	_steps.append({"t": 3.5, "fn": func() -> void:
		_press(UP, true); print("[Bot] drive through the towers")})
	_steps.append({"t": 7.0, "fn": func() -> void:
		_press(UP, false); print("[Bot] past the towers. root_pos=", _root_pos())})
	_steps.append({"t": 7.5, "fn": func() -> void:
		_press(KEY_I, true); print("[Bot] take off")})
	_steps.append({"t": 9.5, "fn": func() -> void:
		_press(KEY_I, false); print("[Bot] splash down. root_pos=", _root_pos(),
		" max_y=%.2f" % _max_y)})
	_steps.append({"t": 11.5, "fn": func() -> void:
		print("[ASSERT] float pos=", _root_pos(), " (pool z -22..-10)")})
	_done_t = 13.0


## 阶段4：飞行 + 游泳（五桨飞行器，飞进水池降落再起飞）
func _setup_sim_phase4() -> void:
	var up_throttle := [KEY_UP, KEY_DOWN]
	var blocks := [
		{"c": [0, 0, 0], "t": "wood_block", "f": 0},
		{"c": [1, 0, 0], "t": "wood_block", "f": 0},
		{"c": [0, 0, 1], "t": "wood_block", "f": 0},
		{"c": [1, 0, 1], "t": "wood_block", "f": 0},
		{"c": [0, 0, 2], "t": "wood_block", "f": 0},
		{"c": [1, 0, 2], "t": "wood_block", "f": 0},
		{"c": [0, 1, 0], "t": "propeller", "f": 4, "k": {"throttle": up_throttle}},
		{"c": [1, 1, 0], "t": "propeller", "f": 4, "k": {"throttle": up_throttle}},
		{"c": [0, 1, 2], "t": "propeller", "f": 4, "k": {"throttle": up_throttle}},
		{"c": [1, 1, 2], "t": "propeller", "f": 4, "k": {"throttle": up_throttle}},
		{"c": [0, 1, 1], "t": "propeller", "f": 0, "k": {"throttle": up_throttle}},
		{"c": [1, 1, 1], "t": "buoy", "f": 0},
	]
	Game.pending_machine = {"name": "flyer", "version": 1, "blocks": blocks}
	_max_y = 0.0
	_steps.append({"t": 1.2, "fn": func() -> void:
		_press(KEY_UP, true); print("[Bot] liftoff")})
	_steps.append({"t": 4.0, "fn": func() -> void:
		_press(KEY_UP, false); print("[Bot] throttle off over pool. root_pos=", _root_pos(),
		" max_y=%.2f" % _max_y)})
	_steps.append({"t": 6.0, "fn": func() -> void:
		print("[ASSERT] splash: root_pos=", _root_pos(), " (should float in pool z -21..-9)")})
	_steps.append({"t": 9.0, "fn": func() -> void:
		_press(KEY_UP, true); print("[Bot] take off from water")})
	_steps.append({"t": 11.0, "fn": func() -> void:
		_press(KEY_UP, false); print("[Bot] airborne again. max_y=%.2f" % _max_y)})
	_done_t = 12.5


var _max_y := 0.0


# ================= 阶段1：建造 =================

func _build_phase1() -> void:
	var m: Machine = _level.machine
	var plan := [
		[1.0, Vector3i(0, 0, 0), "wood_block", 0],
		[1.5, Vector3i(0, 0, 1), "wood_block", 0],
		[2.0, Vector3i(0, 0, 2), "wood_block", 0],
		[2.5, Vector3i(0, 0, 3), "wood_block", 0],
		[3.0, Vector3i(0, 1, 1), "metal_block", 0],
		[3.5, Vector3i(0, 1, 2), "metal_block", 0],
		[4.0, Vector3i(-1, 0, 1), "wheel", 1],
		[4.5, Vector3i(1, 0, 1), "wheel", 3],
		[5.0, Vector3i(-1, 0, 3), "wheel", 1],
		[5.5, Vector3i(1, 0, 2), "wheel", 3],
		[6.0, Vector3i(0, 0, -1), "hinge", 0],
		[6.5, Vector3i(0, 0, -2), "blade", 0],
		[7.0, Vector3i(0, 2, 2), "cannon", 0],
		[7.5, Vector3i(0, 2, 1), "rocket_launcher", 0],
		[8.0, Vector3i(0, 0, 4), "piston", 2],
		[8.5, Vector3i(0, 1, 4), "propeller", 2],
	]
	for p in plan:
		var cell: Vector3i = p[1]
		var type: String = p[2]
		var facing: int = p[3]
		_steps.append({"t": p[0], "fn": func() -> void:
			if m.add_block(cell, type, facing):
				print("[Bot] placed ", type, " at ", cell)
			else:
				push_error("[Bot] FAILED place %s at %s" % [type, cell])})
	_steps.append({"t": 9.5, "fn": func() -> void:
		var err := SaveManager.save_machine(m, "autosave")
		_hud.show_toast("已保存 autosave（%d 个组件）" % m.block_count())
		print("[Bot] saved err=", err)})
	_steps.append({"t": 11.0, "fn": func() -> void:
		m.clear()
		_hud.show_toast("已清空")
		print("[Bot] cleared, count=", m.block_count())})
	_steps.append({"t": 12.0, "fn": func() -> void:
		var err := SaveManager.load_machine(m, "autosave")
		_hud.show_toast("已载入（%d 个组件）" % m.block_count())
		print("[Bot] loaded err=", err, " count=", m.block_count())})
	_done_t = 17.0


# ================= 阶段2：物理模拟 =================

## 在 SimLevel 装配前注入机器数据（SimLevel._ready 先 add 本 bot，再装配）
func _setup_sim_phase2() -> void:
	var slot_mode := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--load-slot"):
			slot_mode = true
	if slot_mode:
		print("[Bot] --load-slot 模式：使用存档机器，不覆盖 pending")
		_steps.append({"t": 1.5, "fn": func() -> void:
			_press(KEY_UP, true); _press(KEY_U, true); print("[Bot] drive + boost")})
		_steps.append({"t": 2.6, "fn": func() -> void:
			_press(KEY_A, true); print("[Bot] steer left")})
		_steps.append({"t": 3.2, "fn": func() -> void:
			var rb: RigidBody3D = _level.get("root_body")
			print("[ASSERT] root_pos=", _root_pos(),
				" ang_y=%.2f (A 转向应 != 0)" % rb.angular_velocity.y if rb else "")})
		_steps.append({"t": 3.8, "fn": func() -> void:
			_press(KEY_A, false)})
		_steps.append({"t": 4.5, "fn": func() -> void:
			_press(KEY_UP, false); _press(KEY_U, false); print("[Bot] brake. root_pos=", _root_pos())})
		_steps.append({"t": 5.0, "fn": func() -> void:
			_press(KEY_DOWN, true); print("[Bot] reverse")})
		_steps.append({"t": 6.2, "fn": func() -> void:
			_press(KEY_DOWN, false); print("[Bot] stop. root_pos=", _root_pos())})
		_done_t = 8.0
		return
	var blocks: Array = []
	if OS.get_cmdline_user_args().has("--min"):
		# 最小复现：地板1 + 轮1（带绑定）+ 配重1（轮的 child 侧）
		blocks = [
			{"c": [0, 0, 0], "t": "wood_block", "f": 0},
			{"c": [-1, 0, 0], "t": "wheel", "f": 1, "k": {"spin": [KEY_UP, KEY_DOWN]}},
			{"c": [-2, 0, 0], "t": "metal_block", "f": 0},
		]
		Game.pending_machine = {"name": "min_rig", "version": 1, "blocks": blocks}
		_steps.append({"t": 1.5, "fn": func() -> void: _press(KEY_UP, true)})
		_steps.append({"t": 4.0, "fn": func() -> void: _press(KEY_UP, false)})
		_done_t = 6.0
		return
	var UP := KEY_UP
	var DOWN := KEY_DOWN
	var spin := [UP, DOWN]
	var swing := [KEY_Q, KEY_E]
	var extend := [KEY_R, KEY_F]
	blocks = [
		{"c": [0, 0, 0], "t": "wood_block", "f": 0},
		{"c": [0, 0, 1], "t": "wood_block", "f": 0},
		{"c": [0, 0, 2], "t": "wood_block", "f": 0},
		{"c": [0, 0, 3], "t": "wood_block", "f": 0},
		{"c": [0, 1, 1], "t": "metal_block", "f": 0},
		{"c": [0, 1, 2], "t": "metal_block", "f": 0},
		{"c": [-1, 0, 1], "t": "wheel", "f": 1, "k": {"spin": spin}},
		{"c": [1, 0, 1], "t": "wheel", "f": 3, "k": {"spin": spin}},
		{"c": [-1, 0, 3], "t": "wheel", "f": 1, "k": {"spin": spin}},
		{"c": [1, 0, 3], "t": "wheel", "f": 3, "k": {"spin": spin}},
		{"c": [0, 0, -1], "t": "hinge", "f": 0, "k": {"swing": swing}},
		{"c": [0, 0, -2], "t": "blade", "f": 0},
		{"c": [0, 2, 2], "t": "cannon", "f": 0},
		{"c": [0, 2, 1], "t": "rocket_launcher", "f": 0},
		{"c": [0, 0, 4], "t": "piston", "f": 2, "k": {"extend": extend}},
		{"c": [0, 1, 4], "t": "propeller", "f": 2},
	]
	Game.pending_machine = {"name": "sim_bot_cart", "version": 1, "blocks": blocks}
	_steps.append({"t": 1.5, "fn": func() -> void:
		_press(KEY_UP, true); print("[Bot] drive forward")})
	_steps.append({"t": 4.5, "fn": func() -> void:
		_press(KEY_UP, false); print("[Bot] brake. root_pos=", _root_pos())
		for m in _level.result.movers:
			if m is RigidBody3D and m.name.begins_with("Wheel"):
				print("[WheelDbg] ", m.name, " pos=", m.global_position,
					" ang=", m.angular_velocity, " contacts=", m.get_contact_count(),
					" slept=", m.sleeping)})
	_steps.append({"t": 5.0, "fn": func() -> void:
		_press(KEY_DOWN, true); print("[Bot] reverse")})
	_steps.append({"t": 6.2, "fn": func() -> void:
		_press(KEY_DOWN, false); print("[Bot] stop. root_pos=", _root_pos())})
	_steps.append({"t": 7.0, "fn": func() -> void:
		_press(KEY_Q, true); print("[Bot] hinge up")})
	_steps.append({"t": 8.9, "fn": func() -> void:
		for beh in _level.result.behaviors:
			if beh is HingeBehavior:
				print("[ASSERT] hinge_theta_mid=%.3f (|.|>1.0 expected)" % beh._theta)})
	_steps.append({"t": 9.0, "fn": func() -> void:
		_press(KEY_Q, false); _press(KEY_E, true); print("[Bot] hinge down")})
	_steps.append({"t": 11.0, "fn": func() -> void:
		_press(KEY_E, false); print("[Bot] hinge stop")
		for beh in _level.result.behaviors:
			if beh is HingeBehavior:
				print("[ASSERT] hinge_theta=%.3f (should be != 0)" % beh._theta)})
	_steps.append({"t": 11.5, "fn": func() -> void:
		_press(KEY_R, true); print("[Bot] piston extend")})
	_steps.append({"t": 13.0, "fn": func() -> void:
		for beh in _level.result.behaviors:
			if beh is PistonBehavior:
				print("[ASSERT] piston_x_mid=%.3f (should be 0.36)" % beh._x)})
	_steps.append({"t": 13.5, "fn": func() -> void:
		_press(KEY_R, false); _press(KEY_F, true); print("[Bot] piston retract")})
	_steps.append({"t": 15.0, "fn": func() -> void:
		_press(KEY_F, false); print("[Bot] piston done. root_pos=", _root_pos())
		for beh in _level.result.behaviors:
			if beh is PistonBehavior:
				print("[ASSERT] piston_x=%.3f (0..0.36)" % beh._x)})
	_steps.append({"t": 15.5, "fn": func() -> void:
		_press(KEY_UP, true); print("[Bot] drive again")})
	_done_t = 18.5


func _press(key: Key, down: bool) -> void:
	if OS.get_cmdline_user_args().has("--real-input"):
		# 走真实输入管道（Input.parse_input_event → _input），验证玩家路径
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.pressed = down
		Input.parse_input_event(ev)
	else:
		_level.keys[key] = down


## 阶段3：武器演示（同一台炮车 + 火箭架，开向靶场开火）
func _setup_sim_phase3() -> void:
	var blocks := [
		{"c": [0, 0, 0], "t": "wood_block", "f": 0},
		{"c": [0, 0, 1], "t": "wood_block", "f": 0},
		{"c": [0, 0, 2], "t": "wood_block", "f": 0},
		{"c": [0, 0, 3], "t": "wood_block", "f": 0},
		{"c": [0, 1, 1], "t": "metal_block", "f": 0},
		{"c": [0, 1, 2], "t": "metal_block", "f": 0},
		{"c": [-1, 0, 1], "t": "wheel", "f": 1, "k": {"spin": [KEY_UP, KEY_DOWN]}},
		{"c": [1, 0, 1], "t": "wheel", "f": 3, "k": {"spin": [KEY_UP, KEY_DOWN]}},
		{"c": [-1, 0, 3], "t": "wheel", "f": 1, "k": {"spin": [KEY_UP, KEY_DOWN]}},
		{"c": [1, 0, 3], "t": "wheel", "f": 3, "k": {"spin": [KEY_UP, KEY_DOWN]}},
		{"c": [0, 2, 2], "t": "cannon", "f": 0, "k": {"fire": [KEY_SPACE]}},
		{"c": [0, 2, 1], "t": "rocket_launcher", "f": 0, "k": {"fire": [KEY_G]}},
		{"c": [0, 1, 3], "t": "blade", "f": 0},
	]
	Game.pending_machine = {"name": "weapon_cart", "version": 1, "blocks": blocks}
	_steps.append({"t": 1.2, "fn": func() -> void:
		_press(KEY_UP, true); print("[Bot] advance to range")})
	_steps.append({"t": 2.6, "fn": func() -> void:
		_press(KEY_UP, false); print("[Bot] in position. root_pos=", _root_pos())})
	_steps.append({"t": 4.0, "fn": func() -> void:
		_press(KEY_SPACE, true)})
	_steps.append({"t": 4.3, "fn": func() -> void:
		_press(KEY_SPACE, false); print("[Bot] cannon shot 1")})
	_steps.append({"t": 5.5, "fn": func() -> void:
		_press(KEY_SPACE, true)})
	_steps.append({"t": 5.8, "fn": func() -> void:
		_press(KEY_SPACE, false); print("[Bot] cannon shot 2")})
	_steps.append({"t": 7.0, "fn": func() -> void:
		_press(KEY_SPACE, true)})
	_steps.append({"t": 7.3, "fn": func() -> void:
		_press(KEY_SPACE, false); print("[Bot] cannon shot 3")})
	_steps.append({"t": 8.5, "fn": func() -> void:
		_press(KEY_G, true)})
	_steps.append({"t": 8.8, "fn": func() -> void:
		_press(KEY_G, false); print("[Bot] rocket away")})
	_steps.append({"t": 10.0, "fn": func() -> void:
		if _level.projectiles:
			print("[ASSERT] projectiles_spawned=%d (expect >= 4)" % _level.projectiles.get_child_count())})
	_steps.append({"t": 11.5, "fn": func() -> void:
		_press(KEY_UP, true); print("[Bot] roll over the rubble")})
	_steps.append({"t": 14.5, "fn": func() -> void:
		_press(KEY_UP, false)})
	_done_t = 16.0


func _root_pos() -> Vector3:
	var rb: RigidBody3D = _level.get("root_body")
	return rb.global_position if rb else Vector3.ZERO


func _physics_process(delta: float) -> void:
	_t += delta
	while _idx < _steps.size() and _t >= float(_steps[_idx].t):
		_steps[_idx].fn.call()
		_idx += 1
	# 相机：环绕机器缓慢旋转（按场景类型分支）
	if mode == "build":
		var bc: BuildCamera = _level.get("cam")
		if bc:
			bc.target = Vector3(0, 0.6, 1.0)
			bc.yaw = -0.8 + _t * 0.22
			bc.pitch = -0.42
			bc.dist = 5.0 if _t < 10.0 else 4.2
			bc.apply()
	else:
		var c: ChaseCamera = _level.get("cam")
		if c:
			c.yaw = -0.8 + _t * 0.2
	if mode == "sim":
		var rb: RigidBody3D = _level.get("root_body")
		if rb:
			_max_y = maxf(_max_y, rb.global_position.y)
		if fmod(_t, 1.0) < delta:
			print("[Bot] t=%.1f root_pos=%s" % [_t, _root_pos()])
	if _t >= _done_t:
		print("[Bot] quit at t=", _t)
		get_tree().quit()
