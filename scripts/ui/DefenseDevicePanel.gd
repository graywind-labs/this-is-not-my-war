extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const PANEL_SCREEN_MARGIN := 16.0
const PANEL_WIDTH := 360.0
const PANEL_HEIGHT := 270.0

var _current_deployment_id := ""
var _name_label: Label
var _value_labels: Dictionary = {}
var _drag_controller


func _ready() -> void:
	visible = false
	_build_panel()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.defense_device_clicked.connect(_on_defense_device_clicked)
		event_bus.defense_device_state_changed.connect(_on_defense_device_state_changed)
		event_bus.npc_clicked.connect(_on_other_world_selection)
		event_bus.building_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("enemy_clicked"):
			event_bus.enemy_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("horse_clicked"):
			event_bus.horse_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("notice_board_clicked"):
			event_bus.notice_board_clicked.connect(_on_simple_world_selection)
		if event_bus.has_signal("merchant_clicked"):
			event_bus.merchant_clicked.connect(_on_simple_world_selection)
		if event_bus.has_signal("world_selection_cleared"):
			event_bus.world_selection_cleared.connect(_hide_panel)
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "DefenseDeviceInfoPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "DefenseDeviceInfoContent"
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.name = "DefenseDevicePanelHeader"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	_name_label = Label.new()
	_name_label.name = "DefenseDeviceNameLabel"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_name_label)
	var close_button := Button.new()
	close_button.name = "DefenseDevicePanelCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, header)
	for field_id in ["hp", "attack", "defense", "penetration", "range", "attack_speed"]:
		var label := Label.new()
		label.name = "DefenseDevice%sLabel" % _pascal_case(field_id)
		content.add_child(label)
		_value_labels[field_id] = label


func show_defense_device(deployment_id: String) -> void:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	var snapshot: Dictionary = (
		device_system.get_deployment(deployment_id)
		if device_system != null and device_system.has_method("get_deployment")
		else {}
	)
	if snapshot.is_empty() or str(snapshot.get("status", "")) != "active" or int(snapshot.get("hp", 0)) <= 0:
		_hide_panel()
		return
	_current_deployment_id = deployment_id
	_refresh(snapshot)
	visible = true
	_fit_to_viewport()


func _refresh(snapshot: Dictionary) -> void:
	var effect: Dictionary = snapshot.get("effect", {}) if snapshot.get("effect", {}) is Dictionary else {}
	_name_label.text = str(snapshot.get("device_name", _current_deployment_id))
	_set_value("hp", "HP：%d / %d" % [int(snapshot.get("hp", 0)), int(snapshot.get("max_hp", 0))])
	_set_value("attack", "攻击：%d" % int(effect.get("damage", 0)))
	_set_value("defense", "防御：%s" % _format_decimal(float(snapshot.get("defense", 0.0))))
	_set_value("penetration", "穿透：%s" % _format_decimal(float(effect.get("penetration", 0.0))))
	_set_value("range", "射程：%s m" % _format_decimal(float(effect.get("range", 0.0)), 2))
	_set_value("attack_speed", "攻速：%s / 秒" % _format_decimal(float(effect.get("attack_speed", 0.0)), 2))


func _set_value(field_id: String, value: String) -> void:
	var label := _value_labels.get(field_id) as Label
	if label != null:
		label.text = value


func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var width := minf(PANEL_WIDTH, maxf(280.0, viewport_size.x - PANEL_SCREEN_MARGIN * 2.0))
	var height := minf(PANEL_HEIGHT, maxf(220.0, viewport_size.y - PANEL_SCREEN_MARGIN * 2.0))
	set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	offset_right = -PANEL_SCREEN_MARGIN
	offset_left = offset_right - width
	offset_top = PANEL_SCREEN_MARGIN
	offset_bottom = offset_top + height


func debug_get_snapshot() -> Dictionary:
	var values := {}
	for raw_id in _value_labels.keys():
		var field_id := str(raw_id)
		var label := _value_labels.get(field_id) as Label
		values[field_id] = label.text if label != null else ""
	return {
		"visible": visible,
		"deployment_id": _current_deployment_id,
		"name": _name_label.text if _name_label != null else "",
		"values": values,
		"has_description": find_child("DefenseDeviceDescription", true, false) != null,
		"has_authority_note": find_child("DefenseDeviceAuthorityNote", true, false) != null
	}


func _on_defense_device_clicked(deployment_id: String) -> void:
	show_defense_device(deployment_id)


func _on_defense_device_state_changed(_snapshot: Dictionary) -> void:
	if not _current_deployment_id.is_empty():
		show_defense_device(_current_deployment_id)


func _on_other_world_selection(_selection_id: String) -> void:
	_hide_panel()


func _on_simple_world_selection() -> void:
	_hide_panel()


func _on_close_pressed() -> void:
	_hide_panel()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("world_selection_cleared"):
		event_bus.world_selection_cleared.emit()


func _hide_panel() -> void:
	visible = false
	_current_deployment_id = ""


func _format_decimal(value: float, decimals: int = 1) -> String:
	var text := ("%%.%df" % decimals) % value
	while text.contains(".") and text.ends_with("0"):
		text = text.left(-1)
	if text.ends_with("."):
		text = text.left(-1)
	return text


func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		if not part.is_empty():
			result += part.left(1).to_upper() + part.substr(1)
	return result
