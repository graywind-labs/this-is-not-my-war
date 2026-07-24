class_name DraggablePanel
extends RefCounted

var _host: Control
var _handle: Control
var _dragging := false
var _drag_offset := Vector2.ZERO
var _has_user_position := false


func bind(host: Control, handle: Control) -> void:
	_host = host
	_handle = handle
	if _host == null or _handle == null:
		return
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	if not _handle.gui_input.is_connected(_on_handle_gui_input):
		_handle.gui_input.connect(_on_handle_gui_input)
	if not _host.visibility_changed.is_connected(_on_host_visibility_changed):
		_host.visibility_changed.connect(_on_host_visibility_changed)
	var viewport := _host.get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func has_user_position() -> bool:
	return _has_user_position


func get_user_position() -> Vector2:
	return _host.global_position if _host != null else Vector2.ZERO


func restore_user_position(position: Vector2) -> void:
	if _host == null or not _has_user_position:
		return
	_host.global_position = position
	clamp_to_viewport()


func clamp_to_viewport() -> void:
	if _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	var viewport := _host.get_viewport()
	if viewport == null:
		return
	var visible_rect := viewport.get_visible_rect()
	var panel_size := _host.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = _host.get_combined_minimum_size()
	var max_position := visible_rect.end - panel_size
	max_position.x = maxf(visible_rect.position.x, max_position.x)
	max_position.y = maxf(visible_rect.position.y, max_position.y)
	_host.global_position = Vector2(
		clampf(_host.global_position.x, visible_rect.position.x, max_position.x),
		clampf(_host.global_position.y, visible_rect.position.y, max_position.y)
	)


func debug_drag_to(global_position: Vector2) -> void:
	if _host == null:
		return
	_detach_from_layout_anchor()
	_has_user_position = true
	_host.global_position = global_position
	clamp_to_viewport()


func _on_handle_gui_input(event: InputEvent) -> void:
	if _host == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_detach_from_layout_anchor()
			_drag_offset = _host.get_global_mouse_position() - _host.global_position
			_has_user_position = true
			_host.move_to_front()
		else:
			clamp_to_viewport()
		_handle.accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		_host.global_position = _host.get_global_mouse_position() - _drag_offset
		clamp_to_viewport()
		_handle.accept_event()


func _detach_from_layout_anchor() -> void:
	if _host == null:
		return
	var current_global_position := _host.global_position
	var current_size := _host.size
	_host.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_host.global_position = current_global_position
	_host.size = current_size


func _on_host_visibility_changed() -> void:
	_dragging = false
	if _host != null and _host.visible:
		_host.call_deferred("move_to_front")
		_host.call_deferred("queue_redraw")
		call_deferred("clamp_to_viewport")


func _on_viewport_size_changed() -> void:
	_dragging = false
	call_deferred("clamp_to_viewport")
