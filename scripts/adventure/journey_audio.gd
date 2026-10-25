extends Node3D

const MUSIC_BUS := "JourneyMusic"
const SFX_BUS := "JourneySFX"
const AUDIO_ROOT := "res://assets/adventure/audio/"
const LOOPS := {"rotor":"rotor_loop", "blower":"blower_loop", "drill":"drill_loop", "booster":"booster_loop"}
const STARTS := {"rotor":"rotor_start", "drill":"drill_start", "booster":"booster_start", "rod":"equip"}
const STOPS := {"rotor":"rotor_stop", "booster":"booster_stop", "rod":"unequip"}
const LOOP_DB := {"rotor":-15.0, "blower":-17.0, "drill":-18.0, "booster":-14.0}

var player: JourneyPlayer
var world: JourneyWorld
var camera: Camera3D
var hud: JourneyHUD
var music: AudioStreamPlayer
var listener: AudioListener3D
var loops: Dictionary = {}
var wheels: Dictionary = {}
var event_counts: Dictionary = {}
var music_volume := 0.72
var sfx_volume := 0.70
var _streams: Dictionary = {}
var _voices: Array[Node] = []
var _bridge_loop: AudioStreamPlayer3D
var _previous_floor := false
var _previous_vertical := 0.0
var _duck_db := 0.0

func _ready() -> void:
	name = "JourneyAudio"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	set_volume("music", music_volume)
	set_volume("sfx", sfx_volume)
	music = AudioStreamPlayer.new()
	music.name = "ExplorationMusic"
	music.bus = MUSIC_BUS
	var stream := load(AUDIO_ROOT + "music/windworn_viaduct.ogg") as AudioStreamOggVorbis
	music.stream = stream.duplicate()
	(music.stream as AudioStreamOggVorbis).loop = true
	music.volume_db = -5.0
	add_child(music)
	music.play()
	listener = AudioListener3D.new()
	listener.name = "PlayerAudioListener"
	add_child(listener)
	listener.make_current()

func configure(body: JourneyPlayer, environment: JourneyWorld, view: Camera3D, interface: JourneyHUD) -> void:
	player = body
	world = environment
	camera = view
	hud = interface
	player.loadout.changed.connect(_rebuild)
	player.respawned.connect(_reset)
	world.bridge_started.connect(_bridge_start)
	world.bridge_arrived.connect(_bridge_arrival)
	hud.sound_requested.connect(play_ui)
	hud.volume_requested.connect(set_volume)
	_rebuild()

func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, "Master")

func set_volume(kind: String, value: float) -> void:
	var bus := MUSIC_BUS if kind == "music" else SFX_BUS
	value = clampf(value, 0.0, 1.0)
	if kind == "music": music_volume = value
	else: sfx_volume = value
	var index := AudioServer.get_bus_index(bus)
	if index < 0: return
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)) - (6.0 if kind == "sfx" else 0.0))

func _stream(key: String, looped := false) -> AudioStream:
	var cache_key := key + ("_looped" if looped else "_once")
	if not _streams.has(cache_key):
		var audio := load(AUDIO_ROOT + "sfx/" + key + ".ogg") as AudioStreamOggVorbis
		var copy := audio.duplicate() as AudioStreamOggVorbis
		copy.loop = looped
		_streams[cache_key] = copy
	return _streams[cache_key]

func _spatial(name_value: String, stream: AudioStream) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = name_value
	voice.stream = stream
	voice.bus = SFX_BUS
	voice.unit_size = 3.0
	voice.max_distance = 50.0
	voice.max_db = 0.0
	voice.panning_strength = 0.55
	add_child(voice)
	return voice

func play_at(key: String, point: Vector3, gain_db := -12.0, pitch := 1.0) -> void:
	_trim_voices()
	if _voices.size() >= 16: return
	var voice := _spatial("OneShot_" + key, _stream(key))
	voice.global_position = point
	voice.volume_db = gain_db
	voice.pitch_scale = pitch
	voice.finished.connect(voice.queue_free)
	_voices.append(voice)
	_count(key)
	voice.play()

func play_ui(key: String) -> void:
	_trim_voices()
	if _voices.size() >= 16: return
	var voice := AudioStreamPlayer.new()
	voice.name = "UI_" + key
	voice.stream = _stream(key)
	voice.bus = SFX_BUS
	voice.volume_db = -13.0 if key == "ui_click" else -10.0
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	_voices.append(voice)
	_count(key)
	voice.play()

func _count(key: String) -> void:
	event_counts[key] = int(event_counts.get(key, 0)) + 1

func _trim_voices() -> void:
	for index in range(_voices.size() - 1, -1, -1):
		if not is_instance_valid(_voices[index]): _voices.remove_at(index)

func _rebuild() -> void:
	for state: Dictionary in loops.values():
		if is_instance_valid(state.voice):
			state.voice.stop()
			state.voice.queue_free()
	for voice: AudioStreamPlayer3D in wheels.values():
		voice.stop()
		voice.queue_free()
	loops.clear()
	wheels.clear()
	for face: String in player.loadout.slots:
		var kind := player.loadout.kind_at(face)
		if not LOOPS.has(kind) and kind != "rod": continue
		var voice: AudioStreamPlayer3D = null
		if LOOPS.has(kind): voice = _spatial("Loop_" + face, _stream(LOOPS[kind], true))
		loops[face] = {"voice":voice, "kind":kind, "active":false, "gain":-60.0, "age":0.0}
	for key: String in player.effects.wheel_nodes:
		var voice := _spatial("Rolling_" + key, _stream("wheel_roll_loop", true))
		voice.volume_db = -60.0
		wheels[key] = voice

func _reset() -> void:
	for state: Dictionary in loops.values():
		if is_instance_valid(state.voice): state.voice.stop()
		state.active = false
		state.gain = -60.0
	for voice: AudioStreamPlayer3D in wheels.values(): voice.stop()
	if is_instance_valid(_bridge_loop): _bridge_loop.stop()
	_previous_floor = false
	_previous_vertical = 0.0

func _component_position(face: String) -> Vector3:
	var kind := player.loadout.kind_at(face)
	var direction := player.world_axis(face)
	var distance := 0.526 + JourneyCatalog.mount_clearance(face, player.loadout.direction_at(face), kind)
	return player.global_position + player.global_basis * (JourneyCatalog.AXES[face] * distance) + direction * 0.3

func _bridge_start() -> void:
	play_at("bridge_start", world.bridge.global_position, -12.0, 0.95)
	if is_instance_valid(_bridge_loop): _bridge_loop.queue_free()
	_bridge_loop = _spatial("BridgeMotion", _stream("bridge_move_loop", true))
	_bridge_loop.volume_db = -22.0
	_bridge_loop.global_position = world.bridge.global_position
	_bridge_loop.play()
	_count("bridge_move_loop")

func _bridge_arrival() -> void:
	if is_instance_valid(_bridge_loop):
		_bridge_loop.stop()
		_bridge_loop.queue_free()
	play_at("bridge_arrived", world.bridge.global_position, -10.0)

func _process(delta: float) -> void:
	_trim_voices()
	if player == null: return
	listener.global_transform = Transform3D(camera.global_basis, player.global_position + Vector3.UP * 0.5)
	var blocked := get_tree().paused or player.assembly_open
	_duck_db = lerpf(_duck_db, -5.0 if blocked else 0.0, 1.0 - exp(-delta * 4.0))
	music.volume_db = -5.0 + _duck_db
	for face: String in loops:
		var state: Dictionary = loops[face]
		var kind: String = state.kind
		var active := not blocked and bool(player.active_faces.get(face, false))
		if kind in ["rotor", "booster"]: active = active and player.component_forces.has(face)
		var point := _component_position(face)
		if active != bool(state.active):
			state.active = active
			state.age = 0.0
			if active and STARTS.has(kind): play_at(STARTS[kind], point, -17.0, 0.95)
			elif not active and not blocked and STOPS.has(kind): play_at(STOPS[kind], point, -19.0)
		state.age = float(state.age) + delta
		var voice := state.voice as AudioStreamPlayer3D
		if voice == null: continue
		voice.global_position = point
		var desired := float(LOOP_DB[kind]) if active else -60.0
		state.gain = lerpf(float(state.gain), desired, 1.0 - exp(-delta * 12.0))
		voice.volume_db = state.gain
		if active and not voice.playing:
			voice.play()
			_count(LOOPS[kind])
		elif not active and float(state.gain) < -55.0: voice.stop()
		voice.pitch_scale = 0.90 + player.energy * 0.10 if kind in ["rotor", "booster"] else 0.96
	for key: String in wheels:
		var voice := wheels[key] as AudioStreamPlayer3D
		var wheel := player.effects.wheel_nodes[key] as Node3D
		var motion := player.velocity + (Vector3.UP * player.yaw_velocity).cross(wheel.global_position-player.global_position)
		var speed := Vector2(motion.x, motion.z).length()
		var contact := not blocked and player.is_on_floor() and speed > 0.35 and not player.effects.wheel_contact(player, wheel).is_empty()
		voice.global_position = wheel.global_position
		var desired := -25.0 + clampf(speed / 4.8, 0.0, 1.0) * 4.0 if contact else -60.0
		voice.volume_db = lerpf(voice.volume_db, desired, 1.0-exp(-delta*12.0))
		voice.pitch_scale = clampf(0.75+speed*0.06, 0.75, 1.25)
		if contact and not voice.playing:
			voice.play()
			_count("wheel_roll_loop")
		elif not contact and voice.volume_db < -55.0: voice.stop()
	if is_instance_valid(_bridge_loop): _bridge_loop.global_position = world.bridge.global_position

func shutdown() -> void:
	set_process(false)
	set_physics_process(false)
	for child: Node in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
	loops.clear()
	wheels.clear()
	_voices.clear()
	_streams.clear()

func _exit_tree() -> void:
	shutdown()

func _physics_process(_delta: float) -> void:
	if player == null or get_tree().paused: return
	var floor_now := player.is_on_floor()
	if floor_now and not _previous_floor and _previous_vertical < -2.0:
		play_at("wheel_landing", player.global_position, -15.0)
	_previous_floor = floor_now
	_previous_vertical = player.velocity.y
