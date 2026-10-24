class_name Presets
extends RefCounted
## 示例机器模板（均为实测可用的布局），供车库界面选择。
## 布局约定：桨叶半径 0.45m，相邻螺旋桨至少间隔 2 格（1m）避免桨叶重叠。

const ASSAULT_CART := {
	"name": "一号机·突击车", "version": 1, "blocks": [
		{"c": [0, 0, 0], "t": "wood_block", "f": 0},
		{"c": [1, 0, 0], "t": "wood_block", "f": 0},
		{"c": [0, 0, 1], "t": "wood_block", "f": 0},
		{"c": [1, 0, 1], "t": "wood_block", "f": 0},
		{"c": [0, 1, 1], "t": "metal_block", "f": 0},
		{"c": [1, 1, 1], "t": "metal_block", "f": 0},
		{"c": [0, 2, 1], "t": "cannon", "f": 0, "k": {"fire": [32]}},
		{"c": [1, 2, 1], "t": "rocket_launcher", "f": 0, "k": {"fire": [71]}},
		{"c": [0, 0, -1], "t": "blade", "f": 0},
		{"c": [-1, 0, 1], "t": "wheel", "f": 1, "k": {"spin": [4194320, 4194322]}},
		{"c": [2, 0, 1], "t": "wheel", "f": 3, "k": {"spin": [4194320, 4194322]}},
		{"c": [-1, 0, 3], "t": "wheel", "f": 1, "k": {"spin": [4194320, 4194322]}},
		{"c": [2, 0, 3], "t": "wheel", "f": 3, "k": {"spin": [4194320, 4194322]}},
	],
}

## 飞行器 v2：3×3 机身，四角上推桨（间隔 2 格，桨叶不重叠），中央前进桨
const FLYER := {
	"name": "飞行器", "version": 1, "blocks": [
		{"c": [0, 0, 0], "t": "wood_block", "f": 0},
		{"c": [1, 0, 0], "t": "wood_block", "f": 0},
		{"c": [2, 0, 0], "t": "wood_block", "f": 0},
		{"c": [0, 0, 1], "t": "wood_block", "f": 0},
		{"c": [1, 0, 1], "t": "wood_block", "f": 0},
		{"c": [2, 0, 1], "t": "wood_block", "f": 0},
		{"c": [0, 0, 2], "t": "wood_block", "f": 0},
		{"c": [1, 0, 2], "t": "wood_block", "f": 0},
		{"c": [2, 0, 2], "t": "wood_block", "f": 0},
		{"c": [0, 1, 0], "t": "propeller", "f": 4, "k": {"throttle": [73, 75]}},
		{"c": [2, 1, 0], "t": "propeller", "f": 4, "k": {"throttle": [73, 75]}},
		{"c": [0, 1, 2], "t": "propeller", "f": 4, "k": {"throttle": [73, 75]}},
		{"c": [2, 1, 2], "t": "propeller", "f": 4, "k": {"throttle": [73, 75]}},
		{"c": [1, 1, 1], "t": "propeller", "f": 0, "k": {"throttle": [73, 75]}},
		{"c": [0, 0, 3], "t": "buoy", "f": 0},
		{"c": [2, 0, 3], "t": "buoy", "f": 0},
	],
}

## 二号机·巨型战车：4×4 底盘、六轮、双炮双火箭、撞角、四桨升空（陆海空全能）
const MEGA := {
	"name": "二号机·巨型战车", "version": 1, "blocks": [
		# 底盘 4×4 木板 (x 0..3, z 0..3)
		{"c": [0, 0, 0], "t": "wood_block", "f": 0},
		{"c": [1, 0, 0], "t": "wood_block", "f": 0},
		{"c": [2, 0, 0], "t": "wood_block", "f": 0},
		{"c": [3, 0, 0], "t": "wood_block", "f": 0},
		{"c": [0, 0, 1], "t": "wood_block", "f": 0},
		{"c": [1, 0, 1], "t": "wood_block", "f": 0},
		{"c": [2, 0, 1], "t": "wood_block", "f": 0},
		{"c": [3, 0, 1], "t": "wood_block", "f": 0},
		{"c": [0, 0, 2], "t": "wood_block", "f": 0},
		{"c": [1, 0, 2], "t": "wood_block", "f": 0},
		{"c": [2, 0, 2], "t": "wood_block", "f": 0},
		{"c": [3, 0, 2], "t": "wood_block", "f": 0},
		{"c": [0, 0, 3], "t": "wood_block", "f": 0},
		{"c": [1, 0, 3], "t": "wood_block", "f": 0},
		{"c": [2, 0, 3], "t": "wood_block", "f": 0},
		{"c": [3, 0, 3], "t": "wood_block", "f": 0},
		{"c": [0, 0, 4], "t": "wood_block", "f": 0},
		{"c": [1, 0, 4], "t": "wood_block", "f": 0},
		{"c": [2, 0, 4], "t": "wood_block", "f": 0},
		{"c": [3, 0, 4], "t": "wood_block", "f": 0},
		# 前排装甲 (z=0) + 后排装甲 (z=3)，承托武器/螺旋桨
		{"c": [0, 1, 0], "t": "metal_block", "f": 0},
		{"c": [1, 1, 0], "t": "metal_block", "f": 0},
		{"c": [2, 1, 0], "t": "metal_block", "f": 0},
		{"c": [3, 1, 0], "t": "metal_block", "f": 0},
		{"c": [0, 1, 4], "t": "metal_block", "f": 0},
		{"c": [1, 1, 4], "t": "metal_block", "f": 0},
		{"c": [2, 1, 4], "t": "metal_block", "f": 0},
		{"c": [3, 1, 4], "t": "metal_block", "f": 0},
		# 前火力：双炮 + 双火箭（朝前 -Z）
		{"c": [0, 2, 0], "t": "cannon", "f": 0},
		{"c": [1, 2, 0], "t": "cannon", "f": 0},
		{"c": [2, 2, 0], "t": "rocket_launcher", "f": 0},
		{"c": [3, 2, 0], "t": "rocket_launcher", "f": 0},
		# 后排升空桨 ×2（间隔 2 格）
		{"c": [0, 2, 4], "t": "propeller", "f": 4, "k": {"throttle": [73, 75]}},
		{"c": [3, 2, 4], "t": "propeller", "f": 4, "k": {"throttle": [73, 75]}},
		# 撞角：车头双尖刺
		{"c": [1, 0, -1], "t": "blade", "f": 0},
		{"c": [2, 0, -1], "t": "blade", "f": 0},
		# 六轮：左右各三，轮距 2 格（1m，轮径 0.9m 不重叠）
		{"c": [-1, 0, 0], "t": "wheel", "f": 1},
		{"c": [4, 0, 0], "t": "wheel", "f": 3},
		{"c": [-1, 0, 2], "t": "wheel", "f": 1},
		{"c": [4, 0, 2], "t": "wheel", "f": 3},
		{"c": [-1, 0, 4], "t": "wheel", "f": 1},
		{"c": [4, 0, 4], "t": "wheel", "f": 3},
		# 浮筒：车尾
		{"c": [1, 1, 5], "t": "buoy", "f": 0},
		{"c": [2, 1, 5], "t": "buoy", "f": 0},
	],
}

const ALL := {
	"一号机·突击车": ASSAULT_CART,
	"飞行器": FLYER,
	"二号机·巨型战车": MEGA,
}


static func get_preset(name: String) -> Dictionary:
	return ALL.get(name, {})
