extends Control

const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"

var _current_building_id: String = ""
var _current_building: Dictionary = {}
var _action_hint_panel: PanelContainer
var _action_hint_label: Label

@onready var name_label: Label = %BuildingNameLabel
@onready var level_label: Label = %BuildingLevelLabel
@onready var hp_label: Label = %BuildingHPLabel
@onready var workstation_label: Label = %BuildingWorkstationLabel
@onready var location_label: Label = %BuildingLocationLabel
@onready var close_button: Button = %BuildingPanelCloseButton
@onready var repair_button: Button = %RepairButton
@onready var upgrade_button: Button = %UpgradeButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	repair_button.mouse_entered.connect(_show_repair_hint)
	repair_button.mouse_exited.connect(_hide_action_hint)
	upgrade_button.mouse_entered.connect(_show_upgrade_hint)
	upgrade_button.mouse_exited.connect(_hide_action_hint)
	_build_action_hint()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.building_clicked.connect(_on_building_clicked)
		event_bus.npc_clicked.connect(_on_npc_clicked)


func _on_building_clicked(building_id: String) -> void:
	show_building(building_id)


func _on_npc_clicked(_npc_id: String) -> void:
	_hide_action_hint()
	visible = false


func show_building(building_id: String) -> void:
	if building_id.is_empty():
		_current_building_id = ""
		_current_building = {}
		_hide_action_hint()
		visible = false
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.get_building_ids().has(building_id):
		_current_building_id = ""
		_current_building = {}
		_hide_action_hint()
		visible = false
		return

	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		_current_building_id = ""
		_current_building = {}
		_hide_action_hint()
		visible = false
		return

	_current_building_id = building_id
	_current_building = building.duplicate(true)
	name_label.text = str(building.get("name", building_id))
	level_label.text = "等级：%d" % int(building.get("level", 1))
	hp_label.text = "HP：%d / %d" % [
		int(building.get("hp", 0)),
		int(building.get("max_hp", 0))
	]
	workstation_label.text = _format_workstations(building.get("workstations", []))
	location_label.text = _format_location_placeholder(building)
	_update_action_buttons(building_system, building_id, building)
	visible = true


func _format_workstations(raw_workstations: Variant) -> String:
	if not raw_workstations is Array or raw_workstations.is_empty():
		return "当前工作位：无"

	var workstations: Array = raw_workstations
	var occupied_count := 0
	var station_lines: Array[String] = []
	for raw_station in workstations:
		if not raw_station is Dictionary:
			continue

		var station: Dictionary = raw_station
		var station_type := str(station.get("type", "unknown"))
		var occupied_by := str(station.get("occupied_by", ""))
		if occupied_by.is_empty() or occupied_by == "<null>":
			occupied_by = "空闲"
		else:
			occupied_count += 1
		station_lines.append("%s：%s" % [station_type, occupied_by])

	var summary := "当前工作位：%d / %d 已占用" % [occupied_count, workstations.size()]
	if station_lines.is_empty():
		return summary
	return "%s\n%s" % [summary, "\n".join(station_lines)]


func _format_location_placeholder(building: Dictionary) -> String:
	var tags: Array = building.get("tags", [])
	var repair_status: Dictionary = building.get("repair_status", {})
	var lines: Array[String] = []
	if tags.is_empty():
		lines.append("地点状态：占位")
	else:
		var tag_labels: Array[String] = []
		for tag in tags:
			tag_labels.append(str(tag))
		lines.append("地点标签：%s" % ", ".join(tag_labels))

	if not repair_status.is_empty():
		lines.append("修复中：%d%%，剩余 %.0f 秒，x%.2f，协助 %d 人" % [
			int(round(float(repair_status.get("progress", 0.0)) * 100.0)),
			float(repair_status.get("remaining_seconds", 0.0)),
			float(repair_status.get("speed_multiplier", 1.0)),
			int(repair_status.get("helper_count", 0))
		])
	return "\n".join(lines)


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "无消耗"

	var parts: Array[String] = []
	for resource_id in cost.keys():
		parts.append("%s x%d" % [_format_resource_name(str(resource_id)), int(cost[resource_id])])
	return ", ".join(parts)


func _format_resource_name(resource_id: String) -> String:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system != null:
		return resource_system.get_resource_name(resource_id)
	return resource_id


func _update_action_buttons(building_system: Node, building_id: String, building: Dictionary) -> void:
	var hp := int(building.get("hp", 0))
	var max_hp := int(building.get("max_hp", 0))
	var repair_status: Dictionary = building.get("repair_status", {})
	var upgrade_config: Dictionary = building.get("upgrade", {})
	var max_level := int(upgrade_config.get("max_level", int(building.get("level", 1))))

	repair_button.disabled = not building_system.can_repair_building(building_id)
	if not repair_status.is_empty():
		repair_button.text = "修复中 %.0f 秒" % float(repair_status.get("remaining_seconds", 0.0))
	else:
		repair_button.text = "修复" if hp < max_hp else "修复（已满）"

	upgrade_button.disabled = not building_system.can_upgrade_building(building_id)
	upgrade_button.text = "升级" if int(building.get("level", 1)) < max_level else "升级（已满）"


func _build_action_hint() -> void:
	_action_hint_panel = PanelContainer.new()
	_action_hint_panel.visible = false
	_action_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_hint_panel.z_index = 100
	add_child(_action_hint_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_action_hint_panel.add_child(margin)

	_action_hint_label = Label.new()
	_action_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_hint_label.custom_minimum_size = Vector2(180.0, 0.0)
	margin.add_child(_action_hint_label)


func _show_repair_hint() -> void:
	_show_action_hint(repair_button, _format_repair_hint())


func _show_upgrade_hint() -> void:
	_show_action_hint(upgrade_button, _format_upgrade_hint())


func _show_action_hint(anchor: Control, text: String) -> void:
	if _action_hint_panel == null or _action_hint_label == null:
		return
	if text.strip_edges().is_empty():
		return

	var viewport_size := get_viewport_rect().size
	_action_hint_label.custom_minimum_size.x = minf(180.0, maxf(24.0, viewport_size.x - 32.0))
	_action_hint_label.text = text
	_action_hint_panel.visible = true
	_action_hint_panel.reset_size()
	_action_hint_panel.size = _action_hint_panel.get_combined_minimum_size()
	_action_hint_panel.global_position = _get_hint_position(anchor)


func _hide_action_hint() -> void:
	if _action_hint_panel != null:
		_action_hint_panel.visible = false


func _get_hint_position(anchor: Control) -> Vector2:
	var viewport_rect := get_viewport_rect()
	var viewport_size := viewport_rect.size
	var margin := 8.0
	var hint_size := _action_hint_panel.size
	if hint_size.x <= 0.0 or hint_size.y <= 0.0:
		hint_size = _action_hint_panel.get_combined_minimum_size()

	var anchor_position := anchor.global_position
	var right_position := anchor_position + Vector2(anchor.size.x + margin, 0.0)
	var left_position := anchor_position - Vector2(hint_size.x + margin, 0.0)
	var next_position := right_position
	if right_position.x + hint_size.x > viewport_size.x - margin and left_position.x >= margin:
		next_position.x = left_position.x

	next_position.x = clampf(next_position.x, margin, maxf(margin, viewport_size.x - hint_size.x - margin))
	next_position.y = clampf(next_position.y, margin, maxf(margin, viewport_size.y - hint_size.y - margin))
	return next_position


func _format_repair_hint() -> String:
	if _current_building.is_empty():
		return ""

	var repair_config: Dictionary = _current_building.get("repair", {})
	var cost: Dictionary = repair_config.get("cost", {})
	var lines: Array[String] = ["修复"]
	lines.append("消耗：%s" % _format_cost(cost))
	if repair_config.is_empty() or cost.is_empty():
		lines.append("条件：该建筑不可修复")
	elif not _current_building.get("repair_status", {}).is_empty():
		lines.append("条件：正在修复中")
	elif int(_current_building.get("hp", 0)) >= int(_current_building.get("max_hp", 0)):
		lines.append("条件：HP 已满")
	elif not _can_afford(cost):
		lines.append("条件：资源不足")
	else:
		lines.append("条件：可执行")
	return "\n".join(lines)


func _format_upgrade_hint() -> String:
	if _current_building.is_empty():
		return ""

	var upgrade_config: Dictionary = _current_building.get("upgrade", {})
	var cost: Dictionary = upgrade_config.get("cost", {})
	var max_level := int(upgrade_config.get("max_level", int(_current_building.get("level", 1))))
	var lines: Array[String] = ["升级"]
	lines.append("消耗：%s" % _format_cost(cost))
	if upgrade_config.is_empty() or cost.is_empty():
		lines.append("条件：该建筑不可升级")
	elif int(_current_building.get("level", 1)) >= max_level:
		lines.append("条件：已达最高等级 Lv.%d" % max_level)
	elif not _can_afford(cost):
		lines.append("条件：资源不足")
	else:
		lines.append("条件：可执行，最高 Lv.%d" % max_level)
	return "\n".join(lines)


func _can_afford(cost: Dictionary) -> bool:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func _on_repair_pressed() -> void:
	if _current_building_id.is_empty():
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.repair_building(_current_building_id):
		show_building(_current_building_id)


func _on_upgrade_pressed() -> void:
	if _current_building_id.is_empty():
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.upgrade_building(_current_building_id):
		show_building(_current_building_id)


func _on_close_pressed() -> void:
	_hide_action_hint()
	visible = false
