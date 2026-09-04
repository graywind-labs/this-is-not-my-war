extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")
const NPCPortraitViewport = preload("res://scripts/ui/NPCPortraitViewport.gd")
const NPCEquipmentWindowScript = preload("res://scripts/ui/NPCEquipmentWindow.gd")
const RateDisplayFormatter = preload("res://scripts/ui/RateDisplayFormatter.gd")

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const DAILY_PLAN_SYSTEM_PATH := "/root/Main/Systems/DailyPlanSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const NPC_NEEDS_SYSTEM_PATH := "/root/Main/Systems/NPCNeedsSystem"
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
const PORTRAIT_GAP := 12.0
const PORTRAIT_MIN_WIDTH := 190.0
const PORTRAIT_MAX_WIDTH := 210.0
const PORTRAIT_VIEWPORT_WIDTH_RATIO := 0.11
const PORTRAIT_HEIGHT_RATIO := 0.52
const PORTRAIT_MIN_HEIGHT := 300.0
const PORTRAIT_MAX_HEIGHT := 420.0
const EQUIPMENT_WINDOW_GAP := 8.0
const EQUIPMENT_WINDOW_SIZE := Vector2(316.0, 332.0)
const MOUNT_VIEW_BUTTON_SIZE := Vector2(120.0, 34.0)
const MOUNT_VIEW_BUTTON_GAP := 4.0
const RECRUITMENT_REQUIRED_TOOLTIP := "需先说服该人物应征入伍，才能进行这项操作。"
const EQUIPMENT_RECRUITMENT_TOOLTIP := "还未征召，无法配装。"
const ORDER_RECRUITMENT_TOOLTIP := "还未征召，无法命令。"
const EQUIP_WEAPON_TOOLTIP := "消耗 1 件所选具体武器库存。"
const UNEQUIP_WEAPON_TOOLTIP := "收回当前主武器并返还同一具体物品；已分配马匹会自动取消。"
const COMBAT_STRATEGY_TOOLTIP := "当前战斗策略只能在符合条件的战时对话中由守备官提出调整。"
const EQUIP_ARMOR_TOOLTIP := "消耗 1 件所选具体盔甲库存。"
const UNEQUIP_ARMOR_TOOLTIP := "收回当前部位的盔甲并返还同一具体物品。"
const ASSIGN_HORSE_TOOLTIP := "分配一匹成年、未占用且当前在厩的马；NPC 还需持有主武器。"
const UNASSIGN_HORSE_TOOLTIP := "取消该 NPC 当前的马匹分配。"
const LOADOUT_LOCKED_TOOLTIP := "只有工作模式下才能更换装备或马匹。"
const RECRUITED_NAME_COLOR := Color(0.64, 0.92, 0.68, 1.0)
const DEFAULT_NAME_COLOR := Color.WHITE
const DEFAULT_ACTION_COLOR := Color.WHITE
const BEHAVIOR_MODE_COLOR := Color(0.66, 0.69, 0.72, 1.0)
const NORMAL_PROGRESS_FILL_COLOR := Color("#71865a")
const DANGER_PROGRESS_FILL_COLOR := Color("#a7433b")
const EXPERIENCE_PROGRESS_FILL_COLOR := Color(0.94, 0.87, 0.70, 1.0)
const FATIGUE_PROGRESS_FILL_COLOR := Color("#777777")
const DANGER_LABEL_COLOR := Color("#dc6157")
const POSITIVE_RATE_LABEL_COLOR := Color("#69c879")
const HP_DANGER_RATIO := 0.30
const SATIETY_DANGER_RATIO := 0.20
const FATIGUE_DANGER_RATIO := 0.80
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
var _weapon_select: OptionButton
var _unequip_weapon_button: Button
var _armor_select: OptionButton
var _armor_equip_button: Button
var _armor_unequip_button: Button
var _horse_select: OptionButton
var _horse_assign_button: Button
var _horse_unassign_button: Button
var _horse_status_label: Label
var _strategy_value_label: Label
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
var _hp_progress: ProgressBar
var _hp_rate_label: Label
var _experience_progress: ProgressBar
var _satiety_progress: ProgressBar
var _fatigue_progress: ProgressBar
var _normal_progress_fill_style: StyleBoxFlat
var _danger_progress_fill_style: StyleBoxFlat
var _experience_progress_fill_style: StyleBoxFlat
var _fatigue_progress_fill_style: StyleBoxFlat
var _strength_point_button: Button
var _intelligence_point_button: Button
var _attribute_point_pulse_elapsed := 0.0
var _llm_status_label: Label
var _interaction_visibility_group: ButtonGroup
var _panel_scroll: ScrollContainer
var _panel_fit_queued := false
var _layout_viewport_override := Vector2.ZERO
var _drag_controller
var _portrait_view
var _equipment_window: NPCEquipmentWindow
var _mount_view_button: Button
var _equipment_unequip_confirm: ConfirmationDialog
var _equipment_notice_dialog: AcceptDialog
var _pending_unequip_slot := ""
var _pending_unequip_npc_id := ""

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
@onready var behavior_mode_label: Label = %NPCBehaviorModeLabel
@onready var skills_label: Label = %NPCSkillsLabel
@onready var current_plan_button: Button = %NPCCurrentPlanButton
@onready var diary_button: Button = %NPCDiaryButton
@onready var knowledge_button: Button = %NPCKnowledgeButton
@onready var event_log_label: Label = %NPCEventLogLabel
@onready var witness_log_label: Label = %NPCWitnessLogLabel
@onready var morale_boost_icon: TextureRect = %NPCMoraleBoostIcon
@onready var work_boost_icon: TextureRect = %NPCWorkBoostIcon
@onready var close_button: Button = %NPCPanelCloseButton
@onready var dialogue_button: Button = %NPCDialogueButton
@onready var dialogue_suspended_dot: Label = %NPCDialogueSuspendedDot
@onready var assign_button: Button = %NPCAssignButton
@onready var public_visibility_radio: CheckBox = %NPCInteractionPublicRadio
@onready var private_visibility_radio: CheckBox = %NPCInteractionPrivateRadio
@onready var gift_money_spin: SpinBox = %NPCGiftMoneySpin
@onready var gift_money_button: Button = %NPCGiftMoneyButton
@onready var gift_wine_spin: SpinBox = %NPCGiftWineSpin
@onready var gift_wine_button: Button = %NPCGiftWineButton
@onready var give_weapon_button: Button = %NPCGiveWeaponButton
@onready var interaction_result_label: Label = %NPCInteractionResultLabel


func _ready() -> void:
	visible = false
	# The responsive root extends left around the portrait. It must not swallow
	# clicks intended for the sibling equipment window in that transparent area.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_portrait_view()
	_setup_mount_view_button()
	_setup_panel_scroll()
	_setup_memory_log_boxes()
	_setup_header_status_label()
	_setup_progression_controls()
	_setup_need_progress_controls()
	_setup_interaction_controls()
	_setup_equipment_controls()
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, name_label.get_parent() as Control)
	close_button.pressed.connect(_on_close_pressed)
	background_button.pressed.connect(_on_background_pressed)
	dialogue_button.pressed.connect(_on_dialogue_pressed)
	assign_button.pressed.connect(_on_order_pressed)
	gift_money_button.pressed.connect(_on_gift_money_pressed)
	gift_wine_button.pressed.connect(_on_gift_wine_pressed)
	give_weapon_button.pressed.connect(_on_equipment_button_pressed)
	current_plan_button.pressed.connect(_on_current_plan_pressed)
	diary_button.pressed.connect(_on_diary_pressed)
	knowledge_button.pressed.connect(_on_knowledge_pressed)
	gift_money_spin.value_changed.connect(_on_gift_money_value_changed)
	gift_wine_spin.value_changed.connect(_on_gift_wine_value_changed)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_clicked.connect(_on_npc_clicked)
		if event_bus.has_signal("enemy_clicked"):
			event_bus.enemy_clicked.connect(_on_enemy_clicked)
		if event_bus.has_signal("horse_clicked"):
			event_bus.horse_clicked.connect(_on_horse_clicked)
		if event_bus.has_signal("defense_device_clicked"):
			event_bus.defense_device_clicked.connect(_on_defense_device_clicked)
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
	if not visibility_changed.is_connected(_on_panel_visibility_changed):
		visibility_changed.connect(_on_panel_visibility_changed)
	_queue_panel_fit()


func _process(_delta: float) -> void:
	_update_attribute_point_button_pulse(_delta)
	if _equipment_window != null and _equipment_window.visible:
		_layout_equipment_window()
	if _mount_view_button != null and _mount_view_button.visible:
		_layout_mount_view_button()


func _update_attribute_point_button_pulse(delta: float) -> void:
	const PULSE_PERIOD_SECONDS := 1.2
	const PULSE_MIN_ALPHA := 0.32
	var has_visible_button := (
		(_strength_point_button != null and _strength_point_button.visible)
		or (_intelligence_point_button != null and _intelligence_point_button.visible)
	)
	if not has_visible_button:
		_attribute_point_pulse_elapsed = 0.0
		_set_attribute_point_button_alpha(_strength_point_button, 1.0)
		_set_attribute_point_button_alpha(_intelligence_point_button, 1.0)
		return
	_attribute_point_pulse_elapsed = fmod(
		_attribute_point_pulse_elapsed + maxf(0.0, delta),
		PULSE_PERIOD_SECONDS
	)
	var wave := (sin(_attribute_point_pulse_elapsed / PULSE_PERIOD_SECONDS * TAU - PI * 0.5) + 1.0) * 0.5
	var alpha := lerpf(PULSE_MIN_ALPHA, 1.0, wave)
	_set_attribute_point_button_alpha(_strength_point_button, alpha)
	_set_attribute_point_button_alpha(_intelligence_point_button, alpha)


func _set_attribute_point_button_alpha(button: Button, alpha: float) -> void:
	if button == null:
		return
	var color := button.modulate
	color.a = clampf(alpha, 0.0, 1.0) if button.visible else 1.0
	button.modulate = color


func _setup_portrait_view() -> void:
	if _portrait_view != null:
		return
	_portrait_view = NPCPortraitViewport.new()
	_portrait_view.name = "NPCPortraitView"
	add_child(_portrait_view)
	move_child(_portrait_view, 0)
	if _portrait_view.has_signal("portrait_clicked"):
		_portrait_view.portrait_clicked.connect(_on_portrait_clicked)
	_portrait_view.hide_preview()


func _setup_mount_view_button() -> void:
	if _mount_view_button != null:
		return
	_mount_view_button = Button.new()
	_mount_view_button.name = "NPCMountViewButton"
	_mount_view_button.text = "查看马匹"
	_mount_view_button.tooltip_text = "查看该 NPC 当前正在骑乘的马匹。"
	_mount_view_button.custom_minimum_size = MOUNT_VIEW_BUTTON_SIZE
	_mount_view_button.size = MOUNT_VIEW_BUTTON_SIZE
	_mount_view_button.visible = false
	_mount_view_button.z_index = 71
	_mount_view_button.focus_mode = Control.FOCUS_NONE
	_mount_view_button.pressed.connect(_on_mount_view_button_pressed)
	add_child(_mount_view_button)


func _on_portrait_clicked(npc_id: String) -> void:
	if npc_id.is_empty() or npc_id != _current_npc_id or not visible:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("play_idle_portrait_talk_gesture"):
		return
	npc_system.play_idle_portrait_talk_gesture(npc_id)


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
	var info_width := clampf(
		viewport_size.x * PANEL_VIEWPORT_WIDTH_RATIO,
		PANEL_MIN_WIDTH,
		PANEL_MAX_WIDTH
	)
	var info_panel := get_node_or_null("PanelContainer") as Control
	if info_panel != null:
		info_width = maxf(info_width, info_panel.get_combined_minimum_size().x)
	# 纵向信息面板始终保持“高于宽”；极矮窗口下优先保留上下安全边距。
	info_width = minf(info_width, maxf(280.0, available_height - 1.0))
	var portrait_width := clampf(
		viewport_size.x * PORTRAIT_VIEWPORT_WIDTH_RATIO,
		PORTRAIT_MIN_WIDTH,
		PORTRAIT_MAX_WIDTH
	)
	var available_width := maxf(1.0, viewport_size.x - PANEL_SCREEN_MARGIN * 2.0)
	portrait_width = minf(portrait_width, maxf(180.0, available_width - info_width - PORTRAIT_GAP))
	var target_width := info_width + PORTRAIT_GAP + portrait_width
	set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	offset_right = -PANEL_SCREEN_MARGIN
	offset_left = offset_right - target_width
	offset_top = PANEL_SCREEN_MARGIN
	# Preserve the visible height for the layout frame. Expanding to the full
	# viewport here flashes an empty dark block below the panel on every refresh.
	offset_bottom = offset_top + preserved_height
	if info_panel != null:
		info_panel.set_anchors_preset(Control.PRESET_FULL_RECT, false)
		info_panel.offset_left = portrait_width + PORTRAIT_GAP
		info_panel.offset_top = 0.0
		info_panel.offset_right = 0.0
		info_panel.offset_bottom = 0.0
	if _portrait_view != null:
		_portrait_view.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		_portrait_view.offset_left = 0.0
		_portrait_view.offset_top = 0.0
		_portrait_view.offset_right = portrait_width
		_portrait_view.offset_bottom = minf(
			preserved_height,
			minf(
				clampf(preserved_height * PORTRAIT_HEIGHT_RATIO, PORTRAIT_MIN_HEIGHT, PORTRAIT_MAX_HEIGHT),
				_get_portrait_height_limit_for_equipment(viewport_size.y)
			)
		)
	_layout_equipment_window()
	if preserved_drag_position != Vector2.INF:
		_drag_controller.restore_user_position(preserved_drag_position)
	await get_tree().process_frame
	await get_tree().process_frame
	_fit_panel_height()


func _fit_panel_height() -> void:
	_panel_fit_queued = false
	if not is_inside_tree():
		return
	_apply_panel_height_from_content()
	call_deferred("_settle_panel_height_after_layout")


func _settle_panel_height_after_layout() -> void:
	if is_inside_tree():
		_apply_panel_height_from_content()


func _apply_panel_height_from_content() -> void:
	var header := name_label.get_parent() as HBoxContainer
	var content := header.get_parent() as VBoxContainer if header != null else null
	if content == null:
		return
	var available_height := maxf(1.0, _get_layout_viewport_size().y - PANEL_SCREEN_MARGIN * 2.0)
	var natural_height := content.get_combined_minimum_size().y + PANEL_CONTENT_VERTICAL_PADDING
	var target_height := minf(available_height, natural_height)
	offset_bottom = offset_top + target_height
	if _portrait_view != null:
		_portrait_view.offset_bottom = minf(
			target_height,
			minf(
				clampf(target_height * PORTRAIT_HEIGHT_RATIO, PORTRAIT_MIN_HEIGHT, PORTRAIT_MAX_HEIGHT),
				_get_portrait_height_limit_for_equipment(_get_layout_viewport_size().y)
			)
		)
	_layout_equipment_window()


func _get_portrait_height_limit_for_equipment(viewport_height: float) -> float:
	return maxf(
		240.0,
		viewport_height
		- PANEL_SCREEN_MARGIN * 2.0
		- EQUIPMENT_WINDOW_GAP
		- EQUIPMENT_WINDOW_SIZE.y
		- MOUNT_VIEW_BUTTON_GAP
		- MOUNT_VIEW_BUTTON_SIZE.y
	)


func show_npc(npc_id: String) -> void:
	if npc_id.is_empty():
		_current_npc_id = ""
		visible = false
		_hide_portrait_view()
		interaction_result_label.text = ""
		interaction_result_label.visible = false
		_close_memory_detail_popup()
		_hide_equipment_window()
		return

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.get_npc_ids().has(npc_id):
		_current_npc_id = ""
		visible = false
		_hide_portrait_view()
		interaction_result_label.text = ""
		interaction_result_label.visible = false
		_close_memory_detail_popup()
		_hide_equipment_window()
		return

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		_current_npc_id = ""
		visible = false
		_hide_portrait_view()
		interaction_result_label.text = ""
		interaction_result_label.visible = false
		_close_memory_detail_popup()
		_hide_equipment_window()
		return

	var previous_npc_id := _current_npc_id
	_current_npc_id = npc_id
	if previous_npc_id != npc_id:
		interaction_result_label.text = ""
		interaction_result_label.visible = false
		if _equipment_window != null:
			_equipment_window.close_picker()
		if _equipment_unequip_confirm != null:
			_equipment_unequip_confirm.hide()
		if _equipment_notice_dialog != null:
			_equipment_notice_dialog.hide()
		_clear_pending_unequip()
	var states: Dictionary = npc.get("states", {})
	_fill_weapon_select()
	_fill_armor_select()
	_fill_horse_select(npc)
	_refresh_strategy_label()

	name_label.text = str(npc.get("name", npc_id))
	name_label.modulate = RECRUITED_NAME_COLOR if bool(npc.get("recruited", false)) else DEFAULT_NAME_COLOR
	_update_llm_status_label(states)
	_update_active_buff_icons(states)
	job_label.text = _format_specialties(npc_system, npc_id)
	attributes_label.text = ""
	_update_hp_progress_control(states)
	_update_progression_controls(npc_system, npc)
	_update_need_progress_controls(states)
	money_label.text = "金钱：%d" % int(states.get("money", 0))
	wine_label.text = "酒：%d" % int(states.get("wine", 0))
	equipment_label.text = ""
	unconscious_label.text = "昏迷：%s" % _format_bool(states.get("unconscious", false))
	recruited_label.text = "已入伍：%s" % _format_bool(npc.get("recruited", false))
	assign_button.visible = true
	var current_action := str(states.get("current_action", "idle"))
	action_label.text = _format_action(current_action)
	action_label.modulate = DANGER_LABEL_COLOR if current_action == "escaping_station" else DEFAULT_ACTION_COLOR
	behavior_mode_label.text = _format_behavior_mode(str(states.get("behavior_mode", "work")))
	behavior_mode_label.modulate = BEHAVIOR_MODE_COLOR
	skills_label.text = _format_skills(npc_system, npc.get("skills", {}))
	_update_memory_labels(npc_id)
	_update_interaction_controls(npc)
	_refresh_equipment_window(npc)
	_refresh_mount_view_button(npc)
	visible = true
	if _portrait_view != null and _portrait_view.has_method("show_npc"):
		_portrait_view.show_npc(npc_id)
	_refresh_memory_detail_popup()
	_queue_panel_fit()


func _update_active_buff_icons(states: Dictionary) -> void:
	var morale: Dictionary = states.get("morale_boost", {}) if states.get("morale_boost", {}) is Dictionary else {}
	var morale_active := bool(morale.get("active", false))
	morale_boost_icon.visible = morale_active
	if morale_active:
		morale_boost_icon.tooltip_text = (
			"士气受到鼓舞\n攻击力 +%s\n移动速度 +%s\n持续至当天 24:00（剩余 %s）"
			% [
				_format_bonus_percent(float(morale.get("attack_bonus", 0.0))),
				_format_bonus_percent(float(morale.get("move_speed_bonus", 0.0))),
				_format_buff_remaining_time(float(morale.get("remaining_game_seconds", 0.0)))
			]
		)

	var work: Dictionary = states.get("work_encouragement_boost", {}) if states.get("work_encouragement_boost", {}) is Dictionary else {}
	var work_active := bool(work.get("active", false))
	work_boost_icon.visible = work_active
	if work_active:
		work_boost_icon.tooltip_text = (
			"工作效率提升\n全部工作产出效率 +%s\n包括生产、训练、协助升级、协助修复、协助治疗等\n持续至当天 24:00（剩余 %s）"
			% [
				_format_bonus_percent(float(work.get("output_bonus", 0.0))),
				_format_buff_remaining_time(float(work.get("remaining_game_seconds", 0.0)))
			]
		)


func _format_bonus_percent(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


func _format_buff_remaining_time(seconds: float) -> String:
	var remaining := maxi(0, int(ceil(seconds)))
	var hours := remaining / 3600
	var minutes := (remaining % 3600) / 60
	var secs := remaining % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]


func _hide_portrait_view() -> void:
	if _portrait_view != null and _portrait_view.has_method("hide_preview"):
		_portrait_view.hide_preview()


func _on_panel_visibility_changed() -> void:
	if not visible or _current_npc_id.is_empty():
		_hide_portrait_view()
		if not visible:
			_hide_equipment_window()
	elif _portrait_view != null and _portrait_view.has_method("show_npc"):
		_portrait_view.show_npc(_current_npc_id)


func debug_get_portrait_snapshot() -> Dictionary:
	var snapshot := {}
	if _portrait_view != null and _portrait_view.has_method("debug_get_snapshot"):
		snapshot = _portrait_view.debug_get_snapshot()
	var info_panel := get_node_or_null("PanelContainer") as Control
	snapshot["panel_visible"] = visible
	snapshot["panel_global_rect"] = get_global_rect()
	snapshot["info_global_rect"] = info_panel.get_global_rect() if info_panel != null else Rect2()
	return snapshot


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


func open_dialogue_history(npc_id: String) -> Dictionary:
	if npc_id.is_empty():
		return {"ok": false, "message": "missing_npc_id"}
	show_npc(npc_id)
	if _current_npc_id != npc_id:
		return {"ok": false, "message": "unknown_npc_id"}
	_open_memory_detail_popup("dialogue_history")
	return {
		"ok": _memory_detail_overlay != null and _memory_detail_overlay.visible,
		"npc_id": npc_id
	}


func _setup_interaction_controls() -> void:
	_interaction_visibility_group = ButtonGroup.new()
	_interaction_visibility_group.allow_unpress = false
	public_visibility_radio.button_group = _interaction_visibility_group
	private_visibility_radio.button_group = _interaction_visibility_group
	public_visibility_radio.button_pressed = true
	_apply_plain_radio_style(public_visibility_radio)
	_apply_plain_radio_style(private_visibility_radio)
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


func _apply_plain_radio_style(radio: CheckBox) -> void:
	if radio == null:
		return
	radio.focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		radio.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var normal_color := Color(0.94, 0.87, 0.70, 1.0)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		radio.add_theme_color_override(color_name, normal_color)


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
	header.move_child(_llm_status_label, behavior_mode_label.get_index() + 1)


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
	var management_row := give_weapon_button.get_parent() as HBoxContainer
	if management_row == null:
		return
	var parent := management_row.get_parent() as VBoxContainer
	if parent == null:
		return
	var strategy_row := HBoxContainer.new()
	strategy_row.name = "NPCCombatStrategyRow"
	strategy_row.add_theme_constant_override("separation", 6)
	parent.add_child(strategy_row)
	parent.move_child(strategy_row, management_row.get_index())
	var strategy_label := Label.new()
	strategy_label.text = "战斗策略："
	strategy_row.add_child(strategy_label)
	_strategy_value_label = Label.new()
	_strategy_value_label.name = "NPCCombatStrategyValue"
	_strategy_value_label.custom_minimum_size = Vector2(150, 30)
	_strategy_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strategy_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_strategy_value_label.tooltip_text = COMBAT_STRATEGY_TOOLTIP
	strategy_row.add_child(_strategy_value_label)

	equipment_label.visible = false
	give_weapon_button.text = "装备"
	assign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	give_weapon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_equipment_window()


func _setup_equipment_window() -> void:
	if _equipment_window != null:
		return
	_equipment_window = NPCEquipmentWindowScript.new() as NPCEquipmentWindow
	_equipment_window.name = "NPCEquipmentWindow"
	_equipment_window.visible = false
	_equipment_window.z_index = 70
	_equipment_window.slot_pressed.connect(_on_equipment_slot_pressed)
	_equipment_window.item_selected.connect(_on_equipment_item_selected)
	# Keep the equipment surface in the NPCPanel input branch. As a UI sibling it
	# could render above the panel via z_index while still losing GUI picking to
	# the panel's responsive portrait area.
	add_child(_equipment_window)

	_equipment_unequip_confirm = ConfirmationDialog.new()
	_equipment_unequip_confirm.name = "NPCEquipmentUnequipConfirm"
	_equipment_unequip_confirm.title = "收回装备"
	_equipment_unequip_confirm.ok_button_text = "是"
	_equipment_unequip_confirm.cancel_button_text = "否"
	_equipment_unequip_confirm.confirmed.connect(_on_equipment_unequip_confirmed)
	_equipment_unequip_confirm.canceled.connect(_clear_pending_unequip)
	_equipment_window.add_child(_equipment_unequip_confirm)

	_equipment_notice_dialog = AcceptDialog.new()
	_equipment_notice_dialog.name = "NPCEquipmentNotice"
	_equipment_notice_dialog.title = "装备"
	_equipment_notice_dialog.ok_button_text = "确定"
	_equipment_window.add_child(_equipment_notice_dialog)
	_layout_equipment_window()


func _layout_equipment_window() -> void:
	if _equipment_window == null or _portrait_view == null:
		return
	var portrait := _portrait_view as Control
	if portrait == null:
		return
	var portrait_rect := portrait.get_global_rect()
	var global_x: float = portrait_rect.end.x - EQUIPMENT_WINDOW_SIZE.x
	var info_panel := get_node_or_null("PanelContainer") as Control
	var panel_bottom := (
		info_panel.get_global_rect().end.y
		if info_panel != null
		else get_global_rect().end.y
	)
	var global_y: float = maxf(
		panel_bottom - EQUIPMENT_WINDOW_SIZE.y,
		portrait_rect.end.y + EQUIPMENT_WINDOW_GAP
	)
	var viewport_size := _get_layout_viewport_size()
	global_x = clampf(
		global_x,
		PANEL_SCREEN_MARGIN,
		viewport_size.x - PANEL_SCREEN_MARGIN - EQUIPMENT_WINDOW_SIZE.x
	)
	_equipment_window.global_position = Vector2(global_x, global_y)
	_layout_mount_view_button()


func _layout_mount_view_button() -> void:
	if _mount_view_button == null or _portrait_view == null or _equipment_window == null:
		return
	var portrait := _portrait_view as Control
	if portrait == null:
		return
	var portrait_rect := portrait.get_global_rect()
	var equipment_rect := _equipment_window.get_global_rect()
	var global_x := portrait_rect.end.x - MOUNT_VIEW_BUTTON_SIZE.x
	var global_y := minf(
		portrait_rect.end.y + MOUNT_VIEW_BUTTON_GAP,
		equipment_rect.position.y - MOUNT_VIEW_BUTTON_GAP - MOUNT_VIEW_BUTTON_SIZE.y
	)
	_mount_view_button.global_position = Vector2(global_x, global_y)
	_mount_view_button.size = MOUNT_VIEW_BUTTON_SIZE


func _refresh_mount_view_button(npc: Dictionary) -> void:
	if _mount_view_button == null:
		return
	var horse_id := _get_current_ridden_horse_id(npc)
	_mount_view_button.set_meta("horse_id", horse_id)
	_mount_view_button.visible = not horse_id.is_empty()
	if _mount_view_button.visible:
		_layout_mount_view_button()


func _get_current_ridden_horse_id(npc: Dictionary) -> String:
	if npc.is_empty():
		return ""
	var states: Dictionary = npc.get("states", {}) if npc.get("states", {}) is Dictionary else {}
	if not bool(states.get("combat_mounted", false)):
		return ""
	var npc_id := str(npc.get("id", _current_npc_id))
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("get_assigned_horse_for_npc"):
		return ""
	var horse: Dictionary = horse_system.get_assigned_horse_for_npc(npc_id)
	if (
		horse.is_empty()
		or str(horse.get("location", "")) != "ridden"
		or str(horse.get("ridden_by_npc_id", "")) != npc_id
	):
		return ""
	return str(horse.get("horse_id", ""))


func _on_mount_view_button_pressed() -> void:
	var npc := _get_current_npc()
	var horse_id := _get_current_ridden_horse_id(npc)
	if horse_id.is_empty():
		_refresh_mount_view_button(npc)
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("horse_clicked"):
		event_bus.horse_clicked.emit(horse_id)


func _on_equipment_button_pressed() -> void:
	if _equipment_window == null or _current_npc_id.is_empty():
		return
	_equipment_window.visible = not _equipment_window.visible
	if not _equipment_window.visible:
		_equipment_window.close_picker()
		_clear_pending_unequip()
		return
	var npc := _get_current_npc()
	if not npc.is_empty():
		_refresh_equipment_window(npc)
	_layout_equipment_window()
	_equipment_window.move_to_front()
	_equipment_window.call_deferred("move_to_front")


func _on_equipment_slot_pressed(slot: String) -> void:
	var npc := _get_current_npc()
	if npc.is_empty():
		return
	var lock_reason := _get_equipment_change_lock_reason(npc)
	if not lock_reason.is_empty():
		_show_equipment_notice(lock_reason)
		return
	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	var item: Dictionary = equipment.get(slot, {}) if equipment.get(slot, {}) is Dictionary else {}
	if not item.is_empty():
		_pending_unequip_slot = slot
		_pending_unequip_npc_id = _current_npc_id
		_equipment_unequip_confirm.dialog_text = "收回%s？" % str(item.get("name", item.get("horse_name", "装备")))
		_equipment_unequip_confirm.popup_centered()
		return
	if slot == "mount" and (equipment.get("main_weapon", {}) as Dictionary).is_empty():
		_show_equipment_notice("需先装备主武器。")
		return
	_refresh_equipment_window(npc)
	_equipment_window.open_picker(slot)


func _on_equipment_item_selected(slot: String, item: Dictionary) -> void:
	var npc := _get_current_npc()
	if npc.is_empty():
		return
	var lock_reason := _get_equipment_change_lock_reason(npc)
	if not lock_reason.is_empty():
		_equipment_window.close_picker()
		_show_equipment_notice(lock_reason)
		return
	var item_id := str(item.get("id", item.get("horse_id", "")))
	var result := {"ok": false, "message": "装备系统不可用。"}
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or item_id.is_empty():
		_show_interaction_result(result, "")
		return
	match slot:
		"main_weapon":
			if equipment_system.has_method("equip_npc_main_weapon"):
				result = equipment_system.equip_npc_main_weapon(_current_npc_id, item_id, _get_selected_visibility())
		"helmet", "chest", "bracers", "greaves":
			if equipment_system.has_method("equip_npc_armor"):
				result = equipment_system.equip_npc_armor(_current_npc_id, slot, item_id, _get_selected_visibility())
		"mount":
			if equipment_system.has_method("equip_npc_mount"):
				result = equipment_system.equip_npc_mount(_current_npc_id, item_id, _get_selected_visibility())
	_show_interaction_result(result, "已装备%s。" % str(item.get("name", item.get("horse_name", item_id))))
	if bool(result.get("ok", false)):
		_equipment_window.close_picker()
		show_npc(_current_npc_id)


func _on_equipment_unequip_confirmed() -> void:
	var slot := _pending_unequip_slot
	var npc_id := _pending_unequip_npc_id
	_clear_pending_unequip()
	if slot.is_empty() or npc_id.is_empty() or npc_id != _current_npc_id:
		return
	var npc := _get_current_npc()
	var lock_reason := _get_equipment_change_lock_reason(npc)
	if npc.is_empty() or not lock_reason.is_empty():
		_show_equipment_notice(lock_reason if not lock_reason.is_empty() else "当前无法更换装备。")
		return
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("unequip_npc_slot"):
		return
	var result: Dictionary = equipment_system.unequip_npc_slot(
		npc_id,
		slot,
		_get_selected_visibility()
	)
	_show_interaction_result(result, "已收回装备。")
	if bool(result.get("ok", false)):
		show_npc(npc_id)


func _clear_pending_unequip() -> void:
	_pending_unequip_slot = ""
	_pending_unequip_npc_id = ""


func _show_equipment_notice(message: String) -> void:
	if _equipment_notice_dialog == null:
		return
	_equipment_notice_dialog.dialog_text = message
	_equipment_notice_dialog.popup_centered()


func _hide_equipment_window() -> void:
	if _equipment_window != null:
		_equipment_window.visible = false
		_equipment_window.close_picker()
	if _equipment_unequip_confirm != null:
		_equipment_unequip_confirm.hide()
	if _equipment_notice_dialog != null:
		_equipment_notice_dialog.hide()
	if _mount_view_button != null:
		_mount_view_button.visible = false
		_mount_view_button.set_meta("horse_id", "")
	_clear_pending_unequip()


func _get_current_npc() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty() or not npc_system.has_method("get_npc"):
		return {}
	return npc_system.get_npc(_current_npc_id)


func _is_equipment_change_locked(npc: Dictionary) -> bool:
	return not _get_equipment_change_lock_reason(npc).is_empty()


func _get_equipment_change_lock_reason(npc: Dictionary) -> String:
	var states: Dictionary = npc.get("states", {}) if npc.get("states", {}) is Dictionary else {}
	if not bool(npc.get("recruited", false)):
		return "尚未入伍，不能装备。"
	if bool(states.get("escaped", false)):
		return "已逃离，无法更换装备。"
	if str(states.get("behavior_mode", "work")) != "work":
		return "只有工作模式下才能更换装备或马匹。"
	return ""


func _refresh_equipment_window(npc: Dictionary) -> void:
	if _equipment_window == null:
		return
	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	_equipment_window.set_loadout(equipment)
	_equipment_window.set_options(_build_equipment_options(npc))
	var lock_reason := _get_equipment_change_lock_reason(npc)
	_equipment_window.set_interaction_locked(not lock_reason.is_empty(), lock_reason)


func _build_equipment_options(npc: Dictionary) -> Dictionary:
	var options := {
		"main_weapon": [],
		"helmet": [],
		"chest": [],
		"bracers": [],
		"greaves": [],
		"mount": [],
	}
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if equipment_system != null and resource_system != null and resource_system.has_method("get_resource"):
		if equipment_system.has_method("get_weapon_ids") and equipment_system.has_method("get_weapon_def"):
			for raw_weapon_id in equipment_system.get_weapon_ids():
				var weapon_id := str(raw_weapon_id)
				var definition: Dictionary = equipment_system.get_weapon_def(weapon_id)
				if _equipment_item_is_available(definition, resource_system):
					(options["main_weapon"] as Array).append(definition)
		if equipment_system.has_method("get_armor_ids") and equipment_system.has_method("get_armor_def"):
			for raw_armor_id in equipment_system.get_armor_ids():
				var armor_id := str(raw_armor_id)
				var definition: Dictionary = equipment_system.get_armor_def(armor_id)
				var slot := str(definition.get("equipment_slot", definition.get("slot", "")))
				if options.has(slot) and _equipment_item_is_available(definition, resource_system):
					(options[slot] as Array).append(definition)
	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	if not (equipment.get("main_weapon", {}) as Dictionary).is_empty():
		var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
		if horse_system != null and horse_system.has_method("get_available_horses_for_npc"):
			for raw_horse in horse_system.get_available_horses_for_npc(_current_npc_id):
				if raw_horse is Dictionary:
					var horse := (raw_horse as Dictionary).duplicate(true)
					horse["id"] = str(horse.get("horse_id", horse.get("id", "")))
					horse["name"] = str(horse.get("name", horse.get("horse_name", horse["id"])))
					(options["mount"] as Array).append(horse)
	return options


func _equipment_item_is_available(definition: Dictionary, resource_system: Node) -> bool:
	var resource_id := str(definition.get("source_resource_id", ""))
	return not resource_id.is_empty() and int(resource_system.get_resource(resource_id)) > 0


func debug_get_equipment_window_snapshot() -> Dictionary:
	if _equipment_window == null:
		return {}
	var snapshot := _equipment_window.debug_get_snapshot()
	snapshot["npc_id"] = _current_npc_id
	snapshot["button_text"] = give_weapon_button.text
	snapshot["summary_visible"] = equipment_label.visible
	snapshot["pending_unequip_slot"] = _pending_unequip_slot
	snapshot["notice_text"] = _equipment_notice_dialog.dialog_text if _equipment_notice_dialog != null else ""
	snapshot["mount_view_button_visible"] = _mount_view_button != null and _mount_view_button.visible
	snapshot["mount_view_button_horse_id"] = str(_mount_view_button.get_meta("horse_id", "")) if _mount_view_button != null else ""
	snapshot["mount_view_button_rect"] = _mount_view_button.get_global_rect() if _mount_view_button != null else Rect2()
	var info_panel := get_node_or_null("PanelContainer") as Control
	snapshot["info_panel_rect"] = info_panel.get_global_rect() if info_panel != null else Rect2()
	return snapshot


func debug_press_mount_view_button() -> Dictionary:
	_on_mount_view_button_pressed()
	return {
		"npc_panel_visible": visible,
		"npc_id": _current_npc_id,
		"horse_id": str(_mount_view_button.get_meta("horse_id", "")) if _mount_view_button != null else "",
	}


func debug_toggle_equipment_window() -> Dictionary:
	_on_equipment_button_pressed()
	return debug_get_equipment_window_snapshot()


func debug_press_equipment_slot(slot: String) -> Dictionary:
	_on_equipment_slot_pressed(slot)
	var snapshot := debug_get_equipment_window_snapshot()
	snapshot["confirm_visible"] = _equipment_unequip_confirm != null and _equipment_unequip_confirm.visible
	snapshot["notice_visible"] = _equipment_notice_dialog != null and _equipment_notice_dialog.visible
	return snapshot


func debug_select_equipment_item(slot: String, item_id: String) -> Dictionary:
	var npc := _get_current_npc()
	for raw_item in (_build_equipment_options(npc).get(slot, []) as Array):
		if raw_item is Dictionary:
			var item := raw_item as Dictionary
			if str(item.get("id", item.get("horse_id", ""))) == item_id:
				_on_equipment_item_selected(slot, item)
				break
	return debug_get_equipment_window_snapshot()


func debug_confirm_equipment_unequip() -> Dictionary:
	if _equipment_unequip_confirm != null:
		_equipment_unequip_confirm.hide()
	_on_equipment_unequip_confirmed()
	return debug_get_equipment_window_snapshot()


func _setup_progression_controls() -> void:
	var parent := attributes_label.get_parent() as VBoxContainer
	if parent == null:
		return

	parent.remove_child(hp_label)

	var attributes_index := attributes_label.get_index()
	parent.remove_child(attributes_label)
	var row := HBoxContainer.new()
	row.name = "NPCAttributePointRow"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	parent.move_child(row, attributes_index)

	attributes_label.text = ""
	attributes_label.visible = false
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
	_combat_stats_label.text = "攻击 0｜防御 0｜穿透 0｜攻速 0.00/秒"
	_combat_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_combat_stats_label)
	parent.move_child(_combat_stats_label, row.get_index() + 1)

	_experience_label = Label.new()
	_experience_label.name = "NPCExperienceLabel"
	_experience_label.text = "经验：0 / 10"
	var hp_row_index := job_label.get_index() + 1
	_hp_rate_label = Label.new()
	_hp_rate_label.name = "NPCHPRecoveryRateLabel"
	_hp_rate_label.visible = false
	_hp_rate_label.add_theme_font_size_override("font_size", 12)
	_hp_rate_label.add_theme_color_override("font_color", POSITIVE_RATE_LABEL_COLOR)
	_hp_progress = _add_progress_row(
		parent,
		hp_label,
		"NPCHPProgressRow",
		"NPCHPProgress",
		hp_row_index,
		_get_need_progress_fill_style(false),
		_hp_rate_label
	)
	_experience_progress = _add_progress_row(
		parent,
		_experience_label,
		"NPCExperienceProgressRow",
		"NPCExperienceProgress",
		hp_row_index + 1,
		_get_experience_progress_fill_style()
	)


func _format_bool(value: Variant) -> String:
	return "是" if bool(value) else "否"


func _format_action(action_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_action_display_text"):
		return str(npc_system.get_npc_action_display_text(action_id))
	return "空闲" if action_id.is_empty() or action_id == "idle" else "其他行动"


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
	return "力量 %d，智力 %d" % [
		int(stats.get("strength", 0)),
		int(stats.get("intelligence", 0))
	]


func _update_progression_controls(npc_system: Node, npc: Dictionary) -> void:
	var progression: Dictionary = npc.get("progression", {})
	if npc_system != null and npc_system.has_method("get_npc_progression"):
		progression = npc_system.get_npc_progression(str(npc.get("id", _current_npc_id)))
	var total_experience := int(progression.get("total_experience", 0))
	var unspent_points := int(progression.get("unspent_skill_points", 0))
	var next_point_xp := maxi(1, int(progression.get("current_level_experience_max", progression.get("next_skill_point_xp", 10))))
	var level_experience := clampi(
		int(progression.get("current_level_experience", total_experience % next_point_xp)),
		0,
		next_point_xp
	)
	if _experience_label != null:
		_experience_label.text = "经验：%d / %d" % [level_experience, next_point_xp]
	if _experience_progress != null:
		_experience_progress.min_value = 0.0
		_experience_progress.max_value = float(next_point_xp)
		_experience_progress.value = float(level_experience)
		_experience_progress.tooltip_text = _experience_label.text if _experience_label != null else ""
		_experience_progress.set_meta("normalized_ratio", float(level_experience) / float(next_point_xp))
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
		_combat_stats_label.text = "攻击 %.1f｜防御 %.1f｜穿透 %.1f｜攻速 %.2f/秒" % [
			float(final_stats.get("attack_power", 0.0)),
			float(final_stats.get("defense", 0.0)),
			float(final_stats.get("penetration", 0.0)),
			float(final_stats.get("attack_speed", 0.0))
		]


func _setup_need_progress_controls() -> void:
	_satiety_progress = _replace_need_label_with_progress(satiety_label, "NPCSatietyProgressRow", "NPCSatietyProgress")
	_fatigue_progress = _replace_need_label_with_progress(fatigue_label, "NPCFatigueProgressRow", "NPCFatigueProgress")
	if _fatigue_progress != null:
		_fatigue_progress.add_theme_stylebox_override("fill", _get_fatigue_progress_fill_style())


func _replace_need_label_with_progress(label: Label, row_name: String, progress_name: String) -> ProgressBar:
	var parent := label.get_parent() as VBoxContainer
	if parent == null:
		return null
	var label_index := label.get_index()
	parent.remove_child(label)
	return _add_progress_row(parent, label, row_name, progress_name, label_index, _get_need_progress_fill_style(false))


func _add_progress_row(
	parent: VBoxContainer,
	label: Label,
	row_name: String,
	progress_name: String,
	row_index: int,
	fill_style: StyleBoxFlat,
	rate_label: Label = null
) -> ProgressBar:
	var row := VBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	parent.move_child(row, clampi(row_index, 0, parent.get_child_count() - 1))
	label.add_theme_font_size_override("font_size", 12)
	if rate_label == null:
		row.add_child(label)
	else:
		var label_row := HBoxContainer.new()
		label_row.name = "%sHeader" % row_name
		label_row.add_theme_constant_override("separation", 8)
		label_row.add_child(label)
		label_row.add_child(rate_label)
		row.add_child(label_row)
	var progress := ProgressBar.new()
	progress.name = progress_name
	progress.custom_minimum_size.y = 16.0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("fill", fill_style)
	row.add_child(progress)
	return progress


func _update_hp_progress_control(states: Dictionary) -> void:
	var hp := float(states.get("hp", 0.0))
	var raw_max_hp := float(states.get("max_hp", 0.0))
	var max_hp := maxf(1.0, raw_max_hp)
	hp_label.text = "HP：%d / %d" % [int(round(hp)), int(round(raw_max_hp))]
	_update_hp_recovery_rate_label(states)
	if _hp_progress == null:
		return
	_hp_progress.min_value = 0.0
	_hp_progress.max_value = max_hp
	_hp_progress.value = clampf(hp, 0.0, max_hp)
	_hp_progress.tooltip_text = hp_label.text
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var danger := ratio < HP_DANGER_RATIO
	_hp_progress.set_meta("danger_state", danger)
	_hp_progress.set_meta("normalized_ratio", ratio)
	_hp_progress.add_theme_stylebox_override("fill", _get_need_progress_fill_style(danger))
	if danger:
		hp_label.add_theme_color_override("font_color", DANGER_LABEL_COLOR)
	else:
		hp_label.remove_theme_color_override("font_color")


func _update_hp_recovery_rate_label(states: Dictionary) -> void:
	if _hp_rate_label == null:
		return
	_hp_rate_label.text = ""
	_hp_rate_label.visible = false
	if not bool(states.get("unconscious", false)) or _current_npc_id.is_empty():
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("get_healing_assist_rate_snapshot"):
		return
	var rate: Dictionary = action_system.get_healing_assist_rate_snapshot(_current_npc_id)
	if not bool(rate.get("active", false)):
		return
	var text := RateDisplayFormatter.format_positive_rate(float(rate.get("hp_per_game_second", 0.0)))
	if text.is_empty():
		return
	_hp_rate_label.text = text
	_hp_rate_label.visible = true


func _update_need_progress_controls(states: Dictionary) -> void:
	_update_need_progress(
		_satiety_progress,
		satiety_label,
		"satiety",
		"饱食度",
		float(states.get("satiety", 0.0)),
		true
	)
	_update_need_progress(
		_fatigue_progress,
		fatigue_label,
		"fatigue",
		"疲劳度",
		float(states.get("fatigue", 0.0)),
		false
	)


func _update_need_progress(
	progress: ProgressBar,
	label: Label,
	need_id: String,
	display_name: String,
	value: float,
	danger_when_low: bool
) -> void:
	if progress == null or label == null:
		return
	var bounds := {"min": 0.0, "max": 100.0}
	var needs_system := get_node_or_null(NPC_NEEDS_SYSTEM_PATH)
	if needs_system != null and needs_system.has_method("get_need_bounds"):
		bounds = needs_system.get_need_bounds(need_id)
	var minimum := float(bounds.get("min", 0.0))
	var maximum := maxf(minimum + 0.001, float(bounds.get("max", 100.0)))
	progress.min_value = minimum
	progress.max_value = maximum
	progress.value = clampf(value, minimum, maximum)
	label.text = "%s %d / %d" % [display_name, int(round(value)), int(round(maximum))]
	progress.tooltip_text = label.text
	var ratio := clampf((value - minimum) / (maximum - minimum), 0.0, 1.0)
	var danger := ratio < SATIETY_DANGER_RATIO if danger_when_low else ratio > FATIGUE_DANGER_RATIO
	progress.set_meta("danger_state", danger)
	var fill_style := _get_need_progress_fill_style(danger)
	if not danger and not danger_when_low:
		fill_style = _get_fatigue_progress_fill_style()
	progress.add_theme_stylebox_override("fill", fill_style)
	if danger:
		label.add_theme_color_override("font_color", DANGER_LABEL_COLOR)
	else:
		label.remove_theme_color_override("font_color")


func _get_need_progress_fill_style(danger: bool) -> StyleBoxFlat:
	if _normal_progress_fill_style == null:
		_normal_progress_fill_style = _make_need_progress_fill_style(NORMAL_PROGRESS_FILL_COLOR)
	if _danger_progress_fill_style == null:
		_danger_progress_fill_style = _make_need_progress_fill_style(DANGER_PROGRESS_FILL_COLOR)
	return _danger_progress_fill_style if danger else _normal_progress_fill_style


func _get_experience_progress_fill_style() -> StyleBoxFlat:
	if _experience_progress_fill_style == null:
		_experience_progress_fill_style = _make_need_progress_fill_style(EXPERIENCE_PROGRESS_FILL_COLOR)
	return _experience_progress_fill_style


func _get_fatigue_progress_fill_style() -> StyleBoxFlat:
	if _fatigue_progress_fill_style == null:
		_fatigue_progress_fill_style = _make_need_progress_fill_style(FATIGUE_PROGRESS_FILL_COLOR)
	return _fatigue_progress_fill_style


func _make_need_progress_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	return style


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
		_set_memory_block_text(event_log_label, _event_log_text, "事件", [])
		if _event_log_text != null:
			_event_log_text.text = "不可用"
		_set_memory_block_text(witness_log_label, _witness_log_text, "见闻", [])
		if _witness_log_text != null:
			_witness_log_text.text = "不可用"
		_refresh_memory_detail_popup()
		_scroll_memory_logs_to_bottom_deferred()
		return

	var event_log: Array = memory_system.get_npc_daily_events(npc_id)
	var witness_log: Array = memory_system.get_npc_witness_events(npc_id)
	_event_log_cache = event_log.duplicate(true)
	_witness_log_cache = witness_log.duplicate(true)
	_set_memory_block_text(event_log_label, _event_log_text, "事件", event_log)
	_set_memory_block_text(witness_log_label, _witness_log_text, "见闻", witness_log)
	_refresh_memory_detail_popup()
	_scroll_memory_logs_to_bottom_deferred()


func _update_interaction_controls(npc: Dictionary) -> void:
	var states: Dictionary = npc.get("states", {})
	var is_escaped := bool(states.get("escaped", false))
	var is_work_mode := str(states.get("behavior_mode", "work")) == "work"
	var is_deep_sleeping := bool(states.get("first_sleep_summary_active", false))
	var llm_activity: Dictionary = states.get("llm_activity", {}) if states.get("llm_activity", {}) is Dictionary else {}
	var is_planning := bool(llm_activity.get("active", false)) and str(llm_activity.get("kind", "")) == "plan"
	var is_recruited := bool(npc.get("recruited", false))
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var has_money := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("money")) >= int(gift_money_spin.value)
	var has_wine := resource_system != null and resource_system.has_method("get_resource") and int(resource_system.get_resource("wine")) >= int(gift_wine_spin.value)
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
	give_weapon_button.disabled = not is_recruited
	give_weapon_button.tooltip_text = "打开装备。" if is_recruited else EQUIPMENT_RECRUITMENT_TOOLTIP
	assign_button.visible = true
	assign_button.disabled = not is_recruited
	assign_button.tooltip_text = "撰写或修改该 NPC 当前持续生效的自然语言指令。" if is_recruited else ORDER_RECRUITMENT_TOOLTIP
	if _strategy_value_label != null:
		_strategy_value_label.modulate = Color(1.0, 1.0, 1.0, 0.45 if is_escaped or not is_recruited else 1.0)
		_set_recruitment_gate_tooltip(_strategy_value_label, is_recruited, COMBAT_STRATEGY_TOOLTIP)


func _set_recruitment_gate_tooltip(control: Control, is_recruited: bool, default_text: String) -> void:
	if control == null:
		return
	control.tooltip_text = default_text if is_recruited else RECRUITMENT_REQUIRED_TOOLTIP


func _set_loadout_tooltip(control: Control, is_recruited: bool, is_work_mode: bool, default_text: String) -> void:
	if control == null:
		return
	if not is_recruited:
		control.tooltip_text = RECRUITMENT_REQUIRED_TOOLTIP
	elif not is_work_mode:
		control.tooltip_text = LOADOUT_LOCKED_TOOLTIP
	else:
		control.tooltip_text = default_text


func _get_escape_dialogue_state(npc_id: String) -> Dictionary:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or npc_id.is_empty() or not combat_system.has_method("get_escape_intervention_state"):
		return {}
	return combat_system.get_escape_intervention_state(npc_id)


func _get_selected_visibility() -> String:
	return "private" if private_visibility_radio.button_pressed else "local_public"


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
		elif str(npc.get("states", {}).get("behavior_mode", "work")) != "work":
			_set_horse_status("战时无法更换装备或马匹。")
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
			_format_horse_location(location)
		])


func _format_horse_location(location: String) -> String:
	match location:
		"stable":
			return "在马厩"
		"approaching_rider":
			return "正奔向骑手"
		"ridden":
			return "已骑乘离厩"
		"returning_stable":
			return "正返回马厩"
		"dead":
			return "已阵亡"
		_:
			return "位置未知"


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


func _refresh_strategy_label() -> void:
	if _strategy_value_label == null:
		return
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or _current_npc_id.is_empty() or not combat_system.has_method("get_npc_combat_strategy"):
		_strategy_value_label.text = "无策略"
		return
	var current: Dictionary = combat_system.get_npc_combat_strategy(_current_npc_id)
	_strategy_value_label.text = str(current.get("label", "无策略")) if not current.is_empty() else "无策略"


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
	_event_log_text = _wrap_memory_label(event_log_label, "NPCEventLogBox", "NPCEventLogText", "事件")
	_witness_log_text = _wrap_memory_label(witness_log_label, "NPCWitnessLogBox", "NPCWitnessLogText", "见闻")
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
	_memory_detail_title_label.text = "事件"
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
	match _memory_detail_mode:
		"background":
			var setting := _get_current_npc_prompt_setting()
			title = "人物背景"
			detail_text = _format_npc_background_block(setting)
		"current_plan":
			var plan := _get_current_daily_plan()
			title = "当前计划"
			detail_text = _format_current_plan_block(plan)
		"diary":
			var diary := _get_current_diary()
			title = "日记"
			detail_text = _format_diary_block(diary)
		"knowledge":
			var graph := _get_current_knowledge_graph()
			title = "认识"
			detail_text = _format_knowledge_graph_block(graph)
		"dialogue_history":
			var dialogues := _get_current_guard_dialogue_history()
			title = "对话记录"
			detail_text = _format_guard_dialogue_history_block(dialogues)
		_:
			var events := _event_log_cache if _memory_detail_mode == "event_log" else _witness_log_cache
			title = "事件" if _memory_detail_mode == "event_log" else "见闻"
			detail_text = _format_memory_detail_block(events)
	if _memory_detail_title_label != null:
		_memory_detail_title_label.text = "%s｜%s" % [
			str(name_label.text),
			title
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
		title_label.text = title
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


func _on_horse_clicked(_horse_id: String) -> void:
	visible = false
	_hide_portrait_view()
	_close_memory_detail_popup()
	_hide_equipment_window()


func _on_enemy_clicked(_enemy_id: String) -> void:
	visible = false
	_hide_portrait_view()
	_close_memory_detail_popup()
	_hide_equipment_window()


func _on_npc_state_changed(npc_id: String) -> void:
	if not visible:
		return
	var current_npc := _get_current_npc()
	var current_states: Dictionary = (
		current_npc.get("states", {}) if current_npc.get("states", {}) is Dictionary else {}
	)
	if npc_id == _current_npc_id or bool(current_states.get("unconscious", false)):
		show_npc(_current_npc_id)


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
		_refresh_equipment_window(npc)


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
	_refresh_equipment_window(npc)
	_refresh_mount_view_button(npc)
	_queue_panel_fit()


func _on_building_clicked(_building_id: String) -> void:
	visible = false
	_hide_portrait_view()
	_close_memory_detail_popup()
	_hide_equipment_window()


func _on_defense_device_clicked(_deployment_id: String) -> void:
	visible = false
	_hide_portrait_view()
	_close_memory_detail_popup()
	_hide_equipment_window()


func _on_close_pressed() -> void:
	visible = false
	_hide_portrait_view()
	_close_memory_detail_popup()
	_hide_equipment_window()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("world_selection_cleared"):
		event_bus.world_selection_cleared.emit()


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


# 战斗策略改为只读显示；调整入口位于符合条件的战时对话。
