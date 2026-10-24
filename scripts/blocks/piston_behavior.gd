class_name PistonBehavior
extends BlockBehavior
## 活塞：推杆沿组件 forward 滑动 0..STROKE（运动学），速度可控。

const STROKE := 0.36
const EXTEND_SPEED := 0.9

var _rest_pos: Vector3
var _rest_basis: Basis
var _x := 0.0
var _ready_done := false


func setup_piston(mover_: AnimatableBody3D) -> void:
	mover = mover_
	_rest_pos = mover.position
	_rest_basis = mover.basis
	call_deferred("_capture_rest")


func _capture_rest() -> void:
	_rest_pos = mover.position
	_rest_basis = mover.basis
	_ready_done = true


func _physics_process(delta: float) -> void:
	if mover == null or not _ready_done:
		return
	var v := axis_value("extend")
	_x = clampf(_x + v * EXTEND_SPEED * delta, 0.0, STROKE)
	mover.position = _rest_pos + _rest_basis * (Vector3(0, 0, -1) * _x)
