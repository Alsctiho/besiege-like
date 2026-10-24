class_name BuildLevel
extends Node3D
## 建造模式关卡：网格放置/旋转/删除/撤销，幽灵预览，录制 Bot 接入。

const GHOST_OK := Color(0.45, 1.0, 0.5, 0.45)
const GHOST_BAD := Color(1.0, 0.35, 0.3, 0.5)

@onready var machine: Machine = $Machine
@onready var cam: BuildCamera = $BuildCamera
@onready var ui: BuildUI = $UI

var selected := ""          # 当前选择的组件 id，""=未选择
var facing := 0
var bot_mode := false

var _ghost: Node3D = null
var _ghost_cell := Vector3i.ZERO
var _ghost_valid := false
var _undo_stack: Array = []
var _mat_ok := StandardMaterial3D.new()
var _mat_bad := StandardMaterial3D.new()


func _ready() -> void:
	_init_mats()
	ui.setup(self)
	# 从模拟模式返回：恢复出发前的机器
	if not Game.pending_machine.is_empty():
		machine.deserialize(Game.pending_machine)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--record-bot"):
			var bot_phase := int(a.get_slice("=", 1)) if "=" in a else 1
			if bot_phase == 1 or bot_phase == 5:  # 5 = 综合演示的建造段，随后切模拟
				bot_mode = true
				var bot := RecordBot.new()
				bot.phase = bot_phase
				bot.mode = "build"
				add_child(bot)


func _init_mats() -> void:
	for m: StandardMaterial3D in [_mat_ok, _mat_bad]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.emission_enabled = true
	_mat_ok.albedo_color = GHOST_OK
	_mat_ok.emission = Color(0.15, 0.45, 0.15)
	_mat_bad.albedo_color = GHOST_BAD
	_mat_bad.emission = Color(0.45, 0.1, 0.08)


func set_selected(id: String) -> void:
	selected = id
	_clear_ghost()
	if id != "":
		ui.hide_binding_panel()
	ui.refresh_tool()


func start_sim() -> void:
	if machine.is_empty():
		ui.show_toast("先放置一些组件")
		return
	Game.pending_machine = machine.serialize()
	Game.level_mode = "" if not Game.puzzle_mode else Game.level_mode
	var target := "res://scenes/sim_level.tscn"
	if Game.puzzle_mode:
		target = "res://scenes/puzzle_flight.tscn"
	get_tree().change_scene_to_file(target)


## 载入示例机器模板
func load_preset(preset_name: String) -> void:
	var preset: Dictionary = Presets.get_preset(preset_name)
	if preset.is_empty():
		ui.show_toast("没有这个示例")
		return
	machine.deserialize(preset)
	clear_undo()
	ui.hide_binding_panel()
	ui.show_toast("已载入示例：%s（%d 个组件）" % [preset_name, machine.block_count()])


func undo_count() -> int:
	return _undo_stack.size()


func clear_undo() -> void:
	_undo_stack.clear()


func undo_last() -> bool:
	if _undo_stack.is_empty():
		return false
	var op: Dictionary = _undo_stack.pop_back()
	if op.op == "add":
		machine.remove_block(op.cell)
	else:
		var d: Dictionary = op.data
		var c: Array = d.c
		machine.add_block(Vector3i(int(c[0]), int(c[1]), int(c[2])), str(d.t), int(d.f))
	return true


func _process(_dt: float) -> void:
	if bot_mode:
		return
	_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if bot_mode:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if selected == "":
					_select_block_under_mouse()
				else:
					_try_place()
			MOUSE_BUTTON_RIGHT:
				_try_remove()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R and selected != "":
			facing = (facing + 1) % 6
			ui.refresh_tool()
		elif event.physical_keycode == KEY_Z and event.ctrl_pressed:
			if undo_last():
				ui.show_toast("已撤销")


func _try_place() -> void:
	if selected == "" or not _ghost_valid:
		return
	if machine.add_block(_ghost_cell, selected, facing):
		_undo_stack.append({"op": "add", "cell": _ghost_cell})
		ui.hide_binding_panel()


func _select_block_under_mouse() -> void:
	var hit := _mouse_ray()
	if hit.is_empty():
		ui.hide_binding_panel()
		return
	var col = hit.collider
	if col == null or not col.has_meta("cell"):
		ui.hide_binding_panel()
		return
	ui.show_binding_panel(col.get_meta("cell"))


func _try_remove() -> void:
	var hit := _mouse_ray()
	if hit.is_empty():
		return
	var col = hit.collider
	if col == null or not col.has_meta("cell"):
		return
	var cell: Vector3i = col.get_meta("cell")
	var data := machine.get_block(cell)
	if data.is_empty():
		return
	if machine.remove_block(cell):
		_undo_stack.append({"op": "remove", "data":
			{"c": [cell.x, cell.y, cell.z], "t": data.type, "f": data.facing}})


func _update_ghost() -> void:
	if selected == "":
		if _ghost:
			_ghost.visible = false
		return
	var hit := _mouse_ray()
	if hit.is_empty():
		if _ghost:
			_ghost.visible = false
		return
	_ghost_cell = machine.world_to_cell(hit.position + hit.normal * (Machine.CELL * 0.51))
	_ghost_valid = machine.can_place(_ghost_cell)
	if _ghost == null:
		_make_ghost(selected)
		if _ghost == null:
			return
	_ghost.visible = true
	_ghost.global_position = machine.cell_to_world(_ghost_cell)
	_ghost.basis = Machine.facing_basis(facing)
	var mat := _mat_ok if _ghost_valid else _mat_bad
	for mi: MeshInstance3D in _ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat


func _make_ghost(type: String) -> void:
	var ps: PackedScene = load(BlockDB.model_path(type))
	if ps == null:
		return
	_ghost = ps.instantiate()
	add_child(_ghost)
	for mi: MeshInstance3D in _ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat_ok
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_ghost_valid = false


func _mouse_ray() -> Dictionary:
	var vp := get_viewport()
	var c := vp.get_camera_3d()
	if c == null:
		return {}
	var mouse := vp.get_mouse_position()
	var from := c.project_ray_origin(mouse)
	var to := from + c.project_ray_normal(mouse) * 120.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(q)
