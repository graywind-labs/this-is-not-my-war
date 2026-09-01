extends Control

const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"

const MARKER_SIZE := Vector2(42.0, 42.0)
const MARKER_SCREEN_MARGIN := 6.0
const POPUP_SCREEN_MARGIN := 12.0
const POPUP_MARKER_GAP := 10.0
const POPUP_PREFERRED_WIDTH := 245.0
const POPUP_MAX_HEIGHT := 330.0
const PICKER_ITEM_BUTTON_SIZE := Vector2(68.0, 68.0)
const PICKER_ITEM_ICON_MAX_WIDTH := 66
const PICKER_GRID_COLUMNS := 3
const PICKER_ITEM_CONTENT_MARGIN := 1.0
const PICKER_ITEM_BORDER_WIDTH := 1

var _markers: Dictionary = {}
var _current_slot_id := ""
var _popup: PanelContainer
var _popup_title_label: Label
var _popup_device_grid: GridContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_popup()
	_connect_refresh_signals()
	call_deferred("_refresh_all")


func _process(_delta: float) -> void:
	_position_markers()
	if _popup != null and _popup.visible:
		_position_popup()


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.disconnect(_on_viewport_size_changed)


func _connect_refresh_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if (
			event_bus.has_signal("defense_device_state_changed")
			and not event_bus.defense_device_state_changed.is_connected(_on_defense_device_state_changed)
		):
			event_bus.defense_device_state_changed.connect(_on_defense_device_state_changed)
		if (
			event_bus.has_signal("resource_changed")
			and not event_bus.resource_changed.is_connected(_on_resource_changed)
		):
			event_bus.resource_changed.connect(_on_resource_changed)
		if (
			event_bus.has_signal("building_state_changed")
			and not event_bus.building_state_changed.is_connected(_on_building_state_changed)
		):
			event_bus.building_state_changed.connect(_on_building_state_changed)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func _refresh_all() -> void:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("get_slot_ids"):
		_hide_all_markers()
		_close_popup()
		return

	var active_slot_ids: Array[String] = []
	for raw_slot_id in device_system.get_slot_ids():
		var slot_id := str(raw_slot_id)
		if slot_id.is_empty():
			continue
		active_slot_ids.append(slot_id)
		if not _markers.has(slot_id):
			_create_marker(slot_id)
		_refresh_marker(slot_id)

	for raw_slot_id in _markers.keys():
		var slot_id := str(raw_slot_id)
		if active_slot_ids.has(slot_id):
			continue
		var stale_marker := _markers.get(slot_id) as Button
		if is_instance_valid(stale_marker):
			stale_marker.queue_free()
		_markers.erase(slot_id)

	if not _current_slot_id.is_empty():
		var current_slot := _get_slot(_current_slot_id)
		if (
			current_slot.is_empty()
			or not bool(current_slot.get("unlocked", false))
			or bool(current_slot.get("occupied", false))
		):
			_close_popup()
		elif _popup != null and _popup.visible:
			_rebuild_popup()

	_position_markers()


func _create_marker(slot_id: String) -> void:
	var marker := Button.new()
	marker.name = "%sDefenseSlotMarker" % slot_id.to_pascal_case()
	marker.custom_minimum_size = MARKER_SIZE
	marker.size = MARKER_SIZE
	marker.focus_mode = Control.FOCUS_NONE
	marker.mouse_filter = Control.MOUSE_FILTER_STOP
	marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	marker.z_index = 2
	marker.set_meta("slot_id", slot_id)
	marker.add_theme_constant_override("outline_size", 3)
	marker.add_theme_color_override("font_outline_color", Color(0.06, 0.045, 0.025, 0.96))
	marker.pressed.connect(_on_marker_pressed.bind(slot_id))
	marker.visible = false
	add_child(marker)
	_markers[slot_id] = marker


func _refresh_marker(slot_id: String) -> void:
	var marker := _markers.get(slot_id) as Button
	if marker == null:
		return
	var slot := _get_slot(slot_id)
	if slot.is_empty():
		marker.visible = false
		return

	var unlocked := bool(slot.get("unlocked", false))
	var occupied := bool(slot.get("occupied", false))
	var slot_name := str(slot.get("name", "防御部署位"))
	var range_multiplier := _get_range_multiplier(slot)

	marker.disabled = not unlocked
	marker.visible = unlocked and not occupied
	marker.text = "+" if unlocked else ""
	marker.tooltip_text = ""
	if not unlocked:
		return
	marker.add_theme_font_size_override("font_size", 25)
	marker.add_theme_color_override("font_color", Color(1.0, 0.91, 0.59, 1.0))
	marker.add_theme_color_override("font_hover_color", Color.WHITE)
	marker.add_theme_color_override("font_pressed_color", Color(0.98, 0.78, 0.28, 1.0))
	marker.add_theme_stylebox_override(
		"normal",
		_make_round_style(Color(0.11, 0.085, 0.045, 0.88), Color(0.84, 0.61, 0.25, 0.96), 2)
	)
	marker.add_theme_stylebox_override(
		"hover",
		_make_round_style(Color(0.25, 0.16, 0.055, 0.96), Color(1.0, 0.82, 0.38, 1.0), 3)
	)
	marker.add_theme_stylebox_override(
		"pressed",
		_make_round_style(Color(0.34, 0.20, 0.045, 1.0), Color(1.0, 0.70, 0.18, 1.0), 2)
	)
	var bonus_text := (
		" · 射程×%s" % _format_number(range_multiplier)
		if not is_equal_approx(range_multiplier, 1.0)
		else ""
	)
	marker.tooltip_text = "%s\n点击选择部署器械%s" % [slot_name, bonus_text]


func _position_markers() -> void:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	var viewport_size := get_viewport_rect().size
	for raw_slot_id in _markers.keys():
		var slot_id := str(raw_slot_id)
		var marker := _markers.get(slot_id) as Button
		if marker == null:
			continue
		var slot := _get_slot(slot_id)
		if (
			camera == null
			or slot.is_empty()
			or bool(slot.get("occupied", false))
			or not bool(slot.get("unlocked", false))
		):
			marker.visible = false
			continue

		var world_position := _to_vector3(slot.get("position", {}))
		if camera.is_position_behind(world_position):
			marker.visible = false
			continue

		var screen_center := camera.unproject_position(world_position)
		var in_view := (
			screen_center.x >= -MARKER_SIZE.x
			and screen_center.y >= -MARKER_SIZE.y
			and screen_center.x <= viewport_size.x + MARKER_SIZE.x
			and screen_center.y <= viewport_size.y + MARKER_SIZE.y
		)
		if not in_view:
			marker.visible = false
			continue

		var maximum_position := Vector2(
			maxf(MARKER_SCREEN_MARGIN, viewport_size.x - MARKER_SIZE.x - MARKER_SCREEN_MARGIN),
			maxf(MARKER_SCREEN_MARGIN, viewport_size.y - MARKER_SIZE.y - MARKER_SCREEN_MARGIN)
		)
		marker.position = (screen_center - MARKER_SIZE * 0.5).clamp(
			Vector2(MARKER_SCREEN_MARGIN, MARKER_SCREEN_MARGIN),
			maximum_position
		)
		marker.visible = true


func _hide_all_markers() -> void:
	for marker_value in _markers.values():
		var marker := marker_value as Button
		if marker != null:
			marker.visible = false


func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.name = "DefenseDeploymentPanel"
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.z_index = 100
	_popup.custom_minimum_size = Vector2(POPUP_PREFERRED_WIDTH, 0.0)
	_popup.add_theme_stylebox_override("panel", _make_popup_style())
	add_child(_popup)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_popup.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	_popup_title_label = Label.new()
	_popup_title_label.name = "Title"
	_popup_title_label.text = "选择防御器械"
	_popup_title_label.tooltip_text = ""
	_popup_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_title_label.add_theme_font_size_override("font_size", 18)
	_popup_title_label.add_theme_color_override("font_color", Color(1.0, 0.89, 0.60, 1.0))
	header.add_child(_popup_title_label)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.custom_minimum_size = Vector2(30.0, 30.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_close_popup)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "DevicePickerScroll"
	scroll.custom_minimum_size.y = 230.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_popup_device_grid = GridContainer.new()
	_popup_device_grid.name = "DevicePickerGrid"
	_popup_device_grid.columns = PICKER_GRID_COLUMNS
	_popup_device_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_device_grid.add_theme_constant_override("h_separation", 8)
	_popup_device_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_popup_device_grid)


func _open_slot(slot_id: String) -> bool:
	var slot := _get_slot(slot_id)
	if (
		slot.is_empty()
		or not bool(slot.get("unlocked", false))
		or bool(slot.get("occupied", false))
	):
		return false
	_current_slot_id = slot_id
	_popup.visible = true
	_popup.move_to_front()
	_rebuild_popup()
	call_deferred("_position_popup")
	return true


func _close_popup() -> void:
	_current_slot_id = ""
	if _popup != null:
		_popup.visible = false


func _rebuild_popup() -> void:
	if _popup == null or _popup_device_grid == null or _current_slot_id.is_empty():
		return
	var slot := _get_slot(_current_slot_id)
	if slot.is_empty():
		_close_popup()
		return

	_popup_title_label.text = "选择防御器械"
	for child in _popup_device_grid.get_children():
		_popup_device_grid.remove_child(child)
		child.queue_free()

	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if device_system == null or resource_system == null or not device_system.has_method("get_device_ids"):
		return

	for raw_device_id in device_system.get_device_ids():
		var device_id := str(raw_device_id)
		var definition: Dictionary = device_system.get_device_definition(device_id)
		if definition.is_empty():
			continue
		var inventory_cost := _as_dictionary(definition.get("inventory_cost", {}))
		if inventory_cost.is_empty():
			continue
		var resource_id := str(inventory_cost.keys()[0])
		var cost_per_device := maxi(1, int(inventory_cost.get(resource_id, 1)))
		var available_count := int(resource_system.get_resource(resource_id)) / cost_per_device
		var eligibility := _get_deploy_eligibility(device_id, _current_slot_id)
		if available_count <= 0 or not bool(eligibility.get("ok", false)):
			continue
		for instance_index in available_count:
			_popup_device_grid.add_child(_make_device_icon_button(device_id, definition, instance_index))
	_popup.reset_size()
	call_deferred("_position_popup")


func _make_device_icon_button(device_id: String, definition: Dictionary, instance_index: int) -> Button:
	var button := Button.new()
	button.name = "%sInventoryIcon%02d" % [device_id.to_pascal_case(), instance_index + 1]
	button.custom_minimum_size = PICKER_ITEM_BUTTON_SIZE
	button.icon = _load_device_icon(definition)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", PICKER_ITEM_ICON_MAX_WIDTH)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = str(definition.get("name", device_id))
	button.set_meta("device_picker_id", device_id)
	button.pressed.connect(_on_deploy_pressed.bind(device_id))
	_apply_icon_button_style(button, PICKER_ITEM_CONTENT_MARGIN, PICKER_ITEM_BORDER_WIDTH)
	return button


func _load_device_icon(definition: Dictionary) -> Texture2D:
	var presentation := _as_dictionary(definition.get("presentation", {}))
	var icon_path := str(presentation.get("icon", definition.get("icon", ""))).strip_edges()
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _apply_icon_button_style(button: Button, content_margin: float, border_width: int) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var source_style := button.get_theme_stylebox(state)
		if source_style == null:
			continue
		var compact_style := source_style.duplicate() as StyleBox
		compact_style.content_margin_left = content_margin
		compact_style.content_margin_top = content_margin
		compact_style.content_margin_right = content_margin
		compact_style.content_margin_bottom = content_margin
		if compact_style is StyleBoxFlat:
			(compact_style as StyleBoxFlat).set_border_width_all(border_width)
		button.add_theme_stylebox_override(state, compact_style)


func _get_deploy_eligibility(device_id: String, slot_id: String) -> Dictionary:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("get_deploy_eligibility"):
		return {"ok": false, "message": "防御器械系统暂不可用。"}
	var result: Variant = device_system.get_deploy_eligibility(device_id, slot_id)
	return result if result is Dictionary else {"ok": false, "message": "部署校验失败。"}


func _on_marker_pressed(slot_id: String) -> void:
	var slot := _get_slot(slot_id)
	if slot.is_empty() or not bool(slot.get("unlocked", false)):
		return
	_open_slot(slot_id)


func _on_deploy_pressed(device_id: String) -> void:
	if _current_slot_id.is_empty():
		return
	var slot_id := _current_slot_id
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("deploy_device"):
		_rebuild_popup()
		return

	var result: Variant = device_system.deploy_device(device_id, slot_id)
	if not result is Dictionary or not bool((result as Dictionary).get("ok", false)):
		var message := (
			str((result as Dictionary).get("message", "系统拒绝了部署请求。"))
			if result is Dictionary
			else "系统没有返回有效部署结果。"
		)
		_refresh_all()
		if _popup != null and _popup.visible:
			_popup_title_label.tooltip_text = message
		return

	_close_popup()
	_refresh_all()


func _position_popup() -> void:
	if _popup == null or not _popup.visible or _current_slot_id.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	var available_width := maxf(1.0, viewport_size.x - POPUP_SCREEN_MARGIN * 2.0)
	var available_height := maxf(1.0, viewport_size.y - POPUP_SCREEN_MARGIN * 2.0)
	_popup.custom_minimum_size.x = minf(POPUP_PREFERRED_WIDTH, available_width)
	var content_minimum := _popup.get_combined_minimum_size()
	_popup.size = Vector2(
		minf(maxf(POPUP_PREFERRED_WIDTH, content_minimum.x), available_width),
		minf(content_minimum.y, minf(POPUP_MAX_HEIGHT, available_height))
	)

	var marker := _markers.get(_current_slot_id) as Button
	var desired_position := (viewport_size - _popup.size) * 0.5
	if marker != null and marker.visible:
		desired_position = marker.position + Vector2(MARKER_SIZE.x + POPUP_MARKER_GAP, -8.0)
		if desired_position.x + _popup.size.x > viewport_size.x - POPUP_SCREEN_MARGIN:
			desired_position.x = marker.position.x - _popup.size.x - POPUP_MARKER_GAP

	var maximum_position := Vector2(
		maxf(POPUP_SCREEN_MARGIN, viewport_size.x - _popup.size.x - POPUP_SCREEN_MARGIN),
		maxf(POPUP_SCREEN_MARGIN, viewport_size.y - _popup.size.y - POPUP_SCREEN_MARGIN)
	)
	_popup.position = desired_position.clamp(
		Vector2(POPUP_SCREEN_MARGIN, POPUP_SCREEN_MARGIN),
		maximum_position
	)


func _get_slot(slot_id: String) -> Dictionary:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("get_slot"):
		return {}
	var result: Variant = device_system.get_slot(slot_id)
	return result if result is Dictionary else {}


func _get_range_multiplier(slot: Dictionary) -> float:
	var modifiers := _as_dictionary(slot.get("effect_modifiers", {}))
	return maxf(0.1, float(modifiers.get("range_multiplier", 1.0)))


func _to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	var value := raw as Dictionary
	return Vector3(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("z", 0.0))
	)


func _as_dictionary(raw: Variant) -> Dictionary:
	return raw if raw is Dictionary else {}


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


func _make_round_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 4
	return style


func _make_popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.052, 0.047, 0.985)
	style.border_color = Color(0.54, 0.42, 0.24, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 10
	return style


func _on_defense_device_state_changed(_snapshot: Dictionary) -> void:
	_refresh_all()


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	if _popup != null and _popup.visible:
		_rebuild_popup()


func _on_building_state_changed(_building_id: String) -> void:
	_refresh_all()


func _on_viewport_size_changed() -> void:
	_position_markers()
	if _popup != null and _popup.visible:
		call_deferred("_position_popup")


func debug_get_marker(slot_id: String) -> Button:
	return _markers.get(slot_id) as Button


func debug_get_marker_snapshot(slot_id: String) -> Dictionary:
	var marker := _markers.get(slot_id) as Button
	var slot := _get_slot(slot_id)
	if marker == null or slot.is_empty():
		return {}
	return {
		"slot_id": slot_id,
		"visible": marker.visible,
		"text": marker.text,
		"tooltip": marker.tooltip_text,
		"position": marker.position,
		"size": marker.size,
		"unlocked": bool(slot.get("unlocked", false)),
		"occupied": bool(slot.get("occupied", false)),
		"required_building_level": int(slot.get("required_building_level", 1)),
		"current_building_level": int(slot.get("current_building_level", 0))
	}


func debug_get_popup_snapshot() -> Dictionary:
	if _popup == null:
		return {}
	return {
		"visible": _popup.visible,
		"position": _popup.position,
		"size": _popup.size,
		"minimum_size": _popup.get_combined_minimum_size(),
		"viewport_size": get_viewport_rect().size,
		"title": _popup_title_label.text if _popup_title_label != null else "",
		"icon_count": _popup_device_grid.get_child_count() if _popup_device_grid != null else 0
	}


func debug_open_slot(slot_id: String) -> bool:
	return _open_slot(slot_id)


func get_current_slot_id() -> String:
	return _current_slot_id


func get_current_slot() -> Dictionary:
	return _get_slot(_current_slot_id) if not _current_slot_id.is_empty() else {}
