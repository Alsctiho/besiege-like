class_name CoreJourney
extends Node3D

const SAVE_PATH := "user://core_journey/save_v1.json"
var player: JourneyPlayer
var world: JourneyWorld
var camera: JourneyCamera
var hud: JourneyHUD
var projectiles: Array[Dictionary] = []
var collected_count := 0
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
	player.respawned.connect(func() -> void: hud.show_toast("已回到最近的安全平台 · 零件保留"))
	if not _verify_mode and FileAccess.file_exists(SAVE_PATH):
		load_progress()
	else:
		hud.show_toast("你就是核心。拾取零件，把能力装到自己身上。")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F and not player.assembly_open:
			var identifier := world.nearest_pickup(player.global_position)
			if not identifier.is_empty() and world.take_pickup(identifier, player.loadout):
				collected_count += 1
				hud.show_toast("获得「%s」 · Tab 打开六面组装" % str(JourneyCatalog.DEFINITIONS[world.pickups[identifier].kind].name))
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
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var bridge_was_active := world.bridge_active
	if not result.is_empty() and world.interact(result.collider, kind):
		if kind == "drill" and _cooldown <= 0:
			hud.show_toast("裂岩已打开 · 通路就在前方")
			_cooldown = 1
			save_progress()
		if kind == "rod" and not bridge_was_active and world.bridge_active: save_progress()
	if kind == "blower":
		for projectile: Dictionary in projectiles:
			if projectile.node.global_position.distance_to(origin) < 5:
				projectile.velocity += direction * 0.35

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		projectile.age += delta
		var next_position: Vector3 = projectile.node.global_position + projectile.velocity * delta
		var query := PhysicsRayQueryParameters3D.create(projectile.node.global_position, next_position, 1)
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			if world.interact(result.collider, "fireball"):
				hud.show_toast("热能机关已点燃 · 升降桥正在就位")
				save_progress()
			projectile.node.queue_free()
			projectiles.remove_at(index)
		elif projectile.age > 4:
			projectile.node.queue_free()
			projectiles.remove_at(index)
		else:
			projectile.node.global_position = next_position
	if world.bridge_active and player.is_on_floor() and player.position.z < -41 and player.position.z > -51:
		player.checkpoint = Vector3(0, 0.98, -46)
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
	world.rock_broken = data.get("rock_broken", false)
	world.blocker.visible = not world.rock_broken
	world.blocker.collision_layer = 0 if world.rock_broken else 1
	if data.get("bridge_active", false): world.activate_bridge()
	world.completed = data.get("completed", false)
	var checkpoint: Variant = data.get("checkpoint", [0, 0.95, 6])
	if checkpoint is Array and checkpoint.size() == 3:
		player.checkpoint = Vector3(float(checkpoint[0]), float(checkpoint[1]), float(checkpoint[2]))
	for identifier: String in world.pickups:
		var owned := player.loadout.items.has(identifier)
		world.pickups[identifier].taken = owned
		world.pickups[identifier].node.visible = not owned
	player.respawn()
	hud.show_toast("旅程与六面装配已恢复")
