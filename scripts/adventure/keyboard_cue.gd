extends Control

const KEY_SIZE := 30.0
const PITCH := 36.0
const FACE_KEYS := {"q":"left", "e":"right", "z":"front", "x":"back", "space":"top"}
const KEY_CODES := {"q":KEY_Q, "w":KEY_W, "e":KEY_E, "a":KEY_A, "s":KEY_S, "d":KEY_D, "f":KEY_F, "z":KEY_Z, "x":KEY_X, "space":KEY_SPACE}
const ACTION_ICONS := {"w":"forward", "a":"forward", "s":"forward", "d":"forward", "f":"hand"}
const ACTION_HINTS := {"w":"W · 沿车头前进", "a":"A · 向左打方向", "s":"S · 沿车头倒车", "d":"D · 向右打方向", "f":"F · 拾取"}
const ARROW_ROTATIONS := {"w":0.0, "a":-PI / 2, "s":PI, "d":PI / 2}
var caps: Dictionary = {}
var icons: Dictionary = {}
var _normal: StyleBoxFlat
var _pressed: StyleBoxFlat

func _ready() -> void:
	name = "KeyboardCue"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_normal = StyleBoxFlat.new()
	_normal.bg_color = Color(0.94, 0.90, 0.82, 0.88)
	_normal.border_color = Color(0.52, 0.43, 0.33, 0.72)
	_normal.set_border_width_all(1)
	_normal.set_corner_radius_all(8)
	_normal.shadow_color = Color(0.18, 0.13, 0.08, 0.16)
	_normal.shadow_size = 2
	_normal.shadow_offset = Vector2(0, 2)
	_pressed = _normal.duplicate() as StyleBoxFlat
	_pressed.bg_color = Color("afcdbb")
	_pressed.border_color = Color("60897c")
	custom_minimum_size = Vector2(180, 102)
	_row(self, ["q", "w", "e"], Vector2.ZERO)
	_row(self, ["a", "s", "d", "f"], Vector2(9, PITCH))
	_row(self, ["z", "x"], Vector2(18, PITCH * 2))
	_key(self, "space", Vector2(90, PITCH * 2), Vector2(90, KEY_SIZE))

func _row(parent: Control, keys: Array, start: Vector2) -> void:
	for index in range(keys.size()):
		_key(parent, keys[index], start + Vector2(PITCH * index, 0))

func _key(parent: Control, key: String, at: Vector2, dimensions := Vector2(KEY_SIZE, KEY_SIZE)) -> void:
	var cap := Panel.new()
	cap.name = "Key_" + key
	cap.position = at
	cap.size = dimensions
	cap.add_theme_stylebox_override("panel", _normal)
	cap.mouse_filter = Control.MOUSE_FILTER_PASS
	cap.set_meta("key_id", key)
	parent.add_child(cap)
	caps[key] = cap

	var icon := TextureRect.new()
	icon.name = "ComponentIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(22, 22)
	icon.position = (dimensions - icon.size) * 0.5
	icon.pivot_offset = icon.size * 0.5
	cap.add_child(icon)
	icons[key] = icon
	icon.texture = JourneyPictograms.texture(ACTION_ICONS.get(key, "empty"))
	icon.rotation = float(ARROW_ROTATIONS.get(key, 0.0))
	cap.tooltip_text = str(ACTION_HINTS.get(key, ""))

func refresh(loadout: JourneyLoadout) -> void:
	for key: String in FACE_KEYS:
		var face: String = FACE_KEYS[key]
		var kind := loadout.kind_at(face)
		icons[key].texture = JourneyPictograms.texture("empty" if kind.is_empty() else kind)
		icons[key].modulate.a = 0.52 if kind.is_empty() else 1.0
		caps[key].tooltip_text = "%s面 · %s · %s" % [JourneyCatalog.LABELS[face], JourneyCatalog.KEYS[face], "空接口" if kind.is_empty() else JourneyCatalog.DEFINITIONS[kind].name]

func update_pressed(enabled: bool) -> void:
	for key: String in KEY_CODES:
		var down := enabled and (JourneyCatalog.face_down(FACE_KEYS[key]) if FACE_KEYS.has(key) else Input.is_physical_key_pressed(KEY_CODES[key]))
		caps[key].add_theme_stylebox_override("panel", _pressed if down else _normal)
		caps[key].set_meta("pressed", down)
