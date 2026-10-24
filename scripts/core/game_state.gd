extends Node
## 全局单例：场景间传递数据（建造 -> 模拟 -> 建造）。
## 在 project.godot [autoload] 中注册为 "Game"。

var pending_machine: Dictionary = {}
var reverse_forward := false   # 机器前方翻转（建造界面可切换）
var puzzle_mode := false       # 解密关卡模式（建造/模拟场景行为随动）
var level_mode := ""           # "" 沙盒 | "battle" 平原战场
var battle_intent := false     # 车库中高亮"出征战场"
