class_name JourneyRockCollapse
extends Node3D

var pieces: Array[RigidBody3D] = []
var elapsed := 0.0

func build(size_value: Vector3, material: Material, impact_direction: Vector3) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 8719
	var cell := size_value / Vector3(8, 3, 1)
	for row in range(3):
		for column in range(8):
			var body := RigidBody3D.new()
			body.name = "RockShard_%d_%d" % [row, column]
			body.mass = 0.45
			body.collision_layer = 0
			body.collision_mask = 1
			body.linear_damp = 0.4
			body.angular_damp = 0.6
			add_child(body)
			body.position = Vector3((column + 0.5) * cell.x - size_value.x / 2, (row + 0.5) * cell.y - size_value.y / 2, 0)
			var mesh := MeshInstance3D.new()
			var geometry := BoxMesh.new()
			geometry.size = cell * Vector3(0.95, 0.96, random.randf_range(0.75, 1.0))
			mesh.mesh = geometry
			mesh.material_override = material
			body.add_child(mesh)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = geometry.size
			collision.shape = shape
			body.add_child(collision)
			var outward := Vector3(body.position.x * 0.2, random.randf_range(0.3, 1.2), random.randf_range(-0.8, 0.8))
			body.linear_velocity = impact_direction.normalized() * random.randf_range(1.0, 2.2) + outward
			body.angular_velocity = Vector3(random.randf_range(-4, 4), random.randf_range(-4, 4), random.randf_range(-4, 4))
			pieces.append(body)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 1.8:
		var remaining := clampf((3.0 - elapsed) / 1.2, 0.01, 1.0)
		for piece: RigidBody3D in pieces:
			if is_instance_valid(piece): piece.get_child(0).scale = Vector3.ONE * remaining
	if elapsed >= 3.0: queue_free()
