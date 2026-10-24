class_name WaterVolume
extends Area3D
## 水域：池内的刚体按浸没比例获得浮力与水阻尼。
## surface_y 为水面世界高度。

var surface_y := 0.0
var buoyancy_factor := 1.6   # 浮力相对重力的倍数（1.6 → 静浮时 ~60% 露出水面）
var water_drag := 1.8

var _bodies := {}


func _ready() -> void:
	body_entered.connect(func(b: Node) -> void:
		if b is RigidBody3D:
			_bodies[b] = true)
	body_exited.connect(func(b: Node) -> void:
		_bodies.erase(b))


func _physics_process(delta: float) -> void:
	for b: RigidBody3D in _bodies.keys():
		if not is_instance_valid(b):
			_bodies.erase(b)
			continue
		# 近似：单格半高 0.25
		var half_h := 0.25
		var bottom := b.global_position.y - half_h
		var submerged: float = clampf((surface_y - bottom) / (half_h * 2.0), 0.0, 1.0)
		if submerged <= 0.0:
			continue
		# 浮力（质量比例简化；带 no_float 标记的方块几乎不下沉扶持）
		var factor := buoyancy_factor
		if b.has_meta("no_float"):
			factor = 0.15
		b.apply_central_force(Vector3.UP * submerged * b.mass * 9.8 * factor)
		# 水阻尼
		b.apply_central_force(-b.linear_velocity * b.mass * water_drag * submerged)
		b.apply_torque(-b.angular_velocity * b.inertia.x * 0.5 * submerged)
