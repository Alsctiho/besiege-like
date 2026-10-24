class_name JourneyCamera
extends Camera3D

var target: JourneyPlayer
var vista := false
var _initialized := false
var _orbit := 0.0
var _look_target := Vector3.ZERO
var _vista_weight := 0.0

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
	var follow := 1.0 - exp(-delta * 4.0)
	var teaching_weight := smoothstep(-13.0, -5.0, target.global_position.z)
	_vista_weight = lerpf(_vista_weight, 1.0 if vista else 0.0, follow)
	teaching_weight *= 1.0 - _vista_weight
	var framing := Vector3(0, 1, -7).lerp(Vector3(-1.5, 0.5, -1.5), teaching_weight)
	var center := target.global_position + framing
	var offset := Vector3(17, 11, 21).lerp(Vector3(9, 12, 14), teaching_weight)
	offset = offset.lerp(Vector3(44, 25, 51), _vista_weight).rotated(Vector3.UP, _orbit)
	var desired := center + offset
	if not vista:
		var pivot := target.global_position + Vector3(0, 0.7, 0)
		var query := PhysicsRayQueryParameters3D.create(pivot, desired, 1)
		query.exclude = [target.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position + hit.normal * 0.6
	if not _initialized:
		global_position = desired
		_look_target = center
		_initialized = true
	else:
		var step := (desired - global_position) * follow
		global_position += step.limit_length(24.0 * delta)
		_look_target = _look_target.lerp(center, follow)
	if global_position.distance_squared_to(_look_target) > 0.001:
		look_at(_look_target)

func reset_tracking() -> void:
	_initialized = false
