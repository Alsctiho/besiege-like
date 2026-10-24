class_name RocketLauncherBehavior
extends BlockBehavior
## 火箭发射器：触发键发射推进火箭，发射后坐力明显，命中产生爆炸。

const COOLDOWN := 2.5
const RECOIL := 12.0

var muzzle_local := Vector3.ZERO
var dir_local := Vector3(0, 0, -1)
var _cooldown := 0.0


func setup_weapon(chassis_: RigidBody3D, cell_world: Vector3, dir_world: Vector3) -> void:
	chassis = chassis_
	muzzle_local = cell_world - chassis.position
	dir_local = chassis.basis.inverse() * dir_world


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown == 0.0 and trigger("fire") and sim != null and chassis != null:
		_cooldown = COOLDOWN
		_fire()


func _fire() -> void:
	var dir := (chassis.global_basis * dir_local).normalized()
	var muzzle: Vector3 = chassis.to_global(muzzle_local) + dir * 0.45
	sim.spawn_rocket(muzzle, dir)
	sim.play_sfx("rocket", muzzle)
	chassis.apply_impulse(-dir * RECOIL, muzzle - chassis.global_position)
