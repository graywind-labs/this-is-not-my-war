extends Control

const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"

var _current_building_id: String = ""

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

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.building_clicked.connect(_on_building_clicked)
		event_bus.npc_clicked.connect(_on_npc_clicked)


func _on_building_clicked(building_id: String) -> void:
	show_building(building_id)


func _on_npc_clicked(_npc_id: String) -> void:
	visible = false


func show_building(building_id: String) -> void:
	if building_id.is_empty():
		_current_building_id = ""
		visible = false
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.get_building_ids().has(building_id):
		_current_building_id = ""
		visible = false
		return

	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		_current_building_id = ""
		visible = false
		return

	_current_building_id = building_id
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
	var repair_config: Dictionary = building.get("repair", {})
	var upgrade_config: Dictionary = building.get("upgrade", {})
	var lines: Array[String] = []
	if tags.is_empty():
		lines.append("地点信息：占位，后续接入见闻与生产状态")
	else:
		var tag_labels: Array[String] = []
		for tag in tags:
			tag_labels.append(str(tag))
		lines.append("地点信息：占位，标签 %s" % ", ".join(tag_labels))

	if not repair_config.is_empty():
		lines.append("修复：%s，恢复 %d HP" % [
			_format_cost(repair_config.get("cost", {})),
			int(repair_config.get("hp_restore", 0))
		])
	if not upgrade_config.is_empty():
		lines.append("升级：%s，最高 Lv.%d" % [
			_format_cost(upgrade_config.get("cost", {})),
			int(upgrade_config.get("max_level", int(building.get("level", 1))))
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
	var upgrade_config: Dictionary = building.get("upgrade", {})
	var max_level := int(upgrade_config.get("max_level", int(building.get("level", 1))))

	repair_button.disabled = not building_system.can_repair_building(building_id)
	repair_button.text = "修复" if hp < max_hp else "修复（已满）"

	upgrade_button.disabled = not building_system.can_upgrade_building(building_id)
	upgrade_button.text = "升级" if int(building.get("level", 1)) < max_level else "升级（已满）"


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
	visible = false
