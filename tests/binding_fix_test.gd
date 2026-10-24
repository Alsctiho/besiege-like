extends SceneTree
## 验证：JSON 载入后按键码必须是 int；未绑定的组件自动获得默认按键。
## godot --headless --path . --script res://tests/binding_fix_test.gd

func _initialize() -> void:
	var m: Node3D = load("res://scripts/core/machine.gd").new()
	var err: int = SaveManager.load_machine(m, "war_flyer")
	print("[T] load err=", err)
	var has_bindings := false
	var all_int := true
	for cell in m.grid:
		var d: Dictionary = m.grid[cell]
		if not d.k.is_empty():
			has_bindings = true
			for action in d.k:
				var arr: Array = d.k[action]
				var t := typeof(arr[0])
				if t != TYPE_INT:
					all_int = false
				print("[T] ", cell, " ", action, " b0=", arr[0], " type=", t,
					" (2=INT ok, 3=FLOAT bad)")
	print("[T] has_bindings=", has_bindings, " all_int=", all_int)
	var placed: bool = m.add_block(Vector3i(3, 0, 2), "wheel", 1)
	var bind: Dictionary = m.get_binding(Vector3i(3, 0, 2))
	print("[T] default_bind=", bind, " placed=", placed,
		" spin_pos_is_up=", bind.get("spin", [0])[0] == KEY_UP)
	quit()
