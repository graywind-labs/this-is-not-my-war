extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const DAILY_PLAN_SYSTEM_PATH := "/root/Main/Systems/DailyPlanSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const GAME_STATE_PATH := "/root/GameState"
const ORDER_PANEL_PATH := "/root/Main/UI/OrderPanel"
const DIALOG_PANEL_PATH := "/root/Main/UI/DialogPanel"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"
const PLAYER_DIALOGUE_KINDS: Array[String] = ["player_npc", "escape_intervention"]
const MEMORY_LOG_BOX_MIN_SIZE := Vector2(0, 112)
const MEMORY_LOG_TEXT_MIN_HEIGHT := 72.0
const MEMORY_DETAIL_MAX_SIZE := Vector2(860, 560)
const MEMORY_DETAIL_SCREEN_MARGIN := 48.0
const DEFAULT_GIFT_MONEY_AMOUNT := 5
const DEFAULT_GIFT_WINE_AMOUNT := 1
const PANEL_SCREEN_MARGIN := 16.0
const PANEL_MIN_WIDTH := 380.0
const PANEL_MAX_WIDTH := 440.0
const PANEL_VIEWPORT_WIDTH_RATIO := 0.22
const PANEL_CONTENT_VERTICAL_PADDING := 24.0
const RECRUITMENT_REQUIRED_TOOLTIP := "需先说服该人物应征入伍，才能进行这项操作。"
const EQUIP_WEAPON_TOOLTIP := "消耗 1 件所选具体武器库存。"
const UNEQUIP_WEAPON_TOOLTIP := "收回当前主武器并返还同一具体物品；已分配马匹会自动取消。"
const COMBAT_STRATEGY_TOOLTIP := "选择该 NPC 当前兵种在战斗模式中使用的策略。"
const EQUIP_ARMOR_TOOLTIP := "消耗 1 件所选具体盔甲库存。"
const UNEQUIP_ARMOR_TOOLTIP := "收回当前部位的盔甲并返还同一具体物品。"
const ASSIGN_HORSE_TOOLTIP := "分配一匹成年、未占用且当前在厩的马；NPC 还需持有主武器。"
const UNASSIGN_HORSE_TOOLTIP := "取消该 NPC 当前的马匹分配。"
const RECRUITED_NAME_COLOR := Color(0.64, 0.92, 0.68, 1.0)
const DEFAULT_NAME_COLOR := Color.WHITE
const KNOWLEDGE_SUBJECT_LABELS := {
	"guard_officer": "守备官",
	"player": "守备官",
	"station": "驿站",
	"plaza": "广场",
	"main_hall": "主厅",
	"dormitory": "宿舍",
	"dining_hall": "食堂",
	"warehouse": "仓库",
	"wall": "围墙",
	"front_gate": "城门",
	"back_gate": "后门",
	"tavern": "酒窖",
	"garden": "菜园",
	"blacksmith": "铁匠铺",
	"training_ground": "训练场",
	"stable": "马厩",
	"chapel": "小教堂",
	"clinic": "小诊所",
	"workshop": "工械坊",
	"battlefield": "战场",
	"residents": "驿站众人",
	"staff": "驿站人员",
	"self": "自己"
}
const KNOWLEDGE_RELATION_LABELS := {
	"impression": "印象",
	"trust": "信任",
	"risk": "风险",
	"promise": "承诺",
	"fear": "忧虑",
	"need": "需求",
	"belief": "看法",
	"status": "状态",
	"order_style": "命令方式",
	"daily_pressure": "当日压力",
	"noticed": "留意事项",
	"availability": "可用情况",
	"plan": "计划",
	"role": "职责",
	"relationship": "关系",
	"attitude": "态度",
	"opinion": "看法",
	"condition": "状况",
	"concern": "担忧",
	"intent": "意图",
	"duty": "职责",
	"health": "健康状况",
	"morale": "士气状态",
	"location": "所在位置",
	"knowledge": "认知",
	"work": "工作情况",
	"schedule": "日程安排",
	"resource": "资源情况",
	"safety": "安全状况",
	"readiness": "准备情况",
	"cooperation": "协作情况",
	"priority": "优先事项",
	"tone": "说话态度"
}
const KNOWLEDGE_VALUE_LABELS := {
	"busy": "忙碌",
	"available": "有空",
	"unavailable": "暂不可用",
	"healthy": "健康",
	"injured": "受伤",
	"unconscious": "昏迷",
	"escaped": "已离开驿站",
	"safe": "安全",
	"unsafe": "不安全",
	"high": "高",
	"medium": "中",
	"low": "低",
	"yes": "是",
	"no": "否",
	"true": "是",
	"false": "否"
}
const KNOWLEDGE_DYNAMIC_PREFIX_LABELS := {
	"promise": "承诺",
	"person": "人物",
	"place": "地点",
	"event": "事件",
	"task": "事务",
	"resource": "资源"
}
const KNOWLEDGE_DETAIL_LABELS := {
	"food_after_battle": "战后食物",
	"safe_passage": "安全通行",
	"medical_care": "医疗照看",
	"front_line_rotation": "前线轮换",
	"work_assignment": "工作安排",
	"rest_after_work": "工作后休息"
}
const KNOWLEDGE_KEY_TOKEN_LABELS := {
	"guard": "守卫",
	"officer": "官",
	"station": "驿站",
	"plaza": "广场",
	"main": "主",
	"hall": "厅",
	"dormitory": "宿舍",
	"dining": "用餐",
	"warehouse": "仓库",
	"wall": "围墙",
	"front": "前方",
	"back": "后方",
	"gate": "门",
	"tavern": "酒窖",
	"garden": "菜园",
	"blacksmith": "铁匠",
	"training": "训练",
	"ground": "场",
	"stable": "马厩",
	"chapel": "教堂",
	"clinic": "诊所",
	"workshop": "工械坊",
	"daily": "当日",
	"pressure": "压力",
	"repair": "修复",
	"upgrade": "升级",
	"food": "食物",
	"battle": "战斗",
	"medical": "医疗",
	"care": "照看",
	"work": "工作",
	"rest": "休息",
	"after": "后",
	"before": "前",
	"rotation": "轮换",
	"assignment": "安排",
	"safe": "安全",
	"passage": "通行",
	"resource": "资源",
	"supply": "补给",
	"defense": "防线",
	"readiness": "准备",
	"availability": "可用情况",
	"status": "状态"
}

var _current_npc_id: String = ""
var _is_sanitizing_gift_money_text := false
var _is_sanitizing_gift_wine_text := false
var _is_filling_strategy_select := false
var _weapon_select: OptionButton
var _unequip_weapon_button: Button
var _armor_select: OptionButton
var _armor_equip_button: Button
var _armor_unequip_button: Button
var _horse_select: OptionButton
var _horse_assign_button: Button
var _horse_unassign_button: Button
var _horse_status_label: Label
var _strategy_select: OptionButton
var _event_log_text: TextEdit
var _witness_log_text: TextEdit
var _event_log_cache: Array = []
var _witness_log_cache: Array = []
var _memory_detail_overlay: Control
var _memory_detail_panel: PanelContainer
var _memory_detail_drag_controller
var _memory_detail_title_label: Label
var _memory_detail_text: TextEdit
var _memory_detail_mode := ""
var _memory_detail_scroll_restore_pending := false
var _memory_detail_scroll_restore_generation := 0
var _memory_detail_saved_vertical := 0
var _memory_detail_saved_horizontal := 0
var _memory_detail_saved_mode := ""
var _memory_detail_saved_npc_id := ""
var _memory_detail_initial_bottom_pending := false
var _memory_detail_initial_plan_scroll_pending := false
var _experience_label: Label
var _strength_value_label: Label
var _intelligence_value_label: Label
var _combat_stats_label: Label
var _strength_point_button: Button
var _intelligence_point_button: Button
var _llm_status_label: Label
var _panel_scroll: ScrollContainer
var _panel_fit_queued := false
var _layout_viewport_override := Vector2.ZERO
var _drag_controller

@onready var name_label: Label = %NPCNameLabel
@onready var background_button: Button = %NPCBackgroundButton
@onready var job_label: Label = %NPCJobLabel
@onready var hp_label: Label = %NPCHPLabel
@onready var attributes_label: Label = %NPCAttributesLabel
@onready var satiety_label: Label = %NPCSatietyLabel
@onready var fatigue_label: Label = %NPCFatigueLabel
@onready var money_label: Label = %NPCMoneyLabel
@onready var wine_label: Label = %NPCWineLabel
@onready var equipment_label: Label = %NPCEquipmentLabel
@onready var unconscious_label: Label = %NPCUnconsciousLabel
@onready var recruited_label: Label = %NPCRecruitedLabel
@onready var action_label: Label = %NPCActionLabel
@onready var skills_label: Label = %NPCSkillsLabel
@onready var current_plan_button: Button = %NPCCurrentPlanButton
@onready var diary_button: Button = %NPCDiaryButton
@onready var knowledge_button: Button = %NPCKnowledgeButton
@onready var event_log_label: Label = %NPCEventLogLabel
@onready var witness_log_label: Label = %NPCWitnessLogLabel
@onready var close_button: Button = %NPCPanelCloseButton
@onready var dialogue_button: Button = %NPCDialogueButton
@onready var dialogue_history_button: Button = %NPCDialogueHistoryButton
@onready var dialogue_suspended_dot: Label = %NPCDialogueSuspendedDot
@onready var assign_button: Button = %NPCAssignButton
@onready var visibility_select: OptionButton = %NPCInteractionVisibilitySelect
@onready var gift_money_spin: SpinBox = %NPCGiftMoneySpin
@onready var gift_money_button: Button = %NPCGiftMoneyButton
@onready var gift_wine_spin: SpinBox = %NPCGiftWineSpin
@onready var gift_wine_button: Button = %NPCGiftWineButton
@onready var give_weapon_button: Button = %NPCGiveWeaponButton
@onready var interaction_result_label: Label = %NPCInteractionResultLabel


func _ready() -> void:
	visible = false
	_setup_panel_scroll()
	_setup_memory_log_boxes()
	_setup_header_status_label()
	_setup_progression_controls()
	_setup_interaction_controls()
	_setup_equipment_controls()
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, name_label.get_parent() as Control)
	close_button.pressed.connect(_on_close_pressed)
	background_button.pressed.connect(_on_background_pressed)
	dialogue_button.pressed.connect(_on_dialogue_pressed)
	dialogue_history_button.pressed.connect(_on_dialogue_history_pressed)
	assign_button.pressed.connect(_on_order_pressed)
	gift_money_button.pressed.connect(_on_gift_money_pressed)
	gift_wine_button.pressed.connect(_on_gift_wine_pressed)
	give_weapon_button.pressed.connect(_on_give_weapon_pressed)
	current_plan_button.pressed.connect(_on_current_plan_pressed)
	diary_button.pressed.connect(_on_diary_pressed)
	knowledge_button.pressed.connect(_on_knowledge_pressed)
	gift_money_spin.value_changed.connect(_on_gift_money_value_changed)
	gift_wine_spin.value_changed.connect(_on_gift_wine_value_changed)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_clicked.connect(_on_npc_clicked)
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
		event_bus.npc_memory_changed.connect(_on_npc_memory_changed)
		event_bus.npc_daily_plan_changed.connect(_on_npc_daily_plan_changed)
		event_bus.building_clicked.connect(_on_building_clicked)
		event_bus.resource_changed.connect(_on_resource_changed)
		if event_bus.has_signal("horse_state_changed"):
			event_bus.horse_state_changed.connect(_on_horse_state_changed)
		if event_bus.has_signal("horse_assignment_changed"):
			event_bus.horse_assignment_changed.connect(_on_horse_assignment_changed)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_queue_panel_fit):
		viewport.size_changed.connect(_queue_panel_fit)
	_queue_panel_fit()


func _setup_panel_scroll() -> void:
	var header := name_label.get_parent() as HBoxContainer
	var content := header.get_parent() as VBoxContainer if header != null else null
	if content == null:
		return
	if content.get_parent() is ScrollContainer:
		_panel_scroll = content.get_parent() as ScrollContainer
		return
	var margin := content.get_parent() as MarginContainer
	if margin == null:
		return
	var content_index := content.get_index()
	margin.remove_child(content)
	var scroll := ScrollContainer.new()
	scroll.name = "NPCPanelScroll"
	scroll.layout_mode = 2
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	margin.move_child(scroll, content_index)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_panel_scroll = scroll


func _queue_panel_fit() -> void:
	if _panel_fit_queued:
		return
	_panel_fit_queued = true
	call_deferred("_fit_panel_width")


func debug_set_layout_viewport_override(viewport_size: Vector2) -> void:
	# SceneTree headless tests do not propagate the configured window size through
	# CanvasLayer consistently. Runtime always leaves this override at ZERO.
	_layout_viewport_override = viewport_size
	_queue_panel_fit()


func _get_layout_viewport_size() -> Vector2:
	if _layout_viewport_override.x > 0.0 and _layout_viewport_override.y > 0.0:
		return _layout_viewport_override
	return get_viewport_rect().size


func _fit_panel_width() -> void:
	if not is_inside_tree():
		_panel_fit_queued = false
		return
	var viewport_size := _get_layout_viewport_size()
	var preserved_drag_position: Vector2 = (
		_drag_controller.get_user_position()
		if _drag_controller != null and _drag_controller.has_user_position()
		else Vector2.INF
	)
	var available_height := maxf(1.0, viewport_size.y - PANEL_SCREEN_MARGIN * 2.0)
	var preserved_height := clampf(maxf(1.0, size.y), 1.0, available_height)
	var target_width := clampf(
		viewport_size.x * PANEL_VIEWPORT_WIDTH_RATIO,
		PANEL_MIN_WIDTH,
		PANEL_MAX_WIDTH
	)
	# 纵向信息面板始终保持“高于宽”；极矮窗口下优先保留上下安全边距。
	target_width = minf(target_width, maxf(280.0, available_height - 1.0))
	set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	offset_right = -PANEL_SCREEN_MARGIN
	offset_left = offset_right - target_width
	offset_top = PANEL_SCREEN_MARGIN
	# Preserve the visible height for the layout frame. Expanding to the full
	# viewport here flashes an empty dark block below the panel on every refresh.
	offset_bottom = offset_top + preserved_height
	if preserved_drag_position != Vector2.INF:
		_drag_controller.restore_user_position(preserved_drag_position)
	await get_tree().process_frame
	_fit_panel_height()


func _fit_panel_height() -> void:
	_panel_fit_queued = false
	if not is_inside_tree():
		return
	var header := name_label.get_parent() as HBoxContainer
	var content := header.get_parent() as VBoxContainer if header != null else null
	if content == null:
		return
	var available_height := maxf(1.0, _get_layout_viewport_size().y - PANEL_SCREEN_MARGIN * 2.0)
	var natural_height := content.get_combined_minimum_size().y + PANEL_CONTENT_VERTICAL_PADDING
	var target_height := minf(available_height, natural_height)
	offset_bottom = offset_top + target_height


func show_npc(npc_id: String) -> void:
	if npc_id.is_empty():
		_current_npc_id = ""
		visible = false
		interaction_result_label.text = ""
		interaction_result_label.visible = false
		_close_memory_detail_popup()
		return

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.get_npc_ids().has(npc_id):
		_current_npc_id = ""
		visible = false
		interaction_result_label.text = ""
		interaction_result_label.visible = false
		_close_memory_detail_popup()
		return

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		_current_npc_id = ""
		visible = false
		interaction_result_label.text = ""
		interaction_result_label.visible = false
		_close_memory_detail_popup()
		return

	var previous_npc_id := _current_npc_id
	_current_npc_id = npc_id
	if previous_npc_id != npc_id:
		interaction_result_label.text = ""
		interaction_result_label.visible = false
	var states: Dictionary = npc.get("states", {})
	_fill_weapon_select()
	_fill_armor_select()
	_fill_horse_select(npc)
	_fill_strategy_select()

	name_label.text = str(npc.get("name", npc_id))
	name_label.modulate = RECRUITED_NAME_COLOR if bool(npc.get("recruited", false)) else DEFAULT_NAME_COLOR
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
	wine_label.text = "酒：%d" % int(states.get("wine", 0))
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
	_update_interaction_controls(npc)
	visible = true
	_refresh_memory_detail_popup()
	_queue_panel_fit()


func debug_open_memory_detail(mode: String) -> Dictionary:
	if not [
		"background",
		"current_plan",
		"diary",
		"knowledge",
		"event_log",
		"witness_log",
		"dialogue_history"
	].has(mode):
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
	gift_wine_spin.min_value = 1.0
	gift_wine_spin.max_value = 20.0
	gift_wine_spin.step = 1.0
	gift_wine_spin.value = DEFAULT_GIFT_WINE_AMOUNT
	var gift_wine_line_edit := gift_wine_spin.get_line_edit()
	if gift_wine_line_edit != null:
		gift_wine_line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		gift_wine_line_edit.text_changed.connect(_on_gift_wine_text_changed)
		gift_wine_line_edit.gui_input.connect(_on_gift_wine_line_edit_gui_input)
	interaction_result_label.text = ""
	interaction_result_label.visible = false


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
	_llm_status_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(_llm_status_label)
	header.move_child(_llm_status_label, background_button.get_index() + 1)


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
	var parent := button_row.get_parent() as VBoxContainer
	if parent == null:
		return

	var weapon_row := HBoxContainer.new()
	weapon_row.name = "NPCWeaponRow"
	weapon_row.add_theme_constant_override("separation", 6)
	parent.add_child(weapon_row)
	parent.move_child(weapon_row, button_row.get_index() + 1)
	var weapon_label := Label.new()
	weapon_label.text = "主武器："
	weapon_row.add_child(weapon_label)
	_weapon_select = OptionButton.new()
	_weapon_select.name = "NPCWeaponSelect"
	_weapon_select.custom_minimum_size = Vector2(120, 30)
	_weapon_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_select.focus_mode = Control.FOCUS_NONE
	_weapon_select.tooltip_text = "选择具体主武器；只能消耗同名物品库存。"
	_weapon_select.item_selected.connect(_on_equipment_option_selected)
	weapon_row.add_child(_weapon_select)
	button_row.remove_child(give_weapon_button)
	weapon_row.add_child(give_weapon_button)
	give_weapon_button.text = "装备武器"
	give_weapon_button.tooltip_text = EQUIP_WEAPON_TOOLTIP
	_unequip_weapon_button = Button.new()
	_unequip_weapon_button.name = "NPCUnequipWeaponButton"
	_unequip_weapon_button.text = "收回武器"
	_unequip_weapon_button.focus_mode = Control.FOCUS_NONE
	_unequip_weapon_button.tooltip_text = UNEQUIP_WEAPON_TOOLTIP
	_unequip_weapon_button.pressed.connect(_on_unequip_weapon_pressed)
	weapon_row.add_child(_unequip_weapon_button)

	var strategy_row := HBoxContainer.new()
	strategy_row.name = "NPCCombatStrategyRow"
	strategy_row.add_theme_constant_override("separation", 6)
	parent.add_child(strategy_row)
	parent.move_child(strategy_row, weapon_row.get_index() + 1)
	var strategy_label := Label.new()
	strategy_label.text = "战斗策略："
	strategy_row.add_child(strategy_label)
	_strategy_select = OptionButton.new()
	_strategy_select.name = "NPCCombatStrategySelect"
	_strategy_select.custom_minimum_size = Vector2(150, 30)
	_strategy_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strategy_select.focus_mode = Control.FOCUS_NONE
	_strategy_select.tooltip_text = COMBAT_STRATEGY_TOOLTIP
	strategy_row.add_child(_strategy_select)
	_strategy_select.item_selected.connect(_on_strategy_selected)

	var armor_row := HBoxContainer.new()
	armor_row.name = "NPCArmorRow"
	armor_row.add_theme_constant_override("separation", 6)
	parent.add_child(armor_row)
	parent.move_child(armor_row, strategy_row.get_index() + 1)
	var armor_label := Label.new()
	armor_label.text = "盔甲："
	armor_row.add_child(armor_label)
	_armor_select = OptionButton.new()
	_armor_select.name = "NPCArmorSelect"
	_armor_select.custom_minimum_size = Vector2(150, 30)
	_armor_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_armor_select.item_selected.connect(_on_equipment_option_selected)
	armor_row.add_child(_armor_select)
	_armor_equip_button = Button.new()
	_armor_equip_button.name = "NPCEquipArmorButton"
	_armor_equip_button.text = "装备"
	_armor_equip_button.tooltip_text = EQUIP_ARMOR_TOOLTIP
	_armor_equip_button.pressed.connect(_on_equip_armor_pressed)
	armor_row.add_child(_armor_equip_button)
	_armor_unequip_button = Button.new()
	_armor_unequip_button.name = "NPCUnequipArmorButton"
	_armor_unequip_button.text = "收回"
	_armor_unequip_button.tooltip_text = UNEQUIP_ARMOR_TOOLTIP
	_armor_unequip_button.pressed.connect(_on_unequip_armor_pressed)
	armor_row.add_child(_armor_unequip_button)

	var horse_row := HBoxContainer.new()
	horse_row.name = "NPCHorseAssignmentRow"
	horse_row.add_theme_constant_override("separation", 6)
	parent.add_child(horse_row)
	parent.move_child(horse_row, armor_row.get_index() + 1)
	var horse_label := Label.new()
	horse_label.text = "坐骑："
	horse_row.add_child(horse_label)
	_horse_select = OptionButton.new()
	_horse_select.name = "NPCHorseSelect"
	_horse_select.custom_minimum_size = Vector2(150, 30)
	_horse_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_horse_select.tooltip_text = "只列出成年、未分配且物理在马厩的马。"
	_horse_select.item_selected.connect(_on_equipment_option_selected)
	horse_row.add_child(_horse_select)
	_horse_assign_button = Button.new()
	_horse_assign_button.name = "NPCAssignHorseButton"
	_horse_assign_button.text = "分配"
	_horse_assign_button.tooltip_text = ASSIGN_HORSE_TOOLTIP
	_horse_assign_button.pressed.connect(_on_assign_horse_pressed)
	horse_row.add_child(_horse_assign_button)
	_horse_unassign_button = Button.new()
	_horse_unassign_button.name = "NPCUnassignHorseButton"
	_horse_unassign_button.text = "取消"
	_horse_unassign_button.tooltip_text = UNASSIGN_HORSE_TOOLTIP
	_horse_unassign_button.pressed.connect(_on_unassign_horse_pressed)
	horse_row.add_child(_horse_unassign_button)
	_horse_status_label = Label.new()
	_horse_status_label.name = "NPCHorseStatusLabel"
	_horse_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_horse_status_label)
	parent.move_child(_horse_status_label, horse_row.get_index() + 1)


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

	_combat_stats_label = Label.new()
	_combat_stats_label.name = "NPCCombatStatsLabel"
	_combat_stats_label.text = "战斗 Lv.1｜攻击 0｜防御 0｜穿透 0｜攻速 0.00/秒"
	_combat_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_combat_stats_label)
	parent.move_child(_combat_stats_label, row.get_index() + 1)


func _format_bool(value: Variant) -> String:
	return "是" if bool(value) else "否"


func _format_action(action_id: String) -> String:
	if action_id.is_empty() or action_id == "idle":
		return "待命"
	if action_id == "planning_day":
		return "制定计划"
	if action_id == "talk_to_guard_officer":
		return "与守备官对话"
	if action_id == "escape_intervention_dialogue":
		return "与守备官进行逃离挽留对话"
	if action_id.begins_with("moving_to_"):
		var target_id := action_id.trim_prefix("moving_to_")
		var target_name := str(KNOWLEDGE_SUBJECT_LABELS.get(target_id, "")).strip_edges()
		return "前往%s" % (target_name if not target_name.is_empty() else "目的地")
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if (
		action_system != null
		and action_system.has_method("get_action_ids")
		and action_system.get_action_ids().has(action_id)
		and action_system.has_method("get_action")
	):
		var action: Dictionary = action_system.get_action(action_id)
		var action_name := str(action.get("name", "")).strip_edges()
		if not action_name.is_empty():
			return action_name
	return "未知行动"


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
			return "未知状态"


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
	if _combat_stats_label != null:
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		var combat_stats: Dictionary = (
			combat_system.get_npc_combat_stats(_current_npc_id)
			if combat_system != null and combat_system.has_method("get_npc_combat_stats")
			else {}
		)
		var final_stats: Dictionary = combat_stats.get("final", {}) if combat_stats.get("final", {}) is Dictionary else {}
		_combat_stats_label.text = "战斗 Lv.%d｜攻击 %.1f｜防御 %.1f｜穿透 %.1f｜攻速 %.2f/秒" % [
			int(combat_stats.get("level", 1)),
			float(final_stats.get("attack_power", 0.0)),
			float(final_stats.get("defense", 0.0)),
			float(final_stats.get("penetration", 0.0)),
			float(final_stats.get("attack_speed", 0.0))
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
	var llm_activity: Dictionary = states.get("llm_activity", {}) if states.get("llm_activity", {}) is Dictionary else {}
	var is_planning := bool(llm_activity.get("active", false)) and str(llm_activity.get("kind", "")) == "plan"
	var is_recruited := bool(npc.get("recruited", false))
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var has_money := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("money")) >= int(gift_money_spin.value)
	var has_wine := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("wine")) >= int(gift_wine_spin.value)
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var selected_weapon_def: Dictionary = equipment_system.get_weapon_def(_get_selected_weapon_id()) if equipment_system != null and equipment_system.has_method("get_weapon_def") else {}
	var selected_weapon_resource_id := str(selected_weapon_def.get("source_resource_id", ""))
	var has_weapon := resource_system != null and not selected_weapon_resource_id.is_empty() and int(resource_system.get_resource(selected_weapon_resource_id)) >= 1
	var selected_armor_def: Dictionary = equipment_system.get_armor_def(_get_selected_armor_id()) if equipment_system != null and equipment_system.has_method("get_armor_def") else {}
	var selected_armor_resource_id := str(selected_armor_def.get("source_resource_id", ""))
	var has_armor_item := resource_system != null and not selected_armor_resource_id.is_empty() and int(resource_system.get_resource(selected_armor_resource_id)) >= 1
	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	var has_main_weapon := not (equipment.get("main_weapon", {}) as Dictionary).is_empty()
	var selected_armor_slot := _get_selected_armor_slot()
	var has_selected_armor_equipped := not selected_armor_slot.is_empty() and not (equipment.get(selected_armor_slot, {}) as Dictionary).is_empty()
	var has_strategy_options := _strategy_select != null and _strategy_select.get_item_count() > 0 and not str(_strategy_select.get_item_metadata(0)).is_empty()
	var escape_dialogue_state := _get_escape_dialogue_state(str(npc.get("id", _current_npc_id)))
	var is_escaping := bool(escape_dialogue_state.get("escaping", false))
	var can_escape_dialogue := bool(escape_dialogue_state.get("can_dialogue", false))
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	var has_suspended_dialogue := (
		dialog_system != null
		and dialog_system.has_method("is_player_dialogue_suspended_for_npc")
		and bool(dialog_system.is_player_dialogue_suspended_for_npc(str(npc.get("id", _current_npc_id))))
	)

	dialogue_suspended_dot.visible = has_suspended_dialogue
	dialogue_button.disabled = is_escaped or (not has_suspended_dialogue and (is_planning or is_deep_sleeping or (is_escaping and not can_escape_dialogue)))
	dialogue_button.tooltip_text = (
		"恢复挂起的对话。" if has_suspended_dialogue
		else "逃离挽留轮次已用完。" if is_escaping and not can_escape_dialogue
		else "NPC正在思考" if is_planning
		else "打开对话面板。"
	)
	gift_money_button.disabled = is_escaped or not has_money
	gift_wine_button.disabled = is_escaped or not has_wine
	give_weapon_button.disabled = is_escaped or not is_recruited or not has_weapon or _get_selected_weapon_id().is_empty()
	_set_recruitment_gate_tooltip(give_weapon_button, is_recruited, EQUIP_WEAPON_TOOLTIP)
	if _unequip_weapon_button != null:
		_unequip_weapon_button.disabled = is_escaped or not is_recruited or not has_main_weapon
		_set_recruitment_gate_tooltip(_unequip_weapon_button, is_recruited, UNEQUIP_WEAPON_TOOLTIP)
	if _armor_equip_button != null:
		_armor_equip_button.disabled = is_escaped or not is_recruited or not has_armor_item or _get_selected_armor_id().is_empty()
		_set_recruitment_gate_tooltip(_armor_equip_button, is_recruited, EQUIP_ARMOR_TOOLTIP)
	if _armor_unequip_button != null:
		_armor_unequip_button.disabled = is_escaped or not is_recruited or not has_selected_armor_equipped
		_set_recruitment_gate_tooltip(_armor_unequip_button, is_recruited, UNEQUIP_ARMOR_TOOLTIP)
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	var assigned_horse: Dictionary = horse_system.get_assigned_horse_for_npc(str(npc.get("id", _current_npc_id))) if horse_system != null and horse_system.has_method("get_assigned_horse_for_npc") else {}
	if _horse_assign_button != null:
		_horse_assign_button.disabled = is_escaped or not is_recruited or not has_main_weapon or _get_selected_horse_id().is_empty()
		_set_recruitment_gate_tooltip(_horse_assign_button, is_recruited, ASSIGN_HORSE_TOOLTIP)
	if _horse_unassign_button != null:
		_horse_unassign_button.disabled = is_escaped or not is_recruited or assigned_horse.is_empty()
		_set_recruitment_gate_tooltip(_horse_unassign_button, is_recruited, UNASSIGN_HORSE_TOOLTIP)
	if _strategy_select != null:
		_strategy_select.disabled = is_escaped or not is_recruited or not has_strategy_options
		_set_recruitment_gate_tooltip(_strategy_select, is_recruited, COMBAT_STRATEGY_TOOLTIP)


func _set_recruitment_gate_tooltip(control: Control, is_recruited: bool, default_text: String) -> void:
	if control == null:
		return
	control.tooltip_text = default_text if is_recruited else RECRUITMENT_REQUIRED_TOOLTIP


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
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_weapon_ids"):
		return
	var selected_index := 0
	var weapon_ids: Array = equipment_system.get_weapon_ids()
	for raw_weapon_id in weapon_ids:
		var weapon_id := str(raw_weapon_id)
		var weapon_def: Dictionary = equipment_system.get_weapon_def(weapon_id) if equipment_system.has_method("get_weapon_def") else {}
		var index := _weapon_select.get_item_count()
		var resource_id := str(weapon_def.get("source_resource_id", ""))
		var stock := int(resource_system.get_resource(resource_id)) if resource_system != null and not resource_id.is_empty() else 0
		_weapon_select.add_item("%s x%d" % [str(weapon_def.get("name", weapon_id)), stock])
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


func _fill_armor_select() -> void:
	if _armor_select == null:
		return
	var previous_id := _get_selected_armor_id()
	_armor_select.clear()
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_armor_ids"):
		return
	var selected_index := 0
	for raw_armor_id in equipment_system.get_armor_ids():
		var armor_id := str(raw_armor_id)
		var armor_def: Dictionary = equipment_system.get_armor_def(armor_id) if equipment_system.has_method("get_armor_def") else {}
		var resource_id := str(armor_def.get("source_resource_id", ""))
		var stock := int(resource_system.get_resource(resource_id)) if resource_system != null and not resource_id.is_empty() else 0
		var index := _armor_select.item_count
		_armor_select.add_item("%s x%d" % [str(armor_def.get("name", armor_id)), stock])
		_armor_select.set_item_metadata(index, armor_id)
		if armor_id == previous_id:
			selected_index = index
	if _armor_select.item_count > 0:
		_armor_select.select(selected_index)


func _get_selected_armor_id() -> String:
	if _armor_select == null or _armor_select.item_count <= 0 or _armor_select.selected < 0:
		return ""
	return str(_armor_select.get_item_metadata(_armor_select.selected))


func _get_selected_armor_slot() -> String:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_armor_def"):
		return ""
	var armor_def: Dictionary = equipment_system.get_armor_def(_get_selected_armor_id())
	return str(armor_def.get("slot", ""))


func _fill_horse_select(npc: Dictionary) -> void:
	if _horse_select == null:
		return
	var previous_id := _get_selected_horse_id()
	_horse_select.clear()
	_horse_select.add_item("选择成年马")
	_horse_select.set_item_metadata(0, "")
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null:
		_set_horse_status("马匹系统不可用")
		return
	var npc_id := str(npc.get("id", _current_npc_id))
	var assigned: Dictionary = horse_system.get_assigned_horse_for_npc(npc_id) if horse_system.has_method("get_assigned_horse_for_npc") else {}
	var added_ids: Array[String] = []
	if not assigned.is_empty():
		var assigned_id := str(assigned.get("horse_id", assigned.get("id", "")))
		if not assigned_id.is_empty():
			var index := _horse_select.item_count
			_horse_select.add_item("%s（已分配）" % str(assigned.get("name", assigned_id)))
			_horse_select.set_item_metadata(index, assigned_id)
			added_ids.append(assigned_id)
			previous_id = assigned_id
	if horse_system.has_method("get_available_horses_for_npc"):
		for raw_horse in horse_system.get_available_horses_for_npc(npc_id):
			var horse: Dictionary = raw_horse if raw_horse is Dictionary else {}
			var horse_id := str(horse.get("horse_id", horse.get("id", raw_horse)))
			if horse_id.is_empty() or added_ids.has(horse_id):
				continue
			var index := _horse_select.item_count
			_horse_select.add_item(str(horse.get("name", horse_id)))
			_horse_select.set_item_metadata(index, horse_id)
			added_ids.append(horse_id)
	var selected_index := 0
	for index in range(_horse_select.item_count):
		if str(_horse_select.get_item_metadata(index)) == previous_id:
			selected_index = index
			break
	_horse_select.select(selected_index)
	if assigned.is_empty():
		var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
		if bool(npc.get("states", {}).get("escaped", false)):
			_set_horse_status("该 NPC 已逃离，不能分配马匹。")
		elif not bool(npc.get("recruited", false)):
			_set_horse_status("")
		elif (equipment.get("main_weapon", {}) as Dictionary).is_empty():
			_set_horse_status("没有主武器，不能分配马匹。")
		elif _horse_select.item_count <= 1:
			_set_horse_status("当前没有可分配的成年在厩马。")
		else:
			_set_horse_status("")
	else:
		var location := str(assigned.get("location", "stable"))
		_set_horse_status("当前分配：%s｜%s" % [
			str(assigned.get("name", assigned.get("horse_id", "马"))),
			"在马厩" if location == "stable" else "已骑乘离厩" if location == "ridden" else "位置未知"
		])


func _set_horse_status(text: String) -> void:
	if _horse_status_label == null:
		return
	_horse_status_label.text = text
	_horse_status_label.visible = not text.is_empty()


func _get_selected_horse_id() -> String:
	if _horse_select == null or _horse_select.item_count <= 0 or _horse_select.selected < 0:
		return ""
	return str(_horse_select.get_item_metadata(_horse_select.selected))


func _on_equipment_option_selected(_index: int) -> void:
	if _current_npc_id.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return
	var npc: Dictionary = npc_system.get_npc(_current_npc_id)
	if npc.is_empty():
		return
	_update_interaction_controls(npc)


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
	interaction_result_label.visible = true
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
		interaction_result_label.visible = true
		show_npc(_current_npc_id)
	else:
		interaction_result_label.text = str(result.get("message", "无法分配技能点。"))
		interaction_result_label.visible = true
	_queue_panel_fit()


func _setup_memory_log_boxes() -> void:
	_event_log_text = _wrap_memory_label(event_log_label, "NPCEventLogBox", "NPCEventLogText", "事件库")
	_witness_log_text = _wrap_memory_label(witness_log_label, "NPCWitnessLogBox", "NPCWitnessLogText", "见闻库")
	_connect_memory_log_clicks(event_log_label, _event_log_text, "event_log")
	_connect_memory_log_clicks(witness_log_label, _witness_log_text, "witness_log")


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
	_memory_detail_drag_controller = DraggablePanelController.new()
	_memory_detail_drag_controller.bind(_memory_detail_panel, header)


func _layout_memory_detail_popup() -> void:
	if _memory_detail_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var width := minf(MEMORY_DETAIL_MAX_SIZE.x, maxf(360.0, viewport_size.x - MEMORY_DETAIL_SCREEN_MARGIN * 2.0))
	var height := minf(MEMORY_DETAIL_MAX_SIZE.y, maxf(320.0, viewport_size.y - MEMORY_DETAIL_SCREEN_MARGIN * 2.0))
	var preserved_drag_position: Vector2 = (
		_memory_detail_drag_controller.get_user_position()
		if _memory_detail_drag_controller != null and _memory_detail_drag_controller.has_user_position()
		else Vector2.INF
	)
	_memory_detail_panel.anchor_left = 0.5
	_memory_detail_panel.anchor_top = 0.5
	_memory_detail_panel.anchor_right = 0.5
	_memory_detail_panel.anchor_bottom = 0.5
	_memory_detail_panel.offset_left = -width / 2.0
	_memory_detail_panel.offset_top = -height / 2.0
	_memory_detail_panel.offset_right = width / 2.0
	_memory_detail_panel.offset_bottom = height / 2.0
	_memory_detail_panel.custom_minimum_size = Vector2(width, height)
	if preserved_drag_position != Vector2.INF:
		_memory_detail_drag_controller.restore_user_position(preserved_drag_position)
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
	_cancel_pending_memory_detail_scroll_restore()
	_layout_memory_detail_popup()
	_memory_detail_overlay.visible = true
	_refresh_memory_detail_popup(false)
	if _memory_detail_text != null:
		_memory_detail_text.scroll_horizontal = 0
		_memory_detail_text.scroll_past_end_of_file = mode == "current_plan"
		if ["event_log", "witness_log", "dialogue_history"].has(mode):
			_schedule_memory_detail_initial_bottom_scroll()
		elif mode == "current_plan":
			_schedule_memory_detail_initial_plan_scroll(_get_current_daily_plan())
		else:
			_memory_detail_text.scroll_vertical = 0


func _close_memory_detail_popup() -> void:
	_cancel_pending_memory_detail_scroll_restore()
	if _memory_detail_overlay != null:
		_memory_detail_overlay.visible = false


func _refresh_memory_detail_popup(preserve_scroll: bool = true) -> void:
	if _memory_detail_overlay == null or not _memory_detail_overlay.visible:
		return
	var detail_text := ""
	var title := ""
	var item_count := 0
	var item_unit := "条"
	match _memory_detail_mode:
		"background":
			var setting := _get_current_npc_prompt_setting()
			title = "人物背景"
			item_count = setting.size()
			detail_text = _format_npc_background_block(setting)
		"current_plan":
			var plan := _get_current_daily_plan()
			title = "当前计划"
			item_count = plan.size()
			detail_text = _format_current_plan_block(plan)
		"diary":
			var diary := _get_current_diary()
			title = "日记"
			item_count = diary.size()
			detail_text = _format_diary_block(diary)
		"knowledge":
			var graph := _get_current_knowledge_graph()
			title = "知识图谱"
			item_count = _count_knowledge_graph_entries(graph)
			detail_text = _format_knowledge_graph_block(graph)
		"dialogue_history":
			var dialogues := _get_current_guard_dialogue_history()
			title = "对话记录"
			item_count = dialogues.size()
			item_unit = "场"
			detail_text = _format_guard_dialogue_history_block(dialogues)
		_:
			var events := _event_log_cache if _memory_detail_mode == "event_log" else _witness_log_cache
			title = "事件库" if _memory_detail_mode == "event_log" else "见闻库"
			item_count = events.size()
			detail_text = _format_memory_detail_block(events)
	if _memory_detail_title_label != null:
		_memory_detail_title_label.text = "%s｜%s｜%d %s" % [
			str(name_label.text),
			title,
			item_count,
			item_unit
		]
	if _memory_detail_text != null:
		_set_memory_detail_text(detail_text, preserve_scroll)


func _get_current_npc_prompt_setting() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty():
		return {}
	var npc: Dictionary = npc_system.get_npc(_current_npc_id)
	return NPCPromptProfile.build_setting(npc) if not npc.is_empty() else {}


func _format_npc_background_block(setting: Dictionary) -> String:
	if setting.is_empty():
		return "暂无人物背景。"
	var sections: Array[String] = []
	for definition in NPCPromptProfile.FIELD_DEFINITIONS:
		var key := str(definition.get("key", ""))
		var label := str(definition.get("label", key))
		sections.append("【%s】\n%s" % [label, _format_npc_prompt_value(setting.get(key))])
	return "\n\n".join(sections)


func _format_npc_prompt_value(value: Variant) -> String:
	if value is Array:
		var items: Array[String] = []
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty():
				items.append(text)
		return "、".join(items) if not items.is_empty() else "暂无"
	if value is Dictionary:
		return JSON.stringify(value, "  ", false) if not value.is_empty() else "暂无"
	var text := str(value).strip_edges()
	return text if not text.is_empty() else "暂无"


func _get_current_daily_plan() -> Array:
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if daily_plan_system == null or _current_npc_id.is_empty() or not daily_plan_system.has_method("get_npc_daily_plan"):
		return []
	return daily_plan_system.get_npc_daily_plan(_current_npc_id)


func _get_current_long_memory() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("get_npc_long_memory"):
		return {}
	return npc_system.get_npc_long_memory(_current_npc_id)


func _get_current_diary() -> Array:
	var long_memory := _get_current_long_memory()
	return (long_memory.get("diary", []) as Array).duplicate(true) if long_memory.get("diary", []) is Array else []


func _get_current_knowledge_graph() -> Dictionary:
	var long_memory := _get_current_long_memory()
	return (long_memory.get("knowledge_graph", {}) as Dictionary).duplicate(true) if long_memory.get("knowledge_graph", {}) is Dictionary else {}


func _format_current_plan_block(plan: Array) -> String:
	if plan.is_empty():
		return "当前没有生效计划。"
	var current_hour := -1
	var game_state := get_node_or_null(GAME_STATE_PATH)
	if game_state != null:
		current_hour = int(game_state.current_hour)
	var display_groups := _build_current_plan_display_groups(plan, current_hour)
	var lines: Array[String] = []
	for raw_group in display_groups:
		var group: Dictionary = raw_group if raw_group is Dictionary else {}
		var start_hour := int(group.get("start_hour", -1))
		var end_hour := int(group.get("end_hour", start_hour))
		var marker := "▶" if bool(group.get("contains_current_hour", false)) else "  "
		var time_text := (
			"%02d:00" % start_hour
			if start_hour == end_hour
			else "%02d:00–%02d:00" % [start_hour, end_hour]
		)
		var action_name := str(group.get("action_name", ""))
		var source := _format_plan_source(str(group.get("source", "")))
		var reason := str(group.get("reason", ""))
		var line := "%s %s  %s" % [marker, time_text, action_name]
		if not source.is_empty():
			line += "｜%s" % source
		if not reason.is_empty():
			line += "\n    %s" % reason
		lines.append(line)
	return "\n\n".join(lines)


func _build_current_plan_display_groups(plan: Array, current_hour: int) -> Array:
	var groups: Array = []
	for raw_item in plan:
		var item: Dictionary = raw_item if raw_item is Dictionary else {}
		var hour := int(item.get("hour", -1))
		var action_id := str(item.get("action_id", "idle"))
		var action_name := str(item.get("action_name", "")).strip_edges()
		if action_name.is_empty():
			action_name = _format_action(action_id)
		var source := str(item.get("source", ""))
		var reason := str(item.get("reason", "")).strip_edges()
		if reason == action_name:
			reason = ""
		var signature := JSON.stringify([
			action_id,
			action_name,
			str(item.get("action_kind", "")),
			source,
			item.get("target", {}),
			int(item.get("priority", 50)),
			reason,
			str(item.get("dialogue_goal", "")).strip_edges(),
		])
		if not groups.is_empty():
			var previous_group: Dictionary = groups[groups.size() - 1]
			if (
				hour == int(previous_group.get("end_hour", -2)) + 1
				and signature == str(previous_group.get("signature", ""))
			):
				previous_group["end_hour"] = hour
				if hour == current_hour:
					previous_group["contains_current_hour"] = true
				groups[groups.size() - 1] = previous_group
				continue
		groups.append({
			"start_hour": hour,
			"end_hour": hour,
			"action_name": action_name,
			"source": source,
			"reason": reason,
			"signature": signature,
			"contains_current_hour": hour == current_hour,
		})
	return groups


func _format_plan_source(source: String) -> String:
	match source:
		"llm_plan_day":
			return "真实 LLM 日计划"
		"llm_plan_revision":
			return "真实 LLM 重估"
		"rule_default":
			return "规则调试计划"
		"mock_plan_day":
			return "Mock 调试计划"
		_:
			return "其他来源"


func _get_current_plan_initial_scroll_line(plan: Array) -> int:
	if plan.is_empty():
		return 0
	var game_state := get_node_or_null(GAME_STATE_PATH)
	if game_state == null:
		return 0
	var current_hour := int(game_state.current_hour)
	var display_groups := _build_current_plan_display_groups(plan, current_hour)
	var current_index := -1
	for index in range(display_groups.size()):
		var raw_group: Variant = display_groups[index]
		var group: Dictionary = raw_group if raw_group is Dictionary else {}
		if bool(group.get("contains_current_hour", false)):
			current_index = index
			break
	if current_index < 0:
		return 0
	var first_action_index := maxi(0, current_index - 2)
	var first_line := 0
	for index in range(first_action_index):
		var raw_group: Variant = display_groups[index]
		var group: Dictionary = raw_group if raw_group is Dictionary else {}
		first_line += 1
		var reason := str(group.get("reason", ""))
		if not reason.is_empty():
			first_line += reason.count("\n") + 1
		# _format_current_plan_block() separates adjacent visible plan groups with one blank line.
		first_line += 1
	return first_line


func _set_memory_detail_text(new_text: String, preserve_scroll: bool) -> void:
	if _memory_detail_text == null or _memory_detail_text.text == new_text:
		return
	if (
		preserve_scroll
		and not _memory_detail_initial_bottom_pending
		and not _memory_detail_initial_plan_scroll_pending
		and not _memory_detail_scroll_restore_pending
	):
		_memory_detail_saved_vertical = _memory_detail_text.scroll_vertical
		_memory_detail_saved_horizontal = _memory_detail_text.scroll_horizontal
		_memory_detail_saved_mode = _memory_detail_mode
		_memory_detail_saved_npc_id = _current_npc_id
		_memory_detail_scroll_restore_pending = true
		_memory_detail_scroll_restore_generation += 1
		call_deferred(
			"_restore_memory_detail_scroll_after_layout",
			_memory_detail_scroll_restore_generation
		)
	_memory_detail_text.text = new_text


func _schedule_memory_detail_initial_plan_scroll(plan: Array) -> void:
	if _memory_detail_text == null:
		return
	_memory_detail_initial_plan_scroll_pending = true
	_memory_detail_scroll_restore_generation += 1
	call_deferred(
		"_scroll_memory_detail_to_current_plan_after_layout",
		_memory_detail_scroll_restore_generation,
		_memory_detail_mode,
		_current_npc_id,
		_get_current_plan_initial_scroll_line(plan)
	)


func _scroll_memory_detail_to_current_plan_after_layout(
	generation: int,
	mode: String,
	npc_id: String,
	first_line: int
) -> void:
	await get_tree().process_frame
	if generation != _memory_detail_scroll_restore_generation:
		return
	if (
		_memory_detail_text == null
		or _memory_detail_overlay == null
		or not _memory_detail_overlay.visible
		or _memory_detail_mode != mode
		or _current_npc_id != npc_id
		or mode != "current_plan"
	):
		_memory_detail_initial_plan_scroll_pending = false
		return
	_memory_detail_text.set_line_as_first_visible(maxi(0, first_line))
	_memory_detail_text.scroll_horizontal = 0
	_memory_detail_initial_plan_scroll_pending = false


func _schedule_memory_detail_initial_bottom_scroll() -> void:
	if _memory_detail_text == null:
		return
	_memory_detail_initial_bottom_pending = true
	_memory_detail_scroll_restore_generation += 1
	call_deferred(
		"_scroll_memory_detail_to_bottom_after_layout",
		_memory_detail_scroll_restore_generation,
		_memory_detail_mode,
		_current_npc_id
	)


func _scroll_memory_detail_to_bottom_after_layout(
	generation: int,
	mode: String,
	npc_id: String
) -> void:
	await get_tree().process_frame
	if generation != _memory_detail_scroll_restore_generation:
		return
	if (
		_memory_detail_text == null
		or _memory_detail_overlay == null
		or not _memory_detail_overlay.visible
		or _memory_detail_mode != mode
		or _current_npc_id != npc_id
		or not ["event_log", "witness_log", "dialogue_history"].has(mode)
	):
		_memory_detail_initial_bottom_pending = false
		return
	_scroll_to_bottom(_memory_detail_text)
	_memory_detail_text.scroll_horizontal = 0
	_memory_detail_initial_bottom_pending = false


func _restore_memory_detail_scroll_after_layout(generation: int) -> void:
	await get_tree().process_frame
	if (
		generation != _memory_detail_scroll_restore_generation
		or _memory_detail_text == null
		or _memory_detail_overlay == null
		or not _memory_detail_overlay.visible
		or _memory_detail_mode != _memory_detail_saved_mode
		or _current_npc_id != _memory_detail_saved_npc_id
	):
		_memory_detail_scroll_restore_pending = false
		return
	_memory_detail_text.scroll_vertical = _memory_detail_saved_vertical
	_memory_detail_text.scroll_horizontal = _memory_detail_saved_horizontal
	_memory_detail_scroll_restore_pending = false


func _cancel_pending_memory_detail_scroll_restore() -> void:
	_memory_detail_scroll_restore_generation += 1
	_memory_detail_scroll_restore_pending = false
	_memory_detail_initial_bottom_pending = false
	_memory_detail_initial_plan_scroll_pending = false


func _format_memory_detail_block(events: Array) -> String:
	# The expanded player view intentionally uses the same whitelist as the
	# compact box. Structured metadata remains available to systems and GM tools.
	return _format_memory_block(events)


func _get_current_guard_dialogue_history() -> Array:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if (
		memory_system == null
		or _current_npc_id.is_empty()
		or not memory_system.has_method("get_all_events")
	):
		return []

	var all_events: Array = memory_system.get_all_events()
	var chronological_events: Array = []
	for event_index in range(all_events.size()):
		var raw_event: Variant = all_events[event_index]
		if not raw_event is Dictionary:
			continue
		var event := (raw_event as Dictionary).duplicate(true)
		event["_history_sequence"] = event_index
		chronological_events.append(event)
	chronological_events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_day := int(left.get("day", 0))
		var right_day := int(right.get("day", 0))
		if left_day != right_day:
			return left_day < right_day
		var left_time := _dialogue_history_time_seconds(str(left.get("time", "00:00:00")))
		var right_time := _dialogue_history_time_seconds(str(right.get("time", "00:00:00")))
		if left_time != right_time:
			return left_time < right_time
		return int(left.get("_history_sequence", 0)) < int(right.get("_history_sequence", 0))
	)

	var dialogues: Array = []
	for raw_event in chronological_events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if not _is_guard_dialogue_history_event(event, _current_npc_id):
			continue
		dialogues.append(event)
	return dialogues


func _is_guard_dialogue_history_event(event: Dictionary, npc_id: String) -> bool:
	if npc_id.is_empty() or str(event.get("type", "")) != "dialogue_turn":
		return false
	var payload: Dictionary = (
		event.get("payload", {})
		if event.get("payload", {}) is Dictionary
		else {}
	)
	var dialogue_kind := str(payload.get("dialogue_kind", ""))
	if dialogue_kind == "npc_npc":
		return false

	var includes_target_npc := str(event.get("subject_npc_id", "")) == npc_id
	var participant_npc_ids: Variant = payload.get("participant_npc_ids", [])
	if participant_npc_ids is Array:
		for raw_participant_id in participant_npc_ids:
			if str(raw_participant_id) == npc_id:
				includes_target_npc = true
				break
	if not includes_target_npc:
		return false
	if PLAYER_DIALOGUE_KINDS.has(dialogue_kind):
		return true
	if not dialogue_kind.is_empty():
		return false

	var actor_ids: Variant = event.get("actor_ids", [])
	if actor_ids is Array:
		for raw_actor_id in actor_ids:
			if str(raw_actor_id) == GUARD_OFFICER_ID:
				return true
	var dialogue_text: Variant = payload.get("dialogue_text", [])
	if dialogue_text is Array:
		for raw_turn in dialogue_text:
			if not raw_turn is Dictionary:
				continue
			var turn: Dictionary = raw_turn
			if (
				str(turn.get("speaker_id", "")) == GUARD_OFFICER_ID
				or str(turn.get("listener_id", "")) == GUARD_OFFICER_ID
				or str(turn.get("speaker_name", "")) == GUARD_OFFICER_NAME
				or str(turn.get("listener_name", "")) == GUARD_OFFICER_NAME
			):
				return true
	return false


func _dialogue_history_time_seconds(time_text: String) -> int:
	var parts := time_text.split(":")
	if parts.size() < 2:
		return 0
	var hour := int(parts[0])
	var minute := int(parts[1])
	var second := int(parts[2]) if parts.size() >= 3 else 0
	return hour * 3600 + minute * 60 + second


func _format_guard_dialogue_history_block(dialogues: Array) -> String:
	if dialogues.is_empty():
		return "暂无与守备官的过往对话。"

	var sections: Array[String] = []
	var current_group_key := ""
	var current_group_heading := ""
	var current_group_entries: Array[String] = []
	for raw_event in dialogues:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		var day := maxi(1, int(event.get("day", 1)))
		var group_key := str(day)
		if group_key != current_group_key:
			if not current_group_entries.is_empty():
				sections.append("%s\n%s" % [
					current_group_heading,
					"\n\n".join(current_group_entries)
				])
			current_group_key = group_key
			current_group_heading = "【第%d天】" % day
			current_group_entries.clear()
		var payload: Dictionary = (
			event.get("payload", {})
			if event.get("payload", {}) is Dictionary
			else {}
		)
		current_group_entries.append("%s\n%s" % [
			str(event.get("time", "--:--:--")),
			_format_guard_dialogue_transcript(payload)
		])
	if not current_group_entries.is_empty():
		sections.append("%s\n%s" % [
			current_group_heading,
			"\n\n".join(current_group_entries)
		])
	return "\n\n".join(sections)


func _format_guard_dialogue_transcript(payload: Dictionary) -> String:
	var lines: Array[String] = []
	var dialogue_text: Variant = payload.get("dialogue_text", [])
	if dialogue_text is Array:
		for raw_turn in dialogue_text:
			if not raw_turn is Dictionary:
				continue
			var turn: Dictionary = raw_turn
			var text := str(turn.get("text", "")).strip_edges()
			if text.is_empty():
				continue
			var speaker_id := str(turn.get("speaker_id", ""))
			var speaker_name := str(turn.get("speaker_name", "")).strip_edges()
			if speaker_name.is_empty():
				speaker_name = (
					GUARD_OFFICER_NAME
					if speaker_id == GUARD_OFFICER_ID
					else str(name_label.text)
					if speaker_id == _current_npc_id
					else speaker_id
				)
			lines.append("%s：%s" % [speaker_name, text])
	if lines.is_empty():
		var speaker_text := str(payload.get("speaker_text", "")).strip_edges()
		var reply_text := str(payload.get("reply_text", "")).strip_edges()
		var speaker_name := str(payload.get("speaker_name", GUARD_OFFICER_NAME)).strip_edges()
		var listener_name := str(payload.get("listener_name", name_label.text)).strip_edges()
		if not speaker_text.is_empty():
			lines.append("%s：%s" % [speaker_name, speaker_text])
		if not reply_text.is_empty():
			lines.append("%s：%s" % [listener_name, reply_text])
	return "\n".join(lines) if not lines.is_empty() else "（本场对话没有可显示的文本）"


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
			var record_label := str(entry.get("record_label", "")).strip_edges()
			var prefix := (
				"%s %s" % [record_label, time_text]
				if not record_label.is_empty()
				else ("第%d天 %s" % [day, time_text] if day > 0 else time_text)
			)
			lines.append("- %s %s" % [prefix, text])
		else:
			lines.append("- %s" % str(raw_entry))
	return "\n\n".join(lines)


func _count_knowledge_graph_entries(graph: Dictionary) -> int:
	var by_subject: Dictionary = graph.get("by_subject", {}) if graph.get("by_subject", {}) is Dictionary else {}
	var count := 0
	for raw_subject in by_subject.keys():
		var relations: Variant = by_subject.get(raw_subject)
		if relations is Dictionary:
			count += (relations as Dictionary).size()
	return count


func _format_knowledge_graph_block(graph: Dictionary) -> String:
	var by_subject: Dictionary = graph.get("by_subject", {}) if graph.get("by_subject", {}) is Dictionary else {}
	if by_subject.is_empty():
		return "暂无知识。"
	var subjects: Array = by_subject.keys()
	subjects.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var sections: Array[String] = []
	for raw_subject in subjects:
		var subject := str(raw_subject)
		var relations: Dictionary = by_subject.get(raw_subject, {}) if by_subject.get(raw_subject, {}) is Dictionary else {}
		if relations.is_empty():
			continue
		var relation_names: Array = relations.keys()
		relation_names.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var subject_label := _format_knowledge_subject_label(subject, relations)
		var lines: Array[String] = ["【%s】" % subject_label]
		for raw_relation in relation_names:
			var relation := str(raw_relation)
			var record: Variant = relations.get(raw_relation)
			if record is Dictionary:
				var record_dict := record as Dictionary
				var relation_label := _format_knowledge_relation_label(relation, str(record_dict.get("relation_label", "")))
				var value_label := _format_knowledge_value_label(
					str(record_dict.get("value", "")),
					str(record_dict.get("value_label", ""))
				)
				lines.append("- %s：%s" % [relation_label, value_label])
			else:
				lines.append("- %s：%s" % [
					_format_knowledge_relation_label(relation),
					_format_knowledge_value_label(str(record))
				])
		sections.append("\n".join(lines))
	return "\n\n".join(sections) if not sections.is_empty() else "暂无知识。"


func _format_knowledge_subject_label(subject: String, relations: Dictionary) -> String:
	for raw_record in relations.values():
		if raw_record is Dictionary:
			var generated_label := str((raw_record as Dictionary).get("subject_label", "")).strip_edges()
			if _is_safe_chinese_knowledge_label(generated_label):
				return generated_label
	if _is_safe_chinese_knowledge_label(subject):
		return subject

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system != null
		and npc_system.has_method("get_npc")
		and npc_system.has_method("get_npc_ids")
		and (npc_system.get_npc_ids() as Array).has(subject)
	):
		var npc: Dictionary = npc_system.get_npc(subject)
		if not npc.is_empty():
			var npc_name := str(npc.get("name", "")).strip_edges()
			var job_name := str(npc.get("background_job", "")).strip_edges()
			if not npc_name.is_empty():
				return "%s（%s）" % [npc_name, job_name] if not job_name.is_empty() else npc_name

	if KNOWLEDGE_SUBJECT_LABELS.has(subject):
		return str(KNOWLEDGE_SUBJECT_LABELS.get(subject, "其他对象"))
	var separator_index := subject.find(":")
	if separator_index > 0:
		var prefix := subject.left(separator_index).to_lower()
		var prefix_label := str(KNOWLEDGE_DYNAMIC_PREFIX_LABELS.get(prefix, ""))
		if not prefix_label.is_empty():
			var detail_label := _translate_knowledge_key(subject.substr(separator_index + 1), "")
			return "%s：%s" % [prefix_label, detail_label] if not detail_label.is_empty() else "%s事项" % prefix_label
	return _translate_knowledge_key(subject, "其他对象")


func _format_knowledge_relation_label(relation: String, generated_label: String = "") -> String:
	if _is_safe_chinese_knowledge_label(generated_label):
		return generated_label.strip_edges()
	if _is_safe_chinese_knowledge_label(relation):
		return relation.strip_edges()
	if KNOWLEDGE_RELATION_LABELS.has(relation):
		return str(KNOWLEDGE_RELATION_LABELS.get(relation, "其他认知"))
	return _translate_knowledge_key(relation, "其他认知")


func _format_knowledge_value_label(value: String, generated_label: String = "") -> String:
	if _is_safe_chinese_knowledge_label(generated_label):
		return generated_label.strip_edges()
	var normalized_value := value.strip_edges()
	if _is_safe_chinese_knowledge_label(normalized_value):
		return normalized_value
	var lower_value := normalized_value.to_lower()
	if KNOWLEDGE_VALUE_LABELS.has(lower_value):
		return str(KNOWLEDGE_VALUE_LABELS.get(lower_value, "尚无中文说明"))
	if KNOWLEDGE_SUBJECT_LABELS.has(lower_value):
		return str(KNOWLEDGE_SUBJECT_LABELS.get(lower_value, "尚无中文说明"))
	var translated_value := _translate_knowledge_key(lower_value, "")
	return translated_value if not translated_value.is_empty() else "尚无中文说明"


func _translate_knowledge_key(raw_key: String, fallback: String) -> String:
	var key := raw_key.strip_edges().to_lower()
	if key.is_empty():
		return fallback
	if KNOWLEDGE_DETAIL_LABELS.has(key):
		return str(KNOWLEDGE_DETAIL_LABELS.get(key, fallback))
	var normalized := key.replace("-", "_").replace(" ", "_")
	var translated_parts: Array[String] = []
	for raw_part in normalized.split("_", false):
		var part := str(raw_part)
		if part.is_valid_int():
			translated_parts.append("%d号" % int(part))
		elif KNOWLEDGE_KEY_TOKEN_LABELS.has(part):
			translated_parts.append(str(KNOWLEDGE_KEY_TOKEN_LABELS.get(part, "")))
		else:
			return fallback
	return "".join(translated_parts) if not translated_parts.is_empty() else fallback


func _is_safe_chinese_knowledge_label(raw_label: String) -> bool:
	var label := raw_label.strip_edges()
	if label.is_empty() or label.contains("_"):
		return false
	var has_chinese_character := false
	for index in range(label.length()):
		var codepoint := label.unicode_at(index)
		if (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122):
			return false
		if (
			(codepoint >= 0x3400 and codepoint <= 0x4DBF)
			or (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
			or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
		):
			has_chinese_character = true
	return has_chinese_character


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


func _on_npc_daily_plan_changed(npc_id: String, _plan: Array) -> void:
	if npc_id == _current_npc_id and _memory_detail_mode == "current_plan":
		_refresh_memory_detail_popup()


func _on_current_plan_pressed() -> void:
	_open_memory_detail_popup("current_plan")


func _on_background_pressed() -> void:
	_open_memory_detail_popup("background")


func _on_diary_pressed() -> void:
	_open_memory_detail_popup("diary")


func _on_knowledge_pressed() -> void:
	_open_memory_detail_popup("knowledge")


func _on_dialogue_history_pressed() -> void:
	_open_memory_detail_popup("dialogue_history")


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
		_fill_weapon_select()
		_fill_armor_select()
		_update_interaction_controls(npc)


func _on_horse_state_changed(_horse_id: String) -> void:
	_refresh_horse_assignment_controls()


func _on_horse_assignment_changed(_horse_id: String, npc_id: String) -> void:
	if npc_id.is_empty() or npc_id == _current_npc_id:
		_refresh_horse_assignment_controls()


func _refresh_horse_assignment_controls() -> void:
	if not visible or _current_npc_id.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var npc: Dictionary = npc_system.get_npc(_current_npc_id)
	if npc.is_empty():
		return
	_fill_horse_select(npc)
	_update_interaction_controls(npc)
	_queue_panel_fit()


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
		interaction_result_label.visible = true
		_queue_panel_fit()


func _on_order_pressed() -> void:
	var order_panel := get_node_or_null(ORDER_PANEL_PATH)
	if order_panel == null or _current_npc_id.is_empty() or not order_panel.has_method("show_order"):
		return
	var result: Dictionary = order_panel.show_order(_current_npc_id)
	if not bool(result.get("ok", false)):
		interaction_result_label.text = str(result.get("message", "无法打开指令。"))
		interaction_result_label.visible = true
		_queue_panel_fit()


func _on_gift_money_value_changed(_value: float) -> void:
	if _current_npc_id.is_empty() or not visible:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var npc: Dictionary = npc_system.get_npc(_current_npc_id)
	if not npc.is_empty():
		_update_interaction_controls(npc)


func _on_gift_wine_value_changed(value: float) -> void:
	_on_gift_money_value_changed(value)


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


func _on_gift_wine_text_changed(new_text: String) -> void:
	if _is_sanitizing_gift_wine_text:
		return
	var sanitized := _digits_only(new_text)
	var line_edit := gift_wine_spin.get_line_edit()
	if line_edit == null or sanitized == new_text:
		return
	_is_sanitizing_gift_wine_text = true
	line_edit.text = sanitized
	line_edit.caret_column = sanitized.length()
	_is_sanitizing_gift_wine_text = false


func _on_gift_wine_line_edit_gui_input(event: InputEvent) -> void:
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
		gift_wine_spin.get_line_edit().release_focus()


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


func _on_gift_wine_pressed() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("give_wine_to_npc"):
		return
	var amount := int(gift_wine_spin.value)
	var result: Dictionary = npc_system.give_wine_to_npc(_current_npc_id, amount, _get_selected_visibility())
	_show_interaction_result(result, "已赠予 %d 份酒。" % amount)
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


func _on_unequip_weapon_pressed() -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or _current_npc_id.is_empty() or not equipment_system.has_method("unequip_npc_slot"):
		return
	var result: Dictionary = equipment_system.unequip_npc_slot(_current_npc_id, "main_weapon", _get_selected_visibility())
	_show_interaction_result(result, "已收回主武器；具体物品已返还库存。")
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)


func _on_equip_armor_pressed() -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or _current_npc_id.is_empty() or not equipment_system.has_method("equip_npc_armor"):
		return
	var result: Dictionary = equipment_system.equip_npc_armor(
		_current_npc_id,
		_get_selected_armor_slot(),
		_get_selected_armor_id(),
		_get_selected_visibility()
	)
	_show_interaction_result(result, "已装备盔甲：%s。" % _get_selected_armor_id())
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)


func _on_unequip_armor_pressed() -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var slot := _get_selected_armor_slot()
	if equipment_system == null or _current_npc_id.is_empty() or slot.is_empty() or not equipment_system.has_method("unequip_npc_slot"):
		return
	var result: Dictionary = equipment_system.unequip_npc_slot(_current_npc_id, slot, _get_selected_visibility())
	_show_interaction_result(result, "已收回该部位盔甲。")
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)


func _on_assign_horse_pressed() -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or _current_npc_id.is_empty() or not horse_system.has_method("assign_horse_to_npc"):
		return
	var result: Dictionary = horse_system.assign_horse_to_npc(_current_npc_id, _get_selected_horse_id(), _get_selected_visibility())
	_show_interaction_result(result, "已分配马匹：%s。" % str(result.get("horse_name", result.get("name", ""))))
	if bool(result.get("ok", false)):
		show_npc(_current_npc_id)


func _on_unassign_horse_pressed() -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or _current_npc_id.is_empty() or not horse_system.has_method("unassign_horse_from_npc"):
		return
	var result: Dictionary = horse_system.unassign_horse_from_npc(_current_npc_id, "player_unassigned", _get_selected_visibility())
	_show_interaction_result(result, "已取消马匹分配。")
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
