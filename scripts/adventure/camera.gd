class_name JourneyCamera
extends Camera3D

var target: JourneyPlayer
var vista := false
var _initialized := false
var _orbit := 0.0

func _ready() -> void:
	current = true
	fov = 54
	far = 650
	near = 0.15

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		vista = not vista
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not target.assembly_open:
		_orbit = clampf(_orbit - event.relative.x * 0.003, -0.8, 0.8)

func _process(delta: float) -> void:
	if target == null:
		return
	var center := target.global_position + Vector3(0, 1, -7)
	var offset := Vector3(44, 25, 51) if vista else Vector3(17, 11, 21)
	offset = offset.rotated(Vector3.UP, _orbit)
	var desired := center + offset
	if not vista:
		var query := PhysicsRayQueryParameters3D.create(center, desired, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position + hit.normal * 0.6
	if not _initialized:
		global_position = desired
		_initialized = true
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-delta * 4.0))
	look_at(center)
