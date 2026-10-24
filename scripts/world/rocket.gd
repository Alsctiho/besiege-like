class_name Rocket
extends RigidBody3D
## 推进火箭：发射后持续推力 1.2s，接触即爆炸（径向冲量+粒子），6 秒自毁。

const THRUST_TIME := 1.2
const THRUST := 55.0
const LIFETIME := 6.0

var _dir := Vector3.ZERO
var _age := 0.0
var _exploded := false


static func create(pos: Vector3, dir: Vector3) -> Rocket:
	var r := Rocket.new()
	r.mass = 0.8
	r.can_sleep = false
	r._dir = dir.normalized()
	r.contact_monitor = true
	r.max_contacts_reported = 4
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.09
	cs.shape = sh
	r.add_child(cs)
	var ps: PackedScene = load("res://assets/models/components/rocket.glb")
	if ps:
		var vis: Node3D = ps.instantiate()
		r.add_child(vis)
		orient_visual(vis, r._dir)
	r.position = pos
	return r


## 模型朝向 -Z 转到 dir（纯数学，不依赖节点入树）
static func orient_visual(vis: Node3D, dir: Vector3) -> void:
	var z_axis := -dir
	var x_axis := Vector3.UP.cross(z_axis)
	if x_axis.length() < 0.01:
		x_axis = Vector3(1, 0, 0)
	x_axis = x_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	vis.basis = Basis(x_axis, y_axis, z_axis)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(LIFETIME)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			_explode())


func _physics_process(delta: float) -> void:
	_age += delta
	if _age < THRUST_TIME:
		apply_central_force(_dir * THRUST)
		# 保持朝向飞行方向
		if linear_velocity.length() > 1.0:
			var vd := linear_velocity.normalized()
			if absf(vd.dot(Vector3.UP)) < 0.99:
				var xx := Vector3.UP.cross(vd).normalized()
				var yy := vd.cross(xx)
				global_basis = Basis(xx, yy, vd)


func _on_body_entered(_body: Node) -> void:
	if not _exploded:
		_explode()


func _explode() -> void:
	_exploded = true
	var parent := get_tree().current_scene
	Explosion.boom(parent if parent else get_parent(), global_position, 2.2, 26.0)
	queue_free()
