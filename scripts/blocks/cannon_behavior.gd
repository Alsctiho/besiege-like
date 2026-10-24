class_name CannonBehavior
extends BlockBehavior
## 火炮：触发键发射实心弹丸，对底盘施加后坐力冲量，带冷却。
## 炮是刚性块（无可动部分），炮口位置/朝向存于底盘局部坐标。

const COOLDOWN := 1.2
const BALL_SPEED := 28.0
const RECOIL := 9.0

var muzzle_local := Vector3.ZERO
var dir_local := Vector3(0, 0, -1)
var _cooldown := 0.0


func setup_weapon(chassis_: RigidBody3D, cell_world: Vector3, dir_world: Vector3) -> void:
	chassis = chassis_
	muzzle_local = cell_world - chassis.position
	dir_local = chassis.basis.inverse() * dir_world


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if Engine.get_physics_frames() % 60 == 0:
		var b: Array = binding.get("fire", [0, 0])
		print("[CannonDbg] binding=", binding, " space=", sim.keys.get(32, false) if sim else "no-sim",
			" chassis=", chassis != null)
	if _cooldown == 0.0 and trigger("fire") and sim != null and chassis != null:
		_cooldown = COOLDOWN
		_fire()


func _fire() -> void:
	var dir := (chassis.global_basis * dir_local).normalized()
	var muzzle: Vector3 = chassis.to_global(muzzle_local) + dir * 0.55
	sim.spawn_cannon_ball(muzzle, dir, BALL_SPEED)
	sim.play_sfx("cannon", muzzle)
	# 后坐力：反向冲量打在炮口位置（带力矩）
	chassis.apply_impulse(-dir * RECOIL, muzzle - chassis.global_position)
