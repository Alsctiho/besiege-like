extends "res://scripts/sim_level.gd"
## 平原战场：开阔平原 + 4 台会移动/躲避的敌方机器。
## 消灭全部敌机获胜；机器完全散架则失败。

var _defeated := false


func _spawn_level_content() -> void:
	var spots := [
		Vector3(-12, 0.4, -8),
		Vector3(12, 0.4, -10),
		Vector3(-7, 0.4, -20),
		Vector3(9, 0.4, -22),
	]
	for pos in spots:
		var r := EnemyRobot.create(pos, root_body)
		sim_root.add_child(r)
		mobs.append(r)
		player_fired.connect(r.on_player_fired)
	hud.show_toast("平原战场：摧毁 %d 台敌方机器！" % mobs.size())


func _return_scene() -> String:
	return "res://scenes/garage.tscn"


func _physics_process(delta: float) -> void:
	super(delta)
	# 失败判定：机器存活方块全部散架
	if not _defeated and root_body != null:
		var alive: int = machine_cells.get(root_body, []).size()
		if alive == 0:
			_defeated = true
			hud.show_toast("机器已完全散架 · 挑战失败")
			Sfx.play(self, "explosion", root_body.global_position)
	# 胜利判定：敌机清空
	if not _defeated and not mobs.is_empty():
		var alive_mobs := 0
		for m in mobs:
			if is_instance_valid(m):
				alive_mobs += 1
		if alive_mobs == 0:
			hud.show_toast("🏆 战场清空！所有敌方机器已摧毁")
			Sfx.play(self, "explosion", root_body.global_position if root_body else Vector3.ZERO)
