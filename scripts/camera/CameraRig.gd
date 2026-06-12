extends Node3D

@export var camera_path: NodePath = NodePath("Camera3D")
@export var keyboard_pan_speed := 14.0
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


func _ready() -> void:
	_camera_offset_direction = camera.position.normalized()
	_zoom_distance = camera.position.length()
	_apply_zoom()
	_clamp_position()


func _process(delta: float) -> void:
	var pan_input := Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		pan_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan_input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		pan_input.y += 1.0
	if Input.is_key_pressed(KEY_S):
		pan_input.y -= 1.0

	if pan_input != Vector2.ZERO:
		_pan_by_vector(pan_input.normalized(), keyboard_pan_speed * delta)


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
	camera.position = _camera_offset_direction * _zoom_distance


func _clamp_position() -> void:
	global_position.x = clampf(global_position.x, x_limits.x, x_limits.y)
	global_position.z = clampf(global_position.z, z_limits.x, z_limits.y)
