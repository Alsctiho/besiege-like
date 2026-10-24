class_name JourneyPalette
extends RefCounted
## 风之旅人风格材质：按 glTF 材质名把机器部件映射到 Journey 着色器的暖色变体。
## 用法：JourneyPalette.apply_tree(root_node)（在装配完成后对整台机器调用一次）。

const SHADER := preload("res://shaders/journey.gdshader")

# 材质名 → 暖色调色（按顺序匹配，先长名后短名）
const TINTS := [
	["wood_dark",  Color(0.48, 0.33, 0.22)],
	["wood",       Color(0.78, 0.58, 0.38)],
	["iron_dark",  Color(0.40, 0.35, 0.34)],
	["iron_light", Color(0.78, 0.71, 0.65)],
	["iron",       Color(0.64, 0.57, 0.52)],
	["brass",      Color(0.92, 0.70, 0.38)],
	["red_cloth",  Color(0.82, 0.28, 0.20)],
	["rubber",     Color(0.34, 0.30, 0.29)],
	["canvas",     Color(0.90, 0.76, 0.52)],
]
const FALLBACK := Color(0.85, 0.68, 0.50)

static var _cache := {}


static func _mat_for(key: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tint", _tint_for(key))
	_cache[key] = m
	return m


static func _tint_for(mat_name: String) -> Color:
	var n := mat_name.to_lower()
	for entry in TINTS:
		if n.contains(entry[0]):
			return entry[1]
	return FALLBACK


static func _key_for_mesh(mi: MeshInstance3D) -> String:
	var mesh := mi.mesh
	if mesh == null:
		return ""
	# 用第一个表面的材质名决定整件配色（每个部件的 glb 通常单一材质族）
	for i in range(mesh.get_surface_count()):
		var mat := mi.get_active_material(i)
		if mat and mat.resource_name != "":
			return mat.resource_name
	return ""


## 遍历子树，把所有网格表面套上 Journey 着色器（按原材质名匹配色调）
static func apply_tree(root: Node) -> void:
	if root == null:
		return
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var key := _key_for_mesh(mi)
		var m := _mat_for(key)
		for i in range(mesh.get_surface_count()):
			(mi as MeshInstance3D).set_surface_override_material(i, m)
