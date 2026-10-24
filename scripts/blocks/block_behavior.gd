class_name BlockBehavior
extends Node
## 功能组件的模拟态行为基类：读取按键绑定，输出驱动量。
## 由 MachineAssembler 创建并挂到模拟根节点；sim 引用由 SimLevel 注入。

var sim: Node = null          # SimLevel，提供 keys: {physical_key: bool}
var cell := Vector3i.ZERO
var binding := {}             # {action: [pos_key, neg_key]}
var mover: AnimatableBody3D = null
var chassis: RigidBody3D = null


func setup(cell_: Vector3i, binding_: Dictionary) -> void:
	cell = cell_
	binding = binding_


## 连续量：正键 +1 / 负键 -1，都按 0
func axis_value(action: String) -> float:
	var v := 0.0
	var b: Array = binding.get(action, [0, 0])
	if sim and b[0] != 0 and sim.keys.get(b[0], false):
		v += 1.0
	if sim and b[1] != 0 and sim.keys.get(b[1], false):
		v -= 1.0
	return clampf(v, -1.0, 1.0)


## 触发量：本帧正键按住
func trigger(action: String) -> bool:
	var b: Array = binding.get(action, [0, 0])
	return sim != null and b[0] != 0 and sim.keys.get(b[0], false)
