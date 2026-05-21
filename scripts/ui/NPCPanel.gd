extends Control

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"

var _current_npc_id: String = ""

@onready var name_label: Label = %NPCNameLabel
@onready var job_label: Label = %NPCJobLabel
@onready var hp_label: Label = %NPCHPLabel
@onready var attributes_label: Label = %NPCAttributesLabel
@onready var satiety_label: Label = %NPCSatietyLabel
@onready var fatigue_label: Label = %NPCFatigueLabel
@onready var money_label: Label = %NPCMoneyLabel
@onready var unconscious_label: Label = %NPCUnconsciousLabel
@onready var recruited_label: Label = %NPCRecruitedLabel
@onready var action_label: Label = %NPCActionLabel
@onready var skills_label: Label = %NPCSkillsLabel
@onready var close_button: Button = %NPCPanelCloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_clicked.connect(_on_npc_clicked)
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
		event_bus.building_clicked.connect(_on_building_clicked)


func show_npc(npc_id: String) -> void:
	if npc_id.is_empty():
		_current_npc_id = ""
		visible = false
		return

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.get_npc_ids().has(npc_id):
		_current_npc_id = ""
		visible = false
		return

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		_current_npc_id = ""
		visible = false
		return

	_current_npc_id = npc_id
	var states: Dictionary = npc.get("states", {})

	name_label.text = str(npc.get("name", npc_id))
	job_label.text = _format_specialties(npc_system, npc_id)
	hp_label.text = "HP：%d / %d" % [
		int(states.get("hp", 0)),
		int(states.get("max_hp", 0))
	]
	attributes_label.text = _format_attributes(npc.get("stats", {}))
	satiety_label.text = "饱食度：%d" % int(states.get("satiety", 0))
	fatigue_label.text = "疲劳度：%d" % int(states.get("fatigue", 0))
	money_label.text = "金钱：%d" % int(states.get("money", 0))
	unconscious_label.text = "昏迷：%s" % _format_bool(states.get("unconscious", false))
	recruited_label.text = "已入伍：%s" % _format_bool(npc.get("recruited", false))
	action_label.text = "当前行动：%s" % _format_action(str(states.get("current_action", "idle")))
	skills_label.text = _format_skills(npc_system, npc.get("skills", {}))
	visible = true


func _format_bool(value: Variant) -> String:
	return "是" if bool(value) else "否"


func _format_action(action_id: String) -> String:
	if action_id.is_empty() or action_id == "idle":
		return "待命"
	return action_id


func _format_attributes(raw_stats: Variant) -> String:
	var stats: Dictionary = raw_stats if raw_stats is Dictionary else {}
	return "属性：力量 %d，智力 %d" % [
		int(stats.get("strength", 0)),
		int(stats.get("intelligence", 0))
	]


func _format_specialties(npc_system: Node, npc_id: String) -> String:
	if npc_system == null or not npc_system.has_method("get_npc_specialties"):
		return "专长：无"

	var specialties: Array = npc_system.get_npc_specialties(npc_id, 3)
	if specialties.is_empty():
		return "专长：无"
	return "专长：%s" % "，".join(specialties)


func _format_skills(npc_system: Node, raw_skills: Variant) -> String:
	if not raw_skills is Dictionary or raw_skills.is_empty():
		return "技能熟练度：无"

	var skills: Dictionary = raw_skills
	if npc_system != null and npc_system.has_method("normalize_skills"):
		skills = npc_system.normalize_skills(raw_skills)

	var professional_skill_names: Array = _get_skill_names(
		npc_system,
		"get_professional_skill_names",
		["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程"]
	)
	var weapon_skill_names: Array = _get_skill_names(
		npc_system,
		"get_weapon_skill_names",
		["剑盾", "长杆", "弓", "弩", "骑术"]
	)

	return "职业熟练度：%s\n武器熟练度：%s" % [
		_format_skill_group(skills, professional_skill_names),
		_format_skill_group(skills, weapon_skill_names)
	]


func _get_skill_names(npc_system: Node, method_name: String, fallback: Array) -> Array:
	if npc_system != null and npc_system.has_method(method_name):
		return npc_system.call(method_name)
	return fallback


func _format_skill_group(skills: Dictionary, skill_names: Array) -> String:
	var parts: Array[String] = []
	for skill_name in skill_names:
		parts.append("%s %d" % [str(skill_name), int(skills.get(skill_name, 0))])
	return "，".join(parts)


func _on_npc_clicked(npc_id: String) -> void:
	show_npc(npc_id)


func _on_npc_state_changed(npc_id: String) -> void:
	if npc_id == _current_npc_id:
		show_npc(npc_id)


func _on_building_clicked(_building_id: String) -> void:
	visible = false


func _on_close_pressed() -> void:
	visible = false
