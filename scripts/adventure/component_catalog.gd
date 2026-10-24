class_name JourneyCatalog
extends RefCounted

const FACES: Array[String] = ["front", "back", "left", "right", "top", "bottom"]
const LABELS := {"front": "前", "back": "后", "left": "左", "right": "右", "top": "上", "bottom": "下"}
const KEYS := {"front": "Z", "back": "X", "left": "Q / ←", "right": "E / →", "top": "↑", "bottom": "↓"}
const AXES := {"front": Vector3.FORWARD, "back": Vector3.BACK, "left": Vector3.LEFT, "right": Vector3.RIGHT, "top": Vector3.UP, "bottom": Vector3.DOWN}
const MODELS := "res://assets/adventure/models/"
const DEFINITIONS := {
	"wheel": {"name": "轮足", "icon": "◎", "color": Color("a1b4b1"), "hint": "提供 WASD 基础移动", "model": "mobility.glb"},
	"rotor": {"name": "旋翼", "icon": "✣", "color": Color("a9cec4"), "hint": "沿工作轴产生推力；换朝向可升空或平移", "model": "rotor.glb"},
	"drill": {"name": "钻头", "icon": "◆", "color": Color("b8bac5"), "hint": "持续按住触发键，钻开接触方向的裂岩", "model": "drill.glb"},
	"fireball": {"name": "火球", "icon": "●", "color": Color("efb174"), "hint": "按下触发键发射；可点燃热能机关", "model": "fireball.glb"},
	"blower": {"name": "吹风", "icon": "≋", "color": Color("77c8ca"), "hint": "定向风场推动轻物、改变火球轨迹", "model": "blower.glb"},
	"rod": {"name": "伸缩", "icon": "↔", "color": Color("d6c7a4"), "hint": "按住伸出，松开收回；触碰远程开关", "model": "rod.glb"},
	"booster": {"name": "推进", "icon": "»", "color": Color("dab071"), "hint": "沿工作朝向提供短时强推力", "model": "booster.glb"},
}

static func face_down(face: String) -> bool:
	match face:
		"left": return Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT)
		"right": return Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_RIGHT)
		"top": return Input.is_physical_key_pressed(KEY_UP)
		"bottom": return Input.is_physical_key_pressed(KEY_DOWN)
		"front": return Input.is_physical_key_pressed(KEY_Z)
		"back": return Input.is_physical_key_pressed(KEY_X)
	return false

static func orientation(direction: String) -> Basis:
	return Basis(Quaternion(Vector3.UP, AXES.get(direction, Vector3.UP)))

static func mount_clearance(face: String, direction: String, kind: String) -> float:
	if kind == "wheel": return 0.0
	var alignment: float = AXES[face].dot(AXES[direction])
	if alignment < -0.5: return 0.9
	if alignment < 0.5: return 0.32
	return 0.0
