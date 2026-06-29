extends Control

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const ORDER_PANEL_PATH := "/root/Main/UI/OrderPanel"
const DIALOG_PANEL_PATH := "/root/Main/UI/DialogPanel"
const MEMORY_LOG_BOX_MIN_SIZE := Vector2(0, 132)
const MEMORY_LOG_TEXT_MIN_HEIGHT := 92.0
const MEMORY_DETAIL_MAX_SIZE := Vector2(860, 560)
const MEMORY_DETAIL_SCREEN_MARGIN := 48.0
const DEFAULT_GIFT_MONEY_AMOUNT := 5

var _current_npc_id: String = ""
var _is_sanitizing_gift_money_text := false
var _is_filling_strategy_select := false
var _weapon_select: OptionButton
var _strategy_select: OptionButton
var _event_log_text: TextEdit
var _witness_log_text: TextEdit
var _event_log_cache: Array = []
var _witness_log_cache: Array = []
var _memory_detail_overlay: Control
var _memory_detail_panel: PanelContainer
var _memory_detail_title_label: Label
var _memory_detail_text: TextEdit
var _memory_detail_mode := ""
var _diary_label: Label
var _diary_text: TextEdit
var _experience_label: Label
var _strength_value_label: Label
var _intelligence_value_label: Label
var _strength_point_button: Button
var _intelligence_point_button: Button
var _llm_status_label: Label

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
@onready var interaction_result_label: Label = %NPCInteractionResultLabel


func _ready() -> void:
	visible = false
	_setup_memory_log_boxes()
	_setup_header_status_label()
	_setup_progression_controls()
	_setup_interaction_controls()
	_setup_equipment_controls()
	close_button.pressed.connect(_on_close_pressed)
	dialogue_button.pressed.connect(_on_dialogue_pressed)
	assign_button.pressed.connect(_on_order_pressed)
	gift_money_button.pressed.connect(_on_gift_money_pressed)
	give_weapon_button.pressed.connect(_on_give_weapon_pressed)
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
		interaction_result_label.text = ""
		_close_memory_detail_popup()
		return

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.get_npc_ids().has(npc_id):
		_current_npc_id = ""
		visible = false
		interaction_result_label.text = ""
		_close_memory_detail_popup()
		return

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		_current_npc_id = ""
		visible = false
		interaction_result_label.text = ""
		_close_memory_detail_popup()
		return

	var previous_npc_id := _current_npc_id
	_current_npc_id = npc_id
	if previous_npc_id != npc_id:
		interaction_result_label.text = ""
	var states: Dictionary = npc.get("states", {})
	_fill_weapon_select()
	_fill_strategy_select()

	name_label.text = str(npc.get("name", npc_id))
	_update_llm_status_label(states)
	job_label.text = _format_specialties(npc_system, npc_id)
	hp_label.text = "HP：%d / %d" % [
		int(states.get("hp", 0)),
		int(states.get("max_hp", 0))
	]
	attributes_label.text = "属性："
	_update_progression_controls(npc_system, npc)
	satiety_label.text = "饱食度：%d" % int(states.get("satiety", 0))
	fatigue_label.text = "疲劳度：%d" % int(states.get("fatigue", 0))
	money_label.text = "金钱：%d" % int(states.get("money", 0))
	equipment_label.text = "当前装备：%s" % _format_equipment(npc.get("equipment", {}))
	unconscious_label.text = "昏迷：%s" % _format_bool(states.get("unconscious", false))
	recruited_label.text = "已入伍：%s" % _format_bool(npc.get("recruited", false))
	assign_button.visible = bool(npc.get("recruited", false))
	assign_button.disabled = not bool(npc.get("recruited", false))
	action_label.text = "当前行动：%s｜行为模式：%s" % [
		_format_action(str(states.get("current_action", "idle"))),
		_format_behavior_mode(str(states.get("behavior_mode", "work")))
	]
	skills_label.text = _format_skills(npc_system, npc.get("skills", {}))
	_update_memory_labels(npc_id)
	_update_diary_labels(npc)
	_update_interaction_controls(npc)
	visible = true


func debug_open_memory_detail(mode: String) -> Dictionary:
	if not ["event_log", "witness_log"].has(mode):
		return {"ok": false, "message": "unknown_memory_detail_mode"}
	_open_memory_detail_popup(mode)
	return {
		"ok": _memory_detail_overlay != null and _memory_detail_overlay.visible,
		"mode": mode
	}


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


func _setup_header_status_label() -> void:
	if _llm_status_label != null:
		return
	var header := name_label.get_parent() as HBoxContainer
	if header == null:
		return
	_llm_status_label = Label.new()
	_llm_status_label.name = "NPCLLMStatusLabel"
	_llm_status_label.text = ""
	_llm_status_label.modulate = Color(0.72, 0.86, 1.0, 1.0)
	_llm_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_llm_status_label)
	header.move_child(_llm_status_label, name_label.get_index() + 1)


func _update_llm_status_label(states: Dictionary) -> void:
	if _llm_status_label == null:
		return
	var status_text := _format_llm_status(states)
	_llm_status_label.text = status_text
	_llm_status_label.visible = not status_text.is_empty()
	if status_text == "正在熟睡":
		_llm_status_label.modulate = Color(1.0, 0.42, 0.38, 1.0)
	else:
		_llm_status_label.modulate = Color(0.72, 0.86, 1.0, 1.0)


func _format_llm_status(states: Dictionary) -> String:
	if bool(states.get("first_sleep_summary_active", false)):
		return "正在熟睡"
	var activity: Dictionary = states.get("llm_activity", {}) if (states.get("llm_activity", {}) is Dictionary) else {}
	if not bool(activity.get("active", false)):
		return ""
	var kind := str(activity.get("kind", ""))
	if kind == "first_sleep_summary":
		return "正在熟睡"
	if kind == "plan":
		return "正在计划下一步行动"
	return "正在思考"


func _setup_equipment_controls() -> void:
	var button_row := give_weapon_button.get_parent() as HBoxContainer
	if button_row == null:
		return
	_weapon_select = OptionButton.new()
	_weapon_select.name = "NPCWeaponSelect"
	_weapon_select.custom_minimum_size = Vector2(116, 30)
	_weapon_select.focus_mode = Control.FOCUS_NONE
	_weapon_select.tooltip_text = "选择要从武器库存转换并装备的主武器类型。"
	button_row.add_child(_weapon_select)
	button_row.move_child(_weapon_select, give_weapon_button.get_index())
	give_weapon_button.text = "装备武器"
	give_weapon_button.tooltip_text = "消耗 1 个武器库存，为已入伍 NPC 装备所选主武器。"

	_strategy_select = OptionButton.new()
	_strategy_select.name = "NPCCombatStrategySelect"
	_strategy_select.custom_minimum_size = Vector2(122, 30)
	_strategy_select.focus_mode = Control.FOCUS_NONE
	_strategy_select.tooltip_text = "选择该 NPC 当前兵种在战斗模式中使用的策略。"
	button_row.add_child(_strategy_select)
	button_row.move_child(_strategy_select, give_weapon_button.get_index() + 1)
	_strategy_select.item_selected.connect(_on_strategy_selected)


func _setup_progression_controls() -> void:
	var parent := attributes_label.get_parent() as VBoxContainer
	if parent == null:
		return

	var hp_index := hp_label.get_index()
	parent.remove_child(hp_label)
	var hp_row := HBoxContainer.new()
	hp_row.name = "NPCHPExperienceRow"
	hp_row.add_theme_constant_override("separation", 12)
	parent.add_child(hp_row)
	parent.move_child(hp_row, hp_index)
	hp_row.add_child(hp_label)

	_experience_label = Label.new()
	_experience_label.name = "NPCExperienceLabel"
	_experience_label.text = "经验：0 / 5"
	_experience_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_experience_label)

	var attributes_index := attributes_label.get_index()
	parent.remove_child(attributes_label)
	var row := HBoxContainer.new()
	row.name = "NPCAttributePointRow"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	parent.move_child(row, attributes_index)

	attributes_label.text = "属性："
	row.add_child(attributes_label)

	_strength_value_label = Label.new()
	_strength_value_label.name = "NPCStrengthValueLabel"
	_strength_value_label.text = "力量 0"
	row.add_child(_strength_value_label)

	_strength_point_button = Button.new()
	_strength_point_button.name = "NPCStrengthPointButton"
	_strength_point_button.text = "+1"
	_strength_point_button.tooltip_text = "消耗 1 个未分配技能点，提高力量。"
	_strength_point_button.focus_mode = Control.FOCUS_NONE
	_strength_point_button.visible = false
	_strength_point_button.custom_minimum_size = Vector2(34, 24)
	_strength_point_button.pressed.connect(func() -> void:
		_assign_attribute_point("strength")
	)
	row.add_child(_strength_point_button)

	var separator := Label.new()
	separator.text = "，"
	row.add_child(separator)

	_intelligence_value_label = Label.new()
	_intelligence_value_label.name = "NPCIntelligenceValueLabel"
	_intelligence_value_label.text = "智力 0"
	row.add_child(_intelligence_value_label)

	_intelligence_point_button = Button.new()
	_intelligence_point_button.name = "NPCIntelligencePointButton"
	_intelligence_point_button.text = "+1"
	_intelligence_point_button.tooltip_text = "消耗 1 个未分配技能点，提高智力。"
	_intelligence_point_button.focus_mode = Control.FOCUS_NONE
	_intelligence_point_button.visible = false
	_intelligence_point_button.custom_minimum_size = Vector2(34, 24)
	_intelligence_point_button.pressed.connect(func() -> void:
		_assign_attribute_point("intelligence")
	)
	row.add_child(_intelligence_point_button)


func _format_bool(value: Variant) -> String:
	return "是" if bool(value) else "否"


func _format_action(action_id: String) -> String:
	if action_id.is_empty() or action_id == "idle":
		return "待命"
	return action_id


func _format_behavior_mode(mode: String) -> String:
	match mode:
		"work":
			return "工作"
		"rally":
			return "集结"
		"combat":
			return "战斗"
		"avoid_combat":
			return "避战"
		"unconscious":
			return "昏迷"
		"escaped":
			return "逃离"
		_:
			return mode


func _format_attributes(raw_stats: Variant) -> String:
	var stats: Dictionary = raw_stats if raw_stats is Dictionary else {}
	return "属性：力量 %d，智力 %d" % [
		int(stats.get("strength", 0)),
		int(stats.get("intelligence", 0))
	]


func _update_progression_controls(npc_system: Node, npc: Dictionary) -> void:
	var progression: Dictionary = npc.get("progression", {})
	if npc_system != null and npc_system.has_method("get_npc_progression"):
		progression = npc_system.get_npc_progression(str(npc.get("id", _current_npc_id)))
	var total_experience := int(progression.get("total_experience", 0))
	var unspent_points := int(progression.get("unspent_skill_points", 0))
	var next_point_xp := maxi(1, int(progression.get("next_skill_point_xp", 5)))
	if _experience_label != null:
		_experience_label.text = "经验：%d / %d" % [total_experience % next_point_xp, next_point_xp]
	var stats: Dictionary = npc.get("stats", {})
	var strength := int(stats.get("strength", 0))
	var intelligence := int(stats.get("intelligence", 0))
	if _strength_value_label != null:
		_strength_value_label.text = "力量 %d" % strength
	if _intelligence_value_label != null:
		_intelligence_value_label.text = "智力 %d" % intelligence
	if _strength_point_button != null:
		_strength_point_button.visible = unspent_points > 0 and strength < 10
		_strength_point_button.disabled = not _strength_point_button.visible
	if _intelligence_point_button != null:
		_intelligence_point_button.visible = unspent_points > 0 and intelligence < 10
		_intelligence_point_button.disabled = not _intelligence_point_button.visible


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
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var main_weapon: Dictionary = equipment.get("main_weapon", {})
	if not main_weapon.is_empty():
		parts.append("主武器 %s" % str(main_weapon.get("name", main_weapon.get("id", "未知武器"))))
	for slot in ["helmet", "chest", "bracers", "greaves", "mount"]:
		var item: Dictionary = equipment.get(slot, {})
		if item.is_empty():
			continue
		var slot_name: String = slot
		if equipment_system != null and equipment_system.has_method("get_slot_label"):
			slot_name = str(equipment_system.get_slot_label(slot))
		parts.append("%s %s" % [slot_name, str(item.get("name", item.get("id", "未知装备")))])
	if equipment_system != null and equipment_system.has_method("determine_unit_type") and equipment_system.has_method("get_unit_type_label"):
		var unit_type := str(equipment_system.determine_unit_type(equipment))
		parts.append("战斗定位 %s" % str(equipment_system.get_unit_type_label(unit_type)))
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
		_event_log_cache = []
		_witness_log_cache = []
		_set_memory_block_text(event_log_label, _event_log_text, "事件库", [])
		if _event_log_text != null:
			_event_log_text.text = "不可用"
		_set_memory_block_text(witness_log_label, _witness_log_text, "见闻库", [])
		if _witness_log_text != null:
			_witness_log_text.text = "不可用"
		_refresh_memory_detail_popup()
		_scroll_memory_logs_to_bottom_deferred()
		return

	var event_log: Array = memory_system.get_npc_daily_events(npc_id)
	var witness_log: Array = memory_system.get_npc_witness_events(npc_id)
	_event_log_cache = event_log.duplicate(true)
	_witness_log_cache = witness_log.duplicate(true)
	_set_memory_block_text(event_log_label, _event_log_text, "事件库", event_log)
	_set_memory_block_text(witness_log_label, _witness_log_text, "见闻库", witness_log)
	_refresh_memory_detail_popup()
	_scroll_memory_logs_to_bottom_deferred()


func _update_interaction_controls(npc: Dictionary) -> void:
	var states: Dictionary = npc.get("states", {})
	var is_escaped := bool(states.get("escaped", false))
	var is_deep_sleeping := bool(states.get("first_sleep_summary_active", false))
	var is_recruited := bool(npc.get("recruited", false))
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var has_money := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("money")) >= int(gift_money_spin.value)
	var has_weapon := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("weapons")) >= 1
	var has_strategy_options := _strategy_select != null and _strategy_select.get_item_count() > 0 and not str(_strategy_select.get_item_metadata(0)).is_empty()
	var escape_dialogue_state := _get_escape_dialogue_state(str(npc.get("id", _current_npc_id)))
	var is_escaping := bool(escape_dialogue_state.get("escaping", false))
	var can_escape_dialogue := bool(escape_dialogue_state.get("can_dialogue", false))

	dialogue_button.disabled = is_escaped or is_deep_sleeping or (is_escaping and not can_escape_dialogue)
	dialogue_button.tooltip_text = "逃离挽留轮次已用完。" if is_escaping and not can_escape_dialogue else "打开对话面板。"
	gift_money_button.disabled = is_escaped or not has_money
	give_weapon_button.disabled = is_escaped or not is_recruited or not has_weapon or _get_selected_weapon_id().is_empty()
	if _strategy_select != null:
		_strategy_select.disabled = is_escaped or not is_recruited or not has_strategy_options


func _get_escape_dialogue_state(npc_id: String) -> Dictionary:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or npc_id.is_empty() or not combat_system.has_method("get_escape_intervention_state"):
		return {}
	return combat_system.get_escape_intervention_state(npc_id)


func _get_selected_visibility() -> String:
	var selected := visibility_select.selected
	if selected < 0:
		return "local_public"
	var metadata: Variant = visibility_select.get_item_metadata(selected)
	return str(metadata) if metadata != null else "local_public"


func _fill_weapon_select() -> void:
	if _weapon_select == null:
		return
	var previous_id := _get_selected_weapon_id()
	_weapon_select.clear()
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_weapon_ids"):
		return
	var selected_index := 0
	var weapon_ids: Array = equipment_system.get_weapon_ids()
	for raw_weapon_id in weapon_ids:
		var weapon_id := str(raw_weapon_id)
		var weapon_def: Dictionary = equipment_system.get_weapon_def(weapon_id) if equipment_system.has_method("get_weapon_def") else {}
		var index := _weapon_select.get_item_count()
		_weapon_select.add_item(str(weapon_def.get("name", weapon_id)))
		_weapon_select.set_item_metadata(index, weapon_id)
		if weapon_id == previous_id or (previous_id.is_empty() and weapon_id == "sword_shield"):
			selected_index = index
	if _weapon_select.get_item_count() > 0:
		_weapon_select.select(selected_index)


func _get_selected_weapon_id() -> String:
	if _weapon_select == null or _weapon_select.get_item_count() <= 0:
		return ""
	var metadata: Variant = _weapon_select.get_item_metadata(_weapon_select.selected)
	if metadata != null:
		return str(metadata)
	return ""


func _fill_strategy_select() -> void:
	if _strategy_select == null:
		return
	_is_filling_strategy_select = true
	_strategy_select.clear()
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or _current_npc_id.is_empty() or not combat_system.has_method("get_npc_combat_strategy_options"):
		_strategy_select.add_item("无策略")
		_strategy_select.set_item_metadata(0, "")
		_is_filling_strategy_select = false
		return
	var options: Array = combat_system.get_npc_combat_strategy_options(_current_npc_id)
	if options.is_empty():
		_strategy_select.add_item("无策略")
		_strategy_select.set_item_metadata(0, "")
		_is_filling_strategy_select = false
		return
	var current: Dictionary = combat_system.get_npc_combat_strategy(_current_npc_id) if combat_system.has_method("get_npc_combat_strategy") else {}
	var current_id := str(current.get("id", ""))
	var selected_index := 0
	for raw_option in options:
		var option: Dictionary = raw_option if raw_option is Dictionary else {}
		var strategy_id := str(option.get("id", ""))
		var index := _strategy_select.get_item_count()
		_strategy_select.add_item(str(option.get("label", strategy_id)))
		_strategy_select.set_item_metadata(index, strategy_id)
		if strategy_id == current_id:
			selected_index = index
	_strategy_select.select(selected_index)
	_is_filling_strategy_select = false


func _get_selected_strategy_id() -> String:
	if _strategy_select == null or _strategy_select.get_item_count() <= 0:
		return ""
	var metadata: Variant = _strategy_select.get_item_metadata(_strategy_select.selected)
	if metadata != null:
		return str(metadata)
	return ""


func _show_interaction_result(result: Dictionary, success_text: String) -> void:
	if bool(result.get("ok", false)):
		interaction_result_label.text = success_text
	else:
		interaction_result_label.text = str(result.get("message", "操作失败。"))


func _assign_attribute_point(attribute_name: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("assign_npc_attribute_point"):
		return
	var result: Dictionary = npc_system.assign_npc_attribute_point(_current_npc_id, attribute_name)
	if bool(result.get("ok", false)):
		interaction_result_label.text = "已分配到%s。" % str(result.get("attribute_label", attribute_name))
		show_npc(_current_npc_id)
	else:
		interaction_result_label.text = str(result.get("message", "无法分配技能点。"))


func _setup_memory_log_boxes() -> void:
	var parent := event_log_label.get_parent() as VBoxContainer
	_event_log_text = _wrap_memory_label(event_log_label, "NPCEventLogBox", "NPCEventLogText", "事件库")
	_witness_log_text = _wrap_memory_label(witness_log_label, "NPCWitnessLogBox", "NPCWitnessLogText", "见闻库")
	_connect_memory_log_clicks(event_log_label, _event_log_text, "event_log")
	_connect_memory_log_clicks(witness_log_label, _witness_log_text, "witness_log")
	if parent != null:
		_diary_label = Label.new()
		_diary_label.name = "NPCDiaryLabel"
		parent.add_child(_diary_label)
		_diary_text = _wrap_memory_label(_diary_label, "NPCDiaryBox", "NPCDiaryText", "日记")


func _wrap_memory_label(label: Label, box_name: String, text_name: String, title: String) -> TextEdit:
	if label == null:
		return null
	var parent := label.get_parent() as VBoxContainer
	if parent == null:
		return null
	var insert_index := label.get_index()
	parent.remove_child(label)

	var box := PanelContainer.new()
	box.name = box_name
	box.custom_minimum_size = MEMORY_LOG_BOX_MIN_SIZE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(box)
	parent.move_child(box, insert_index)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	box.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

	label.text = "%s：暂无" % title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)

	var text := TextEdit.new()
	text.name = text_name
	text.text = "暂无"
	text.editable = false
	text.custom_minimum_size = Vector2(0, MEMORY_LOG_TEXT_MIN_HEIGHT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(text)
	return text


func _connect_memory_log_clicks(title_label: Label, body_text: TextEdit, mode: String) -> void:
	if title_label != null:
		title_label.mouse_filter = Control.MOUSE_FILTER_STOP
		title_label.gui_input.connect(func(event: InputEvent) -> void:
			_on_memory_log_gui_input(event, mode)
		)
	if body_text != null:
		body_text.mouse_filter = Control.MOUSE_FILTER_STOP
		body_text.gui_input.connect(func(event: InputEvent) -> void:
			_on_memory_log_gui_input(event, mode)
		)


func _setup_memory_detail_popup() -> void:
	if _memory_detail_overlay != null:
		return
	var ui_root := get_parent()
	if ui_root == null:
		return

	_memory_detail_overlay = Control.new()
	_memory_detail_overlay.name = "NPCMemoryDetailPopup"
	_memory_detail_overlay.visible = false
	_memory_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_memory_detail_overlay.z_index = 80
	_memory_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(_memory_detail_overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "NPCMemoryDetailBackdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.38)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_memory_detail_overlay.add_child(backdrop)

	_memory_detail_panel = PanelContainer.new()
	_memory_detail_panel.name = "NPCMemoryDetailPanel"
	_memory_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_memory_detail_overlay.add_child(_memory_detail_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_memory_detail_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.name = "NPCMemoryDetailHeader"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	_memory_detail_title_label = Label.new()
	_memory_detail_title_label.name = "NPCMemoryDetailTitle"
	_memory_detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_memory_detail_title_label.text = "事件库"
	header.add_child(_memory_detail_title_label)

	var close_detail_button := Button.new()
	close_detail_button.name = "NPCMemoryDetailCloseButton"
	close_detail_button.text = "×"
	close_detail_button.tooltip_text = "关闭"
	close_detail_button.focus_mode = Control.FOCUS_NONE
	close_detail_button.custom_minimum_size = Vector2(34, 30)
	close_detail_button.pressed.connect(_close_memory_detail_popup)
	header.add_child(close_detail_button)

	_memory_detail_text = TextEdit.new()
	_memory_detail_text.name = "NPCMemoryDetailText"
	_memory_detail_text.editable = false
	_memory_detail_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_memory_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_memory_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_memory_detail_text)


func _layout_memory_detail_popup() -> void:
	if _memory_detail_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var width := minf(MEMORY_DETAIL_MAX_SIZE.x, maxf(360.0, viewport_size.x - MEMORY_DETAIL_SCREEN_MARGIN * 2.0))
	var height := minf(MEMORY_DETAIL_MAX_SIZE.y, maxf(320.0, viewport_size.y - MEMORY_DETAIL_SCREEN_MARGIN * 2.0))
	_memory_detail_panel.anchor_left = 0.5
	_memory_detail_panel.anchor_top = 0.5
	_memory_detail_panel.anchor_right = 0.5
	_memory_detail_panel.anchor_bottom = 0.5
	_memory_detail_panel.offset_left = -width / 2.0
	_memory_detail_panel.offset_top = -height / 2.0
	_memory_detail_panel.offset_right = width / 2.0
	_memory_detail_panel.offset_bottom = height / 2.0
	_memory_detail_panel.custom_minimum_size = Vector2(width, height)
	if _memory_detail_text != null:
		_memory_detail_text.custom_minimum_size = Vector2(0.0, maxf(180.0, height - 96.0))


func _open_memory_detail_popup(mode: String) -> void:
	if _current_npc_id.is_empty():
		return
	if _memory_detail_overlay == null:
		_setup_memory_detail_popup()
	if _memory_detail_overlay == null:
		return
	_memory_detail_mode = mode
	_layout_memory_detail_popup()
	_memory_detail_overlay.visible = true
	_refresh_memory_detail_popup()
	if _memory_detail_text != null:
		_memory_detail_text.scroll_vertical = 0


func _close_memory_detail_popup() -> void:
	if _memory_detail_overlay != null:
		_memory_detail_overlay.visible = false


func _refresh_memory_detail_popup() -> void:
	if _memory_detail_overlay == null or not _memory_detail_overlay.visible:
		return
	var events := _event_log_cache if _memory_detail_mode == "event_log" else _witness_log_cache
	var title := "事件库" if _memory_detail_mode == "event_log" else "见闻库"
	if _memory_detail_title_label != null:
		_memory_detail_title_label.text = "%s｜%s｜%d 条" % [
			str(name_label.text),
			title,
			events.size()
		]
	if _memory_detail_text != null:
		_memory_detail_text.text = _format_memory_detail_block(events)


func _format_memory_detail_block(events: Array) -> String:
	if events.is_empty():
		return "暂无"

	var lines: Array[String] = []
	for index in range(events.size()):
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		var summary := str(event.get("summary", "")).strip_edges()
		if summary.is_empty():
			summary = str(event.get("type", "未命名事件"))
		var payload: Variant = event.get("payload", {})
		var payload_text := JSON.stringify(payload, "\t") if payload != null else "{}"
		lines.append("%d. %s %s\n%s\n类型：%s\n地点：%s｜可见性：%s｜重要度：%d\n事件ID：%s\n参与：%s\n目标：%s\nPayload：\n%s" % [
			index + 1,
			_format_event_day(event),
			str(event.get("time", "--:--:--")),
			summary,
			str(event.get("type", "")),
			str(event.get("location_id", "")),
			str(event.get("visibility", "")),
			int(event.get("importance", 0)),
			str(event.get("event_id", "")),
			_format_id_array(event.get("actor_ids", [])),
			_format_id_array(event.get("target_ids", [])),
			payload_text
		])
	return "\n\n".join(lines)


func _format_event_day(event: Dictionary) -> String:
	var day := int(event.get("day", 0))
	return "第%d天" % day if day > 0 else "当天"


func _format_id_array(raw_value: Variant) -> String:
	if not raw_value is Array:
		return "无"
	var values: Array = raw_value
	if values.is_empty():
		return "无"
	var parts: Array[String] = []
	for raw_item in values:
		parts.append(str(raw_item))
	return "，".join(parts)


func _set_memory_block_text(title_label: Label, body_text: TextEdit, title: String, events: Array) -> void:
	if title_label != null:
		title_label.text = "%s：%d 条" % [title, events.size()]
	if body_text != null:
		body_text.text = _format_memory_block(events)


func _update_diary_labels(npc: Dictionary) -> void:
	var diary: Array = npc.get("diary", []) if (npc.get("diary", []) is Array) else []
	if _diary_label != null:
		_diary_label.text = "日记：%d 条" % diary.size()
	if _diary_text != null:
		_diary_text.text = _format_diary_block(diary)
	_scroll_memory_logs_to_bottom_deferred()


func _format_memory_block(events: Array) -> String:
	if events.is_empty():
		return "暂无"

	var lines: Array[String] = []
	for index in range(events.size()):
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		var summary := str(event.get("summary", ""))
		if summary.is_empty():
			summary = str(event.get("type", "未命名事件"))
		lines.append("- %s %s" % [str(event.get("time", "--:--:--")), summary])
	return "\n".join(lines)


func _format_diary_block(diary: Array) -> String:
	if diary.is_empty():
		return "暂无"

	var lines: Array[String] = []
	for raw_entry in diary:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var day := int(entry.get("day", 0))
			var time_text := str(entry.get("time", "--:--:--"))
			var text := str(entry.get("entry", "")).strip_edges()
			var summary := str(entry.get("memory_summary", "")).strip_edges()
			var prefix := "第%d天 %s" % [day, time_text] if day > 0 else time_text
			if summary.is_empty():
				lines.append("- %s %s" % [prefix, text])
			else:
				lines.append("- %s %s\n  记忆摘要：%s" % [prefix, text, summary])
		else:
			lines.append("- %s" % str(raw_entry))
	return "\n".join(lines)


func _scroll_memory_logs_to_bottom_deferred() -> void:
	call_deferred("_scroll_memory_logs_to_bottom")
	call_deferred("_scroll_memory_logs_to_bottom_after_layout")


func _scroll_memory_logs_to_bottom_after_layout() -> void:
	await get_tree().process_frame
	_scroll_memory_logs_to_bottom()


func _scroll_memory_logs_to_bottom() -> void:
	_scroll_to_bottom(_event_log_text)
	_scroll_to_bottom(_witness_log_text)
	_scroll_to_bottom(_diary_text)


func _scroll_to_bottom(text: TextEdit) -> void:
	if text == null:
		return
	text.scroll_vertical = text.get_line_count()
	var scroll_bar := text.get_v_scroll_bar()
	if scroll_bar != null:
		scroll_bar.value = scroll_bar.max_value


func _on_npc_clicked(npc_id: String) -> void:
	show_npc(npc_id)


func _on_npc_state_changed(npc_id: String) -> void:
	if visible and npc_id == _current_npc_id:
		show_npc(npc_id)


func _on_npc_memory_changed(npc_id: String) -> void:
	if npc_id == _current_npc_id:
		_update_memory_labels(npc_id)


func _on_memory_log_gui_input(event: InputEvent, mode: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	accept_event()
	_open_memory_detail_popup(mode)


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
	_close_memory_detail_popup()


func _on_close_pressed() -> void:
	visible = false
	_close_memory_detail_popup()


func _on_dialogue_pressed() -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or _current_npc_id.is_empty():
		return
	var order_panel := get_node_or_null(ORDER_PANEL_PATH)
	if order_panel != null:
		order_panel.visible = false
	var result: Dictionary = dialog_system.start_player_dialogue(_current_npc_id)
	if not bool(result.get("ok", false)):
		interaction_result_label.text = str(result.get("message", "无法开始对话。"))


func _on_order_pressed() -> void:
	var order_panel := get_node_or_null(ORDER_PANEL_PATH)
	if order_panel == null or _current_npc_id.is_empty() or not order_panel.has_method("show_order"):
		return
	var result: Dictionary = order_panel.show_order(_current_npc_id)
	if not bool(result.get("ok", false)):
		interaction_result_label.text = str(result.get("message", "无法打开指令。"))


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
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or _current_npc_id.is_empty() or not equipment_system.has_method("equip_npc_main_weapon"):
		return
	var result: Dictionary = equipment_system.equip_npc_main_weapon(_current_npc_id, _get_selected_weapon_id(), _get_selected_visibility())
	_show_interaction_result(result, "已装备武器：%s。" % str(result.get("unit_type_label", "")))
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)


func _on_strategy_selected(_index: int) -> void:
	if _is_filling_strategy_select:
		return
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var strategy_id := _get_selected_strategy_id()
	if combat_system == null or _current_npc_id.is_empty() or strategy_id.is_empty() or not combat_system.has_method("set_npc_combat_strategy"):
		return
	var result: Dictionary = combat_system.set_npc_combat_strategy(_current_npc_id, strategy_id, _get_selected_visibility())
	var strategy: Dictionary = result.get("strategy", {}) if (result.get("strategy", {}) is Dictionary) else {}
	_show_interaction_result(result, "战斗策略：%s。" % str(strategy.get("label", strategy_id)))
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)
