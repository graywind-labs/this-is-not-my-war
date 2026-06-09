extends Control

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const ORDER_PANEL_PATH := "/root/Main/UI/OrderPanel"
const MAX_MEMORY_LINES := 4
const DEFAULT_GIFT_MONEY_AMOUNT := 5
const DEFAULT_ATTACK_DAMAGE := 10

var _current_npc_id: String = ""
var _is_sanitizing_gift_money_text := false

@onready var name_label: Label = %NPCNameLabel
@onready var job_label: Label = %NPCJobLabel
@onready var hp_label: Label = %NPCHPLabel
@onready var attributes_label: Label = %NPCAttributesLabel
@onready var satiety_label: Label = %NPCSatietyLabel
@onready var fatigue_label: Label = %NPCFatigueLabel
@onready var money_label: Label = %NPCMoneyLabel
@onready var equipment_label: Label = %NPCEquipmentLabel
@onready var unconscious_label: Label = %NPCUnconsciousLabel
@onready var recruited_label: Label = %NPCRecruitedLabel
@onready var action_label: Label = %NPCActionLabel
@onready var skills_label: Label = %NPCSkillsLabel
@onready var event_log_label: Label = %NPCEventLogLabel
@onready var witness_log_label: Label = %NPCWitnessLogLabel
@onready var close_button: Button = %NPCPanelCloseButton
@onready var dialogue_button: Button = %NPCDialogueButton
@onready var assign_button: Button = %NPCAssignButton
@onready var visibility_select: OptionButton = %NPCInteractionVisibilitySelect
@onready var gift_money_spin: SpinBox = %NPCGiftMoneySpin
@onready var gift_money_button: Button = %NPCGiftMoneyButton
@onready var give_weapon_button: Button = %NPCGiveWeaponButton
@onready var attack_button: Button = %NPCAttackButton
@onready var interaction_result_label: Label = %NPCInteractionResultLabel


func _ready() -> void:
	visible = false
	_setup_interaction_controls()
	close_button.pressed.connect(_on_close_pressed)
	dialogue_button.pressed.connect(_on_dialogue_pressed)
	assign_button.pressed.connect(_on_order_pressed)
	gift_money_button.pressed.connect(_on_gift_money_pressed)
	give_weapon_button.pressed.connect(_on_give_weapon_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	gift_money_spin.value_changed.connect(_on_gift_money_value_changed)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_clicked.connect(_on_npc_clicked)
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
		event_bus.npc_memory_changed.connect(_on_npc_memory_changed)
		event_bus.building_clicked.connect(_on_building_clicked)
		event_bus.resource_changed.connect(_on_resource_changed)


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
	equipment_label.text = "当前装备：%s" % _format_equipment(npc.get("equipment", {}))
	unconscious_label.text = "昏迷：%s" % _format_bool(states.get("unconscious", false))
	recruited_label.text = "已入伍：%s" % _format_bool(npc.get("recruited", false))
	assign_button.visible = bool(npc.get("recruited", false))
	assign_button.disabled = not bool(npc.get("recruited", false))
	action_label.text = "当前行动：%s" % _format_action(str(states.get("current_action", "idle")))
	skills_label.text = _format_skills(npc_system, npc.get("skills", {}))
	_update_memory_labels(npc_id)
	_update_interaction_controls(npc)
	visible = true


func _setup_interaction_controls() -> void:
	visibility_select.clear()
	visibility_select.add_item("同地点公开", 0)
	visibility_select.set_item_metadata(0, "local_public")
	visibility_select.add_item("私下", 1)
	visibility_select.set_item_metadata(1, "private")
	gift_money_spin.min_value = 1.0
	gift_money_spin.max_value = 20.0
	gift_money_spin.step = 1.0
	gift_money_spin.value = DEFAULT_GIFT_MONEY_AMOUNT
	var gift_money_line_edit := gift_money_spin.get_line_edit()
	if gift_money_line_edit != null:
		gift_money_line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		gift_money_line_edit.text_changed.connect(_on_gift_money_text_changed)
		gift_money_line_edit.gui_input.connect(_on_gift_money_line_edit_gui_input)
	interaction_result_label.text = ""


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


func _format_equipment(raw_equipment: Variant) -> String:
	var equipment: Dictionary = raw_equipment if raw_equipment is Dictionary else {}
	if equipment.is_empty():
		return "无"

	var parts: Array[String] = []
	var main_weapon: Dictionary = equipment.get("main_weapon", {})
	if not main_weapon.is_empty():
		parts.append("主武器 %s" % str(main_weapon.get("name", main_weapon.get("id", "未知武器"))))
	if parts.is_empty():
		return "无"
	return "，".join(parts)


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


func _update_memory_labels(npc_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		event_log_label.text = "事件库：不可用"
		witness_log_label.text = "见闻库：不可用"
		return

	var event_log: Array = memory_system.get_npc_daily_events(npc_id)
	var witness_log: Array = memory_system.get_npc_witness_events(npc_id)
	event_log_label.text = _format_memory_block("事件库", event_log)
	witness_log_label.text = _format_memory_block("见闻库", witness_log)


func _update_interaction_controls(npc: Dictionary) -> void:
	var states: Dictionary = npc.get("states", {})
	var is_escaped := bool(states.get("escaped", false))
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var has_money := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("money")) >= int(gift_money_spin.value)
	var has_weapon := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("weapons")) >= 1

	gift_money_button.disabled = is_escaped or not has_money
	give_weapon_button.disabled = is_escaped or not has_weapon
	attack_button.disabled = is_escaped


func _get_selected_visibility() -> String:
	var selected := visibility_select.selected
	if selected < 0:
		return "local_public"
	var metadata: Variant = visibility_select.get_item_metadata(selected)
	return str(metadata) if metadata != null else "local_public"


func _show_interaction_result(result: Dictionary, success_text: String) -> void:
	if bool(result.get("ok", false)):
		interaction_result_label.text = success_text
	else:
		interaction_result_label.text = str(result.get("message", "操作失败。"))


func _format_memory_block(title: String, events: Array) -> String:
	if events.is_empty():
		return "%s：暂无" % title

	var lines: Array[String] = ["%s：%d 条" % [title, events.size()]]
	var start_index := maxi(0, events.size() - MAX_MEMORY_LINES)
	for index in range(start_index, events.size()):
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		var summary := str(event.get("summary", ""))
		if summary.is_empty():
			summary = str(event.get("type", "未命名事件"))
		lines.append("- %s %s" % [str(event.get("time", "--:--:--")), summary])
	return "\n".join(lines)


func _on_npc_clicked(npc_id: String) -> void:
	show_npc(npc_id)


func _on_npc_state_changed(npc_id: String) -> void:
	if visible and npc_id == _current_npc_id:
		show_npc(npc_id)


func _on_npc_memory_changed(npc_id: String) -> void:
	if npc_id == _current_npc_id:
		_update_memory_labels(npc_id)


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	if _current_npc_id.is_empty() or not visible:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var npc: Dictionary = npc_system.get_npc(_current_npc_id)
	if not npc.is_empty():
		_update_interaction_controls(npc)


func _on_building_clicked(_building_id: String) -> void:
	visible = false


func _on_close_pressed() -> void:
	visible = false


func _on_dialogue_pressed() -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or _current_npc_id.is_empty():
		return
	var result: Dictionary = dialog_system.start_player_dialogue(_current_npc_id)
	if bool(result.get("ok", false)):
		visible = false


func _on_order_pressed() -> void:
	var order_panel := get_node_or_null(ORDER_PANEL_PATH)
	if order_panel == null or _current_npc_id.is_empty() or not order_panel.has_method("show_order"):
		return
	var result: Dictionary = order_panel.show_order(_current_npc_id)
	if bool(result.get("ok", false)):
		visible = false


func _on_gift_money_value_changed(_value: float) -> void:
	if _current_npc_id.is_empty() or not visible:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var npc: Dictionary = npc_system.get_npc(_current_npc_id)
	if not npc.is_empty():
		_update_interaction_controls(npc)


func _on_gift_money_text_changed(new_text: String) -> void:
	if _is_sanitizing_gift_money_text:
		return
	var sanitized := _digits_only(new_text)
	var line_edit := gift_money_spin.get_line_edit()
	if line_edit == null:
		return
	if sanitized == new_text:
		return

	_is_sanitizing_gift_money_text = true
	line_edit.text = sanitized
	line_edit.caret_column = sanitized.length()
	_is_sanitizing_gift_money_text = false


func _on_gift_money_line_edit_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	var is_letter_key := (
		key_event.keycode >= KEY_A and key_event.keycode <= KEY_Z
	) or (
		key_event.physical_keycode >= KEY_A and key_event.physical_keycode <= KEY_Z
	)
	if is_letter_key:
		gift_money_spin.get_line_edit().release_focus()


func _digits_only(text: String) -> String:
	var result := ""
	for index in range(text.length()):
		var character := text.substr(index, 1)
		if character >= "0" and character <= "9":
			result += character
	return result


func _on_gift_money_pressed() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("give_money_to_npc"):
		return
	var amount := int(gift_money_spin.value)
	var result: Dictionary = npc_system.give_money_to_npc(_current_npc_id, amount, _get_selected_visibility())
	_show_interaction_result(result, "已赠予 %d 枚第纳尔。" % amount)
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)


func _on_give_weapon_pressed() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("give_placeholder_weapon_to_npc"):
		return
	var result: Dictionary = npc_system.give_placeholder_weapon_to_npc(_current_npc_id, _get_selected_visibility())
	_show_interaction_result(result, "已交给 NPC 一把短剑。")
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)


func _on_attack_pressed() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("apply_damage_to_npc"):
		return
	var result: Dictionary = npc_system.apply_damage_to_npc(_current_npc_id, DEFAULT_ATTACK_DAMAGE, "guard_officer", _get_selected_visibility())
	_show_interaction_result(result, "已造成 %d 点伤害。" % DEFAULT_ATTACK_DAMAGE)
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)
