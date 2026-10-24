class_name EnemyRobot
extends RigidBody3D
## 敌方战斗机器：四轮小机器人。
## - 与玩家保持 8~15m 距离游走，周期性横向扫动
## - 玩家开火时快速侧移躲避
## - 距离内开火攻击玩家（命中使机器散架）
## - 可被撞毁/击毁（3 发）

const MAX_HP := 3
const FIRE_COOLDOWN := 2.8
const FIRE_RANGE := 20.0
const BALL_SPEED := 14.0

var hp := MAX_HP
var player: RigidBody3D
var _barrel: MeshInstance3D
var _wheels: Array = []
var _cooldown := 2.0
var _strafe_dir := 1.0
var _strafe_timer := 2.5
var _dodge_timer := 0.0
var _dodge_burst := 0.0
var _wheel_spin := 0.0
var _flash_mat: StandardMaterial3D


static func create(pos: Vector3, player_: RigidBody3D) -> EnemyRobot:
	var r := EnemyRobot.new()
	r.name = "EnemyRobot"
	r.position = pos
	r.mass = 5.0
	r.can_sleep = false
	r.contact_monitor = true
	r.max_contacts_reported = 4
	r.add_to_group("enemy")
	r.player = player_

	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	r.physics_material_override = pm

	# 车体
	var body := BoxMesh.new()
	body.size = Vector3(0.7, 0.35, 0.95)
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = body
	body_mi.position = Vector3(0, 0.25, 0)
	r.add_child(body_mi)
	# 驾驶舱
	var cab := BoxMesh.new()
	cab.size = Vector3(0.5, 0.3, 0.5)
	var cab_mi := MeshInstance3D.new()
	cab_mi.mesh = cab
	cab_mi.position = Vector3(0, 0.55, 0.08)
	r.add_child(cab_mi)
	# 炮管
	var gun := CylinderMesh.new()
	gun.top_radius = 0.045
	gun.bottom_radius = 0.045
	gun.height = 0.55
	var gun_mi := MeshInstance3D.new()
	gun_mi.mesh = gun
	gun_mi.rotation.x = 1.35
	gun_mi.position = Vector3(0, 0.55, -0.3)
	r.add_child(gun_mi)
	r._barrel = gun_mi
	# 红眼
	var eye := OmniLight3D.new()
	eye.light_color = Color(1.0, 0.22, 0.12)
	eye.light_energy = 1.4
	eye.omni_range = 3.5
	eye.position = Vector3(0, 0.6, -0.15)
	r.add_child(eye)
	# 四轮（视觉，随速度自转）
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var w := CylinderMesh.new()
			w.top_radius = 0.18
			w.bottom_radius = 0.18
			w.height = 0.1
			var wmi := MeshInstance3D.new()
			wmi.mesh = w
			wmi.rotation.z = 1.5708
			wmi.position = Vector3(sx * 0.38, 0.0, sz * 0.34)
			r.add_child(wmi)
			r._wheels.append(wmi)
	# 碰撞体
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.95, 0.55, 1.15)
	cs.shape = sh
	cs.position = Vector3(0, 0.25, 0)
	r.add_child(cs)
	return r


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = Color(1.0, 0.4, 0.3)
	_flash_mat.emission_enabled = true
	_flash_mat.emission = Color(1.0, 0.3, 0.2)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_p: Vector3 = player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var fwd := to_p.normalized() if dist > 0.05 else Vector3(0, 0, -1)
	var right := Vector3(fwd.z, 0, -fwd.x)  # 横向

	# 朝向玩家
	rotation.y = lerp_angle(rotation.y, atan2(fwd.x, fwd.z) + PI, 4.0 * delta)

	# 计时器
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(2.0, 4.0)
		_strafe_dir = -_strafe_dir
	_dodge_timer -= delta
	if _dodge_timer <= 0.0 and dist < FIRE_RANGE:
		_dodge_timer = randf_range(3.0, 5.5)
		_dodge_burst = 0.7  # 闪避冲刺
		_strafe_dir = -_strafe_dir

	# 期望速度：保持距离 + 横向扫动 + 闪避冲刺
	var desired := Vector3.ZERO
	if dist < 8.0:
		desired -= fwd * 4.5  # 太近：后退
	elif dist > 15.0:
		desired += fwd * 4.0  # 太远：逼近
	desired += right * 2.6 * _strafe_dir
	if _dodge_burst > 0.0:
		desired += right * 7.0 * _strafe_dir
		_dodge_burst -= delta
	desired.y = linear_velocity.y  # 保留竖直（重力）
	linear_velocity = linear_velocity.lerp(desired, minf(4.0 * delta, 1.0))

	# 轮子自转
	var ground_speed := Vector3(linear_velocity.x, 0, linear_velocity.z).length()
	_wheel_spin += ground_speed / 0.18 * delta
	for w in _wheels:
		w.rotation.x = _wheel_spin

	# 开火
	_cooldown -= delta
	if _cooldown <= 0.0 and dist < FIRE_RANGE:
		_cooldown = FIRE_COOLDOWN + randf_range(-0.4, 0.6)
		_fire_at(player.global_position + Vector3.UP * 0.25)


func _fire_at(target: Vector3) -> void:
	var lvl := get_tree().current_scene
	if lvl == null or not lvl.has_method("spawn_hostile_ball"):
		return
	var muzzle: Vector3 = global_position + Vector3(0, 0.55, 0)
	var lead: Vector3 = Vector3.ZERO
	if player and is_instance_valid(player):
		lead = player.linear_velocity * 0.25
	var dir := (target + lead - muzzle).normalized()
	var spread := Vector3(randf_range(-0.05, 0.05), randf_range(-0.03, 0.03), randf_range(-0.05, 0.05))
	lvl.spawn_hostile_ball(muzzle, (dir + spread).normalized(), BALL_SPEED)
	if lvl.has_method("play_sfx"):
		lvl.play_sfx("cannon", muzzle)


## 玩家开火时的躲避信号（SimLevel.player_fired 连接）
func on_player_fired(pos: Vector3) -> void:
	if global_position.distance_to(pos) < 16.0:
		_dodge_timer = minf(_dodge_timer, 0.1)  # 立刻触发闪避冲刺
		_strafe_dir = -_strafe_dir


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("machine") and linear_velocity.length() > 3.0:
		take_damage(1)


func take_damage(n: int) -> void:
	hp -= n
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector3(1.12, 1.12, 1.12), 0.06)
	pop.tween_property(self, "scale", Vector3.ONE, 0.08)
	if hp <= 0:
		var lvl := get_tree().current_scene
		if lvl:
			Explosion.boom(lvl, global_position + Vector3.UP * 0.3, 1.6, 10.0)
		queue_free()
