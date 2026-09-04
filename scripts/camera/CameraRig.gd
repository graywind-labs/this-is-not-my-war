extends Node3D

@export var camera_path: NodePath = NodePath("Camera3D")
@export var keyboard_pan_speed := 28.0
@export var keyboard_pan_boost_multiplier := 2.0
@export var mouse_pan_speed := 0.035
@export var zoom_step := 2.5
@export var min_zoom_distance := 18.0
@export var max_zoom_distance := 42.0
@export var x_limits := Vector2(-18.0, 18.0)
@export var z_limits := Vector2(-21.0, 34.0)

@onready var camera: Camera3D = get_node(camera_path)

var _is_middle_dragging := false
var _camera_offset_direction := Vector3.ZERO
var _zoom_distance := 0.0
var _pressed_pan_keys: Dictionary = {}
var _is_keyboard_pan_boost_active := false
var _shake_elapsed := 0.0
var _shake_duration := 0.0
var _shake_amplitude := 0.0
var _shake_frequency := 18.0
var _camera_base_position := Vector3.ZERO


func _ready() -> void:
	_camera_offset_direction = camera.position.normalized()
	_zoom_distance = camera.position.length()
	_apply_zoom()
	_clamp_position()


func _process(delta: float) -> void:
	if _is_text_input_focused():
		_reset_keyboard_pan()
	else:
		var pan_input := Vector2.ZERO
		if _pressed_pan_keys.has(KEY_A):
			pan_input.x -= 1.0
		if _pressed_pan_keys.has(KEY_D):
			pan_input.x += 1.0
		if _pressed_pan_keys.has(KEY_W):
			pan_input.y += 1.0
		if _pressed_pan_keys.has(KEY_S):
			pan_input.y -= 1.0

		if pan_input != Vector2.ZERO:
			var speed_multiplier := keyboard_pan_boost_multiplier if _is_keyboard_pan_boost_active else 1.0
			_pan_by_vector(pan_input.normalized(), keyboard_pan_speed * speed_multiplier * delta)
	_update_camera_shake(delta)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if _is_shift_key(key_event):
		_is_keyboard_pan_boost_active = key_event.pressed
		return
	var pan_key := _get_pan_key(key_event)
	if pan_key == Key.KEY_NONE:
		return
	_is_keyboard_pan_boost_active = key_event.shift_pressed
	if not key_event.pressed:
		_pressed_pan_keys.erase(pan_key)
		return
	if key_event.echo or _is_text_input_focused():
		return
	_pressed_pan_keys[pan_key] = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_is_middle_dragging = mouse_button.pressed
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_step)
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_middle_dragging:
		var mouse_motion := event as InputEventMouseMotion
		var distance_scale := _zoom_distance / max_zoom_distance
		_pan_by_vector(Vector2(-mouse_motion.relative.x, mouse_motion.relative.y), mouse_pan_speed * distance_scale)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset_input_state()


func _get_pan_key(event: InputEventKey) -> Key:
	var physical_key := event.physical_keycode
	if [KEY_A, KEY_D, KEY_W, KEY_S].has(physical_key):
		return physical_key
	var logical_key := event.keycode
	if [KEY_A, KEY_D, KEY_W, KEY_S].has(logical_key):
		return logical_key
	return Key.KEY_NONE


func _is_shift_key(event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_SHIFT or event.keycode == KEY_SHIFT


func _is_text_input_focused() -> bool:
	if not is_inside_tree():
		return false
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _reset_keyboard_pan() -> void:
	_pressed_pan_keys.clear()
	_is_keyboard_pan_boost_active = false


func _reset_input_state() -> void:
	_reset_keyboard_pan()
	_is_middle_dragging = false


func _pan_by_vector(input_vector: Vector2, amount: float) -> void:
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	global_position += (right * input_vector.x + forward * input_vector.y) * amount
	_clamp_position()


func _zoom(delta_distance: float) -> void:
	_zoom_distance = clampf(_zoom_distance + delta_distance, min_zoom_distance, max_zoom_distance)
	_apply_zoom()


func _apply_zoom() -> void:
	_camera_base_position = _camera_offset_direction * _zoom_distance
	if _shake_duration <= 0.0:
		camera.position = _camera_base_position


func get_zoom_distance() -> float:
	return _zoom_distance


func request_camera_shake(duration_seconds: float, amplitude: float, frequency: float = 18.0) -> void:
	var requested_duration := maxf(0.0, duration_seconds)
	var requested_amplitude := maxf(0.0, amplitude)
	if requested_duration <= 0.0 or requested_amplitude <= 0.0:
		return
	# A stronger impact replaces the descent tremor; equal-strength requests extend it.
	if requested_amplitude >= _shake_amplitude or _shake_duration <= 0.0:
		_shake_elapsed = 0.0
		_shake_duration = requested_duration
		_shake_amplitude = requested_amplitude
		_shake_frequency = maxf(1.0, frequency)
	else:
		_shake_duration = maxf(_shake_duration, _shake_elapsed + requested_duration)


func get_camera_shake_snapshot() -> Dictionary:
	return {
		"active": _shake_duration > 0.0,
		"elapsed_seconds": _shake_elapsed,
		"duration_seconds": _shake_duration,
		"amplitude": _shake_amplitude,
		"frequency": _shake_frequency
	}


func _update_camera_shake(delta: float) -> void:
	if _shake_duration <= 0.0:
		camera.position = _camera_base_position
		return
	_shake_elapsed = minf(_shake_duration, _shake_elapsed + maxf(0.0, delta))
	var progress := clampf(_shake_elapsed / _shake_duration, 0.0, 1.0)
	var envelope := pow(1.0 - progress, 0.72)
	var phase := _shake_elapsed * _shake_frequency * TAU
	var offset := Vector3(
		sin(phase * 1.0),
		cos(phase * 1.37) * 0.72,
		sin(phase * 0.73 + 1.9) * 0.45
	) * _shake_amplitude * envelope
	camera.position = _camera_base_position + offset
	if _shake_elapsed < _shake_duration:
		return
	_shake_elapsed = 0.0
	_shake_duration = 0.0
	_shake_amplitude = 0.0
	camera.position = _camera_base_position


func _clamp_position() -> void:
	global_position.x = clampf(global_position.x, x_limits.x, x_limits.y)
	global_position.z = clampf(global_position.z, z_limits.x, z_limits.y)
