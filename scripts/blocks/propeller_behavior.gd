class_name PropellerBehavior
extends BlockBehavior
## 螺旋桨：油门按键沿组件 forward 施加推力到底盘。
## 推力 = 底盘重量 × 1.35 / 底盘桨数（装配器写入 meta），任意构型推重比一致。

const MAX_THROTTLE_SPEED := 9.0
const TWR := 1.35

var dir_local := Vector3(0, 0, -1)
var _power := 60.0
var _visual: Node3D = null
var _visual_rest := Basis()
var _spin := 0.0


func setup_propeller(chassis_: RigidBody3D, cell_world: Vector3, dir_world: Vector3,
		visual: Node3D) -> void:
	chassis = chassis_
	dir_local = chassis.basis.inverse() * dir_world
	_power = clampf(chassis.mass * 9.8 * TWR / maxf(float(chassis.get_meta("prop_count", 1)), 1.0),
		10.0, 400.0)
	_visual = visual
	if _visual:
		_visual_rest = _visual.basis


func _physics_process(delta: float) -> void:
	if chassis == null:
		return
	var v := axis_value("throttle")
	if absf(v) < 0.01:
		return
	var dir := (chassis.global_basis * dir_local).normalized()
	# 顺桨方向速度达到上限后停止加力
	if chassis.linear_velocity.dot(dir) < MAX_THROTTLE_SPEED:
		chassis.apply_central_force(dir * v * _power)
	if _visual:
		_spin += v * 20.0 * delta
		# 桨叶建模在网格 XZ 面（轴 = 局部 Y），在建模旋转基础上叠加自转
		_visual.basis = _visual_rest * Basis(Vector3(0, 1, 0), _spin)
