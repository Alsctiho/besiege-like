class_name EnemyTurret
extends RigidBody3D
## 敌方炮台小怪：铸铁小机器人，玩家靠近时发射敌对弹丸攻击机器。
## 可被撞击（高速碰撞）或武器击毁。

var hp := 3
var player_root: RigidBody3D = null
var _cooldown := 0.0
var _barrel: MeshInstance3D


static func create(pos: Vector3, player: RigidBody3D) -> EnemyTurret:
	var t := EnemyTurret.new()
	t.name = "EnemyTurret"
	t.position = pos
	t.mass = 4.0
	t.can_sleep = false
	t.contact_monitor = true
	t.max_contacts_reported = 4
	t.add_to_group("enemy")
	t.player_root = player

	var base := BoxMesh.new()
	base.size = Vector3(0.6, 0.35, 0.6)
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	base_mi.position = Vector3(0, 0.05, 0)
	t.add_child(base_mi)
	var head := BoxMesh.new()
	head.size = Vector3(0.45, 0.35, 0.45)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = head
	head_mi.position = Vector3(0, 0.42, 0)
	t.add_child(head_mi)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.05
	barrel.bottom_radius = 0.05
	barrel.height = 0.5
	var barrel_mi := MeshInstance3D.new()
	barrel_mi.mesh = barrel
	barrel_mi.rotation.x = 1.2
	barrel_mi.position = Vector3(0, 0.5, -0.25)
	t._barrel = barrel_mi
	t.add_child(barrel_mi)
	var eye := OmniLight3D.new()
	eye.light_color = Color(1.0, 0.25, 0.15)
	eye.light_energy = 1.2
	eye.omni_range = 3.0
	eye.position = Vector3(0, 0.55, 0)
	t.add_child(eye)

	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.6, 0.9, 0.6)
	cs.shape = sh
	cs.position = Vector3(0, 0.35, 0)
	t.add_child(cs)
	return t


func _ready() -> void:
	contact_monitor = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if player_root == null or not is_instance_valid(player_root):
		return
	var to_player: Vector3 = player_root.global_position - global_position
	var dist := to_player.length()
	if dist > 18.0:
		return
	# 炮管指向玩家
	var dir := to_player.normalized()
	_barrel.look_at_from_position(_barrel.position, _barrel.position + dir, Vector3.UP)
	if _cooldown == 0.0:
		_cooldown = 2.6 + randf() * 0.8
		var lvl := get_tree().current_scene
		if lvl and lvl.has_method("spawn_hostile_ball"):
			var muzzle: Vector3 = global_position + Vector3(0, 0.5, 0) + dir * 0.5
			var spread := Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.06), randf_range(-0.06, 0.06))
			lvl.spawn_hostile_ball(muzzle, (dir + spread).normalized(), 15.0)
			if lvl.has_method("play_sfx"):
				lvl.play_sfx("cannon", muzzle)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("machine") and linear_velocity.length() > 3.5:
		take_damage(1)
		var lvl := get_tree().current_scene
		if lvl and lvl.has_method("damage_machine_block"):
			lvl.damage_machine_block(body, global_position, 1)


func take_damage(n: int) -> void:
	hp -= n
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.06)
	pop.tween_property(self, "scale", Vector3.ONE, 0.08)
	if hp <= 0:
		var lvl := get_tree().current_scene
		if lvl:
			Explosion.boom(lvl, global_position + Vector3.UP * 0.4, 1.6, 9.0)
		queue_free()
