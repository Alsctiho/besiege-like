class_name WheelBehavior
extends BlockBehavior
## 马达轮：轮子 = HingeJoint3D 铰接在底盘上的独立刚体，关节马达驱动。
## 已实测：impulse 30 + 摩擦 1.0 时驱动正常且不翘头（抬头力矩 < 自重恢复力矩）。
## 镜像安装的轮（轴反向）马达符号自动取反，同一按键下合力一致。

const MAX_SPEED := 10.0
const MOTOR_IMPULSE := 30.0

var joint: HingeJoint3D
var fwd_dir := Vector3.RIGHT
var _motor_sign := 1.0


func setup_wheel(joint_: HingeJoint3D, body: RigidBody3D, chassis_: RigidBody3D,
		cell: Vector3i, binding: Dictionary, axle: Vector3) -> void:
	joint = joint_
	setup(cell, binding)
	fwd_dir = axle.normalized()
	var a := axle.normalized()
	# 镜像轴规范化：让左右两侧的轮在同一按键下朝同一方向滚
	_motor_sign = -1.0 if (a.x > 0.0 or (absf(a.x) < 0.001 and a.z > 0.0)) else 1.0


## 按 ↑ 时机器的推进方向（水平，供方向箭头显示）
func roll_direction() -> Vector3:
	return -(fwd_dir.cross(Vector3.UP)) * _motor_sign


func _physics_process(delta: float) -> void:
	if joint == null or not is_instance_valid(joint):
		return
	var v := axis_value("spin")
	if sim and sim.reverse_forward:
		v = -v
	var moving := absf(v) > 0.01
	# 只在驱动时开马达；怠速自由滑行（落地时锁轮会导致翻滚偏斜）
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, moving)
	if moving:
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -_motor_sign * v * MAX_SPEED)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, MOTOR_IMPULSE)
