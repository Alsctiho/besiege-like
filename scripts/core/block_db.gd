class_name BlockDB
## 组件静态数据库：所有可放置组件的定义与查询。
##
## 坐标约定（与 Blender 导出的 .glb 一致）：
## - 组件模型 forward = 自身 -Z（Blender +Y 导出后映射为 Godot -Z），facing 绕 Y 每 90° 一档；
## - 关节类组件（轮/铰链/活塞）的 mount 侧为自身 +Z（背面），forward 侧为可动/工作侧；
## - 轮子自转轴 = 自身 X，铰链/活塞轴 = 自身 X。

const MODEL_DIR := "res://assets/models/components/"

enum Kind { STRUCTURE, WHEEL, HINGE, PISTON, BLADE, CANNON, ROCKET_LAUNCHER, PROPELLER, BUOY, BOOSTER }

# actions: 可绑定按键的动作。analog=true 表示连续量(-1..1)，false 表示触发式。
const DEFS := {
	"wood_block": {
		"name": "木方块", "kind": Kind.STRUCTURE, "cat": "结构",
		"mass": 2.0, "hp": 40.0, "model": MODEL_DIR + "block_wood.glb",
		"actions": [],
	},
	"metal_block": {
		"name": "金属方块", "kind": Kind.STRUCTURE, "cat": "结构",
		"mass": 4.0, "hp": 90.0, "model": MODEL_DIR + "block_metal.glb",
		"actions": [],
	},
	"blade": {
		"name": "尖刺", "kind": Kind.BLADE, "cat": "武器",
		"mass": 2.5, "hp": 50.0, "model": MODEL_DIR + "blade.glb",
		"actions": [],
	},
	"wheel": {
		"name": "马达轮", "kind": Kind.WHEEL, "cat": "运动",
		"mass": 3.0, "hp": 30.0, "model": MODEL_DIR + "wheel.glb",
		"actions": [{"id": "spin", "label": "转动", "analog": true}],
	},
	"hinge": {
		"name": "铰链", "kind": Kind.HINGE, "cat": "运动",
		"mass": 2.0, "hp": 35.0, "model": MODEL_DIR + "hinge.glb",
		"actions": [{"id": "swing", "label": "摆动", "analog": true}],
	},
	"piston": {
		"name": "活塞", "kind": Kind.PISTON, "cat": "运动",
		"mass": 2.5, "hp": 35.0, "model": MODEL_DIR + "piston.glb",
		"actions": [{"id": "extend", "label": "伸缩", "analog": true}],
	},
	"cannon": {
		"name": "火炮", "kind": Kind.CANNON, "cat": "武器",
		"mass": 4.0, "hp": 35.0, "model": MODEL_DIR + "cannon.glb",
		"actions": [{"id": "fire", "label": "开火", "analog": false}],
	},
	"rocket_launcher": {
		"name": "火箭发射器", "kind": Kind.ROCKET_LAUNCHER, "cat": "武器",
		"mass": 3.5, "hp": 30.0, "model": MODEL_DIR + "rocket_launcher.glb",
		"actions": [{"id": "fire", "label": "发射", "analog": false}],
	},
	"propeller": {
		"name": "螺旋桨", "kind": Kind.PROPELLER, "cat": "动力",
		"mass": 2.0, "hp": 25.0, "model": MODEL_DIR + "propeller.glb",
		"actions": [{"id": "throttle", "label": "油门", "analog": true}],
	},
	"buoy": {
		"name": "浮筒", "kind": Kind.BUOY, "cat": "动力",
		"mass": 1.0, "hp": 25.0, "model": MODEL_DIR + "buoy.glb",
		"actions": [],
	},
	"booster": {
		"name": "喷射器", "kind": Kind.BOOSTER, "cat": "动力",
		"mass": 2.5, "hp": 30.0, "model": MODEL_DIR + "booster.glb",
		"actions": [{"id": "throttle", "label": "喷射(长按)", "analog": true}],
	},
}

# 建造面板显示顺序
const PALETTE_ORDER: Array[String] = [
	"wood_block", "metal_block", "blade",
	"wheel", "hinge", "piston",
	"cannon", "rocket_launcher", "propeller", "buoy", "booster",
]

# 新放置组件的默认按键（可随后在绑定面板修改）
const DEFAULT_BINDINGS := {
	"wheel": {"spin": [KEY_UP, KEY_DOWN]},
	"hinge": {"swing": [KEY_Q, KEY_E]},
	"piston": {"extend": [KEY_R, KEY_F]},
	"cannon": {"fire": [KEY_SPACE]},
	"rocket_launcher": {"fire": [KEY_G]},
	"propeller": {"throttle": [KEY_I, KEY_K]},
	"booster": {"throttle": [KEY_U, KEY_J]},
}


static func default_bindings(id: String) -> Dictionary:
	var out := {}
	var raw: Dictionary = DEFAULT_BINDINGS.get(id, {})
	for action in raw:
		out[action] = (raw[action] as Array).duplicate()
	return out


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func model_path(id: String) -> String:
	var def: Dictionary = DEFS.get(id, {})
	return def.get("model", "")


static func display_name(id: String) -> String:
	var def: Dictionary = DEFS.get(id, {})
	return def.get("name", id)
