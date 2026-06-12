extends Control

const GM_ENABLED := true

const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const DAILY_PLAN_SYSTEM_PATH := "/root/Main/Systems/DailyPlanSystem"
const DAILY_REFLECTION_SYSTEM_PATH := "/root/Main/Systems/DailyReflectionSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"

const DEFAULT_LOCATION_IDS := [
	"plaza", "dormitory", "dining_hall", "tavern", "garden", "blacksmith",
	"training_ground", "stable", "chapel", "clinic", "workshop"
]
const DEFAULT_VISIBILITIES := ["private", "local_public"]
const COMMAND_HISTORY_LIMIT := 40
const PANEL_BUTTON_GAP := 8.0
const MIN_USABLE_VIEWPORT_SIZE := Vector2(320.0, 240.0)
const FALLBACK_VIEWPORT_SIZE := Vector2(1280.0, 720.0)

var _gm_button: Button
var _panel: PanelContainer
var _command_input: LineEdit
var _result_text: TextEdit
var _resource_select: OptionButton
var _resource_amount_input: LineEdit
var _building_select: OptionButton
var _building_amount_input: LineEdit
var _npc_select: OptionButton
var _npc_state_key_input: LineEdit
var _npc_state_value_input: LineEdit
var _attribute_select: OptionButton
var _order_text_input: LineEdit
var _proactive_talk_input: LineEdit
var _location_select: OptionButton
var _action_select: OptionButton
var _combat_wave_select: OptionButton
var _equipment_weapon_select: OptionButton
var _equipment_armor_slot_select: OptionButton
var _repair_building_select: OptionButton
var _upgrade_building_select: OptionButton
var _heal_target_select: OptionButton
var _dialogue_text_input: LineEdit
var _notice_input: LineEdit
var _visibility_select: OptionButton
var _memory_amount_input: LineEdit
var _event_type_input: LineEdit
var _day_input: LineEdit
var _hour_input: LineEdit
var _minute_input: LineEdit
var _second_input: LineEdit
var _is_dragging_button := false
var _button_dragged := false
var _drag_offset := Vector2.ZERO
var _history: Array[String] = []


func _ready() -> void:
	visible = GM_ENABLED
	if not GM_ENABLED:
		process_mode = Node.PROCESS_MODE_DISABLED
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	call_deferred("_refresh_options")


func _process(_delta: float) -> void:
	if _panel != null and _panel.visible:
		_position_panel_near_button()


func _build_ui() -> void:
	_gm_button = Button.new()
	_gm_button.name = "GMButton"
	_gm_button.text = "GM"
	_gm_button.tooltip_text = "打开 GM 调试面板"
	_gm_button.custom_minimum_size = Vector2(56, 36)
	_gm_button.position = Vector2(24, 220)
	_gm_button.modulate = Color(1.0, 1.0, 1.0, 0.68)
	_gm_button.focus_mode = Control.FOCUS_NONE
	_gm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_gm_button)
	_gm_button.pressed.connect(_on_gm_button_pressed)
	_gm_button.gui_input.connect(_on_gm_button_gui_input)

	_panel = PanelContainer.new()
	_panel.name = "GMWindow"
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.custom_minimum_size = Vector2(620, 440)
	_panel.size = _panel.custom_minimum_size
	_panel.position = Vector2(72, 72)
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	var title := Label.new()
	title.text = "GM 调试面板"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.focus_mode = Control.FOCUS_NONE
	refresh_button.pressed.connect(_refresh_options)
	header.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func() -> void:
		_panel.visible = false
	)
	header.add_child(close_button)

	var command_row := HBoxContainer.new()
	content.add_child(command_row)

	_command_input = LineEdit.new()
	_command_input.placeholder_text = "输入 GM 命令，例如 help / add_resource money 20 / memory cook_01"
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.text_submitted.connect(func(_text: String) -> void:
		_execute_command_from_input()
	)
	command_row.add_child(_command_input)

	var execute_button := Button.new()
	execute_button.text = "执行"
	execute_button.focus_mode = Control.FOCUS_NONE
	execute_button.pressed.connect(_execute_command_from_input)
	command_row.add_child(execute_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(596, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 10)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sections)

	_add_resource_section(sections)
	_add_time_section(sections)
	_add_building_section(sections)
	_add_npc_section(sections)
	_add_action_section(sections)
	_add_combat_section(sections)
	_add_backend_section(sections)
	_add_memory_section(sections)

	_result_text = TextEdit.new()
	_result_text.editable = false
	_result_text.custom_minimum_size = Vector2(596, 90)
	_result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_result_text)
	_log("GM 面板已就绪。输入 help 查看命令。")


func _add_resource_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("资源"))
	var row := _make_row(parent)
	_resource_select = _make_select(row)
	_resource_amount_input = _make_input(row, "数量", "20", 80)
	_add_button(row, "增加", func() -> void:
		_run_add_resource(_selected_id(_resource_select), _int_from_input(_resource_amount_input, 0))
	)
	_add_button(row, "扣除", func() -> void:
		_run_spend_resource(_selected_id(_resource_select), _int_from_input(_resource_amount_input, 0))
	)
	_add_button(row, "快照", _show_resource_snapshot)


func _add_time_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("时间"))
	var row := _make_row(parent)
	_day_input = _make_input(row, "天", "1", 54)
	_hour_input = _make_input(row, "时", "6", 54)
	_minute_input = _make_input(row, "分", "0", 54)
	_second_input = _make_input(row, "秒", "0", 54)
	_add_button(row, "设置", func() -> void:
		_run_set_time(
			_int_from_input(_day_input, 1),
			_int_from_input(_hour_input, 6),
			_int_from_input(_minute_input, 0),
			_int_from_input(_second_input, 0)
		)
	)
	_add_button(row, "跳 1 小时", _run_advance_hour)
	_add_button(row, "LLM 减速", func() -> void:
		_run_slowdown("gm_manual", -1.0, "gm_manual")
	)
	_add_button(row, "清减速", _run_clear_slowdowns)


func _add_building_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("建筑"))
	var row := _make_row(parent)
	_building_select = _make_select(row)
	_building_amount_input = _make_input(row, "数值", "20", 80)
	_add_button(row, "选中", func() -> void:
		_run_select_building(_selected_id(_building_select))
	)
	_add_button(row, "受损", func() -> void:
		_run_damage_building(_selected_id(_building_select), _int_from_input(_building_amount_input, 0))
	)
	_add_button(row, "修复", func() -> void:
		_run_repair_building(_selected_id(_building_select))
	)
	_add_button(row, "升级", func() -> void:
		_run_upgrade_building(_selected_id(_building_select))
	)
	_add_button(row, "快照", func() -> void:
		_show_building(_selected_id(_building_select))
	)


func _add_npc_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("NPC"))
	var row := _make_row(parent)
	_npc_select = _make_select(row)
	_location_select = _make_select(row)
	_add_button(row, "选中", func() -> void:
		_run_select_npc(_selected_id(_npc_select))
	)
	_add_button(row, "移动到地点", func() -> void:
		_run_move_npc(_selected_id(_npc_select), _selected_id(_location_select))
	)
	_add_button(row, "立即进入", func() -> void:
		_run_enter_location(_selected_id(_npc_select), _selected_id(_location_select))
	)

	var state_row := _make_row(parent)
	_npc_state_key_input = _make_input(state_row, "状态字段", "satiety", 120)
	_npc_state_value_input = _make_input(state_row, "值", "80", 100)
	_add_button(state_row, "设置状态", func() -> void:
		_run_set_npc_state(
			_selected_id(_npc_select),
			_npc_state_key_input.text.strip_edges(),
			_parse_value(_npc_state_value_input.text)
		)
	)
	_add_button(state_row, "NPC 快照", func() -> void:
		_show_npc(_selected_id(_npc_select))
	)
	var recruit_button := _add_button(state_row, "设为入伍", func() -> void:
		_run_recruit_npc(_selected_id(_npc_select))
	)
	recruit_button.name = "RecruitNpcButton"

	var attribute_row := _make_row(parent)
	var attribute_label := Label.new()
	attribute_label.text = "技能点分配"
	attribute_row.add_child(attribute_label)
	_attribute_select = _make_select(attribute_row)
	_attribute_select.name = "AttributeSelect"
	_add_button(attribute_row, "分配属性", func() -> void:
		_run_assign_attribute(_selected_id(_npc_select), _selected_id(_attribute_select))
	)

	var order_row := _make_row(parent)
	_order_text_input = _make_input(order_row, "自然语言指令", "守住城门，但先保证自己安全。", 300)
	_order_text_input.name = "OrderTextInput"
	_add_button(order_row, "发布指令", func() -> void:
		_run_publish_order(_selected_id(_npc_select), _order_text_input.text)
	)
	_add_button(order_row, "查看指令", func() -> void:
		_show_order(_selected_id(_npc_select))
	)
	_add_button(order_row, "重评估请求", _show_plan_reevaluation_request)

	var plan_row := _make_row(parent)
	var plan_label := Label.new()
	plan_label.text = "每日计划"
	plan_row.add_child(plan_label)
	var generate_plan_button := _add_button(plan_row, "生成计划", func() -> void:
		_run_generate_plan(_selected_id(_npc_select))
	)
	generate_plan_button.name = "GeneratePlanButton"
	var execute_plan_button := _add_button(plan_row, "执行当前计划", func() -> void:
		_run_execute_plan(_selected_id(_npc_select))
	)
	execute_plan_button.name = "ExecutePlanButton"
	var show_plan_button := _add_button(plan_row, "查看计划", func() -> void:
		_show_daily_plan(_selected_id(_npc_select))
	)
	show_plan_button.name = "ShowPlanButton"
	var revise_plan_button := _add_button(plan_row, "立即重评估", func() -> void:
		_run_revise_plan(_selected_id(_npc_select), "gm_manual")
	)
	revise_plan_button.name = "RevisePlanButton"

	var reflection_row := _make_row(parent)
	var reflection_label := Label.new()
	reflection_label.text = "首次睡眠总结"
	reflection_row.add_child(reflection_label)
	var reflect_npc_button := _add_button(reflection_row, "首次总结", func() -> void:
		_run_reflect_npc(_selected_id(_npc_select), false)
	)
	reflect_npc_button.name = "ReflectNpcButton"
	var long_memory_button := _add_button(reflection_row, "长期记忆", func() -> void:
		_show_long_memory(_selected_id(_npc_select))
	)
	long_memory_button.name = "LongMemoryButton"
	var last_reflection_button := _add_button(reflection_row, "最近总结", _show_last_reflection)
	last_reflection_button.name = "LastReflectionButton"

	var proactive_row := _make_row(parent)
	_proactive_talk_input = _make_input(proactive_row, "主动交涉开场", "守备官，我想问问我们到底还能守多久？", 340)
	_proactive_talk_input.name = "ProactiveTalkInput"
	_add_button(proactive_row, "主动交涉", func() -> void:
		_run_start_proactive_talk(_selected_id(_npc_select), _proactive_talk_input.text)
	)
	_add_button(proactive_row, "交涉状态", func() -> void:
		_show_proactive_talk(_selected_id(_npc_select))
	)

	var equipment_row := _make_row(parent)
	var weapon_label := Label.new()
	weapon_label.text = "装备"
	equipment_row.add_child(weapon_label)
	_equipment_weapon_select = _make_select(equipment_row)
	_equipment_weapon_select.name = "EquipmentWeaponSelect"
	_equipment_armor_slot_select = _make_select(equipment_row)
	_equipment_armor_slot_select.name = "EquipmentArmorSlotSelect"
	_add_button(equipment_row, "装备武器", func() -> void:
		_run_equip_weapon(_selected_id(_npc_select), _selected_id(_equipment_weapon_select), _selected_id(_visibility_select))
	)
	_add_button(equipment_row, "装备盔甲", func() -> void:
		_run_equip_armor(_selected_id(_npc_select), _selected_id(_equipment_armor_slot_select), _selected_id(_visibility_select))
	)
	_add_button(equipment_row, "装备坐骑", func() -> void:
		_run_equip_mount(_selected_id(_npc_select), _selected_id(_visibility_select))
	)
	_add_button(equipment_row, "兵种", func() -> void:
		_show_unit_type(_selected_id(_npc_select))
	)


func _add_action_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("行动"))
	var row := _make_row(parent)
	_action_select = _make_select(row)
	_action_select.name = "ActionSelect"
	var assign_action_button := _add_button(row, "指定行动", func() -> void:
		_run_assign_action(_selected_id(_npc_select), _selected_id(_action_select))
	)
	assign_action_button.name = "AssignActionButton"

	var repair_row := _make_row(parent)
	var repair_target_label := Label.new()
	repair_target_label.text = "修复目标"
	repair_row.add_child(repair_target_label)
	_repair_building_select = _make_select(repair_row)
	_repair_building_select.name = "RepairBuildingSelect"
	var assist_button := _add_button(repair_row, "协助修复", func() -> void:
		_run_assist_repair(_selected_id(_npc_select), _selected_id(_repair_building_select))
	)
	assist_button.name = "AssistRepairButton"

	var upgrade_row := _make_row(parent)
	var upgrade_target_label := Label.new()
	upgrade_target_label.text = "升级目标"
	upgrade_row.add_child(upgrade_target_label)
	_upgrade_building_select = _make_select(upgrade_row)
	_upgrade_building_select.name = "UpgradeBuildingSelect"
	var assist_upgrade_button := _add_button(upgrade_row, "协助升级", func() -> void:
		_run_assist_upgrade(_selected_id(_npc_select), _selected_id(_upgrade_building_select))
	)
	assist_upgrade_button.name = "AssistUpgradeButton"

	var heal_row := _make_row(parent)
	var heal_target_label := Label.new()
	heal_target_label.text = "治疗目标"
	heal_row.add_child(heal_target_label)
	_heal_target_select = _make_select(heal_row)
	_heal_target_select.name = "HealTargetSelect"
	var assist_heal_button := _add_button(heal_row, "协助治疗", func() -> void:
		_run_assist_heal(_selected_id(_npc_select), _selected_id(_heal_target_select))
	)
	assist_heal_button.name = "AssistHealButton"


func _add_combat_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("战斗 / 敌人"))
	var row := _make_row(parent)
	_combat_wave_select = _make_select(row)
	_combat_wave_select.name = "CombatWaveSelect"
	var spawn_first_wave_button := _add_button(row, "生成第一波敌人", func() -> void:
		_run_spawn_enemy_wave(1)
	)
	spawn_first_wave_button.name = "SpawnFirstWaveButton"
	_add_button(row, "生成所选波次", func() -> void:
		_run_spawn_enemy_wave(_int_from_selected_id(_combat_wave_select, 1))
	)
	var combat_alarm_button := _add_button(row, "警铃集结", _run_combat_alarm)
	combat_alarm_button.name = "CombatAlarmButton"
	_add_button(row, "敌人快照", _show_combat_snapshot)
	var step_enemy_ai_button := _add_button(row, "推进敌人AI", func() -> void:
		_run_step_enemy_ai(60.0)
	)
	step_enemy_ai_button.name = "StepEnemyAIButton"
	_add_button(row, "清空敌人", _run_clear_enemies)
	var mode_row := _make_row(parent)
	_add_button(mode_row, "行为模式快照", _show_behavior_modes)
	_add_button(mode_row, "模拟避战", func() -> void:
		_run_avoid_npc(_selected_id(_npc_select))
	)
	_add_button(mode_row, "推进集结等待", func() -> void:
		_run_advance_rally_wait(3600.0)
	)


func _add_backend_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("后端 / LLMBridge"))
	var row := _make_row(parent)
	_dialogue_text_input = _make_input(row, "对话文本", "守备官需要你帮忙守住这里。", 300)
	_add_button(row, "健康检查", _run_backend_health)
	_add_button(row, "对话 Mock", func() -> void:
		_run_dialogue_mock(_selected_id(_npc_select), _dialogue_text_input.text, false)
	)
	_add_button(row, "应征 Mock", func() -> void:
		_run_dialogue_mock(_selected_id(_npc_select), _dialogue_text_input.text, true)
	)
	_add_button(row, "LLM 状态", func() -> void:
		_show_llm_state(_selected_id(_npc_select))
	)
	_add_button(row, "最近指令注入", _show_last_npc_context_injection)


func _add_memory_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("记忆 / 见闻 / 广场"))
	var row := _make_row(parent)
	_notice_input = _make_input(row, "公告内容", "今天所有人先吃饭。", 260)
	_add_button(row, "写公告", func() -> void:
		_run_plaza_notice(_notice_input.text)
	)
	_add_button(row, "地点快照", func() -> void:
		_show_location(_selected_id(_location_select))
	)
	_add_button(row, "短期记忆", func() -> void:
		_show_memory(_selected_id(_npc_select))
	)

	var event_row := _make_row(parent)
	_visibility_select = _make_select(event_row)
	_memory_amount_input = _make_input(event_row, "数值", "5", 70)
	_event_type_input = _make_input(event_row, "事件类型", "plaza_status_changed", 170)
	_add_button(event_row, "给钱事件", func() -> void:
		_run_give_money(_selected_id(_npc_select), _int_from_input(_memory_amount_input, 0), _selected_id(_visibility_select))
	)
	_add_button(event_row, "攻击事件", func() -> void:
		_run_attack_npc(_selected_id(_npc_select), _int_from_input(_memory_amount_input, 0), _selected_id(_visibility_select))
	)
	_add_button(event_row, "广场广播", func() -> void:
		_run_public_event(_event_type_input.text.strip_edges(), _selected_id(_npc_select))
	)
	_add_button(event_row, "事件列表", _show_events)


func _make_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _make_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _make_select(row: HBoxContainer) -> OptionButton:
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(150, 30)
	select.focus_mode = Control.FOCUS_NONE
	row.add_child(select)
	return select


func _make_input(row: HBoxContainer, placeholder: String, text: String, width: int) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.text = text
	input.custom_minimum_size = Vector2(width, 30)
	row.add_child(input)
	return input


func _add_button(row: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	row.add_child(button)
	return button


func _refresh_options() -> void:
	_fill_resource_select()
	_fill_building_select()
	_fill_npc_select()
	_fill_attribute_select()
	_fill_action_select()
	_fill_combat_wave_select()
	_fill_equipment_selects()
	_fill_location_select()
	_fill_visibility_select()
	_log("GM 选项已刷新。")


func _fill_resource_select() -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var ids: Array = []
	if resource_system != null and resource_system.has_method("get_resource_ids"):
		ids = resource_system.get_resource_ids()
	_fill_select(_resource_select, ids, func(id: String) -> String:
		if resource_system != null and resource_system.has_method("get_resource_name"):
			return "%s | %s" % [id, resource_system.get_resource_name(id)]
		return id
	)


func _fill_building_select() -> void:
	_fill_building_select_control(_building_select)
	_fill_building_select_control(_repair_building_select)
	_fill_building_select_control(_upgrade_building_select)


func _fill_building_select_control(select: OptionButton) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var ids: Array = []
	if building_system != null and building_system.has_method("get_building_ids"):
		ids = building_system.get_building_ids()
	_fill_select(select, ids, func(id: String) -> String:
		if building_system != null:
			var building: Dictionary = building_system.get_building(id)
			return "%s | %s" % [id, str(building.get("name", id))]
		return id
	)


func _fill_npc_select() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var ids: Array = []
	if npc_system != null and npc_system.has_method("get_npc_ids"):
		ids = npc_system.get_npc_ids()
	_fill_select(_npc_select, ids, func(id: String) -> String:
		if npc_system != null:
			var npc: Dictionary = npc_system.get_npc(id)
			return "%s | %s" % [id, str(npc.get("name", id))]
		return id
	)
	_fill_select(_heal_target_select, ids, func(id: String) -> String:
		if npc_system != null:
			var npc: Dictionary = npc_system.get_npc(id)
			return "%s | %s" % [id, str(npc.get("name", id))]
		return id
	)


func _fill_attribute_select() -> void:
	_fill_select(_attribute_select, ["strength", "intelligence"], func(id: String) -> String:
		if id == "strength":
			return "strength | 力量"
		if id == "intelligence":
			return "intelligence | 智力"
		return id
	)


func _fill_action_select() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var ids: Array = []
	if action_system != null and action_system.has_method("get_action_ids"):
		ids = action_system.get_action_ids()
	_fill_select(_action_select, ids, func(id: String) -> String:
		if action_system != null:
			var action: Dictionary = action_system.get_action(id)
			return "%s | %s" % [id, str(action.get("name", id))]
		return id
	)


func _fill_combat_wave_select() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var ids: Array = []
	if combat_system != null and combat_system.has_method("get_wave_numbers"):
		ids = combat_system.get_wave_numbers()
	_fill_select(_combat_wave_select, ids, func(id: String) -> String:
		var wave_number := int(id)
		if combat_system != null and combat_system.has_method("get_wave_config"):
			var wave: Dictionary = combat_system.get_wave_config(wave_number)
			return "%d | %s" % [wave_number, str(wave.get("name", "第%d波敌人" % wave_number))]
		return id
	)


func _fill_equipment_selects() -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var weapon_ids: Array = []
	var armor_slots: Array = []
	if equipment_system != null:
		if equipment_system.has_method("get_weapon_ids"):
			weapon_ids = equipment_system.get_weapon_ids()
		if equipment_system.has_method("get_armor_slot_ids"):
			armor_slots = equipment_system.get_armor_slot_ids()
	_fill_select(_equipment_weapon_select, weapon_ids, func(id: String) -> String:
		if equipment_system != null and equipment_system.has_method("get_weapon_def"):
			var weapon: Dictionary = equipment_system.get_weapon_def(id)
			return "%s | %s" % [id, str(weapon.get("name", id))]
		return id
	)
	_fill_select(_equipment_armor_slot_select, armor_slots, func(id: String) -> String:
		if equipment_system != null and equipment_system.has_method("get_slot_label"):
			return "%s | %s" % [id, str(equipment_system.get_slot_label(id))]
		return id
	)


func _fill_location_select() -> void:
	_fill_select(_location_select, DEFAULT_LOCATION_IDS, func(id: String) -> String:
		return id
	)


func _fill_visibility_select() -> void:
	_fill_select(_visibility_select, DEFAULT_VISIBILITIES, func(id: String) -> String:
		return id
	)


func _fill_select(select: OptionButton, ids: Array, label_getter: Callable) -> void:
	if select == null:
		return
	var previous_id := _selected_id(select)
	select.clear()
	var selected_index := 0
	for raw_id in ids:
		var id := str(raw_id)
		var index := select.get_item_count()
		select.add_item(str(label_getter.call(id)))
		select.set_item_metadata(index, id)
		if id == previous_id:
			selected_index = index
	if select.get_item_count() > 0:
		select.select(selected_index)


func _selected_id(select: OptionButton) -> String:
	if select == null or select.get_item_count() <= 0:
		return ""
	var metadata: Variant = select.get_item_metadata(select.selected)
	if metadata != null:
		return str(metadata)
	return select.get_item_text(select.selected).split(" | ")[0]


func _execute_command_from_input() -> void:
	var command := _command_input.text.strip_edges()
	if command.is_empty():
		return
	_log("> %s" % command)
	_execute_command(command)
	_command_input.clear()


func _execute_command(command: String) -> void:
	var parts := command.split(" ", false)
	if parts.is_empty():
		return

	var op := str(parts[0]).to_lower()
	match op:
		"help":
			_log(_help_text())
		"refresh":
			_refresh_options()
		"snapshot":
			_show_resource_snapshot()
			_show_combat_snapshot()
			_show_events()
		"add_resource":
			if _require_args(parts, 3, "add_resource <resource_id> <amount>"):
				_run_add_resource(str(parts[1]), int(parts[2]))
		"spend_resource":
			if _require_args(parts, 3, "spend_resource <resource_id> <amount>"):
				_run_spend_resource(str(parts[1]), int(parts[2]))
		"set_time":
			if _require_args(parts, 5, "set_time <day> <hour> <minute> <second>"):
				_run_set_time(int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4]))
		"advance_hour":
			_run_advance_hour()
		"slowdown":
			if parts.size() >= 2:
				var scale := float(parts[2]) if parts.size() >= 3 else -1.0
				var reason := str(parts[3]) if parts.size() >= 4 else "gm_manual"
				_run_slowdown(str(parts[1]), scale, reason)
			else:
				_run_slowdown("gm_manual", -1.0, "gm_manual")
		"release_slowdown":
			if _require_args(parts, 2, "release_slowdown <request_id>"):
				_run_release_slowdown(str(parts[1]))
		"clear_slowdowns":
			_run_clear_slowdowns()
		"select_npc":
			if _require_args(parts, 2, "select_npc <npc_id>"):
				_run_select_npc(str(parts[1]))
		"select_building":
			if _require_args(parts, 2, "select_building <building_id>"):
				_run_select_building(str(parts[1]))
		"move_npc":
			if _require_args(parts, 3, "move_npc <npc_id> <building_id>"):
				_run_move_npc(str(parts[1]), str(parts[2]))
		"enter_location":
			if _require_args(parts, 3, "enter_location <npc_id> <location_id>"):
				_run_enter_location(str(parts[1]), str(parts[2]))
		"set_npc_state":
			if _require_args(parts, 4, "set_npc_state <npc_id> <key> <value>"):
				_run_set_npc_state(str(parts[1]), str(parts[2]), _parse_value(str(parts[3])))
		"recruit_npc":
			if _require_args(parts, 2, "recruit_npc <npc_id>"):
				_run_recruit_npc(str(parts[1]))
		"assign_attribute":
			if _require_args(parts, 3, "assign_attribute <npc_id> <strength|intelligence>"):
				_run_assign_attribute(str(parts[1]), str(parts[2]))
		"publish_order":
			if _require_args(parts, 3, "publish_order <npc_id> <text>"):
				_run_publish_order(str(parts[1]), command.substr(("publish_order %s" % str(parts[1])).length()).strip_edges())
		"order":
			if _require_args(parts, 2, "order <npc_id>"):
				_show_order(str(parts[1]))
		"plan_request":
			_show_plan_reevaluation_request()
		"plan_generate":
			if parts.size() >= 2:
				_run_generate_plan(str(parts[1]))
			else:
				_run_generate_plan("all")
		"plan_generate_rule":
			if parts.size() >= 2:
				_run_generate_rule_plan(str(parts[1]))
			else:
				_run_generate_rule_plan("all")
		"plan_execute":
			if parts.size() >= 2:
				_run_execute_plan(str(parts[1]))
			else:
				_run_execute_plan("all")
		"plan":
			if _require_args(parts, 2, "plan <npc_id>"):
				_show_daily_plan(str(parts[1]))
		"plan_revise":
			if parts.size() >= 2:
				var reason := str(parts[2]) if parts.size() >= 3 else "gm_manual"
				_run_revise_plan(str(parts[1]), reason)
			else:
				_run_revise_plan(_selected_id(_npc_select), "gm_manual")
		"reflect_npc":
			if _require_args(parts, 2, "reflect_npc <npc_id> [force]"):
				var force := parts.size() >= 3 and str(parts[2]).to_lower() in ["force", "true", "1"]
				_run_reflect_npc(str(parts[1]), force)
		"long_memory":
			if _require_args(parts, 2, "long_memory <npc_id>"):
				_show_long_memory(str(parts[1]))
		"reflection_result":
			_show_last_reflection()
		"llm_state":
			if _require_args(parts, 2, "llm_state <npc_id>"):
				_show_llm_state(str(parts[1]))
		"start_proactive":
			if _require_args(parts, 3, "start_proactive <npc_id> <text>"):
				_run_start_proactive_talk(str(parts[1]), command.substr(("start_proactive %s" % str(parts[1])).length()).strip_edges())
		"proactive":
			if _require_args(parts, 2, "proactive <npc_id>"):
				_show_proactive_talk(str(parts[1]))
		"equip_weapon":
			if _require_args(parts, 3, "equip_weapon <npc_id> <weapon_id> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "local_public"
				_run_equip_weapon(str(parts[1]), str(parts[2]), visibility)
		"equip_armor":
			if _require_args(parts, 3, "equip_armor <npc_id> <slot> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "local_public"
				_run_equip_armor(str(parts[1]), str(parts[2]), visibility)
		"equip_mount":
			if _require_args(parts, 2, "equip_mount <npc_id> [visibility]"):
				var visibility := str(parts[2]) if parts.size() >= 3 else "local_public"
				_run_equip_mount(str(parts[1]), visibility)
		"unit_type":
			if _require_args(parts, 2, "unit_type <npc_id>"):
				_show_unit_type(str(parts[1]))
		"assign_action":
			if _require_args(parts, 3, "assign_action <npc_id> <action_id>"):
				_run_assign_action(str(parts[1]), str(parts[2]))
		"work":
			if _require_args(parts, 3, "work <npc_id> <building_id>"):
				_run_work(str(parts[1]), str(parts[2]))
		"train_instructor":
			if _require_args(parts, 2, "train_instructor <npc_id>"):
				_run_training_instructor(str(parts[1]))
		"train_student":
			if _require_args(parts, 2, "train_student <npc_id>"):
				_run_training_student(str(parts[1]))
		"assist_repair":
			if _require_args(parts, 3, "assist_repair <npc_id> <building_id>"):
				_run_assist_repair(str(parts[1]), str(parts[2]))
		"assist_upgrade":
			if _require_args(parts, 3, "assist_upgrade <npc_id> <building_id>"):
				_run_assist_upgrade(str(parts[1]), str(parts[2]))
		"assist_heal":
			if _require_args(parts, 3, "assist_heal <healer_npc_id> <target_npc_id>"):
				_run_assist_heal(str(parts[1]), str(parts[2]))
		"eat":
			if _require_args(parts, 2, "eat <npc_id>"):
				_run_eat(str(parts[1]))
		"sleep":
			if _require_args(parts, 2, "sleep <npc_id>"):
				_run_sleep(str(parts[1]))
		"spawn_wave":
			var spawn_wave_number := int(parts[1]) if parts.size() >= 2 else 1
			_run_spawn_enemy_wave(spawn_wave_number)
		"enemy_wave":
			var enemy_wave_number := int(parts[1]) if parts.size() >= 2 else 1
			_run_spawn_enemy_wave(enemy_wave_number)
		"enemies":
			_show_combat_snapshot()
		"alarm", "rally":
			_run_combat_alarm()
		"step_enemies":
			var step_seconds := float(parts[1]) if parts.size() >= 2 else 60.0
			_run_step_enemy_ai(step_seconds)
		"clear_enemies":
			_run_clear_enemies()
		"behavior_modes":
			_show_behavior_modes()
		"avoid_npc":
			if _require_args(parts, 2, "avoid_npc <npc_id>"):
				_run_avoid_npc(str(parts[1]))
		"advance_rally_wait":
			var rally_seconds := float(parts[1]) if parts.size() >= 2 else 3600.0
			_run_advance_rally_wait(rally_seconds)
		"damage_building":
			if _require_args(parts, 3, "damage_building <building_id> <amount>"):
				_run_damage_building(str(parts[1]), int(parts[2]))
		"repair_building":
			if _require_args(parts, 2, "repair_building <building_id>"):
				_run_repair_building(str(parts[1]))
		"upgrade_building":
			if _require_args(parts, 2, "upgrade_building <building_id>"):
				_run_upgrade_building(str(parts[1]))
		"plaza_notice":
			_run_plaza_notice(command.substr("plaza_notice".length()).strip_edges())
		"backend_health":
			_run_backend_health()
		"dialogue_mock":
			if _require_args(parts, 3, "dialogue_mock <npc_id> <text>"):
				_run_dialogue_mock(str(parts[1]), command.substr(("dialogue_mock %s" % str(parts[1])).length()).strip_edges(), false)
		"dialogue_recruit":
			if _require_args(parts, 3, "dialogue_recruit <npc_id> <text>"):
				_run_dialogue_mock(str(parts[1]), command.substr(("dialogue_recruit %s" % str(parts[1])).length()).strip_edges(), true)
		"last_order_injection":
			_show_last_npc_context_injection()
		"give_money":
			if _require_args(parts, 3, "give_money <npc_id> <amount> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "local_public"
				_run_give_money(str(parts[1]), int(parts[2]), visibility)
		"attack_npc":
			if _require_args(parts, 3, "attack_npc <npc_id> <damage> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "local_public"
				_run_attack_npc(str(parts[1]), int(parts[2]), visibility)
		"damage_npc":
			if _require_args(parts, 3, "damage_npc <npc_id> <damage> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "local_public"
				_run_attack_npc(str(parts[1]), int(parts[2]), visibility)
		"recover_npc":
			if _require_args(parts, 3, "recover_npc <npc_id> <game_seconds>"):
				_run_recover_npc(str(parts[1]), float(parts[2]))
		"memory":
			if _require_args(parts, 2, "memory <npc_id>"):
				_show_memory(str(parts[1]))
		"location":
			if _require_args(parts, 2, "location <location_id>"):
				_show_location(str(parts[1]))
		"events":
			_show_events()
		"plaza_events":
			_show_plaza_events()
		_:
			_log("未知命令：%s。输入 help 查看命令。" % op)


func _require_args(parts: Array, count: int, usage: String) -> bool:
	if parts.size() >= count:
		return true
	_log("参数不足：%s" % usage)
	return false


func _run_add_resource(resource_id: String, amount: int) -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		_log("ResourceSystem 不可用。")
		return
	var ok: bool = resource_system.debug_add_resource(resource_id, amount)
	_log("资源增加 %s %+d：%s，当前=%d" % [resource_id, amount, _ok_text(ok), resource_system.get_resource(resource_id)])


func _run_spend_resource(resource_id: String, amount: int) -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		_log("ResourceSystem 不可用。")
		return
	var ok: bool = resource_system.debug_spend_resources({resource_id: amount})
	_log("资源扣除 %s %d：%s，当前=%d" % [resource_id, amount, _ok_text(ok), resource_system.get_resource(resource_id)])


func _show_resource_snapshot() -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		_log("ResourceSystem 不可用。")
		return
	_log("资源快照：%s" % _compact(resource_system.get_resource_snapshot()))


func _run_set_time(day: int, hour: int, minute: int, second: int) -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.set_current_time(day, hour, minute, second)
	_log("时间已设置为第 %d 天 %02d:%02d:%02d。" % [day, hour, minute, second])


func _run_advance_hour() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.debug_advance_hour()
	_log("已跳过 1 小时。")


func _run_slowdown(request_id: String, scale: float, reason: String) -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.request_time_slowdown(request_id, scale, reason)
	_log("已注册减速请求：%s，有效倍率=%s。" % [request_id, time_system.get_effective_speed_label()])


func _run_release_slowdown(request_id: String) -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.release_time_slowdown(request_id)
	_log("已释放减速请求：%s，有效倍率=%s。" % [request_id, time_system.get_effective_speed_label()])


func _run_clear_slowdowns() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.clear_time_slowdowns()
	_log("已清空所有减速请求。")


func _run_select_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	_log("选中建筑 %s：%s" % [building_id, _ok_text(building_system.debug_select_building(building_id))])


func _run_damage_building(building_id: String, amount: int) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	var ok: bool = building_system.debug_damage_building(building_id, amount)
	_log("建筑受损 %s -%d：%s" % [building_id, amount, _ok_text(ok)])
	_show_building(building_id)


func _run_repair_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	var ok: bool = building_system.repair_building(building_id)
	_log("修复建筑 %s：%s" % [building_id, _ok_text(ok)])
	_show_building(building_id)


func _run_upgrade_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	var ok: bool = building_system.upgrade_building(building_id)
	_log("升级建筑 %s：%s" % [building_id, _ok_text(ok)])
	_show_building(building_id)


func _show_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	_log("建筑快照 %s：%s" % [building_id, _compact(building_system.get_building(building_id))])


func _run_select_npc(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("选中 NPC %s：%s" % [npc_id, _ok_text(npc_system.debug_select_npc(npc_id))])


func _run_move_npc(npc_id: String, building_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("移动 NPC %s -> %s：%s" % [npc_id, building_id, _ok_text(npc_system.debug_move_npc_to_building(npc_id, building_id))])


func _run_enter_location(npc_id: String, location_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("NPC 立即进入 %s -> %s：%s" % [npc_id, location_id, _ok_text(npc_system.debug_enter_location_immediately(npc_id, location_id))])


func _run_set_npc_state(npc_id: String, key: String, value: Variant) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("设置 NPC 状态 %s.%s=%s：%s" % [npc_id, key, str(value), _ok_text(npc_system.set_npc_state_value(npc_id, key, value))])


func _show_npc(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("NPC 快照 %s：%s" % [npc_id, _compact(npc_system.get_npc(npc_id))])


func _run_recruit_npc(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("set_npc_recruited"):
		_log("NPCSystem 入伍接口不可用。")
		return
	var ok: bool = npc_system.set_npc_recruited(npc_id, true)
	_log("设为入伍 %s：%s" % [npc_id, _ok_text(ok)])
	_show_npc(npc_id)


func _run_assign_attribute(npc_id: String, attribute_name: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_assign_attribute_point"):
		_log("NPCSystem 属性分配接口不可用。")
		return
	var result: Dictionary = npc_system.debug_assign_attribute_point(npc_id, attribute_name)
	_log("分配技能点 %s -> %s：%s" % [npc_id, attribute_name, _compact(result)])


func _run_publish_order(npc_id: String, text: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_publish_npc_order"):
		_log("NPCSystem 指令接口不可用。")
		return
	var result: Dictionary = npc_system.debug_publish_npc_order(npc_id, text)
	_log("发布指令 %s：%s" % [npc_id, _compact(result)])


func _show_order(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_current_order"):
		_log("NPCSystem 指令接口不可用。")
		return
	_log("当前指令 %s：%s" % [npc_id, _compact(npc_system.get_current_order(npc_id))])


func _show_plan_reevaluation_request() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_last_plan_reevaluation_request"):
		_log("NPCSystem 计划重评估请求接口不可用。")
		return
	_log("最近计划重评估请求：%s" % _compact(npc_system.get_last_plan_reevaluation_request()))
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if plan_system != null and plan_system.has_method("get_last_reevaluation_result"):
		_log("最近计划重评估结果：%s" % _compact(plan_system.get_last_reevaluation_result()))
	if plan_system != null and plan_system.has_method("get_last_plan_generation_result"):
		_log("最近每日计划生成结果：%s" % _compact(plan_system.get_last_plan_generation_result()))


func _run_generate_plan(npc_id: String) -> void:
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if plan_system == null or not plan_system.has_method("debug_generate_plan"):
		_log("DailyPlanSystem 计划生成接口不可用。")
		return
	var target_id := "all" if npc_id.is_empty() else npc_id
	var result: Dictionary = plan_system.debug_generate_plan(target_id)
	_log("生成每日计划 %s：%s" % [target_id, _compact(result)])


func _run_generate_rule_plan(npc_id: String) -> void:
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if plan_system == null or not plan_system.has_method("debug_generate_rule_plan"):
		_log("DailyPlanSystem 规则计划接口不可用。")
		return
	var target_id := "all" if npc_id.is_empty() else npc_id
	var result: Dictionary = plan_system.debug_generate_rule_plan(target_id)
	_log("生成规则每日计划 %s：%s" % [target_id, _compact(result)])


func _run_execute_plan(npc_id: String) -> void:
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if plan_system == null or not plan_system.has_method("debug_execute_current_plan"):
		_log("DailyPlanSystem 计划执行接口不可用。")
		return
	var target_id := "all" if npc_id.is_empty() else npc_id
	var result: Dictionary = plan_system.debug_execute_current_plan(target_id, true)
	_log("执行当前小时计划 %s：%s" % [target_id, _compact(result)])


func _show_daily_plan(npc_id: String) -> void:
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if plan_system == null or not plan_system.has_method("debug_get_plan"):
		_log("DailyPlanSystem 计划查看接口不可用。")
		return
	_log("每日计划 %s：%s" % [npc_id, _compact(plan_system.debug_get_plan(npc_id))])


func _run_reflect_npc(npc_id: String, force: bool = false) -> void:
	var reflection_system := get_node_or_null(DAILY_REFLECTION_SYSTEM_PATH)
	if reflection_system == null or not reflection_system.has_method("debug_generate_reflection"):
		_log("DailyReflectionSystem 首次睡眠总结接口不可用。")
		return
	var result: Dictionary = reflection_system.debug_generate_reflection(npc_id, force)
	_log("首次睡眠总结 %s：%s" % [npc_id, _compact(result)])


func _show_long_memory(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_long_memory"):
		_log("NPCSystem 长期记忆接口不可用。")
		return
	_log("长期记忆 %s：%s" % [npc_id, _compact(npc_system.get_npc_long_memory(npc_id))])


func _show_last_reflection() -> void:
	var reflection_system := get_node_or_null(DAILY_REFLECTION_SYSTEM_PATH)
	if reflection_system == null or not reflection_system.has_method("get_last_reflection_result"):
		_log("DailyReflectionSystem 最近总结接口不可用。")
		return
	_log("最近首次睡眠总结：%s" % _compact(reflection_system.get_last_reflection_result()))


func _run_revise_plan(npc_id: String, reason: String) -> void:
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if plan_system == null or not plan_system.has_method("debug_request_reevaluation"):
		_log("DailyPlanSystem 计划重评估接口不可用。")
		return
	var result: Dictionary = plan_system.debug_request_reevaluation(npc_id, reason)
	_log("计划重评估 %s：%s" % [npc_id, _compact(result)])


func _run_start_proactive_talk(npc_id: String, text: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_start_proactive_talk"):
		_log("NPCSystem 主动交涉接口不可用。")
		return
	var result: Dictionary = npc_system.debug_start_proactive_talk(npc_id, text)
	_log("主动交涉 %s：%s" % [npc_id, _compact(result)])


func _show_proactive_talk(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_proactive_talk"):
		_log("NPCSystem 主动交涉状态不可用。")
		return
	_log("主动交涉状态 %s：%s" % [npc_id, _compact(npc_system.get_proactive_talk(npc_id))])


func _run_equip_weapon(npc_id: String, weapon_id: String, visibility: String) -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("debug_equip_weapon"):
		_log("EquipmentSystem 武器接口不可用。")
		return
	var result: Dictionary = equipment_system.debug_equip_weapon(npc_id, weapon_id, visibility)
	_log("装备武器 %s -> %s：%s" % [npc_id, weapon_id, _compact(result)])


func _run_equip_armor(npc_id: String, slot: String, visibility: String) -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("debug_equip_armor"):
		_log("EquipmentSystem 盔甲接口不可用。")
		return
	var result: Dictionary = equipment_system.debug_equip_armor(npc_id, slot, visibility)
	_log("装备盔甲 %s -> %s：%s" % [npc_id, slot, _compact(result)])


func _run_equip_mount(npc_id: String, visibility: String) -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("debug_equip_mount"):
		_log("EquipmentSystem 坐骑接口不可用。")
		return
	var result: Dictionary = equipment_system.debug_equip_mount(npc_id, visibility)
	_log("装备坐骑 %s：%s" % [npc_id, _compact(result)])


func _show_unit_type(npc_id: String) -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_npc_unit_type_label"):
		_log("EquipmentSystem 兵种接口不可用。")
		return
	if equipment_system.has_method("get_unit_type_snapshot"):
		_log("兵种 %s：%s" % [npc_id, _compact(equipment_system.get_unit_type_snapshot(npc_id))])
		return
	_log("兵种 %s：%s，装备=%s" % [
		npc_id,
		str(equipment_system.get_npc_unit_type_label(npc_id)),
		_compact(equipment_system.get_equipment_snapshot(npc_id))
	])


func _run_assign_action(npc_id: String, action_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派行动 %s -> %s：%s" % [npc_id, action_id, _ok_text(action_system.debug_assign_action(npc_id, action_id))])


func _run_work(npc_id: String, building_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派工作 %s -> %s：%s" % [npc_id, building_id, _ok_text(action_system.debug_assign_work(npc_id, building_id))])


func _run_training_instructor(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派训练教官 %s：%s" % [npc_id, _ok_text(action_system.debug_assign_action(npc_id, "work_training_instructor"))])


func _run_training_student(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派受训者 %s：%s" % [npc_id, _ok_text(action_system.debug_assign_action(npc_id, "receive_weapon_training"))])


func _run_assist_repair(npc_id: String, building_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("协助修复 %s -> %s：%s" % [npc_id, building_id, _ok_text(action_system.debug_assign_repair_assist(npc_id, building_id))])


func _run_assist_upgrade(npc_id: String, building_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("协助升级 %s -> %s：%s" % [npc_id, building_id, _ok_text(action_system.debug_assign_upgrade_assist(npc_id, building_id))])


func _run_assist_heal(healer_npc_id: String, target_npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_heal_assist"):
		_log("ActionSystem 协助治疗接口不可用。")
		return
	_log("协助治疗 %s -> %s：%s" % [healer_npc_id, target_npc_id, _ok_text(action_system.debug_assign_heal_assist(healer_npc_id, target_npc_id))])


func _run_spawn_enemy_wave(wave_number: int) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_spawn_wave"):
		_log("CombatSystem 敌人生成接口不可用。")
		return
	var result: Dictionary = combat_system.debug_spawn_wave(wave_number)
	_log("生成敌人波次 %d：%s" % [wave_number, _compact(result)])


func _run_clear_enemies() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_clear_enemies"):
		_log("CombatSystem 清空敌人接口不可用。")
		return
	var result: Dictionary = combat_system.debug_clear_enemies()
	_log("清空敌人：%s" % _compact(result))


func _run_combat_alarm() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_trigger_combat_alarm"):
		_log("CombatSystem 警铃集结接口不可用。")
		return
	var result: Dictionary = combat_system.debug_trigger_combat_alarm()
	_log("警铃集结：%s" % _compact(result))


func _show_combat_snapshot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_get_combat_snapshot"):
		_log("CombatSystem 不可用。")
		return
	_log("战斗 / 敌人快照：%s" % _compact(combat_system.debug_get_combat_snapshot()))


func _show_behavior_modes() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_get_behavior_mode_snapshot"):
		_log("NPCSystem 行为模式快照不可用。")
		return
	_log("NPC 行为模式：%s" % _compact(npc_system.debug_get_behavior_mode_snapshot()))


func _run_avoid_npc(npc_id: String) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_trigger_npc_avoidance"):
		_log("CombatSystem 避战调试接口不可用。")
		return
	var result: Dictionary = combat_system.debug_trigger_npc_avoidance(npc_id)
	_log("模拟避战 %s：%s" % [npc_id, _compact(result)])


func _run_advance_rally_wait(game_seconds: float) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_advance_rally_wait"):
		_log("CombatSystem 集结等待推进接口不可用。")
		return
	var result: Dictionary = combat_system.debug_advance_rally_wait(game_seconds)
	_log("推进集结等待 %.1f 秒：%s" % [game_seconds, _compact(result)])


func _run_step_enemy_ai(game_seconds: float) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_step_enemy_ai"):
		_log("CombatSystem 敌人 AI 推进接口不可用。")
		return
	var result: Dictionary = combat_system.debug_step_enemy_ai(game_seconds)
	_log("推进敌人 AI %.1f 秒：%s" % [game_seconds, _compact(result)])


func _run_backend_health() -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("debug_check_health"):
		_log("LLMBridge 不可用。")
		return
	var result: Dictionary = llm_bridge.debug_check_health()
	_log("后端健康检查：%s" % _compact(result))


func _run_dialogue_mock(npc_id: String, text: String, is_recruitment_request: bool) -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("debug_request_dialogue"):
		_log("LLMBridge 对话接口不可用。")
		return
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		clean_text = "守备官需要你帮忙守住这里。"
	var result: Dictionary = llm_bridge.debug_request_dialogue(npc_id, clean_text, is_recruitment_request, "private")
	_log("对话 Mock %s：%s" % [npc_id, _compact(result)])


func _show_last_npc_context_injection() -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("get_last_npc_context_injection"):
		_log("LLMBridge 指令注入快照不可用。")
		return
	_log("最近 NPC LLM 指令注入：%s" % _compact(llm_bridge.get_last_npc_context_injection()))


func _show_llm_state(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
	var snapshot := {
		"npc_id": npc_id,
		"llm_activity": state.get("llm_activity", {}),
		"first_sleep_summary_active": bool(state.get("first_sleep_summary_active", false)),
		"first_sleep_summary_request_id": str(state.get("first_sleep_summary_request_id", "")),
		"pending_plan_reevaluation_after_sleep": state.get("pending_plan_reevaluation_after_sleep", {})
	}
	_log("LLM 状态 %s：%s" % [npc_id, _compact(snapshot)])


func _run_eat(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派吃饭 %s：%s" % [npc_id, _ok_text(action_system.debug_assign_eat(npc_id))])


func _run_sleep(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派睡觉 %s：%s" % [npc_id, _ok_text(action_system.debug_assign_sleep(npc_id))])


func _run_plaza_notice(text: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	memory_system.debug_set_plaza_notice(text)
	_log("广场公告已更新：%s" % text)


func _run_give_money(npc_id: String, amount: int, visibility: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var event: Dictionary = memory_system.debug_record_player_money_given(npc_id, amount, visibility)
	_log("给钱事件：%s" % _compact(event))


func _run_attack_npc(npc_id: String, damage: int, visibility: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_damage_npc"):
		_log("NPCSystem 扣血接口不可用。")
		return
	var result: Dictionary = npc_system.debug_damage_npc(npc_id, damage, visibility)
	_log("NPC 扣血：%s" % _compact(result))


func _run_recover_npc(npc_id: String, game_seconds: float) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_advance_unconscious_recovery"):
		_log("NPCSystem 昏迷恢复接口不可用。")
		return
	var result: Dictionary = npc_system.debug_advance_unconscious_recovery(npc_id, game_seconds)
	_log("NPC 昏迷恢复推进：%s" % _compact(result))


func _run_public_event(event_type: String, subject_npc_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var event: Dictionary = memory_system.debug_broadcast_plaza_event(event_type, subject_npc_id, {"source": "gm_panel"})
	_log("广场广播：%s" % _compact(event))


func _show_memory(npc_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	_log("短期记忆 %s：%s" % [npc_id, _compact(memory_system.debug_get_npc_short_term_memory(npc_id))])


func _show_location(location_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	_log("地点快照 %s：%s" % [location_id, _compact(memory_system.debug_get_location_snapshot(location_id))])


func _show_events() -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var events: Array = memory_system.debug_get_all_events()
	_log("全局事件 %d 条：%s" % [events.size(), _compact(_tail(events, 8))])


func _show_plaza_events() -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var events: Array = memory_system.debug_get_plaza_events()
	_log("广场本地公开事件 %d 条：%s" % [events.size(), _compact(_tail(events, 8))])


func _on_gm_button_pressed() -> void:
	if _button_dragged:
		_button_dragged = false
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_position_panel_near_button()
		_panel.move_to_front()


func _on_gm_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_dragging_button = event.pressed
		if event.pressed:
			_button_dragged = false
			_drag_offset = event.position
		return

	if event is InputEventMouseMotion and _is_dragging_button:
		var motion := event as InputEventMouseMotion
		if motion.relative.length() > 1.0:
			_button_dragged = true
		var viewport_size := _get_usable_viewport_size()
		var next_position := _gm_button.position + motion.relative
		next_position.x = clampf(next_position.x, 0.0, viewport_size.x - _gm_button.size.x)
		next_position.y = clampf(next_position.y, 0.0, viewport_size.y - _gm_button.size.y)
		_gm_button.position = next_position
		if _panel.visible:
			_position_panel_near_button()


func _position_panel_near_button() -> void:
	if _panel == null or _gm_button == null:
		return

	var button_rect := _gm_button.get_global_rect()
	var panel_size := _get_panel_size(_panel)
	var viewport_size := _get_usable_viewport_size()
	var desired_position := Vector2(
		button_rect.position.x,
		button_rect.position.y + button_rect.size.y + PANEL_BUTTON_GAP
	)
	if desired_position.y + panel_size.y > viewport_size.y:
		desired_position.y = button_rect.position.y - panel_size.y - PANEL_BUTTON_GAP

	_panel.global_position = _clamp_panel_position(desired_position, panel_size, viewport_size)


func _get_panel_size(panel: Control) -> Vector2:
	var panel_size := panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel.custom_minimum_size
	return panel_size


func _clamp_panel_position(desired_position: Vector2, panel_size: Vector2, viewport_size: Vector2) -> Vector2:
	var max_x := maxf(0.0, viewport_size.x - panel_size.x)
	var max_y := maxf(0.0, viewport_size.y - panel_size.y)
	return Vector2(
		clampf(desired_position.x, 0.0, max_x),
		clampf(desired_position.y, 0.0, max_y)
	)


func _get_usable_viewport_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < MIN_USABLE_VIEWPORT_SIZE.x or viewport_size.y < MIN_USABLE_VIEWPORT_SIZE.y:
		return FALLBACK_VIEWPORT_SIZE
	return viewport_size


func _int_from_input(input: LineEdit, fallback: int) -> int:
	if input == null:
		return fallback
	var text := input.text.strip_edges()
	if text.is_valid_int():
		return int(text)
	return fallback


func _int_from_selected_id(select: OptionButton, fallback: int) -> int:
	var selected := _selected_id(select)
	if selected.is_valid_int():
		return int(selected)
	return fallback


func _parse_value(text: String) -> Variant:
	var clean := text.strip_edges()
	if clean.to_lower() == "true":
		return true
	if clean.to_lower() == "false":
		return false
	if clean.is_valid_int():
		return int(clean)
	if clean.is_valid_float():
		return float(clean)
	return clean


func _tail(items: Array, max_count: int) -> Array:
	var start := maxi(0, items.size() - max_count)
	return items.slice(start, items.size())


func _compact(value: Variant) -> String:
	var text := JSON.stringify(value)
	if text.length() > 2200:
		return "%s..." % text.substr(0, 2200)
	return text


func _ok_text(ok: bool) -> String:
	return "成功" if ok else "失败"


func _log(message: String) -> void:
	_history.append(message)
	while _history.size() > COMMAND_HISTORY_LIMIT:
		_history.remove_at(0)
	if _result_text != null:
		_result_text.text = "\n".join(_history)
		_result_text.scroll_vertical = _result_text.get_line_count()


func _help_text() -> String:
	return "\n".join([
		"常用命令：",
		"refresh | snapshot | events | plaza_events",
		"add_resource <id> <amount> | spend_resource <id> <amount>",
		"set_time <day> <hour> <minute> <second> | advance_hour",
		"slowdown [id] [scale] [reason] | release_slowdown <id> | clear_slowdowns",
		"backend_health | dialogue_mock <npc_id> <text> | dialogue_recruit <npc_id> <text> | llm_state <npc_id> | last_order_injection",
		"select_npc <npc_id> | select_building <building_id>",
		"move_npc <npc_id> <building_id> | enter_location <npc_id> <location_id>",
		"set_npc_state <npc_id> <key> <value> | recruit_npc <npc_id> | assign_attribute <npc_id> <strength|intelligence>",
		"publish_order <npc_id> <text> | order <npc_id> | plan_request | plan_generate [npc_id|all] | plan_generate_rule [npc_id|all] | plan_execute [npc_id|all] | plan <npc_id> | plan_revise <npc_id> [reason]",
		"reflect_npc <npc_id> [force] | long_memory <npc_id> | reflection_result",
		"start_proactive <npc_id> <text> | proactive <npc_id>",
		"equip_weapon <npc_id> <weapon_id> [visibility] | equip_armor <npc_id> <slot> [visibility] | equip_mount <npc_id> [visibility] | unit_type <npc_id>",
		"assign_action <npc_id> <action_id> | work <npc_id> <building_id> | train_instructor <npc_id> | train_student <npc_id> | assist_repair <npc_id> <building_id> | assist_upgrade <npc_id> <building_id> | assist_heal <healer_npc_id> <target_npc_id> | eat <npc_id> | sleep <npc_id>",
		"alarm | rally | spawn_wave [wave_number] | enemy_wave [wave_number] | enemies | step_enemies [game_seconds] | clear_enemies | behavior_modes | avoid_npc <npc_id> | advance_rally_wait [game_seconds]",
		"damage_building <building_id> <amount> | repair_building <building_id> | upgrade_building <building_id>",
		"plaza_notice <text> | give_money <npc_id> <amount> [visibility] | attack_npc <npc_id> <damage> [visibility]",
		"damage_npc <npc_id> <damage> [visibility] 与 attack_npc 等价，会扣除 HP 并触发昏迷判定。",
		"recover_npc <npc_id> <game_seconds> 会用自然恢复规则推进昏迷恢复。",
		"memory <npc_id> | location <location_id>"
	])
