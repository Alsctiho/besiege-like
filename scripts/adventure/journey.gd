class_name CoreJourney
extends Node3D

const SAVE_PATH := "user://core_journey/save_v1.json"
var player: JourneyPlayer
var world: JourneyWorld
var camera: JourneyCamera
var hud: JourneyHUD
var projectiles: Array[Dictionary] = []
var collected_count := 0
var restart_backup_path := ""
var _verify_mode := false
var _cooldown := 0.0
var _projectile_material := JourneyGeometry.material(Color("ffba65"), 0, 3.0)

func _ready() -> void:
	name = "CoreJourney"
	_verify_mode = OS.get_cmdline_user_args().has("--journey-verify")
	world = JourneyWorld.new()
	add_child(world)
	player = JourneyPlayer.new()
	add_child(player)
	player.position = player.checkpoint
	player.tool_used.connect(_tool_used)
	camera = JourneyCamera.new()
	camera.name = "JourneyCamera"
	camera.target = player
	add_child(camera)
	hud = JourneyHUD.new()
	hud.player = player
	hud.world = world
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.save_requested.connect(save_progress)
	hud.load_requested.connect(load_progress, CONNECT_DEFERRED)
	hud.restart_requested.connect(restart_progress, CONNECT_DEFERRED)
	world.bridge_started.connect(func() -> void: hud.show_toast("升降桥正在上升 · 前方断口"))
	world.bridge_arrived.connect(func() -> void: hud.show_toast("升降桥已到位 · 可以通行"))
	player.respawned.connect(func() -> void: hud.show_toast("已回到最近的安全平台 · 零件保留"))
	if not _verify_mode and FileAccess.file_exists(SAVE_PATH):
		load_progress()
	else:
		hud.show_toast("F · 拾取   Tab · 组装")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F and not player.assembly_open:
			var identifier := world.nearest_pickup(player.global_position)
			if not identifier.is_empty() and world.take_pickup(identifier, player.loadout):
				collected_count += 1
				hud.show_toast("+ %s" % str(JourneyCatalog.DEFINITIONS[world.pickups[identifier].kind].name))
				save_progress()
		if event.physical_keycode == KEY_BACKSPACE:
			player.respawn()

func _tool_used(_face: String, kind: String, origin: Vector3, direction: Vector3, _continuous: bool) -> void:
	if kind == "fireball":
		var node := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.28
		node.mesh = sphere
		node.material_override = _projectile_material
		add_child(node)
		node.global_position = origin
		projectiles.append({"node": node, "velocity": direction * 14, "age": 0.0})
		return
	var distance := 3.0 if kind == "rod" else 1.8
	if kind == "blower": distance = 6.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 1)
	query.exclude = [player.get_rid()]
	query.hit_from_inside = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var bridge_was_active := world.bridge_active
	if not result.is_empty() and world.interact(result.collider, kind, direction):
		if kind == "drill" and _cooldown <= 0:
			hud.show_toast("裂岩已打开 · 通路就在前方")
			_cooldown = 1
			save_progress()
		if kind == "rod" and not bridge_was_active and world.bridge_active: save_progress()
	if kind == "blower":
		for projectile: Dictionary in projectiles:
			if projectile.node.global_position.distance_to(origin) < 5:
				projectile.velocity += direction * 0.35

func _fireball_contact(start: Vector3, finish: Vector3) -> Dictionary:
	var shape := SphereShape3D.new()
	shape.radius = 0.14
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.exclude = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	var hits := space.intersect_shape(query, 1)
	if not hits.is_empty(): return hits[0]
	query.motion = finish - start
	var fractions := space.cast_motion(query)
	if fractions.size() == 2 and fractions[0] < 1.0:
		query.transform.origin = start + query.motion * minf(1.0, fractions[1] + 0.001)
		query.motion = Vector3.ZERO
		hits = space.intersect_shape(query, 1)
		if not hits.is_empty(): return hits[0]
	query.transform.origin = finish
	query.motion = Vector3.ZERO
	hits = space.intersect_shape(query, 1)
	return hits[0] if not hits.is_empty() else {}

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		projectile.age += delta
		var next_position: Vector3 = projectile.node.global_position + projectile.velocity * delta
		var result := _fireball_contact(projectile.node.global_position, next_position)
		if not result.is_empty():
			if world.interact(result.collider, "fireball"):
				save_progress()
			projectile.node.queue_free()
			projectiles.remove_at(index)
		elif projectile.age > 4:
			projectile.node.queue_free()
			projectiles.remove_at(index)
		else:
			projectile.node.global_position = next_position
	if world.bridge_ready and player.is_on_floor() and player.position.z < -41 and player.position.z > -51:
		var checkpoint := Vector3(0, 0.98, -46)
		if player.checkpoint != checkpoint:
			player.checkpoint = checkpoint
			save_progress()
	if not world.completed and player.position.distance_to(Vector3(0, 3.98, -72)) < 2:
		world.completed = true
		hud.show_toast("穿越完成 · 你的装配打开了新的旅途")
		save_progress()

func save_progress() -> void:
	if _verify_mode: return
	var data := {"version": 1, "loadout": player.loadout.snapshot(), "rock_broken": world.rock_broken, "bridge_active": world.bridge_active, "completed": world.completed, "checkpoint": [player.checkpoint.x, player.checkpoint.y, player.checkpoint.z]}
	var directory := DirAccess.make_dir_recursive_absolute("user://core_journey")
	if directory != OK:
		push_error("CoreJourney.save_progress: cannot create save directory")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("CoreJourney.save_progress: cannot write save")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_progress() -> void:
	if _verify_mode: return
	if not FileAccess.file_exists(SAVE_PATH):
		hud.show_toast("还没有本旅程的存档")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		hud.show_toast("无法读取存档")
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary or data.get("version", 0) != 1:
		hud.show_toast("存档格式不兼容；旧机器存档不受影响")
		return
	if not player.loadout.restore(data.get("loadout", {})):
		hud.show_toast("存档装配数据无效，未覆盖当前配置")
		return
	world.restore_progress(data, player.loadout.items)
	var checkpoint: Variant = data.get("checkpoint", [0, 0.95, 6])
	if checkpoint is Array and checkpoint.size() == 3:
		player.checkpoint = Vector3(float(checkpoint[0]), float(checkpoint[1]), float(checkpoint[2]))
	_clear_projectiles()
	player.respawn()
	camera.reset_tracking()
	hud.show_toast("继续旅程 · 裂岩已打开" if world.rock_broken else "继续旅程 · 已恢复零件与机关")

func _clear_projectiles() -> void:
	for projectile: Dictionary in projectiles:
		projectile.node.queue_free()
	projectiles.clear()

func restart_progress() -> void:
	restart_backup_path = ""
	if not _verify_mode and FileAccess.file_exists(SAVE_PATH):
		var backup_path := SAVE_PATH + ".backup-" + str(Time.get_unix_time_from_system()).replace(".", "-")
		var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(backup_path))
		if error != OK:
			hud.show_toast("无法备份原存档，未重新开始")
			return
		restart_backup_path = backup_path
	_clear_projectiles()
	player.loadout.restore({"items": {"starter_wheels": "wheel"}, "slots": {"bottom": {"id": "starter_wheels", "direction": "bottom"}}})
	world.restore_progress({}, player.loadout.items)
	collected_count = 0
	player.checkpoint = Vector3(0, 0.95, 6)
	player.rotation = Vector3.ZERO
	player.respawn()
	camera.reset_tracking()
	hud.close_journey_menu()
	hud.show_toast("重新开始 · F 拾取 / Tab 组装")
	save_progress()
