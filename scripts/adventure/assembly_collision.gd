extends RefCounted

static var _mesh_shapes: Dictionary = {}
static var _rotor_shapes: Dictionary = {}

static func parts(module: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in module.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var rotor := mesh.get_parent() as Node3D
		if rotor != null and rotor.name == "Rotor":
			var swept := _rotor_envelope(mesh)
			result.append({"shape":swept.shape, "transform":rotor.global_transform * swept.transform})
		else:
			if not _mesh_shapes.has(mesh.mesh):
				_mesh_shapes[mesh.mesh] = mesh.mesh.create_convex_shape()
			var shape := _mesh_shapes[mesh.mesh] as Shape3D
			if shape != null:
				result.append({"shape":shape, "transform":mesh.global_transform})
	return result

static func _rotor_envelope(mesh: MeshInstance3D) -> Dictionary:
	var key := [mesh.mesh, mesh.transform]
	if _rotor_shapes.has(key): return _rotor_shapes[key]
	var radius := 0.0
	var bottom := INF
	var top := -INF
	for vertex: Vector3 in mesh.mesh.get_faces():
		var point: Vector3 = mesh.transform * vertex
		radius = maxf(radius, Vector2(point.x, point.z).length())
		bottom = minf(bottom, point.y)
		top = maxf(top, point.y)
	var shape := CylinderShape3D.new()
	shape.radius = maxf(radius, 0.01)
	shape.height = maxf(top - bottom, 0.01)
	var envelope := {"shape":shape, "transform":Transform3D(Basis.IDENTITY, Vector3(0, (top + bottom) * 0.5, 0))}
	_rotor_shapes[key] = envelope
	return envelope

static func intersects(first: Array[Dictionary], second: Array[Dictionary]) -> bool:
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(body, space)
	PhysicsServer3D.body_set_collision_layer(body, 1)
	for part: Dictionary in second:
		PhysicsServer3D.body_add_shape(body, (part.shape as Shape3D).get_rid(), part.transform)
	var state := PhysicsServer3D.space_get_direct_state(space)
	var overlap := false
	for part: Dictionary in first:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = part.shape
		query.transform = part.transform
		query.margin = 0.001
		query.collision_mask = 1
		if not state.intersect_shape(query, 1).is_empty():
			overlap = true
			break
	PhysicsServer3D.free_rid(body)
	PhysicsServer3D.free_rid(space)
	return overlap
