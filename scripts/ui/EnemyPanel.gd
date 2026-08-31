extends Control


const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const NPCPortraitViewport = preload("res://scripts/ui/NPCPortraitViewport.gd")
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const PANEL_SCREEN_MARGIN := 16.0
const PANEL_WIDTH := 650.0
const PANEL_HEIGHT := 420.0
const PORTRAIT_GAP := 12.0
const PORTRAIT_MIN_WIDTH := 190.0
const PORTRAIT_MAX_WIDTH := 210.0
const PORTRAIT_VIEWPORT_WIDTH_RATIO := 0.11
const PORTRAIT_MIN_HEIGHT := 300.0
const PORTRAIT_MAX_HEIGHT := 420.0
const REFRESH_INTERVAL_SECONDS := 0.10

var _current_enemy_id := ""
var _portrait_view
var _name_label: Label
var _value_labels: Dictionary = {}
var _drag_controller
var _layout_viewport_override := Vector2.ZERO
var _refresh_remaining := 0.0


func _ready() -> void:
	visible = false
	_build_panel()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if event_bus.has_signal("enemy_clicked"):
			event_bus.enemy_clicked.connect(_on_enemy_clicked)
		event_bus.npc_clicked.connect(_on_other_world_selection)
		event_bus.building_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("horse_clicked"):
			event_bus.horse_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("defense_device_clicked"):
			event_bus.defense_device_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("world_selection_cleared"):
			event_bus.world_selection_cleared.connect(_on_world_selection_cleared)
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_fit_to_viewport)
	set_process(false)
	_fit_to_viewport()


func _build_panel() -> void:
	var row := HBoxContainer.new()
	row.name = "EnemyPanelRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", int(PORTRAIT_GAP))
	add_child(row)

	_portrait_view = NPCPortraitViewport.new()
	_portrait_view.name = "EnemyPortraitView"
	_portrait_view.custom_minimum_size = Vector2(PORTRAIT_MIN_WIDTH, PORTRAIT_MIN_HEIGHT)
	_portrait_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait_view)

	var panel := PanelContainer.new()
	panel.name = "EnemyInfoPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "EnemyInfoContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.name = "EnemyPanelHeader"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	_name_label = Label.new()
	_name_label.name = "EnemyNameLabel"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_name_label)
	var close_button := Button.new()
	close_button.name = "EnemyPanelCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, header)

	for field_id in [
		"hp", "unit_type", "weapon", "attack", "defense", "penetration",
		"attack_speed", "attack_range", "move_speed", "current_action"
	]:
		var label := Label.new()
		label.name = "Enemy%sLabel" % _pascal_case(field_id)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
		_value_labels[field_id] = label


func show_enemy(enemy_id: String) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("get_enemy_detail_snapshot"):
		_hide_panel()
		return
	var snapshot: Dictionary = combat_system.get_enemy_detail_snapshot(enemy_id)
	if snapshot.is_empty():
		_hide_panel()
		return
	_current_enemy_id = enemy_id
	_refresh(snapshot)
	visible = true
	_portrait_view.show_enemy(enemy_id)
	_refresh_remaining = REFRESH_INTERVAL_SECONDS
	set_process(true)
	_fit_to_viewport()


func _refresh(snapshot: Dictionary) -> void:
	_name_label.text = str(snapshot.get("name", _current_enemy_id))
	_set_value("hp", "HP：%d / %d" % [int(snapshot.get("hp", 0)), int(snapshot.get("max_hp", 0))])
	_set_value("unit_type", "兵种：%s" % str(snapshot.get("unit_type_label", "--")))
	_set_value("weapon", "武器：%s" % str(snapshot.get("weapon_name", "--")))
	_set_value("attack", "攻击：%d" % int(snapshot.get("attack_power", 0)))
	_set_value("defense", "防御：%d" % int(snapshot.get("defense", 0)))
	_set_value("penetration", "穿透：%s" % _format_decimal(float(snapshot.get("penetration", 0.0))))
	_set_value("attack_speed", "攻速：%s / 秒" % _format_decimal(float(snapshot.get("attack_speed", 0.0)), 2))
	_set_value("attack_range", "射程：%s m" % _format_decimal(float(snapshot.get("attack_range", 0.0)), 2))
	_set_value("move_speed", "移速：%s m/s" % _format_decimal(float(snapshot.get("move_speed", 0.0)), 2))
	_set_value("current_action", "当前行动：%s" % str(snapshot.get("action_label", "--")))


func _set_value(field_id: String, value: String) -> void:
	var label := _value_labels.get(field_id) as Label
	if label != null:
		label.text = value


func _process(delta: float) -> void:
	if not visible or _current_enemy_id.is_empty():
		return
	_refresh_remaining -= delta
	if _refresh_remaining > 0.0:
		return
	_refresh_remaining = REFRESH_INTERVAL_SECONDS
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var snapshot: Dictionary = (
		combat_system.get_enemy_detail_snapshot(_current_enemy_id)
		if combat_system != null and combat_system.has_method("get_enemy_detail_snapshot")
		else {}
	)
	if snapshot.is_empty():
		_hide_panel()
		return
	_refresh(snapshot)


func _fit_to_viewport() -> void:
	var viewport_size := _get_layout_viewport_size()
	var width := minf(PANEL_WIDTH, maxf(440.0, viewport_size.x - PANEL_SCREEN_MARGIN * 2.0))
	var height := minf(PANEL_HEIGHT, maxf(320.0, viewport_size.y - PANEL_SCREEN_MARGIN * 2.0))
	var portrait_width := clampf(
		viewport_size.x * PORTRAIT_VIEWPORT_WIDTH_RATIO,
		PORTRAIT_MIN_WIDTH,
		PORTRAIT_MAX_WIDTH
	)
	var portrait_height := clampf(height, PORTRAIT_MIN_HEIGHT, PORTRAIT_MAX_HEIGHT)
	if _portrait_view != null:
		_portrait_view.custom_minimum_size = Vector2(portrait_width, portrait_height)
	set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	offset_right = -PANEL_SCREEN_MARGIN
	offset_left = offset_right - width
	offset_top = PANEL_SCREEN_MARGIN
	offset_bottom = offset_top + height


func _get_layout_viewport_size() -> Vector2:
	if _layout_viewport_override.x > 0.0 and _layout_viewport_override.y > 0.0:
		return _layout_viewport_override
	return get_viewport_rect().size


func debug_set_layout_viewport_override(viewport_size: Vector2) -> void:
	_layout_viewport_override = viewport_size
	_fit_to_viewport()


func debug_get_snapshot() -> Dictionary:
	var values := {}
	for raw_id in _value_labels.keys():
		var field_id := str(raw_id)
		var label := _value_labels.get(field_id) as Label
		values[field_id] = label.text if label != null else ""
	return {
		"visible": visible,
		"enemy_id": _current_enemy_id,
		"name": _name_label.text if _name_label != null else "",
		"values": values,
		"rect": get_global_rect(),
		"portrait": _portrait_view.debug_get_snapshot() if _portrait_view != null else {},
		"has_authority_note": find_child("EnemyAuthorityNote", true, false) != null,
	}


func _on_enemy_clicked(enemy_id: String) -> void:
	show_enemy(enemy_id)


func _on_other_world_selection(_selection_id: String) -> void:
	_hide_panel()


func _on_world_selection_cleared() -> void:
	_hide_panel()


func _on_close_pressed() -> void:
	_hide_panel()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("world_selection_cleared"):
		event_bus.world_selection_cleared.emit()


func _hide_panel() -> void:
	visible = false
	_current_enemy_id = ""
	set_process(false)
	if _portrait_view != null:
		_portrait_view.hide_preview()


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
