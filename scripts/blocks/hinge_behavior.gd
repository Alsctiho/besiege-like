class_name HingeBehavior
extends BlockBehavior
## 铰链：运动学摇臂绕自身局部 X 轴（世界方向由朝向决定）旋转，速度可控。

const MAX_SPEED := 3.0

var _rest_basis: Basis
var _theta := 0.0
var _ready_done := false


func setup_hinge(mover_: AnimatableBody3D) -> void:
	mover = mover_
	_rest_basis = mover.basis
	call_deferred("_capture_rest")


func _capture_rest() -> void:
	_rest_basis = mover.basis
	_ready_done = true


func _physics_process(delta: float) -> void:
	if mover == null or not _ready_done:
		return
	var v := axis_value("swing")
	if absf(v) > 0.01:
		_theta = wrapf(_theta + v * MAX_SPEED * delta, -PI, PI)
	mover.basis = Basis(_rest_basis.x, _theta) * _rest_basis
