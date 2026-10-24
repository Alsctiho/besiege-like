class_name JourneyWorld
extends Node3D

var bridge: AnimatableBody3D
var brazier: StaticBody3D
var blocker: StaticBody3D
var switch_body: StaticBody3D
var portal: Node3D
var pickups: Dictionary = {}
var bridge_active := false
var rock_broken := false
var completed := false
var light_material: StandardMaterial3D
var _time := 0.0
var _sand := JourneyGeometry.material(Color("cdb08c"))
var _stone := JourneyGeometry.material(Color("a9674c"))
var _dark := JourneyGeometry.material(Color("755248"))
var _white := JourneyGeometry.material(Color("e4d5b9"))
var _metal := JourneyGeometry.material(Color("524b47"), 0.35)
var _glow := JourneyGeometry.material(Color("f5c887"), 0.0, 2.0)

func _ready() -> void:
	name = "World"
	_build_environment()
	_build_route()
	_build_monuments()
	_build_interactables()

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("aeb9bd")
	sky_material.sky_horizon_color = Color("efd7b7")
	sky_material.ground_bottom_color = Color("b98b6d")
	sky_material.ground_horizon_color = Color("e9cfac")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6cbd0")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("e9cfad")
	environment.fog_density = 0.0017
	environment.fog_height = -22
	environment.fog_height_density = 0.028
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	environment.ssao_enabled = true
	environment.ssao_intensity = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -32, 0)
	sun.light_color = Color("ffe6bb")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140
	add_child(sun)

func _deck(center: Vector3, size: Vector3) -> void:
	JourneyGeometry.box(self, center - Vector3(0, 0.65, 0), Vector3(size.x, 1.3, size.z), _stone, true)
	JourneyGeometry.box(self, center + Vector3(0, 0.018, 0), Vector3(size.x - 0.12, 0.025, size.z - 0.05), _sand)
	for side in [-1, 1]:
		var edge := center + Vector3(side * (size.x / 2 - 0.13), 0.14, 0)
		JourneyGeometry.box(self, edge, Vector3(0.20, 0.28, size.z), _white)
		for index in range(maxi(1, int(size.z / 4))):
			var location := center + Vector3(side * (size.x / 2 - 0.14), 0.22, -size.z / 2 + 2 + index * 4)
			JourneyGeometry.cylinder(self, location, 0.07, 0.14, _glow, 8)

func _build_route() -> void:
	_deck(Vector3(0, 0, 1), Vector3(18, 1, 24))
	_deck(Vector3(0, 0, -19.5), Vector3(6, 1, 17))
	_deck(Vector3(0, 0, -46), Vector3(14, 1, 10))
	_deck(Vector3(0, 3, -65), Vector3(12, 1, 22))
	for z_position in [8.0, -7.0, -22.0, -46.0, -65.0]:
		var height := 3.0 if z_position < -55 else 0.0
		JourneyGeometry.box(self, Vector3(0, height - 34, z_position), Vector3(3.2, 67, 3.2), _dark)
		JourneyGeometry.box(self, Vector3(0, height - 2, z_position), Vector3(4.4, 1.1, 4.4), _white)
	for z_position in [-6.0, -22.0, -46.0, -66.0]:
		var arch := JourneyGeometry.ring(self, Vector3(0, -6, z_position), 5.4, 1.6, 2.1, _stone, 32)
		arch.rotation.y = PI / 2
		JourneyGeometry.box(self, Vector3(0, -13, z_position - 5.4), Vector3(2.5, 16, 2.8), _stone)
		JourneyGeometry.box(self, Vector3(0, -13, z_position + 5.4), Vector3(2.5, 16, 2.8), _stone)

func _build_monuments() -> void:
	var ring_center := Vector3(-55, 27, -100)
	JourneyGeometry.ring(self, ring_center, 40, 4.2, 7, _stone, 64)
	JourneyGeometry.ring(self, ring_center + Vector3(0, 0, 4), 37.5, 0.45, 0.25, _white, 64)
	JourneyGeometry.ring(self, ring_center, 28, 1.1, 4, _metal, 48)
	for index in range(12):
		var angle := TAU * float(index) / 12
		var spoke := JourneyGeometry.box(self, ring_center + Vector3(sin(angle), cos(angle), 0) * 32.5, Vector3(1.8, 12, 5), _dark)
		spoke.rotation.z = -angle
	for index in range(9):
		var tower_x := -100.0 + index * 26
		var height := 60.0 + sin(index * 2.3) * 22
		JourneyGeometry.box(self, Vector3(tower_x, height / 2 - 25, -170 - absf(index - 4) * 12), Vector3(9, height, 12), _white)
		JourneyGeometry.box(self, Vector3(tower_x, height - 25, -170 - absf(index - 4) * 12), Vector3(11, 2, 14), _stone)
	JourneyGeometry.box(self, Vector3(-20, 30, -174), Vector3(120, 2, 6), _dark)
	for index in range(18):
		var location := Vector3(-80 + index * 10, -43, -60 - index * 5)
		var rock := JourneyGeometry.box(self, location, Vector3(12 + index % 3 * 4, 24 + index % 4 * 8, 18), _stone)
		rock.rotation.y = index * 0.3
	JourneyGeometry.box(self, Vector3(-22, -8, 14), Vector3(9, 58, 9), _dark)
	JourneyGeometry.box(self, Vector3(-22, 21, 14), Vector3(13, 4, 13), _white)
	for x_position in [-9.0, 9.0]:
		JourneyGeometry.box(self, Vector3(x_position, 10, -74), Vector3(3.8, 18, 4), _stone)
	JourneyGeometry.box(self, Vector3(0, 19, -74), Vector3(22, 3, 5), _white)

func _build_interactables() -> void:
	blocker = JourneyGeometry.box(self, Vector3(0, 1.2, -11.5), Vector3(5.9, 2.4, 0.75), _dark, true) as StaticBody3D
	blocker.name = "CrackedBarrier"
	blocker.set_meta("interaction", "drill")
	for index in range(6):
		var mark := JourneyGeometry.box(blocker, Vector3(-2.3 + index * 0.87, 0, 0.4), Vector3(0.07, 1.8, 0.03), _sand)
		mark.rotation.z = 0.3 if index % 2 == 0 else -0.2
	brazier = JourneyGeometry.box(self, Vector3(1.3, 0.7, -26.7), Vector3(0.9, 1.4, 0.9), _metal, true) as StaticBody3D
	brazier.name = "HeatReceiver"
	brazier.set_meta("interaction", "fireball")
	light_material = JourneyGeometry.material(Color("a35f38"), 0, 0.2)
	JourneyGeometry.cylinder(brazier, Vector3(0, 0.8, 0), 0.38, 0.35, light_material)
	switch_body = JourneyGeometry.box(self, Vector3(-1.7, 0.9, -27), Vector3(0.55, 1.8, 0.55), _white, true) as StaticBody3D
	switch_body.name = "BridgeSwitch"
	switch_body.set_meta("interaction", "rod")
	JourneyGeometry.box(switch_body, Vector3(0, 0.5, 0.29), Vector3(0.3, 0.3, 0.05), _glow)
	bridge = AnimatableBody3D.new()
	bridge.name = "LiftBridge"
	add_child(bridge)
	bridge.position = Vector3(0, -8, -34.5)
	JourneyGeometry.box(bridge, Vector3.ZERO, Vector3(5.2, 0.7, 13), _white)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.2, 0.7, 13)
	collision.shape = shape
	bridge.add_child(collision)
	portal = Node3D.new()
	portal.name = "JourneyGate"
	add_child(portal)
	portal.position = Vector3(0, 3, -72)
	JourneyGeometry.ring(portal, Vector3(0, 2.2, 0), 2.0, 0.15, 0.10, _glow, 32)
	add_pickup("ruin_drill", "drill", Vector3(-1.5, 0.65, 3.0))
	add_pickup("ruin_fireball", "fireball", Vector3(1.8, 0.65, -4.0))
	add_pickup("ruin_rotor", "rotor", Vector3(1.6, 0.65, -19))
	add_pickup("ruin_rod", "rod", Vector3(-1.5, 0.65, -22))
	add_pickup("ruin_booster", "booster", Vector3(2, 0.65, -47))
	add_pickup("ruin_blower", "blower", Vector3(-2, 0.65, -45))
	add_pickup("ruin_rotor_second", "rotor", Vector3(2, 3.65, -60))
	var wind_body := JourneyGeometry.box(self, Vector3(-3.2, 0.8, -43), Vector3(0.8, 0.8, 0.8), _sand, true)
	wind_body.name = "WindCube"
	wind_body.set_meta("interaction", "blower")

func add_pickup(identifier: String, kind: String, location: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Pickup_" + identifier
	add_child(node)
	node.position = location
	var visual := JourneyGeometry.model(kind)
	visual.scale = Vector3.ONE * 0.65
	node.add_child(visual)
	JourneyGeometry.cylinder(node, Vector3(0, -0.45, 0), 0.45, 0.07, _metal)
	var signal_material := JourneyGeometry.material(Color("6ec5bf"), 0, 1.6)
	JourneyGeometry.cylinder(node, Vector3(0, -0.39, 0), 0.31, 0.035, signal_material)
	pickups[identifier] = {"kind": kind, "node": node, "base": location, "taken": false}

func nearest_pickup(location: Vector3) -> String:
	var best := ""
	var distance := 2.35
	for identifier: String in pickups:
		var item: Dictionary = pickups[identifier]
		if item.taken: continue
		var current: float = location.distance_to(item.node.global_position)
		if current < distance:
			distance = current
			best = identifier
	return best

func take_pickup(identifier: String, loadout: JourneyLoadout) -> bool:
	if not pickups.has(identifier) or pickups[identifier].taken:
		return false
	if not loadout.acquire(identifier, pickups[identifier].kind):
		return false
	pickups[identifier].taken = true
	pickups[identifier].node.visible = false
	return true

func activate_bridge() -> void:
	if bridge_active: return
	bridge_active = true
	light_material.albedo_color = Color("ffdba2")
	light_material.emission = Color("ffc675")
	light_material.emission_energy_multiplier = 2.5
	var tween := create_tween()
	tween.tween_property(bridge, "position:y", -0.35, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func interact(body: Node, kind: String) -> bool:
	if body == blocker and kind == "drill" and not rock_broken:
		rock_broken = true
		blocker.collision_layer = 0
		blocker.visible = false
		return true
	if body == brazier and kind == "fireball":
		activate_bridge()
		return true
	if body == switch_body and kind == "rod":
		activate_bridge()
		return true
	if body.get_meta("interaction", "") == "blower" and kind == "blower":
		body.position.x = move_toward(body.position.x, -4.5, 0.03)
		return true
	return false

func _process(delta: float) -> void:
	_time += delta
	for item: Dictionary in pickups.values():
		if item.taken: continue
		item.node.position.y = item.base.y + sin(_time * 1.8) * 0.1
		item.node.get_child(0).rotation.y += delta * 0.5
