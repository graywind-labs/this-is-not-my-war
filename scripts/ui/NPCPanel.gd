extends Control

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const ORDER_PANEL_PATH := "/root/Main/UI/OrderPanel"
const DIALOG_PANEL_PATH := "/root/Main/UI/DialogPanel"
const MEMORY_LOG_BOX_MIN_SIZE := Vector2(0, 132)
const MEMORY_LOG_TEXT_MIN_HEIGHT := 92.0
const DEFAULT_GIFT_MONEY_AMOUNT := 5
const DEFAULT_ATTACK_DAMAGE := 10

var _current_npc_id: String = ""
var _is_sanitizing_gift_money_text := false
var _weapon_select: OptionButton
var _event_log_text: TextEdit
var _witness_log_text: TextEdit
var _experience_label: Label
var _strength_value_label: Label
var _intelligence_value_label: Label
var _strength_point_button: Button
var _intelligence_point_button: Button

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
	_setup_memory_log_boxes()
	_setup_progression_controls()
	_setup_interaction_controls()
	_setup_equipment_controls()
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
	_fill_weapon_select()

	name_label.text = str(npc.get("name", npc_id))
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
		_set_memory_block_text(event_log_label, _event_log_text, "事件库", [])
		if _event_log_text != null:
			_event_log_text.text = "不可用"
		_set_memory_block_text(witness_log_label, _witness_log_text, "见闻库", [])
		if _witness_log_text != null:
			_witness_log_text.text = "不可用"
		_scroll_memory_logs_to_bottom_deferred()
		return

	var event_log: Array = memory_system.get_npc_daily_events(npc_id)
	var witness_log: Array = memory_system.get_npc_witness_events(npc_id)
	_set_memory_block_text(event_log_label, _event_log_text, "事件库", event_log)
	_set_memory_block_text(witness_log_label, _witness_log_text, "见闻库", witness_log)
	_scroll_memory_logs_to_bottom_deferred()


func _update_interaction_controls(npc: Dictionary) -> void:
	var states: Dictionary = npc.get("states", {})
	var is_escaped := bool(states.get("escaped", false))
	var is_recruited := bool(npc.get("recruited", false))
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var has_money := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("money")) >= int(gift_money_spin.value)
	var has_weapon := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("weapons")) >= 1

	gift_money_button.disabled = is_escaped or not has_money
	give_weapon_button.disabled = is_escaped or not is_recruited or not has_weapon or _get_selected_weapon_id().is_empty()
	attack_button.disabled = is_escaped


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
	_event_log_text = _wrap_memory_label(event_log_label, "NPCEventLogBox", "NPCEventLogText", "事件库")
	_witness_log_text = _wrap_memory_label(witness_log_label, "NPCWitnessLogBox", "NPCWitnessLogText", "见闻库")


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


func _set_memory_block_text(title_label: Label, body_text: TextEdit, title: String, events: Array) -> void:
	if title_label != null:
		title_label.text = "%s：%d 条" % [title, events.size()]
	if body_text != null:
		body_text.text = _format_memory_block(events)


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


func _scroll_memory_logs_to_bottom_deferred() -> void:
	call_deferred("_scroll_memory_logs_to_bottom")
	call_deferred("_scroll_memory_logs_to_bottom_after_layout")


func _scroll_memory_logs_to_bottom_after_layout() -> void:
	await get_tree().process_frame
	_scroll_memory_logs_to_bottom()


func _scroll_memory_logs_to_bottom() -> void:
	_scroll_to_bottom(_event_log_text)
	_scroll_to_bottom(_witness_log_text)


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


func _on_attack_pressed() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("apply_damage_to_npc"):
		return
	var result: Dictionary = npc_system.apply_damage_to_npc(_current_npc_id, DEFAULT_ATTACK_DAMAGE, "guard_officer", _get_selected_visibility())
	_show_interaction_result(result, "已造成 %d 点伤害。" % DEFAULT_ATTACK_DAMAGE)
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)
