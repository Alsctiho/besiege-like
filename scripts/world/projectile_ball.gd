class_name ProjectileBall
extends RigidBody3D
## 火炮实心弹丸：直线飞行，撞击靠物理碰撞自然传递冲量，5 秒后消失。
## hostile = 敌方弹丸：命中玩家机器时造成散架伤害，且不再 friendly 弹跳。

var hostile := false


static func create(pos: Vector3, dir: Vector3, speed: float, hostile_ := false) -> ProjectileBall:
	var b := ProjectileBall.new()
	b.mass = 1.5
	b.can_sleep = false
	b.contact_monitor = true
	b.max_contacts_reported = 4
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.1
	cs.shape = sh
	b.add_child(cs)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.17)
	mat.metallic = 0.8
	mat.roughness = 0.4
	sphere.material = mat
	mesh.mesh = sphere
	b.add_child(mesh)
	b.global_position = pos
	b.linear_velocity = dir * speed
	b.hostile = hostile_
	if hostile_:
		b.mass = 0.4
		b.gravity_scale = 0.0  # 直线弹道
		var m := b.get_node("Mesh") as MeshInstance3D
		if m and m.mesh:
			(m.mesh as SphereMesh).radius = 0.09
			(m.mesh as SphereMesh).height = 0.18
	return b


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _on_body_entered(body: Node) -> void:
	if not hostile:
		if body != null and body.has_method("take_damage"):
			body.take_damage(1)
		return
	# 敌对弹丸：命中机器 → 散架伤害
	if body != null and body.is_in_group("machine"):
		var lvl := get_tree().current_scene
		if lvl and lvl.has_method("damage_machine_block"):
			lvl.damage_machine_block(body, global_position, 1)
	queue_free()
