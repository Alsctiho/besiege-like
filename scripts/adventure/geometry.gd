class_name JourneyGeometry
extends RefCounted

static func material(color: Color, metallic := 0.0, glow := 0.0) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.78
	value.metallic = metallic
	if glow > 0.0:
		value.emission_enabled = true
		value.emission = color
		value.emission_energy_multiplier = glow
	return value

static func box(parent: Node3D, location: Vector3, size: Vector3, mat: Material, solid := false) -> Node3D:
	var value: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(value)
	value.position = location
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	value.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var geometry := BoxShape3D.new()
		geometry.size = size
		collision.shape = geometry
		value.add_child(collision)
	return value

static func cylinder(parent: Node3D, location: Vector3, radius: float, height: float, mat: Material, segments := 12) -> MeshInstance3D:
	var value := MeshInstance3D.new()
	var geometry := CylinderMesh.new()
	geometry.top_radius = radius
	geometry.bottom_radius = radius
	geometry.height = height
	geometry.radial_segments = segments
	value.mesh = geometry
	value.material_override = mat
	parent.add_child(value)
	value.position = location
	return value

static func ring(parent: Node3D, location: Vector3, radius: float, thickness: float, depth: float, mat: Material, segments := 48) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = location
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		var size := Vector3(radius * TAU / float(segments) * 1.03, thickness, depth)
		var block := box(root, Vector3(sin(angle), cos(angle), 0) * radius, size, mat)
		block.rotation.z = -angle
	return root

static func model(kind: String) -> Node3D:
	var filename := "core.glb" if kind == "core" else str(JourneyCatalog.DEFINITIONS[kind].model)
	var packed := load(JourneyCatalog.MODELS + filename) as PackedScene
	var instance: Node3D = packed.instantiate() as Node3D if packed != null else Node3D.new()
	if kind == "core":
		var wrapper := Node3D.new()
		wrapper.add_child(instance)
		instance.rotation.y = PI
		return wrapper
	return instance

static func mounted_module(kind: String, face: String, direction: String) -> Node3D:
	var mount := Node3D.new()
	mount.position = JourneyCatalog.AXES[face] * 0.526
	var component := model(kind)
	mount.add_child(component)
	var clearance := JourneyCatalog.mount_clearance(face, direction, kind)
	component.position = JourneyCatalog.AXES[face] * clearance
	if kind != "wheel": component.basis = JourneyCatalog.orientation(direction)
	if clearance > 0:
		var arm := cylinder(mount, JourneyCatalog.AXES[face] * clearance / 2, 0.065, clearance, material(Color("89948f"), 0.5), 8)
		arm.basis = orientation_for_normal(JourneyCatalog.AXES[face])
	return mount

static func orientation_for_normal(axis: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, axis))
