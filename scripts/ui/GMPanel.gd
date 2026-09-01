extends Control

const GM_ENABLED := true
const DialogueEmotionCatalog = preload("res://scripts/core/DialogueEmotionCatalog.gd")

const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const ROOF_VISIBILITY_CONTROLLER_PATH := "/root/Main/Presentation/RoofVisibilityController"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"
const BLACKSMITH_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt"
const WORKSHOP_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt"
const CHAPEL_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Chapel/ChapelArt"
const CLINIC_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Clinic/ClinicArt"
const DINING_HALL_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall/DiningHallArt"
const DORMITORY_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory/DormitoryArt"
const TAVERN_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Tavern/TavernArt"
const GARDEN_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Garden/GardenArt"
const TRAINING_GROUND_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/TrainingGround/TrainingGroundArt"
const STABLE_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Stable/StableArt"
const MAIN_HALL_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt"
const WAREHOUSE_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots/Warehouse/WarehouseArt"
const FORTIFICATION_ART_VIEW_PATH := "/root/Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt"
const LEGACY_BLACKSMITH_ART_VIEW_PATH := "/root/Main/WorldRoot/Station/Buildings/BlacksmithArtView"
const ACTOR_MOTION_SANDBOX_PATH := "res://scenes/debug/ActorMotionSandbox.tscn"
const NPC_DEV_LAB_PATH := "res://scenes/debug/NPCDevLab.tscn"
const CHIBI_CHARACTER_PREVIEW_CONTROLLER_PATH := "/root/Main/Presentation/ChibiCharacterPilotPreviewController"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const DAILY_PLAN_SYSTEM_PATH := "/root/Main/Systems/DailyPlanSystem"
const DAILY_REFLECTION_SYSTEM_PATH := "/root/Main/Systems/DailyReflectionSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const PIETY_SYSTEM_PATH := "/root/Main/Systems/PietySystem"
const CRAFTING_SYSTEM_PATH := "/root/Main/Systems/CraftingSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const MERCHANT_SYSTEM_PATH := "/root/Main/Systems/MerchantSystem"
const SPATIAL_SAVE_SYSTEM_PATH := "/root/Main/Systems/SpatialSaveSystem"

const DEFAULT_LOCATION_IDS := [
	"plaza", "dormitory", "dining_hall", "tavern", "garden", "blacksmith",
	"training_ground", "stable", "chapel", "clinic", "workshop"
]
const DEFAULT_VISIBILITIES := ["private", "local_public"]
const LEGACY_AGGREGATE_RESOURCE_IDS := ["weapons", "armor", "defense_devices", "horse_readiness"]
const COMMAND_HISTORY_LIMIT := 40
const PANEL_BUTTON_GAP := 8.0
const MIN_USABLE_VIEWPORT_SIZE := Vector2(320.0, 240.0)
const FALLBACK_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const LLM_USAGE_REFRESH_SECONDS := 3.0

var _gm_button: Button
var _panel: PanelContainer
var _llm_usage_summary_label: Label
var _command_input: LineEdit
var _result_text: TextEdit
var _resource_select: OptionButton
var _resource_amount_input: LineEdit
var _building_select: OptionButton
var _building_amount_input: LineEdit
var _npc_select: OptionButton
var _formal_action_npc_select: OptionButton
var _ai_npc_select: OptionButton
var _npc_dialogue_target_select: OptionButton
var _npc_state_key_input: LineEdit
var _npc_state_value_input: LineEdit
var _attribute_select: OptionButton
var _order_text_input: LineEdit
var _proactive_talk_input: LineEdit
var _location_select: OptionButton
var _formal_action_location_select: OptionButton
var _action_select: OptionButton
var _combat_wave_select: OptionButton
var _equipment_weapon_select: OptionButton
var _equipment_armor_slot_select: OptionButton
var _crafting_building_select: OptionButton
var _crafting_recipe_select: OptionButton
var _horse_select: OptionButton
var _horse_damage_input: LineEdit
var _horse_advance_input: LineEdit
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
var _llm_usage_refresh_elapsed := 0.0
var _llm_usage_request_pending := false


func _ready() -> void:
	visible = GM_ENABLED
	if not GM_ENABLED:
		process_mode = Node.PROCESS_MODE_DISABLED
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_connect_llm_usage_signal()
	call_deferred("_refresh_options")


func _process(delta: float) -> void:
	if _panel != null and _panel.visible:
		_position_panel_near_button()
		_llm_usage_refresh_elapsed += delta
		if _llm_usage_refresh_elapsed >= LLM_USAGE_REFRESH_SECONDS:
			_llm_usage_refresh_elapsed = 0.0
			_request_llm_usage_refresh()


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
	_panel.custom_minimum_size = Vector2(900, 620)
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

	_llm_usage_summary_label = Label.new()
	_llm_usage_summary_label.name = "LLMUsageSummaryLabel"
	_llm_usage_summary_label.text = "本次运行：等待后端用量…"
	_llm_usage_summary_label.tooltip_text = "按正式供应商每次 HTTP 尝试累计；人民币为基于供应商 usage 与配置单价的估算。"
	_llm_usage_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_llm_usage_summary_label.add_theme_font_size_override("font_size", 13)
	_llm_usage_summary_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	content.add_child(_llm_usage_summary_label)

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

	var quick_row := HBoxContainer.new()
	quick_row.name = "GMQuickActions"
	quick_row.add_theme_constant_override("separation", 8)
	content.add_child(quick_row)
	var quick_label := Label.new()
	quick_label.text = "快捷操作"
	quick_label.add_theme_font_size_override("font_size", 15)
	quick_row.add_child(quick_label)
	var recruit_and_equip_all_button := _add_button(
		quick_row,
		"一键征召&配装",
		_run_recruit_and_equip_all
	)
	recruit_and_equip_all_button.name = "RecruitAndEquipAllButton"
	recruit_and_equip_all_button.custom_minimum_size = Vector2(180, 38)
	recruit_and_equip_all_button.tooltip_text = "全员入伍并配置四名步兵、四名骑手及指定全甲组合"
	var quick_hint := Label.new()
	quick_hint.text = "用于八人阵型、取马和战斗回归；重复点击保持幂等"
	quick_hint.modulate = Color(0.78, 0.82, 0.88, 1.0)
	quick_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_row.add_child(quick_hint)

	var tabs := TabContainer.new()
	tabs.name = "GMSectionTabs"
	tabs.custom_minimum_size = Vector2(876, 330)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var common_sections := _make_tab_sections(tabs, "常用")
	var world_sections := _make_tab_sections(tabs, "世界建筑")
	var crafting_sections := _make_tab_sections(tabs, "制造马匹")
	var action_sections := _make_tab_sections(tabs, "正式行动")
	var ai_sections := _make_tab_sections(tabs, "AI信息")

	_add_resource_section(common_sections)
	_add_time_section(common_sections)
	_add_npc_section(common_sections)
	_add_combat_section(common_sections)
	_add_building_section(world_sections)
	_add_crafting_horse_section(crafting_sections)
	_add_action_section(action_sections)
	_add_backend_section(ai_sections)
	_add_memory_section(ai_sections)

	_result_text = TextEdit.new()
	_result_text.editable = false
	_result_text.custom_minimum_size = Vector2(876, 100)
	_result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_result_text)
	_log("GM 面板已就绪。输入 help 查看命令。")


func _make_tab_sections(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.name = "%sSections" % tab_name
	sections.add_theme_constant_override("separation", 10)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sections)
	return sections


func _add_resource_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("资源"))
	var row := _make_row(parent)
	_resource_select = _make_select(row)
	_resource_select.name = "ResourceSelect"
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
	_add_button(row, "推进模拟 1 小时", _run_advance_hour)
	_add_button(row, "LLM 减速", func() -> void:
		_run_slowdown("gm_manual", -1.0, "gm_manual")
	)
	_add_button(row, "清减速", _run_clear_slowdowns)
	_add_button(row, "快照", _show_time_snapshot)
	var merchant_row := _make_row(parent)
	var merchant_label := Label.new()
	merchant_label.text = "T0129C 行商马车"
	merchant_row.add_child(merchant_label)
	_add_button(merchant_row, "强制进场", _run_merchant_wagon_arrival)
	_add_button(merchant_row, "正式商路", _run_formal_merchant_wagon_arrival)
	_add_button(merchant_row, "强制离场", _run_merchant_wagon_departure)
	_add_button(merchant_row, "马车快照", _show_merchant_wagon_snapshot)


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
	var roof_snapshot_button := _add_button(row, "屋顶快照", _show_roof_visibility_snapshot)
	roof_snapshot_button.name = "RoofVisibilitySnapshotButton"
	var art_preview_row := _make_row(parent)
	var art_preview_label := Label.new()
	art_preview_label.text = "铁匠铺美术预览（不改权威等级）"
	art_preview_row.add_child(art_preview_label)
	for preview_level in [1, 2, 3]:
		_add_button(
			art_preview_row,
			"等级 %d" % preview_level,
			_run_smithy_art_level.bind(preview_level)
		)
	var workshop_art_preview_row := _make_row(parent)
	var workshop_art_preview_label := Label.new()
	workshop_art_preview_label.text = "工械坊美术预览（不改权威等级）"
	workshop_art_preview_row.add_child(workshop_art_preview_label)
	for preview_level in [1, 2, 3]:
		var workshop_preview_button := _add_button(
			workshop_art_preview_row,
			"等级 %d" % preview_level,
			_run_workshop_art_level.bind(preview_level)
		)
		workshop_preview_button.name = "WorkshopArtLevel%dButton" % preview_level
	var chapel_art_preview_row := _make_row(parent)
	var chapel_art_preview_label := Label.new()
	chapel_art_preview_label.text = "小教堂美术预览（不改权威等级）"
	chapel_art_preview_row.add_child(chapel_art_preview_label)
	for preview_level in [1, 2]:
		var chapel_preview_button := _add_button(
			chapel_art_preview_row,
			"等级 %d" % preview_level,
			_run_chapel_art_level.bind(preview_level)
		)
		chapel_preview_button.name = "ChapelArtLevel%dButton" % preview_level
	var clinic_art_preview_row := _make_row(parent)
	var clinic_art_preview_label := Label.new()
	clinic_art_preview_label.text = "小诊所美术预览（不改权威等级）"
	clinic_art_preview_row.add_child(clinic_art_preview_label)
	for preview_level in [1, 2, 3]:
		var clinic_preview_button := _add_button(
			clinic_art_preview_row,
			"等级 %d" % preview_level,
			_run_clinic_art_level.bind(preview_level)
		)
		clinic_preview_button.name = "ClinicArtLevel%dButton" % preview_level
	var dining_hall_art_preview_row := _make_row(parent)
	var dining_hall_art_preview_label := Label.new()
	dining_hall_art_preview_label.text = "食堂美术预览（不改权威等级）"
	dining_hall_art_preview_row.add_child(dining_hall_art_preview_label)
	for preview_level in [1, 2, 3]:
		var dining_hall_preview_button := _add_button(
			dining_hall_art_preview_row,
			"等级 %d" % preview_level,
			_run_dining_hall_art_level.bind(preview_level)
		)
		dining_hall_preview_button.name = "DiningHallArtLevel%dButton" % preview_level
	var dormitory_art_preview_row := _make_row(parent)
	var dormitory_art_preview_label := Label.new()
	dormitory_art_preview_label.text = "宿舍美术预览（不改权威等级）"
	dormitory_art_preview_row.add_child(dormitory_art_preview_label)
	for preview_level in [1, 2]:
		var dormitory_preview_button := _add_button(
			dormitory_art_preview_row,
			"等级 %d" % preview_level,
			_run_dormitory_art_level.bind(preview_level)
		)
		dormitory_preview_button.name = "DormitoryArtLevel%dButton" % preview_level
	var tavern_art_preview_row := _make_row(parent)
	var tavern_art_preview_label := Label.new()
	tavern_art_preview_label.text = "酒窖美术预览（不改权威等级）"
	tavern_art_preview_row.add_child(tavern_art_preview_label)
	for preview_level in [1, 2, 3]:
		var tavern_preview_button := _add_button(
			tavern_art_preview_row,
			"等级 %d" % preview_level,
			_run_tavern_art_level.bind(preview_level)
		)
		tavern_preview_button.name = "TavernArtLevel%dButton" % preview_level
	var garden_art_preview_row := _make_row(parent)
	var garden_art_preview_label := Label.new()
	garden_art_preview_label.text = "菜园美术预览（不改权威等级）"
	garden_art_preview_row.add_child(garden_art_preview_label)
	for preview_level in [1, 2, 3]:
		var garden_preview_button := _add_button(
			garden_art_preview_row,
			"等级 %d" % preview_level,
			_run_garden_art_level.bind(preview_level)
		)
		garden_preview_button.name = "GardenArtLevel%dButton" % preview_level
	var training_ground_art_preview_row := _make_row(parent)
	var training_ground_art_preview_label := Label.new()
	training_ground_art_preview_label.text = "训练场美术预览（不改权威等级）"
	training_ground_art_preview_row.add_child(training_ground_art_preview_label)
	for preview_level in [1, 2, 3]:
		var training_ground_preview_button := _add_button(
			training_ground_art_preview_row,
			"等级 %d" % preview_level,
			_run_training_ground_art_level.bind(preview_level)
		)
		training_ground_preview_button.name = "TrainingGroundArtLevel%dButton" % preview_level
	var stable_art_preview_row := _make_row(parent)
	var stable_art_preview_label := Label.new()
	stable_art_preview_label.text = "马厩美术预览（不改权威等级）"
	stable_art_preview_row.add_child(stable_art_preview_label)
	for preview_level in [1, 2, 3]:
		var stable_preview_button := _add_button(
			stable_art_preview_row,
			"等级 %d" % preview_level,
			_run_stable_art_level.bind(preview_level)
		)
		stable_preview_button.name = "StableArtLevel%dButton" % preview_level
	var main_hall_art_preview_row := _make_row(parent)
	var main_hall_art_preview_label := Label.new()
	main_hall_art_preview_label.text = "主厅美术预览（不改权威等级）"
	main_hall_art_preview_row.add_child(main_hall_art_preview_label)
	for preview_level in [1, 2, 3, 4, 5, 6]:
		var main_hall_preview_button := _add_button(
			main_hall_art_preview_row,
			"等级 %d" % preview_level,
			_run_main_hall_art_level.bind(preview_level)
		)
		main_hall_preview_button.name = "MainHallArtLevel%dButton" % preview_level
	var warehouse_art_preview_row := _make_row(parent)
	var warehouse_art_preview_label := Label.new()
	warehouse_art_preview_label.text = "仓库美术预览（不改权威等级）"
	warehouse_art_preview_row.add_child(warehouse_art_preview_label)
	for preview_level in [1, 2, 3]:
		var warehouse_preview_button := _add_button(
			warehouse_art_preview_row,
			"等级 %d" % preview_level,
			_run_warehouse_art_level.bind(preview_level)
		)
		warehouse_preview_button.name = "WarehouseArtLevel%dButton" % preview_level
	var wall_art_preview_row := _make_row(parent)
	var wall_art_preview_label := Label.new()
	wall_art_preview_label.text = "围墙美术预览（不改权威等级）"
	wall_art_preview_row.add_child(wall_art_preview_label)
	for preview_level in [1, 2, 3, 4, 5, 6]:
		var wall_preview_button := _add_button(
			wall_art_preview_row,
			"等级 %d" % preview_level,
			_run_wall_art_level.bind(preview_level)
		)
		wall_preview_button.name = "WallArtLevel%dButton" % preview_level
	var gate_snapshot_button := _add_button(wall_art_preview_row, "城门快照", _show_gate_art_snapshot)
	gate_snapshot_button.name = "GateArtSnapshotButton"
	var layout_preview_row := _make_row(parent)
	var layout_preview_label := Label.new()
	layout_preview_label.text = "T0129C-A5-P7 默认正式空间"
	layout_preview_row.add_child(layout_preview_label)
	var preview_button := _add_button(
		layout_preview_row,
		"恢复默认正式世界",
		_run_station_layout_preview.bind(true)
	)
	preview_button.name = "StationLayoutPreviewButton"
	_add_button(layout_preview_row, "布局快照", _show_station_layout_snapshot)
	var spatial_save_row := _make_row(parent)
	var spatial_save_label := Label.new()
	spatial_save_label.text = "T0129C-A5-P8 正式空间检查点"
	spatial_save_row.add_child(spatial_save_label)
	var spatial_save_button := _add_button(spatial_save_row, "保存空间", _run_formal_spatial_save)
	spatial_save_button.name = "FormalSpatialSaveButton"
	var spatial_load_button := _add_button(spatial_save_row, "读取空间", _run_formal_spatial_load)
	spatial_load_button.name = "FormalSpatialLoadButton"
	_add_button(spatial_save_row, "存档快照", _show_formal_spatial_save_snapshot)
	var motion_sandbox_row := _make_row(parent)
	var motion_sandbox_label := Label.new()
	motion_sandbox_label.text = "T0129C-A2 实体运动（独立验证）"
	motion_sandbox_row.add_child(motion_sandbox_label)
	var motion_sandbox_button := _add_button(
		motion_sandbox_row,
		"运行运动沙盒（F8 返回）",
		_run_actor_motion_sandbox
	)
	motion_sandbox_button.name = "ActorMotionSandboxButton"
	var character_pilot_row := _make_row(parent)
	var character_pilot_label := Label.new()
	character_pilot_label.text = "T0130-D1 角色与装备开发检视"
	character_pilot_row.add_child(character_pilot_label)
	var character_sandbox_button := _add_button(character_pilot_row, "NPC 开发检视场景", _run_npc_dev_lab)
	character_sandbox_button.name = "NPCDevLabButton"
	_add_button(character_pilot_row, "正式角色快照", _show_chibi_formal_character_snapshot)
	var formal_stable_row := _make_row(parent)
	var formal_stable_label := Label.new()
	formal_stable_label.text = "马厩真实照料"
	formal_stable_row.add_child(formal_stable_label)
	var formal_stable_work_button := _add_button(formal_stable_row, "托马→真实照料", _run_formal_stable_work)
	formal_stable_work_button.name = "FormalStableWorkButton"
	_add_button(formal_stable_row, "停止真实照料", _stop_formal_stable_work)
	_add_button(formal_stable_row, "真实照料快照", _show_formal_stable_work_snapshot)
	var formal_dining_row := _make_row(parent)
	var formal_dining_label := Label.new()
	formal_dining_label.text = "A5-P5d 食堂真实生产"
	formal_dining_row.add_child(formal_dining_label)
	var formal_dining_button := _add_button(formal_dining_row, "布鲁诺→真实烹饪", _run_formal_dining_work)
	formal_dining_button.name = "FormalDiningWorkButton"
	_add_button(formal_dining_row, "停止真实烹饪", _stop_formal_dining_work)
	_add_button(formal_dining_row, "真实烹饪快照", _show_formal_dining_work_snapshot)
	var formal_dining_eat_row := _make_row(parent)
	var formal_dining_eat_label := Label.new()
	formal_dining_eat_label.text = "A5-P5j 食堂真实用餐"
	formal_dining_eat_row.add_child(formal_dining_eat_label)
	var formal_dining_eat_button := _add_button(formal_dining_eat_row, "布鲁诺→真实用餐", _run_formal_dining_eat)
	formal_dining_eat_button.name = "FormalDiningEatButton"
	var formal_dining_eat_stop_button := _add_button(formal_dining_eat_row, "停止真实用餐", _stop_formal_dining_eat)
	formal_dining_eat_stop_button.name = "FormalDiningEatStopButton"
	var formal_dining_eat_snapshot_button := _add_button(formal_dining_eat_row, "真实用餐快照", _show_formal_dining_eat_snapshot)
	formal_dining_eat_snapshot_button.name = "FormalDiningEatSnapshotButton"
	var formal_dormitory_sleep_row := _make_row(parent)
	var formal_dormitory_sleep_label := Label.new()
	formal_dormitory_sleep_label.text = "A5-P6a 宿舍真实睡眠"
	formal_dormitory_sleep_row.add_child(formal_dormitory_sleep_label)
	var formal_dormitory_sleep_button := _add_button(formal_dormitory_sleep_row, "艾达→真实睡眠", _run_formal_dormitory_sleep)
	formal_dormitory_sleep_button.name = "FormalDormitorySleepButton"
	var formal_dormitory_sleep_stop_button := _add_button(formal_dormitory_sleep_row, "停止真实睡眠", _stop_formal_dormitory_sleep)
	formal_dormitory_sleep_stop_button.name = "FormalDormitorySleepStopButton"
	var formal_dormitory_sleep_snapshot_button := _add_button(formal_dormitory_sleep_row, "真实睡眠快照", _show_formal_dormitory_sleep_snapshot)
	formal_dormitory_sleep_snapshot_button.name = "FormalDormitorySleepSnapshotButton"
	var formal_garden_row := _make_row(parent)
	var formal_garden_label := Label.new()
	formal_garden_label.text = "A5-P5e 菜园真实生产"
	formal_garden_row.add_child(formal_garden_label)
	var formal_garden_button := _add_button(formal_garden_row, "伊沃→真实耕作", _run_formal_garden_work)
	formal_garden_button.name = "FormalGardenWorkButton"
	_add_button(formal_garden_row, "停止真实耕作", _stop_formal_garden_work)
	_add_button(formal_garden_row, "真实耕作快照", _show_formal_garden_work_snapshot)
	var formal_tavern_row := _make_row(parent)
	var formal_tavern_label := Label.new()
	formal_tavern_label.text = "A5-P5f 酒窖真实生产"
	formal_tavern_row.add_child(formal_tavern_label)
	var formal_tavern_button := _add_button(formal_tavern_row, "马塞尔→真实酿酒", _run_formal_tavern_work)
	formal_tavern_button.name = "FormalTavernWorkButton"
	_add_button(formal_tavern_row, "停止真实酿酒", _stop_formal_tavern_work)
	_add_button(formal_tavern_row, "真实酿酒快照", _show_formal_tavern_work_snapshot)
	var formal_clinic_row := _make_row(parent)
	var formal_clinic_label := Label.new()
	formal_clinic_label.text = "A5-P5g 小诊所真实服务"
	formal_clinic_row.add_child(formal_clinic_label)
	var formal_clinic_doctor_button := _add_button(formal_clinic_row, "莉娜→真实坐诊", _run_formal_clinic_doctor)
	formal_clinic_doctor_button.name = "FormalClinicDoctorButton"
	var formal_clinic_patient_button := _add_button(formal_clinic_row, "布鲁诺→真实病床", _run_formal_clinic_patient)
	formal_clinic_patient_button.name = "FormalClinicPatientButton"
	_add_button(formal_clinic_row, "停止诊所样片", _stop_formal_clinic_work)
	_add_button(formal_clinic_row, "诊所真实快照", _show_formal_clinic_work_snapshot)
	var formal_training_row := _make_row(parent)
	var formal_training_label := Label.new()
	formal_training_label.text = "A5-P5h 训练场真实训练"
	formal_training_row.add_child(formal_training_label)
	var formal_training_instructor_button := _add_button(formal_training_row, "艾达→真实执教", _run_formal_training_instructor)
	formal_training_instructor_button.name = "FormalTrainingInstructorButton"
	var formal_training_student_button := _add_button(formal_training_row, "格伦→真实受训", _run_formal_training_student)
	formal_training_student_button.name = "FormalTrainingStudentButton"
	_add_button(formal_training_row, "停止训练样片", _stop_formal_training_work)
	_add_button(formal_training_row, "训练真实快照", _show_formal_training_work_snapshot)
	var formal_chapel_row := _make_row(parent)
	var formal_chapel_label := Label.new()
	formal_chapel_label.text = "A5-P5i 小教堂真实礼拜"
	formal_chapel_row.add_child(formal_chapel_label)
	var formal_chapel_prayer_button := _add_button(formal_chapel_row, "伊沃→真实祈祷", _run_formal_chapel_prayer)
	formal_chapel_prayer_button.name = "FormalChapelPrayerButton"
	var formal_chapel_leader_button := _add_button(formal_chapel_row, "马塞尔→真实主持", _run_formal_chapel_leader)
	formal_chapel_leader_button.name = "FormalChapelLeaderButton"
	_add_button(formal_chapel_row, "停止礼拜样片", _stop_formal_chapel_work)
	_add_button(formal_chapel_row, "教堂真实快照", _show_formal_chapel_work_snapshot)


func _add_crafting_horse_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("制造 / 马匹"))
	var crafting_row := _make_row(parent)
	var crafting_label := Label.new()
	crafting_label.text = "制造"
	crafting_row.add_child(crafting_label)
	_crafting_building_select = _make_select(crafting_row)
	_crafting_building_select.name = "CraftingBuildingSelect"
	_crafting_building_select.item_selected.connect(func(_index: int) -> void:
		_fill_crafting_recipe_select()
	)
	_crafting_recipe_select = _make_select(crafting_row)
	_crafting_recipe_select.name = "CraftingRecipeSelect"
	_add_button(crafting_row, "设置目标", func() -> void:
		_run_craft_target(
			_selected_id(_crafting_building_select),
			_selected_id(_crafting_recipe_select),
			false
		)
	)
	_add_button(crafting_row, "强制换目标", func() -> void:
		_run_craft_target(
			_selected_id(_crafting_building_select),
			_selected_id(_crafting_recipe_select),
			true
		)
	)
	_add_button(crafting_row, "完成阶段", func() -> void:
		_run_craft_stage(_selected_id(_crafting_building_select), _selected_id(_npc_select))
	)
	_add_button(crafting_row, "制造快照", func() -> void:
		_show_craft_snapshot(_selected_id(_crafting_building_select))
	)
	var formal_blacksmith_row := _make_row(parent)
	var formal_blacksmith_label := Label.new()
	formal_blacksmith_label.text = "A5-P5b 正式铁匠制造"
	formal_blacksmith_row.add_child(formal_blacksmith_label)
	var formal_blacksmith_button := _add_button(formal_blacksmith_row, "格伦→真实打铁", _run_formal_blacksmith_work)
	formal_blacksmith_button.name = "FormalBlacksmithWorkButton"
	_add_button(formal_blacksmith_row, "停止真实打铁", _stop_formal_blacksmith_work)
	_add_button(formal_blacksmith_row, "真实打铁快照", _show_formal_blacksmith_work_snapshot)
	var formal_workshop_row := _make_row(parent)
	var formal_workshop_label := Label.new()
	formal_workshop_label.text = "A5-P5c 正式工械制造"
	formal_workshop_row.add_child(formal_workshop_label)
	var formal_workshop_button := _add_button(formal_workshop_row, "欧文→真实制造", _run_formal_workshop_work)
	formal_workshop_button.name = "FormalWorkshopWorkButton"
	_add_button(formal_workshop_row, "停止真实制造", _stop_formal_workshop_work)
	_add_button(formal_workshop_row, "真实制造快照", _show_formal_workshop_work_snapshot)

	var horse_row := _make_row(parent)
	var horse_label := Label.new()
	horse_label.text = "马匹"
	horse_row.add_child(horse_label)
	_horse_select = _make_select(horse_row)
	_horse_select.name = "HorseSelect"
	_horse_damage_input = _make_input(horse_row, "伤害", "10", 70)
	_horse_damage_input.name = "HorseDamageInput"
	_horse_advance_input = _make_input(horse_row, "推进秒", "3600", 90)
	_horse_advance_input.name = "HorseAdvanceInput"
	_add_button(horse_row, "马匹快照", func() -> void:
		_show_horse_snapshot(_selected_id(_horse_select))
	)
	_add_button(horse_row, "马匹受伤", func() -> void:
		_run_horse_damage(_selected_id(_horse_select), float(_horse_damage_input.text))
	)
	_add_button(horse_row, "推进马匹", func() -> void:
		_run_horse_advance(float(_horse_advance_input.text))
	)
	_add_button(horse_row, "强制繁育", _run_horse_birth)

	var horse_assignment_row := _make_row(parent)
	var assignment_label := Label.new()
	assignment_label.text = "马匹分配使用上方 NPC / 马匹选项"
	assignment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horse_assignment_row.add_child(assignment_label)
	_add_button(horse_assignment_row, "分配马匹", func() -> void:
		_run_horse_assign(
			_selected_id(_npc_select),
			_selected_id(_horse_select),
			_selected_id(_visibility_select)
		)
	)
	_add_button(horse_assignment_row, "取消分配", func() -> void:
		_run_horse_unassign(_selected_id(_npc_select), _selected_id(_visibility_select))
	)


func _add_npc_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("NPC"))
	var row := _make_row(parent)
	_npc_select = _make_select(row)
	_npc_select.name = "CommonNpcSelect"
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
	_add_button(state_row, "空间快照", func() -> void:
		_show_spatial_migration(_selected_id(_npc_select))
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
	_add_button(equipment_row, "兵种", func() -> void:
		_show_unit_type(_selected_id(_npc_select))
	)


func _add_action_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("行动"))
	var npc_row := _make_row(parent)
	var npc_label := Label.new()
	npc_label.text = "行动 NPC"
	npc_row.add_child(npc_label)
	_formal_action_npc_select = _make_select(npc_row)
	_formal_action_npc_select.name = "FormalActionNpcSelect"
	_formal_action_npc_select.tooltip_text = "本页下方全部行动、停止和快照按钮都以此 NPC 为发起者"
	var location_label := Label.new()
	location_label.text = "拜访地点"
	npc_row.add_child(location_label)
	_formal_action_location_select = _make_select(npc_row)
	_formal_action_location_select.name = "FormalActionLocationSelect"
	_formal_action_location_select.tooltip_text = "本页“真实拜访”使用的目标地点"

	var row := _make_row(parent)
	_action_select = _make_select(row)
	_action_select.name = "ActionSelect"
	var assign_action_button := _add_button(row, "指定行动", func() -> void:
		_run_assign_action(_selected_id(_formal_action_npc_select), _selected_id(_action_select))
	)
	assign_action_button.name = "AssignActionButton"

	var formal_visit_row := _make_row(parent)
	var formal_visit_label := Label.new()
	formal_visit_label.text = "A5-P6b 使用行动 NPC / 拜访地点"
	formal_visit_row.add_child(formal_visit_label)
	var formal_visit_button := _add_button(formal_visit_row, "真实拜访", func() -> void:
		_run_formal_visit_location(_selected_id(_formal_action_npc_select), _selected_id(_formal_action_location_select))
	)
	formal_visit_button.name = "FormalVisitLocationButton"
	var formal_visit_stop_button := _add_button(formal_visit_row, "停止真实拜访", func() -> void:
		_stop_formal_visit_location(_selected_id(_formal_action_npc_select))
	)
	formal_visit_stop_button.name = "FormalVisitLocationStopButton"
	var formal_visit_snapshot_button := _add_button(formal_visit_row, "真实拜访快照", func() -> void:
		_show_formal_visit_location_snapshot(_selected_id(_formal_action_npc_select))
	)
	formal_visit_snapshot_button.name = "FormalVisitLocationSnapshotButton"

	var formal_dialogue_row := _make_row(parent)
	var formal_dialogue_label := Label.new()
	formal_dialogue_label.text = "A5-P6c 使用行动 NPC / 对话目标"
	formal_dialogue_row.add_child(formal_dialogue_label)
	_npc_dialogue_target_select = _make_select(formal_dialogue_row)
	_npc_dialogue_target_select.name = "FormalNpcDialogueTargetSelect"
	var formal_dialogue_button := _add_button(formal_dialogue_row, "真实找人对话", func() -> void:
		_run_formal_npc_dialogue(_selected_id(_formal_action_npc_select), _selected_id(_npc_dialogue_target_select))
	)
	formal_dialogue_button.name = "FormalNpcDialogueButton"
	var formal_dialogue_stop_button := _add_button(formal_dialogue_row, "停止真实对话", func() -> void:
		_stop_formal_npc_dialogue(_selected_id(_formal_action_npc_select))
	)
	formal_dialogue_stop_button.name = "FormalNpcDialogueStopButton"
	var formal_dialogue_snapshot_button := _add_button(formal_dialogue_row, "真实对话快照", func() -> void:
		_show_formal_npc_dialogue_snapshot(_selected_id(_formal_action_npc_select))
	)
	formal_dialogue_snapshot_button.name = "FormalNpcDialogueSnapshotButton"

	var repair_row := _make_row(parent)
	var repair_target_label := Label.new()
	repair_target_label.text = "A5-P6d-1 真实修复目标"
	repair_row.add_child(repair_target_label)
	_repair_building_select = _make_select(repair_row)
	_repair_building_select.name = "RepairBuildingSelect"
	var assist_button := _add_button(repair_row, "协助修复", func() -> void:
		_run_assist_repair(_selected_id(_formal_action_npc_select), _selected_id(_repair_building_select))
	)
	assist_button.name = "AssistRepairButton"
	var assist_stop_button := _add_button(repair_row, "停止真实修复", func() -> void:
		_stop_formal_repair_assist(_selected_id(_formal_action_npc_select))
	)
	assist_stop_button.name = "FormalRepairAssistStopButton"
	var assist_snapshot_button := _add_button(repair_row, "真实修复快照", func() -> void:
		_show_formal_repair_assist_snapshot(_selected_id(_formal_action_npc_select), _selected_id(_repair_building_select))
	)
	assist_snapshot_button.name = "FormalRepairAssistSnapshotButton"

	var upgrade_row := _make_row(parent)
	var upgrade_target_label := Label.new()
	upgrade_target_label.text = "A5-P6d-2 真实升级协助"
	upgrade_row.add_child(upgrade_target_label)
	_upgrade_building_select = _make_select(upgrade_row)
	_upgrade_building_select.name = "UpgradeBuildingSelect"
	var assist_upgrade_button := _add_button(upgrade_row, "协助升级", func() -> void:
		_run_assist_upgrade(_selected_id(_formal_action_npc_select), _selected_id(_upgrade_building_select))
	)
	assist_upgrade_button.name = "AssistUpgradeButton"
	var assist_upgrade_stop_button := _add_button(upgrade_row, "停止真实升级", func() -> void:
		_stop_formal_upgrade_assist(_selected_id(_formal_action_npc_select))
	)
	assist_upgrade_stop_button.name = "FormalUpgradeAssistStopButton"
	var assist_upgrade_snapshot_button := _add_button(upgrade_row, "真实升级快照", func() -> void:
		_show_formal_upgrade_assist_snapshot(_selected_id(_formal_action_npc_select), _selected_id(_upgrade_building_select))
	)
	assist_upgrade_snapshot_button.name = "FormalUpgradeAssistSnapshotButton"

	var heal_row := _make_row(parent)
	var heal_target_label := Label.new()
	heal_target_label.text = "A5-P6d-3 真实协助治疗"
	heal_row.add_child(heal_target_label)
	_heal_target_select = _make_select(heal_row)
	_heal_target_select.name = "HealTargetSelect"
	var assist_heal_button := _add_button(heal_row, "协助治疗", func() -> void:
		_run_assist_heal(_selected_id(_formal_action_npc_select), _selected_id(_heal_target_select))
	)
	assist_heal_button.name = "AssistHealButton"
	var assist_heal_stop_button := _add_button(heal_row, "停止真实治疗", func() -> void:
		_stop_formal_heal_assist(_selected_id(_formal_action_npc_select))
	)
	assist_heal_stop_button.name = "FormalHealAssistStopButton"
	var assist_heal_snapshot_button := _add_button(heal_row, "真实治疗快照", func() -> void:
		_show_formal_heal_assist_snapshot(_selected_id(_formal_action_npc_select), _selected_id(_heal_target_select))
	)
	assist_heal_snapshot_button.name = "FormalHealAssistSnapshotButton"


func _add_combat_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("战斗 / 敌人"))
	var row := _make_row(parent)
	_combat_wave_select = _make_select(row)
	_combat_wave_select.name = "CombatWaveSelect"
	var spawn_selected_wave_button := _add_button(row, "生成所选波次", func() -> void:
		_run_spawn_enemy_wave(_int_from_selected_id(_combat_wave_select, 1))
	)
	spawn_selected_wave_button.name = "SpawnSelectedWaveButton"
	var next_wave_button := _add_button(row, "跳到下一波", _run_trigger_next_wave)
	next_wave_button.name = "TriggerNextWaveButton"
	var combat_alarm_button := _add_button(row, "警铃集结", _run_combat_alarm)
	combat_alarm_button.name = "CombatAlarmButton"
	_add_button(row, "敌人快照", _show_combat_snapshot)
	var step_enemy_ai_button := _add_button(row, "推进敌人AI", func() -> void:
		_run_step_enemy_ai(1.0)
	)
	step_enemy_ai_button.name = "StepEnemyAIButton"
	_add_button(row, "清空敌人", _run_clear_enemies)
	var ruin_row := _make_row(parent)
	var ruin_label := Label.new()
	ruin_label.text = "T0157 塔防废墟验收"
	ruin_row.add_child(ruin_label)
	var destroy_device_button := _add_button(ruin_row, "摧毁首个塔防", _run_destroy_first_defense_device)
	destroy_device_button.name = "DestroyFirstDefenseDeviceButton"
	var device_ruin_snapshot_button := _add_button(ruin_row, "塔防废墟快照", _show_defense_device_ruins)
	device_ruin_snapshot_button.name = "DefenseDeviceRuinSnapshotButton"
	var formal_enemy_row := _make_row(parent)
	var formal_enemy_label := Label.new()
	formal_enemy_label.text = "C3-P7 / A4-P7 五波动态实体争抢 / 补位"
	formal_enemy_row.add_child(formal_enemy_label)
	var formal_enemy_attack_button := _add_button(formal_enemy_row, "所选波次动态群战", _run_formal_dynamic_wave_slice)
	formal_enemy_attack_button.name = "FormalSecondWaveButton"
	_add_button(formal_enemy_row, "动态群战快照", _show_formal_dynamic_wave_slice_snapshot)
	_add_button(formal_enemy_row, "停止动态群战", _stop_formal_dynamic_wave_slice)
	var mode_row := _make_row(parent)
	_add_button(mode_row, "行为模式快照", _show_behavior_modes)
	_add_button(mode_row, "模拟避战", func() -> void:
		_run_avoid_npc(_selected_id(_npc_select))
	)
	_add_button(mode_row, "推进集结等待", func() -> void:
		_run_advance_rally_wait(3600.0)
	)
	var piety_row := _make_row(parent)
	var fill_piety_button := _add_button(piety_row, "充满虔诚", _run_fill_piety)
	fill_piety_button.name = "FillPietyButton"
	var piety_snapshot_button := _add_button(piety_row, "虔诚 / 陨石快照", _show_piety_snapshot)
	piety_snapshot_button.name = "PietySnapshotButton"
	_add_button(piety_row, "推进陨石 1 秒", func() -> void:
		_run_step_piety_effects(60.0)
	)


func _add_backend_section(parent: VBoxContainer) -> void:
	var npc_row := _make_row(parent)
	var npc_label := Label.new()
	npc_label.text = "AI 指令目标"
	npc_row.add_child(npc_label)
	_ai_npc_select = _make_select(npc_row)
	_ai_npc_select.name = "AINpcSelect"
	_ai_npc_select.tooltip_text = "AI信息页全部 NPC 指令都作用于此人；与常用页、正式行动页的选择相互独立。"
	_ai_npc_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	parent.add_child(_make_section_title("AI 对话 / LLMBridge"))
	var row := _make_row(parent)
	_dialogue_text_input = _make_input(row, "对话文本", "守备官需要你帮忙守住这里。", 300)
	_add_button(row, "健康检查", _run_backend_health)
	_add_button(row, "对话 Mock", func() -> void:
		_run_dialogue_mock(_selected_id(_ai_npc_select), _dialogue_text_input.text, false)
	)
	_add_button(row, "应征 Mock", func() -> void:
		_run_dialogue_mock(_selected_id(_ai_npc_select), _dialogue_text_input.text, true)
	)
	_add_button(row, "LLM 状态", func() -> void:
		_show_llm_state(_selected_id(_ai_npc_select))
	)
	_add_button(row, "对话意图复核", func() -> void:
		_show_dialogue_intent_revalidation(_selected_id(_ai_npc_select))
	)
	_add_button(row, "成本统计", _show_llm_usage)
	_add_button(row, "最近指令注入", _show_last_npc_context_injection)
	_add_button(row, "驿站上下文", _show_station_context)
	var work_row := _make_row(parent)
	var work_label := Label.new()
	work_label.text = "特殊交互：鼓励工作"
	work_row.add_child(work_label)
	var work_mock_button := _add_button(work_row, "工作鼓励 Mock", func() -> void:
		_run_dialogue_mock(_selected_id(_ai_npc_select), _dialogue_text_input.text, false, false, false, true)
	)
	work_mock_button.name = "WorkEncouragementDialogueMockButton"
	var work_dialogue_button := _add_button(work_row, "打开工作鼓励对话", func() -> void:
		_run_open_work_encouragement_dialogue(_selected_id(_ai_npc_select))
	)
	work_dialogue_button.name = "OpenWorkEncouragementDialogueButton"
	var morale_row := _make_row(parent)
	var morale_label := Label.new()
	morale_label.text = "特殊交互：鼓舞士气"
	morale_row.add_child(morale_label)
	var morale_mock_button := _add_button(morale_row, "鼓舞 Mock", func() -> void:
		_run_dialogue_mock(_selected_id(_ai_npc_select), _dialogue_text_input.text, false, true)
	)
	morale_mock_button.name = "MoraleEncouragementMockButton"
	var morale_dialogue_button := _add_button(morale_row, "打开鼓舞对话", func() -> void:
		_run_open_morale_encouragement_dialogue(_selected_id(_ai_npc_select))
	)
	morale_dialogue_button.name = "OpenMoraleEncouragementDialogueButton"
	var strategy_row := _make_row(parent)
	var strategy_label := Label.new()
	strategy_label.text = "特殊交互：调整战斗策略"
	strategy_row.add_child(strategy_label)
	var strategy_mock_button := _add_button(strategy_row, "策略 Mock", func() -> void:
		_run_dialogue_mock(_selected_id(_ai_npc_select), _dialogue_text_input.text, false, false, true)
	)
	strategy_mock_button.name = "CombatStrategyDialogueMockButton"
	var strategy_dialogue_button := _add_button(strategy_row, "打开策略对话", func() -> void:
		_run_open_combat_strategy_dialogue(_selected_id(_ai_npc_select))
	)
	strategy_dialogue_button.name = "OpenCombatStrategyDialogueButton"

	parent.add_child(_make_section_title("特殊交互结果展台（本地，不调用 LLM）"))
	var recruitment_result_row := _make_row(parent)
	var recruitment_result_label := Label.new()
	recruitment_result_label.text = "提出应征"
	recruitment_result_row.add_child(recruitment_result_label)
	_add_named_special_result_button(recruitment_result_row, "同意入伍", "RecruitmentAcceptPreviewButton", "recruitment", "accept")
	_add_named_special_result_button(recruitment_result_row, "拒绝入伍", "RecruitmentRejectPreviewButton", "recruitment", "reject")
	_add_named_special_result_button(recruitment_result_row, "忽略应征", "RecruitmentNonePreviewButton", "recruitment", "none")

	var morale_result_row := _make_row(parent)
	var morale_result_label := Label.new()
	morale_result_label.text = "鼓舞士气"
	morale_result_row.add_child(morale_result_label)
	_add_named_special_result_button(morale_result_row, "士气提升", "MoraleBoostPreviewButton", "morale_encouragement", "morale_boost")
	_add_named_special_result_button(morale_result_row, "继续参战", "MoraleNonePreviewButton", "morale_encouragement", "none")
	_add_named_special_result_button(morale_result_row, "决定逃离", "MoraleEscapePreviewButton", "morale_encouragement", "escape")

	var work_result_row := _make_row(parent)
	var work_result_label := Label.new()
	work_result_label.text = "鼓励工作"
	work_result_row.add_child(work_result_label)
	_add_named_special_result_button(work_result_row, "效率提升", "WorkBoostPreviewButton", "work_encouragement", "work_boost")
	_add_named_special_result_button(work_result_row, "无事发生", "WorkNonePreviewButton", "work_encouragement", "none")
	_add_named_special_result_button(work_result_row, "决定逃离", "WorkEscapePreviewButton", "work_encouragement", "escape")

	var strategy_result_row := _make_row(parent)
	var strategy_result_label := Label.new()
	strategy_result_label.text = "战斗策略"
	strategy_result_row.add_child(strategy_result_label)
	_add_named_special_result_button(strategy_result_row, "改变策略", "StrategyChangePreviewButton", "combat_strategy", "change")
	_add_named_special_result_button(strategy_result_row, "保持策略", "StrategyKeepPreviewButton", "combat_strategy", "keep")
	var clear_buff_button := _add_button(strategy_result_row, "清除两类增益", func() -> void:
		_run_clear_dialogue_buffs(_selected_id(_ai_npc_select))
	)
	clear_buff_button.name = "ClearDialogueBuffsButton"

	var escape_result_row := _make_row(parent)
	var escape_result_label := Label.new()
	escape_result_label.text = "逃离 / 挽留"
	escape_result_row.add_child(escape_result_label)
	var start_escape_button := _add_button(escape_result_row, "开始逃离", func() -> void:
		_run_escape_npc(_selected_id(_ai_npc_select))
	)
	start_escape_button.name = "StartEscapePreviewButton"
	var stay_button := _add_button(escape_result_row, "挽留成功", func() -> void:
		_run_escape_intervention_preview(_selected_id(_ai_npc_select), "stay")
	)
	stay_button.name = "EscapeStayPreviewButton"
	var leave_button := _add_button(escape_result_row, "继续逃离", func() -> void:
		_run_escape_intervention_preview(_selected_id(_ai_npc_select), "leave")
	)
	leave_button.name = "EscapeLeavePreviewButton"

	parent.add_child(_make_section_title("NPC 回复情绪气泡（本地，不调用 LLM）"))
	var emotion_presentations := DialogueEmotionCatalog.get_all_presentations()
	for row_index in range(2):
		var emotion_row := _make_row(parent)
		if row_index == 0:
			var emotion_label := Label.new()
			emotion_label.text = "世界 + 第二人称"
			emotion_row.add_child(emotion_label)
		var start_index := row_index * 5
		var end_index := mini(start_index + 5, emotion_presentations.size())
		for presentation_index in range(start_index, end_index):
			var presentation: Dictionary = emotion_presentations[presentation_index]
			var emotion_id := str(presentation.get("emotion_id", "none"))
			var button := _add_button(
				emotion_row,
				"%s %s" % [str(presentation.get("emoji", "…")), str(presentation.get("emotion_label", ""))],
				func() -> void:
					_run_dialogue_emotion_preview(_selected_id(_ai_npc_select), emotion_id)
			)
			button.name = "DialogueEmotion%sPreviewButton" % emotion_id.capitalize()
			button.tooltip_text = "打开所选 NPC 人物框，并复用正式信号同时展示世界与第二人称气泡。"
		if row_index == 1:
			var sequence_button := _add_button(emotion_row, "快速替换演示", func() -> void:
				_run_dialogue_emotion_sequence(_selected_id(_ai_npc_select))
			)
			sequence_button.name = "DialogueEmotionSequencePreviewButton"


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
	_add_button(row, "短期记忆 / LLM", func() -> void:
		_show_memory(_selected_id(_ai_npc_select))
	)

	var event_row := _make_row(parent)
	_visibility_select = _make_select(event_row)
	_memory_amount_input = _make_input(event_row, "数值", "5", 70)
	_event_type_input = _make_input(event_row, "事件类型", "plaza_status_changed", 170)
	_add_button(event_row, "给钱事件", func() -> void:
		_run_give_money(_selected_id(_ai_npc_select), _int_from_input(_memory_amount_input, 0), _selected_id(_visibility_select))
	)
	_add_button(event_row, "攻击事件", func() -> void:
		_run_attack_npc(_selected_id(_ai_npc_select), _int_from_input(_memory_amount_input, 0), _selected_id(_visibility_select))
	)
	_add_button(event_row, "广场广播", func() -> void:
		_run_public_event(_event_type_input.text.strip_edges(), _selected_id(_ai_npc_select))
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
	_fill_crafting_selects()
	_fill_horse_select()
	_fill_location_select()
	_fill_visibility_select()
	if _panel != null and _panel.visible:
		_request_llm_usage_refresh()
	_log("GM 选项已刷新。")


func _fill_resource_select() -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var ids: Array = []
	if resource_system != null and resource_system.has_method("get_resource_ids"):
		for raw_resource_id in resource_system.get_resource_ids():
			var resource_id := str(raw_resource_id)
			if not LEGACY_AGGREGATE_RESOURCE_IDS.has(resource_id):
				ids.append(resource_id)
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
	_fill_select(_formal_action_npc_select, ids, func(id: String) -> String:
		if npc_system != null:
			var npc: Dictionary = npc_system.get_npc(id)
			return "%s | %s" % [id, str(npc.get("name", id))]
		return id
	)
	_fill_select(_ai_npc_select, ids, func(id: String) -> String:
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
	_fill_select(_npc_dialogue_target_select, ids, func(id: String) -> String:
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
	if action_system != null and action_system.has_method("get_direct_debug_action_ids"):
		ids = action_system.get_direct_debug_action_ids()
	elif action_system != null and action_system.has_method("get_action_ids"):
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


func _fill_crafting_selects() -> void:
	_fill_select(_crafting_building_select, ["blacksmith", "workshop"], func(id: String) -> String:
		return id
	)
	_fill_crafting_recipe_select()


func _fill_crafting_recipe_select() -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	var building_id := _selected_id(_crafting_building_select)
	var recipe_ids: Array = []
	if crafting_system != null and crafting_system.has_method("get_recipe_ids_for_building"):
		recipe_ids = crafting_system.get_recipe_ids_for_building(building_id)
	_fill_select(_crafting_recipe_select, recipe_ids, func(id: String) -> String:
		if crafting_system != null and crafting_system.has_method("get_recipe"):
			var recipe: Dictionary = crafting_system.get_recipe(id)
			return "%s | %s" % [id, str(recipe.get("name", id))]
		return id
	)


func _fill_horse_select() -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	var horse_ids: Array = []
	if horse_system != null and horse_system.has_method("get_horse_ids"):
		horse_ids = horse_system.get_horse_ids()
	_fill_select(_horse_select, horse_ids, func(id: String) -> String:
		if horse_system != null and horse_system.has_method("get_horse_snapshot"):
			var horse: Dictionary = horse_system.get_horse_snapshot(id)
			return "%s | %s | %s" % [
				id,
				str(horse.get("name", id)),
				str(horse.get("life_stage", ""))
			]
		return id
	)


func _fill_location_select() -> void:
	_fill_select(_location_select, DEFAULT_LOCATION_IDS, func(id: String) -> String:
		return id
	)
	_fill_select(_formal_action_location_select, DEFAULT_LOCATION_IDS, func(id: String) -> String:
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
			_show_time_snapshot()
			_show_resource_snapshot()
			_show_roof_visibility_snapshot()
			_show_station_layout_snapshot()
			_show_craft_snapshot()
			_show_horse_snapshot()
			_show_combat_snapshot()
			_show_piety_snapshot()
			_show_events()
		"time_snapshot":
			_show_time_snapshot()
		"merchant_wagon":
			var merchant_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match merchant_mode:
				"arrival", "arrive", "enter":
					_run_merchant_wagon_arrival()
				"formal_arrival", "formal", "long_route":
					_run_formal_merchant_wagon_arrival()
				"departure", "depart", "leave":
					_run_merchant_wagon_departure()
				_:
					_show_merchant_wagon_snapshot()
		"roof_visibility":
			_show_roof_visibility_snapshot()
		"station_layout":
			var layout_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match layout_mode:
				"preview", "formal", "new":
					_run_station_layout_preview(true)
				"legacy", "gameplay", "old", "return":
					_run_station_layout_preview(false)
				_:
					_show_station_layout_snapshot()
		"formal_spatial_save":
			var save_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match save_mode:
				"save", "write":
					_run_formal_spatial_save()
				"load", "read", "restore":
					_run_formal_spatial_load()
				_:
					_show_formal_spatial_save_snapshot()
		"motion_sandbox":
			_run_actor_motion_sandbox()
		"character_pilot":
			var character_pilot_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match character_pilot_mode:
				"glen", "work":
					_run_formal_blacksmith_work()
				"enemy", "wave":
					_run_spawn_enemy_wave(1)
				"sandbox", "lab", "dev_lab":
					_run_npc_dev_lab()
				_:
					_show_chibi_formal_character_snapshot()
		"formal_nav_pilot":
			var formal_pilot_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_pilot_mode:
				"glen", "blacksmith":
					_run_glen_navigation_pilot()
				"clinic_doctor", "doctor":
					_run_clinic_navigation_pilot("doctor")
				"clinic_bed", "bed":
					_run_clinic_navigation_pilot("bed")
				"dormitory_bed", "dormitory", "sleep":
					_run_dormitory_navigation_pilot()
				"dining_seat", "dining", "seat":
					_run_dining_navigation_pilot()
				"chapel_prayer_seat", "chapel", "prayer_seat":
					_run_chapel_navigation_pilot()
				"stable_care", "stable", "horse_care":
					_run_stable_navigation_pilot()
				"stop", "restore":
					_stop_formal_navigation_pilots()
				_:
					_show_formal_navigation_pilot_snapshot()
		"formal_stable_work":
			var formal_stable_work_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_stable_work_mode:
				"run", "start":
					_run_formal_stable_work()
				"stop", "clear":
					_stop_formal_stable_work()
				_:
					_show_formal_stable_work_snapshot()
		"formal_dining_work":
			var formal_dining_work_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_dining_work_mode:
				"run", "start":
					_run_formal_dining_work()
				"stop", "clear":
					_stop_formal_dining_work()
				_:
					_show_formal_dining_work_snapshot()
		"formal_dining_eat":
			var formal_dining_eat_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_dining_eat_mode:
				"run", "start":
					_run_formal_dining_eat()
				"stop", "clear":
					_stop_formal_dining_eat()
				_:
					_show_formal_dining_eat_snapshot()
		"formal_dormitory_sleep":
			var formal_dormitory_sleep_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_dormitory_sleep_mode:
				"run", "start":
					_run_formal_dormitory_sleep()
				"stop", "clear":
					_stop_formal_dormitory_sleep()
				_:
					_show_formal_dormitory_sleep_snapshot()
		"formal_garden_work":
			var formal_garden_work_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_garden_work_mode:
				"run", "start":
					_run_formal_garden_work()
				"stop", "clear":
					_stop_formal_garden_work()
				_:
					_show_formal_garden_work_snapshot()
		"formal_visit":
			var formal_visit_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			var formal_visit_npc_id := str(parts[2]) if parts.size() >= 3 else _selected_id(_formal_action_npc_select)
			match formal_visit_mode:
				"run", "start":
					if _require_args(parts, 4, "formal_visit run <npc_id> <location_id>"):
						_run_formal_visit_location(formal_visit_npc_id, str(parts[3]))
				"stop", "clear":
					_stop_formal_visit_location(formal_visit_npc_id)
				_:
					_show_formal_visit_location_snapshot(formal_visit_npc_id)
		"formal_npc_dialogue":
			var formal_dialogue_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			var formal_dialogue_speaker_id := str(parts[2]) if parts.size() >= 3 else _selected_id(_formal_action_npc_select)
			match formal_dialogue_mode:
				"run", "start":
					if _require_args(parts, 4, "formal_npc_dialogue run <speaker_npc_id> <target_npc_id> [opening_text]"):
						var prefix := "formal_npc_dialogue %s %s %s" % [formal_dialogue_mode, formal_dialogue_speaker_id, str(parts[3])]
						_run_formal_npc_dialogue(
							formal_dialogue_speaker_id,
							str(parts[3]),
							command.substr(prefix.length()).strip_edges()
						)
				"stop", "clear":
					_stop_formal_npc_dialogue(formal_dialogue_speaker_id)
				_:
					_show_formal_npc_dialogue_snapshot(formal_dialogue_speaker_id)
		"formal_repair_assist":
			var formal_repair_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			var formal_repair_npc_id := str(parts[2]) if parts.size() >= 3 else _selected_id(_formal_action_npc_select)
			match formal_repair_mode:
				"run", "start":
					if _require_args(parts, 4, "formal_repair_assist run <npc_id> <building_id>"):
						_run_assist_repair(formal_repair_npc_id, str(parts[3]))
				"stop", "clear":
					_stop_formal_repair_assist(formal_repair_npc_id)
				_:
					var formal_repair_building_id := str(parts[3]) if parts.size() >= 4 else _selected_id(_repair_building_select)
					_show_formal_repair_assist_snapshot(formal_repair_npc_id, formal_repair_building_id)
		"formal_upgrade_assist":
			var formal_upgrade_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			var formal_upgrade_npc_id := str(parts[2]) if parts.size() >= 3 else _selected_id(_formal_action_npc_select)
			match formal_upgrade_mode:
				"run", "start":
					if _require_args(parts, 4, "formal_upgrade_assist run <npc_id> <building_id>"):
						_run_assist_upgrade(formal_upgrade_npc_id, str(parts[3]))
				"stop", "clear":
					_stop_formal_upgrade_assist(formal_upgrade_npc_id)
				_:
					var formal_upgrade_building_id := str(parts[3]) if parts.size() >= 4 else _selected_id(_upgrade_building_select)
					_show_formal_upgrade_assist_snapshot(formal_upgrade_npc_id, formal_upgrade_building_id)
		"formal_heal_assist":
			var formal_heal_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			var formal_healer_npc_id := str(parts[2]) if parts.size() >= 3 else _selected_id(_formal_action_npc_select)
			match formal_heal_mode:
				"run", "start":
					if _require_args(parts, 4, "formal_heal_assist run <healer_npc_id> <target_npc_id>"):
						_run_assist_heal(formal_healer_npc_id, str(parts[3]))
				"stop", "clear":
					_stop_formal_heal_assist(formal_healer_npc_id)
				_:
					var formal_heal_target_id := str(parts[3]) if parts.size() >= 4 else _selected_id(_heal_target_select)
					_show_formal_heal_assist_snapshot(formal_healer_npc_id, formal_heal_target_id)
		"formal_tavern_work":
			var formal_tavern_work_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_tavern_work_mode:
				"run", "start":
					_run_formal_tavern_work()
				"stop", "clear":
					_stop_formal_tavern_work()
				_:
					_show_formal_tavern_work_snapshot()
		"formal_clinic_work":
			var formal_clinic_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_clinic_mode:
				"doctor", "run", "start":
					_run_formal_clinic_doctor()
				"patient", "bed":
					_run_formal_clinic_patient()
				"stop", "clear":
					_stop_formal_clinic_work()
				_:
					_show_formal_clinic_work_snapshot()
		"formal_training_work":
			var formal_training_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_training_mode:
				"instructor", "coach":
					_run_formal_training_instructor()
				"student", "trainee":
					_run_formal_training_student()
				"stop", "clear":
					_stop_formal_training_work()
				_:
					_show_formal_training_work_snapshot()
		"formal_chapel_work":
			var formal_chapel_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_chapel_mode:
				"leader", "mass":
					_run_formal_chapel_leader()
				"prayer", "pray":
					_run_formal_chapel_prayer()
				"stop", "clear":
					_stop_formal_chapel_work()
				_:
					_show_formal_chapel_work_snapshot()
		"formal_blacksmith_work":
			var formal_blacksmith_work_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_blacksmith_work_mode:
				"run", "start":
					_run_formal_blacksmith_work()
				"stop", "clear":
					_stop_formal_blacksmith_work()
				_:
					_show_formal_blacksmith_work_snapshot()
		"formal_workshop_work":
			var formal_workshop_work_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_workshop_work_mode:
				"run", "start":
					_run_formal_workshop_work()
				"stop", "clear":
					_stop_formal_workshop_work()
				_:
					_show_formal_workshop_work_snapshot()
		"formal_enemy_pilot":
			var enemy_pilot_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match enemy_pilot_mode:
				"run", "start":
					_run_formal_enemy_navigation_pilot()
				"stop", "clear":
					_stop_formal_enemy_navigation_pilot()
				_:
					_show_formal_enemy_navigation_pilot_snapshot()
		"formal_enemy_attack_slice":
			var attack_slice_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match attack_slice_mode:
				"run", "start":
					_run_formal_active_enemy_main_hall_slice()
				"stop", "clear":
					_stop_formal_active_enemy_main_hall_slice()
				_:
					_show_formal_active_enemy_main_hall_slice_snapshot()
		"formal_enemy_warehouse_slice":
			var warehouse_slice_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match warehouse_slice_mode:
				"run", "start":
					_run_formal_active_enemy_main_hall_slice()
				"stop", "clear":
					_stop_formal_active_enemy_main_hall_slice()
				_:
					_show_formal_active_enemy_main_hall_slice_snapshot()
		"formal_enemy_main_hall_slice":
			var main_hall_slice_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match main_hall_slice_mode:
				"run", "start":
					_run_formal_active_enemy_main_hall_slice()
				"stop", "clear":
					_stop_formal_active_enemy_main_hall_slice()
				_:
					_show_formal_active_enemy_main_hall_slice_snapshot()
		"formal_first_wave_slice":
			var formal_first_wave_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_first_wave_mode:
				"run", "start":
					_run_formal_first_wave_slice()
				"stop", "clear":
					_stop_formal_first_wave_slice()
				_:
					_show_formal_first_wave_slice_snapshot()
		"formal_second_wave_slice":
			var formal_second_wave_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match formal_second_wave_mode:
				"run", "start":
					_run_formal_second_wave_slice()
				"stop", "clear":
					_stop_formal_second_wave_slice()
				_:
					_show_formal_second_wave_slice_snapshot()
		"formal_dynamic_wave":
			var dynamic_wave_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match dynamic_wave_mode:
				"run", "start":
					var dynamic_wave_number := int(parts[2]) if parts.size() >= 3 else _int_from_selected_id(_combat_wave_select, 1)
					_run_formal_dynamic_wave_slice(dynamic_wave_number)
				"stop", "clear":
					_stop_formal_dynamic_wave_slice()
				_:
					_show_formal_dynamic_wave_slice_snapshot()
		"glen_nav_pilot":
			var pilot_mode := str(parts[1]).to_lower() if parts.size() >= 2 else "snapshot"
			match pilot_mode:
				"run", "start":
					_run_glen_navigation_pilot()
				"stop", "restore":
					_stop_glen_navigation_pilot()
				_:
					_show_glen_navigation_pilot_snapshot()
		"add_resource":
			if _require_args(parts, 3, "add_resource <resource_id> <amount>"):
				_run_add_resource(str(parts[1]), int(parts[2]))
		"spend_resource":
			if _require_args(parts, 3, "spend_resource <resource_id> <amount>"):
				_run_spend_resource(str(parts[1]), int(parts[2]))
		"craft_target":
			if _require_args(parts, 3, "craft_target <blacksmith|workshop> <recipe_id|none> [force]"):
				var recipe_id := str(parts[2])
				if recipe_id.to_lower() in ["none", "clear", "empty"]:
					recipe_id = ""
				var force := parts.size() >= 4 and str(parts[3]).to_lower() in ["force", "true", "1", "yes"]
				_run_craft_target(str(parts[1]), recipe_id, force)
		"craft_stage":
			if _require_args(parts, 2, "craft_stage <blacksmith|workshop> [npc_id]"):
				var npc_id := str(parts[2]) if parts.size() >= 3 else ""
				_run_craft_stage(str(parts[1]), npc_id)
		"craft_snapshot":
			_show_craft_snapshot(str(parts[1]) if parts.size() >= 2 else "")
		"horse_snapshot":
			_show_horse_snapshot(str(parts[1]) if parts.size() >= 2 else "")
		"horse_damage":
			if _require_args(parts, 3, "horse_damage <horse_id> <amount>"):
				_run_horse_damage(str(parts[1]), float(parts[2]))
		"horse_advance":
			if _require_args(parts, 2, "horse_advance <game_seconds>"):
				_run_horse_advance(float(parts[1]))
		"horse_birth":
			_run_horse_birth()
		"horse_assign":
			if _require_args(parts, 3, "horse_assign <npc_id> <horse_id> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "local_public"
				_run_horse_assign(str(parts[1]), str(parts[2]), visibility)
		"horse_unassign":
			if _require_args(parts, 2, "horse_unassign <npc_id> [visibility]"):
				var visibility := str(parts[2]) if parts.size() >= 3 else "local_public"
				_run_horse_unassign(str(parts[1]), visibility)
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
		"spatial":
			if _require_args(parts, 2, "spatial <npc_id>"):
				_show_spatial_migration(str(parts[1]))
		"set_npc_state":
			if _require_args(parts, 4, "set_npc_state <npc_id> <key> <value>"):
				_run_set_npc_state(str(parts[1]), str(parts[2]), _parse_value(str(parts[3])))
		"recruit_npc":
			if _require_args(parts, 2, "recruit_npc <npc_id>"):
				_run_recruit_npc(str(parts[1]))
		"recruit_equip_all":
			_run_recruit_and_equip_all()
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
		"dialogue_carryover":
			_show_dialogue_carryover()
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
		"intent_revalidation":
			if _require_args(parts, 2, "intent_revalidation <npc_id>"):
				_show_dialogue_intent_revalidation(str(parts[1]))
		"llm_usage":
			_show_llm_usage()
		"station_context":
			_show_station_context()
		"start_proactive":
			if _require_args(parts, 3, "start_proactive <npc_id> <text>"):
				_run_start_proactive_talk(str(parts[1]), command.substr(("start_proactive %s" % str(parts[1])).length()).strip_edges())
		"npc_talk":
			if _require_args(parts, 3, "npc_talk <speaker_npc_id> <target_npc_id> [opening_text]"):
				var prefix := "npc_talk %s %s" % [str(parts[1]), str(parts[2])]
				_run_npc_talk(str(parts[1]), str(parts[2]), command.substr(prefix.length()).strip_edges())
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
		"next_wave", "jump_wave":
			_run_trigger_next_wave()
		"enemies":
			_show_combat_snapshot()
		"alarm", "rally":
			_run_combat_alarm()
		"step_enemies":
			var step_seconds := float(parts[1]) if parts.size() >= 2 else 1.0
			_run_step_enemy_ai(step_seconds)
		"clear_enemies":
			_run_clear_enemies()
		"behavior_modes":
			_show_behavior_modes()
		"avoid_npc":
			if _require_args(parts, 2, "avoid_npc <npc_id>"):
				_run_avoid_npc(str(parts[1]))
		"escape_npc":
			if _require_args(parts, 2, "escape_npc <npc_id>"):
				_run_escape_npc(str(parts[1]))
		"advance_rally_wait":
			var rally_seconds := float(parts[1]) if parts.size() >= 2 else 3600.0
			_run_advance_rally_wait(rally_seconds)
		"piety_fill":
			_run_fill_piety()
		"piety_set":
			if _require_args(parts, 2, "piety_set <value>"):
				_run_set_piety(float(parts[1]))
		"piety_snapshot":
			_show_piety_snapshot()
		"piety_step":
			var piety_step_seconds := float(parts[1]) if parts.size() >= 2 else 60.0
			_run_step_piety_effects(piety_step_seconds)
		"damage_building":
			if _require_args(parts, 3, "damage_building <building_id> <amount>"):
				_run_damage_building(str(parts[1]), int(parts[2]))
		"destroy_defense_device":
			if parts.size() >= 2:
				_run_destroy_defense_device(str(parts[1]))
			else:
				_run_destroy_first_defense_device()
		"defense_device_ruins":
			_show_defense_device_ruins()
		"repair_building":
			if _require_args(parts, 2, "repair_building <building_id>"):
				_run_repair_building(str(parts[1]))
		"upgrade_building":
			if _require_args(parts, 2, "upgrade_building <building_id>"):
				_run_upgrade_building(str(parts[1]))
		"smithy_art_level":
			if _require_args(parts, 2, "smithy_art_level <1|2|3>"):
				_run_smithy_art_level(int(parts[1]))
		"workshop_art_level":
			if _require_args(parts, 2, "workshop_art_level <1|2|3>"):
				_run_workshop_art_level(int(parts[1]))
		"chapel_art_level":
			if _require_args(parts, 2, "chapel_art_level <1|2>"):
				_run_chapel_art_level(int(parts[1]))
		"clinic_art_level":
			if _require_args(parts, 2, "clinic_art_level <1|2|3>"):
				_run_clinic_art_level(int(parts[1]))
		"dining_hall_art_level":
			if _require_args(parts, 2, "dining_hall_art_level <1|2|3>"):
				_run_dining_hall_art_level(int(parts[1]))
		"dormitory_art_level":
			if _require_args(parts, 2, "dormitory_art_level <1|2>"):
				_run_dormitory_art_level(int(parts[1]))
		"tavern_art_level":
			if _require_args(parts, 2, "tavern_art_level <1|2|3>"):
				_run_tavern_art_level(int(parts[1]))
		"garden_art_level":
			if _require_args(parts, 2, "garden_art_level <1|2|3>"):
				_run_garden_art_level(int(parts[1]))
		"training_ground_art_level":
			if _require_args(parts, 2, "training_ground_art_level <1|2|3>"):
				_run_training_ground_art_level(int(parts[1]))
		"stable_art_level":
			if _require_args(parts, 2, "stable_art_level <1|2|3>"):
				_run_stable_art_level(int(parts[1]))
		"main_hall_art_level":
			if _require_args(parts, 2, "main_hall_art_level <1|2|3|4|5|6>"):
				_run_main_hall_art_level(int(parts[1]))
		"warehouse_art_level":
			if _require_args(parts, 2, "warehouse_art_level <1|2|3>"):
				_run_warehouse_art_level(int(parts[1]))
		"wall_art_level":
			if _require_args(parts, 2, "wall_art_level <1|2|3|4|5|6>"):
				_run_wall_art_level(int(parts[1]))
		"gate_art_snapshot":
			_show_gate_art_snapshot()
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
		"dialogue_morale":
			if _require_args(parts, 3, "dialogue_morale <npc_id> <text>"):
				_run_dialogue_mock(str(parts[1]), command.substr(("dialogue_morale %s" % str(parts[1])).length()).strip_edges(), false, true)
		"dialogue_strategy":
			if _require_args(parts, 3, "dialogue_strategy <npc_id> <text>"):
				_run_dialogue_mock(str(parts[1]), command.substr(("dialogue_strategy %s" % str(parts[1])).length()).strip_edges(), false, false, true)
		"dialogue_work":
			if _require_args(parts, 3, "dialogue_work <npc_id> <text>"):
				_run_dialogue_mock(str(parts[1]), command.substr(("dialogue_work %s" % str(parts[1])).length()).strip_edges(), false, false, false, true)
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


func _show_time_snapshot() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	if time_system.has_method("get_time_scale_snapshot"):
		_log("时间倍率快照：%s" % _compact(time_system.get_time_scale_snapshot()))
	else:
		_log("时间倍率：玩家=%s，有效=%s。" % [time_system.get_speed_label(), time_system.get_effective_speed_label()])


func _show_resource_snapshot() -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		_log("ResourceSystem 不可用。")
		return
	_log("资源快照：%s" % _compact(resource_system.get_resource_snapshot()))


func _run_craft_target(building_id: String, recipe_id: String, force: bool) -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("set_target"):
		_log("CraftingSystem 目标接口不可用。")
		return
	var result: Dictionary = crafting_system.call("set_target", building_id, recipe_id, force)
	_log("制造目标 %s -> %s：%s" % [
		building_id,
		recipe_id if not recipe_id.is_empty() else "未选择",
		_compact(result)
	])


func _run_craft_stage(building_id: String, npc_id: String = "") -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if (
		crafting_system == null
		or not crafting_system.has_method("get_project_snapshot")
		or not crafting_system.has_method("complete_stage")
	):
		_log("CraftingSystem 阶段接口不可用。")
		return
	var project: Dictionary = crafting_system.call("get_project_snapshot", building_id)
	if project.is_empty():
		_log("制造建筑不可用：%s" % building_id)
		return
	var project_revision := int(project.get("project_revision", project.get("revision", -1)))
	var result: Dictionary = crafting_system.call("complete_stage", building_id, project_revision, npc_id)
	_log("完成制造阶段 %s revision=%d npc=%s：%s" % [
		building_id,
		project_revision,
		npc_id if not npc_id.is_empty() else "gm",
		_compact(result)
	])


func _show_craft_snapshot(building_id: String = "") -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null:
		_log("CraftingSystem 不可用。")
		return
	if not building_id.is_empty() and crafting_system.has_method("get_project_snapshot"):
		_log("制造项目快照 %s：%s" % [
			building_id,
			_compact(crafting_system.call("get_project_snapshot", building_id))
		])
		return
	if crafting_system.has_method("debug_get_snapshot"):
		_log("制造系统快照：%s" % _compact(crafting_system.call("debug_get_snapshot")))
		return
	_log("CraftingSystem 调试快照接口不可用。")


func _show_horse_snapshot(horse_id: String = "") -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null:
		_log("HorseSystem 不可用。")
		return
	if not horse_id.is_empty() and horse_system.has_method("get_horse_snapshot"):
		_log("马匹快照 %s：%s" % [
			horse_id,
			_compact(horse_system.call("get_horse_snapshot", horse_id))
		])
		return
	if horse_system.has_method("get_horses_snapshot"):
		var snapshot := {
			"counts": horse_system.call("get_horse_counts_snapshot") if horse_system.has_method("get_horse_counts_snapshot") else {},
			"stable": horse_system.call("get_stable_summary") if horse_system.has_method("get_stable_summary") else {},
			"balance": horse_system.call("get_balance_snapshot") if horse_system.has_method("get_balance_snapshot") else {},
			"horses": horse_system.call("get_horses_snapshot")
		}
		_log("马匹系统快照：%s" % _compact(snapshot))
		return
	_log("HorseSystem 快照接口不可用。")


func _run_horse_damage(horse_id: String, damage: float) -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("debug_damage"):
		_log("HorseSystem debug_damage 接口不可用。")
		return
	var result: Dictionary = horse_system.call("debug_damage", horse_id, damage)
	_log("马匹受伤 %s -%.2f：%s" % [horse_id, damage, _compact(result)])


func _run_horse_advance(game_seconds: float) -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("debug_advance"):
		_log("HorseSystem debug_advance 接口不可用。")
		return
	var result: Dictionary = horse_system.call("debug_advance", game_seconds)
	_log("推进马匹生态 %.2f 游戏秒：%s" % [game_seconds, _compact(result)])


func _run_horse_birth() -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("debug_force_birth"):
		_log("HorseSystem debug_force_birth 接口不可用。")
		return
	var result: Dictionary = horse_system.call("debug_force_birth")
	_fill_horse_select()
	_log("强制马匹繁育：%s" % _compact(result))


func _run_horse_assign(npc_id: String, horse_id: String, visibility: String) -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("assign_horse_to_npc"):
		_log("HorseSystem 分配接口不可用。")
		return
	var result: Dictionary = horse_system.call("assign_horse_to_npc", npc_id, horse_id, visibility)
	_fill_horse_select()
	_log("分配马匹 %s -> %s：%s" % [npc_id, horse_id, _compact(result)])


func _run_horse_unassign(npc_id: String, visibility: String) -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("unassign_horse_from_npc"):
		_log("HorseSystem 取消分配接口不可用。")
		return
	var result: Dictionary = horse_system.call(
		"unassign_horse_from_npc",
		npc_id,
		"gm_manual",
		visibility
	)
	_fill_horse_select()
	_log("取消马匹分配 %s：%s" % [npc_id, _compact(result)])


func _run_merchant_wagon_arrival() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null or not merchant_system.has_method("debug_force_wagon_arrival"):
		_log("MerchantSystem 行商马车进场接口不可用。")
		return
	_log("行商马车开始进场：%s" % _compact(merchant_system.call("debug_force_wagon_arrival")))


func _run_formal_merchant_wagon_arrival() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null or not merchant_system.has_method("debug_force_formal_wagon_arrival"):
		_log("MerchantSystem 正式远距商路接口不可用。")
		return
	_log("行商马车开始正式远距进场：%s" % _compact(merchant_system.call("debug_force_formal_wagon_arrival")))


func _run_merchant_wagon_departure() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null or not merchant_system.has_method("debug_force_wagon_departure"):
		_log("MerchantSystem 行商马车离场接口不可用。")
		return
	_log("行商马车开始离场：%s" % _compact(merchant_system.call("debug_force_wagon_departure")))


func _show_merchant_wagon_snapshot() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null or not merchant_system.has_method("get_market_snapshot"):
		_log("MerchantSystem 行商马车快照接口不可用。")
		return
	_log("行商马车快照：%s" % _compact(merchant_system.call("get_market_snapshot")))


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
	var success := bool(time_system.debug_advance_hour())
	_log("推进模拟 1 小时：%s" % _ok_text(success))


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


func _run_destroy_defense_device(deployment_id: String) -> void:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("debug_destroy_device"):
		_log("DefenseDeviceSystem 塔防摧毁调试接口不可用。")
		return
	_log("摧毁塔防 %s：%s" % [deployment_id, _compact(device_system.debug_destroy_device(deployment_id))])
	_show_defense_device_ruins()


func _run_destroy_first_defense_device() -> void:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("debug_destroy_first_device"):
		_log("DefenseDeviceSystem 首个塔防摧毁调试接口不可用。")
		return
	_log("摧毁首个已部署塔防：%s" % _compact(device_system.debug_destroy_first_device()))
	_show_defense_device_ruins()


func _show_defense_device_ruins() -> void:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("get_state_snapshot"):
		_log("DefenseDeviceSystem 塔防废墟快照不可用。")
		return
	var snapshot: Dictionary = device_system.get_state_snapshot()
	_log("塔防废墟：%s" % _compact({
		"deployments": snapshot.get("deployments", []),
		"ruins": snapshot.get("ruins", [])
	}))


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


func _show_roof_visibility_snapshot() -> void:
	var controller := get_node_or_null(ROOF_VISIBILITY_CONTROLLER_PATH)
	if controller == null or not controller.has_method("debug_get_snapshot"):
		_log("RoofVisibilityController 不可用。")
		return
	_log("屋顶可见性快照：%s" % _compact(controller.call("debug_get_snapshot")))


func _run_station_layout_preview(enabled: bool) -> void:
	if not enabled:
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("debug_stop_all_formal_navigation_pilots"):
			npc_system.call("debug_stop_all_formal_navigation_pilots", "preview_closed")
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null:
		_log("StationLayoutController 不可用。")
		return
	var snapshot: Dictionary = {}
	if controller.has_method("debug_set_legacy_compatibility_enabled"):
		snapshot = controller.call("debug_set_legacy_compatibility_enabled", not enabled)
	elif controller.has_method("debug_set_preview_enabled"):
		snapshot = controller.call("debug_set_preview_enabled", enabled)
	else:
		_log("StationLayoutController 缺少空间切换接口。")
		return
	var state_text := "默认正式世界" if enabled else "临时旧图兼容模式"
	_log("切换到%s：%s" % [state_text, _compact(snapshot)])


func _show_station_layout_snapshot() -> void:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("debug_get_layout_snapshot"):
		_log("StationLayoutController 不可用。")
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var snapshot := {
		"layout": controller.call("debug_get_layout_snapshot"),
		"default_npc_world": (
			npc_system.get_default_formal_world_snapshot()
			if npc_system != null and npc_system.has_method("get_default_formal_world_snapshot")
			else {}
		),
	}
	_log("A5-P7 默认正式世界快照：%s" % _compact(snapshot))


func _run_formal_spatial_save() -> void:
	var save_system := get_node_or_null(SPATIAL_SAVE_SYSTEM_PATH)
	if save_system == null or not save_system.has_method("debug_save_formal_spatial_checkpoint"):
		_log("SpatialSaveSystem 不可用。")
		return
	_log("A5-P8 保存正式空间：%s" % _compact(save_system.debug_save_formal_spatial_checkpoint()))


func _run_formal_spatial_load() -> void:
	var save_system := get_node_or_null(SPATIAL_SAVE_SYSTEM_PATH)
	if save_system == null or not save_system.has_method("debug_load_formal_spatial_checkpoint"):
		_log("SpatialSaveSystem 不可用。")
		return
	_log("A5-P8 读取正式空间：%s" % _compact(save_system.debug_load_formal_spatial_checkpoint()))


func _show_formal_spatial_save_snapshot() -> void:
	var save_system := get_node_or_null(SPATIAL_SAVE_SYSTEM_PATH)
	if save_system == null or not save_system.has_method("debug_get_formal_spatial_checkpoint_snapshot"):
		_log("SpatialSaveSystem 不可用。")
		return
	_log("A5-P8 正式空间存档快照：%s" % _compact(save_system.debug_get_formal_spatial_checkpoint_snapshot()))


func _run_actor_motion_sandbox() -> void:
	if not ResourceLoader.exists(ACTOR_MOTION_SANDBOX_PATH, "PackedScene"):
		_log("运动沙盒场景不存在：%s" % ACTOR_MOTION_SANDBOX_PATH)
		return
	_log("正在打开 T0129C-A2 独立运动沙盒；按 F8 返回 Main。")
	get_tree().call_deferred("change_scene_to_file", ACTOR_MOTION_SANDBOX_PATH)


func _run_npc_dev_lab() -> void:
	if not ResourceLoader.exists(NPC_DEV_LAB_PATH, "PackedScene"):
		_log("T0130-D1 NPC 开发检视场景不存在：%s" % NPC_DEV_LAB_PATH)
		return
	_log("正在打开 T0130-D1 NPC 开发检视场景；可切换角色、模式、动作、装备与坐骑，F8 返回 Main。")
	get_tree().call_deferred("change_scene_to_file", NPC_DEV_LAB_PATH)


func _run_chibi_character_main_preview(enabled: bool) -> void:
	var controller := get_node_or_null(CHIBI_CHARACTER_PREVIEW_CONTROLLER_PATH)
	if controller == null or not controller.has_method("debug_set_preview_enabled"):
		_log("T0130-P0 主场景试片控制器不可用。")
		return
	var snapshot: Dictionary = controller.call("debug_set_preview_enabled", enabled)
	_log("T0130-P0 主场景角色试片：%s" % str(snapshot))
	if enabled and _panel != null:
		_panel.visible = false


func _show_chibi_character_preview_snapshot() -> void:
	var controller := get_node_or_null(CHIBI_CHARACTER_PREVIEW_CONTROLLER_PATH)
	if controller == null or not controller.has_method("debug_get_snapshot"):
		_log("T0130-P0 主场景试片控制器不可用。")
		return
	_log("T0130-P0 角色试片快照：%s" % str(controller.call("debug_get_snapshot")))


func _show_chibi_formal_character_snapshot() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var snapshot := {
		"glen": npc_system.debug_get_npc_character_art_snapshot("blacksmith_01") if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot") else {},
		"toma": npc_system.debug_get_npc_character_art_snapshot("stableman_01") if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot") else {},
		"bruno": npc_system.debug_get_npc_character_art_snapshot("cook_01") if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot") else {},
		"ivo": npc_system.debug_get_npc_character_art_snapshot("gardener_01") if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot") else {},
		"active_enemies": combat_system.debug_get_enemy_art_snapshots() if combat_system != null and combat_system.has_method("debug_get_enemy_art_snapshots") else [],
	}
	_log("T0130-P4 正式角色快照：%s" % _compact(snapshot))


func _run_glen_navigation_pilot() -> void:
	_run_formal_navigation_pilot("glen", "格伦→铁匠铺")


func _run_clinic_navigation_pilot(mode: String) -> void:
	var pilot_id := "clinic_doctor" if mode == "doctor" else "clinic_bed"
	var mode_label := "莉娜→诊疗位" if mode == "doctor" else "莉娜→病床"
	_run_formal_navigation_pilot(pilot_id, mode_label)


func _run_dormitory_navigation_pilot() -> void:
	_run_formal_navigation_pilot("dormitory_bed", "艾达→固定床")


func _run_dining_navigation_pilot() -> void:
	_run_formal_navigation_pilot("dining_seat", "布鲁诺→用餐席")


func _run_chapel_navigation_pilot() -> void:
	_run_formal_navigation_pilot("chapel_prayer_seat", "马塞尔→祈祷席")


func _run_stable_navigation_pilot() -> void:
	_run_formal_navigation_pilot("stable_care", "托马→马厩照料位")


func _run_formal_stable_work() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	):
		_log("托马→马厩真实照料：失败（游戏当前暂停；请点击主界面左上“继续”后重试，未创建正式路线或工位预留。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_work"):
		_log("ActionSystem 的马厩真实照料入口不可用。")
		return
	var started := bool(action_system.debug_assign_work("stableman_01", "stable"))
	_log("托马→马厩真实照料：%s" % _ok_text(started))
	_show_formal_stable_work_snapshot()


func _stop_formal_stable_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("stableman_01", "gm_formal_stable_work_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("stableman_01", "gm_stopped", true)
	_log("停止托马真实照料：%s" % _ok_text(interrupted))
	_show_formal_stable_work_snapshot()


func _show_formal_stable_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "stableman_01",
		"runtime_action": (
			action_system.get_runtime_action_snapshot("stableman_01")
			if action_system != null and action_system.has_method("get_runtime_action_snapshot")
			else {}
		),
		"formal_session": (
			npc_system.get_formal_workstation_action_snapshot("stableman_01")
			if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
			else {}
		),
		"character_art": (
			npc_system.debug_get_npc_character_art_snapshot("stableman_01")
			if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot")
			else {}
		),
		"stable_horses": (
			horse_system.get_stable_horse_summary()
			if horse_system != null and horse_system.has_method("get_stable_horse_summary")
			else {}
		)
	}
	_log("马厩真实照料快照：%s" % _compact(snapshot))


func _run_formal_dining_work() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	):
		_log("布鲁诺→食堂真实烹饪：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_work"):
		_log("ActionSystem 的食堂真实烹饪入口不可用。")
		return
	var started := bool(action_system.debug_assign_work("cook_01", "dining_hall"))
	_log("布鲁诺→食堂真实烹饪：%s" % _ok_text(started))
	_show_formal_dining_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_dining_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("cook_01", "gm_formal_dining_work_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("cook_01", "gm_stopped", true)
	_log("停止布鲁诺食堂真实烹饪：%s" % _ok_text(interrupted))
	_show_formal_dining_work_snapshot()


func _show_formal_dining_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "cook_01",
		"runtime_action": (
			action_system.get_runtime_action_snapshot("cook_01")
			if action_system != null and action_system.has_method("get_runtime_action_snapshot")
			else {}
		),
		"formal_session": (
			npc_system.get_formal_workstation_action_snapshot("cook_01")
			if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
			else {}
		),
		"character_art": (
			npc_system.debug_get_npc_character_art_snapshot("cook_01")
			if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot")
			else {}
		),
		"resources": {
			"grain": resource_system.get_resource("grain") if resource_system != null else -1,
			"meal": resource_system.get_resource("meal") if resource_system != null else -1
		},
		"dining_hall": (
			building_system.get_building("dining_hall")
			if building_system != null and building_system.has_method("get_building")
			else {}
		)
	}
	_log("食堂真实烹饪快照：%s" % _compact(snapshot))


func _run_formal_dining_eat() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("布鲁诺→食堂真实用餐：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的食堂真实用餐入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("cook_01", "eat_at_dining_hall"))
	_log("布鲁诺→食堂真实用餐：%s" % _ok_text(started))
	_show_formal_dining_eat_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_dining_eat() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("cook_01", "gm_formal_dining_eat_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("cook_01", "gm_stopped", true)
	_log("停止布鲁诺食堂真实用餐：%s" % _ok_text(interrupted))
	_show_formal_dining_eat_snapshot()


func _show_formal_dining_eat_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "cook_01",
		"runtime_action": action_system.get_runtime_action_snapshot("cook_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"formal_session": npc_system.get_formal_workstation_action_snapshot("cook_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"npc": npc_system.get_npc("cook_01") if npc_system != null else {},
		"resources": {
			"meal": resource_system.get_resource("meal") if resource_system != null else -1,
			"grain": resource_system.get_resource("grain") if resource_system != null else -1
		},
		"dining_hall": building_system.get_building("dining_hall") if building_system != null else {}
	}
	_log("食堂真实用餐快照：%s" % _compact(snapshot))


func _run_formal_dormitory_sleep() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("艾达→宿舍真实睡眠：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的宿舍真实睡眠入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("veteran_deputy_01", "sleep_in_dormitory"))
	_log("艾达→宿舍真实睡眠：%s" % _ok_text(started))
	_show_formal_dormitory_sleep_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_dormitory_sleep() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("veteran_deputy_01", "gm_formal_dormitory_sleep_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("veteran_deputy_01", "gm_stopped", true)
	_log("停止艾达宿舍真实睡眠：%s" % _ok_text(interrupted))
	_show_formal_dormitory_sleep_snapshot()


func _show_formal_dormitory_sleep_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var reflection_system := get_node_or_null(DAILY_REFLECTION_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "veteran_deputy_01",
		"runtime_action": action_system.get_runtime_action_snapshot("veteran_deputy_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"formal_session": npc_system.get_formal_workstation_action_snapshot("veteran_deputy_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"npc": npc_system.get_npc("veteran_deputy_01") if npc_system != null else {},
		"dormitory": building_system.get_building("dormitory") if building_system != null else {},
		"first_sleep_summary": reflection_system.get_async_reflection_snapshot() if reflection_system != null and reflection_system.has_method("get_async_reflection_snapshot") else {}
	}
	_log("宿舍真实睡眠快照：%s" % _compact(snapshot))


func _run_formal_garden_work() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	):
		_log("伊沃→菜园真实耕作：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_work"):
		_log("ActionSystem 的菜园真实耕作入口不可用。")
		return
	var started := bool(action_system.debug_assign_work("gardener_01", "garden"))
	_log("伊沃→菜园真实耕作：%s" % _ok_text(started))
	_show_formal_garden_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_garden_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("gardener_01", "gm_formal_garden_work_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("gardener_01", "gm_stopped", true)
	_log("停止伊沃菜园真实耕作：%s" % _ok_text(interrupted))
	_show_formal_garden_work_snapshot()


func _show_formal_garden_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "gardener_01",
		"runtime_action": (
			action_system.get_runtime_action_snapshot("gardener_01")
			if action_system != null and action_system.has_method("get_runtime_action_snapshot")
			else {}
		),
		"formal_session": (
			npc_system.get_formal_workstation_action_snapshot("gardener_01")
			if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
			else {}
		),
		"character_art": (
			npc_system.debug_get_npc_character_art_snapshot("gardener_01")
			if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot")
			else {}
		),
		"grain": resource_system.get_resource("grain") if resource_system != null else -1,
		"garden": (
			building_system.get_building("garden")
			if building_system != null and building_system.has_method("get_building")
			else {}
		)
	}
	_log("菜园真实耕作快照：%s" % _compact(snapshot))


func _run_formal_tavern_work() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	):
		_log("马塞尔→酒窖真实酿酒：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_work"):
		_log("ActionSystem 的酒窖真实酿酒入口不可用。")
		return
	var started := bool(action_system.debug_assign_work("priest_01", "tavern"))
	_log("马塞尔→酒窖真实酿酒：%s" % _ok_text(started))
	_show_formal_tavern_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_tavern_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("priest_01", "gm_formal_tavern_work_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("priest_01", "gm_stopped", true)
	_log("停止马塞尔酒窖真实酿酒：%s" % _ok_text(interrupted))
	_show_formal_tavern_work_snapshot()


func _show_formal_tavern_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "priest_01",
		"runtime_action": (
			action_system.get_runtime_action_snapshot("priest_01")
			if action_system != null and action_system.has_method("get_runtime_action_snapshot")
			else {}
		),
		"formal_session": (
			npc_system.get_formal_workstation_action_snapshot("priest_01")
			if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
			else {}
		),
		"resources": {
			"grain": resource_system.get_resource("grain") if resource_system != null else -1,
			"wine": resource_system.get_resource("wine") if resource_system != null else -1
		},
		"tavern": (
			building_system.get_building("tavern")
			if building_system != null and building_system.has_method("get_building")
			else {}
		)
	}
	_log("酒窖真实酿酒快照：%s" % _compact(snapshot))


func _run_formal_clinic_doctor() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("莉娜→小诊所真实坐诊：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的诊所真实坐诊入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("doctor_01", "work_clinic_doctor"))
	_log("莉娜→小诊所真实坐诊：%s" % _ok_text(started))
	_show_formal_clinic_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _run_formal_clinic_patient() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("布鲁诺→小诊所真实病床：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的诊所真实病床入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("cook_01", "receive_clinic_treatment"))
	_log("布鲁诺→小诊所真实病床：%s%s" % [
		_ok_text(started),
		"（需先用既有 NPC 扣血入口制造真实伤情，并让至少一名医生在途或在岗。）" if not started else ""
	])
	_show_formal_clinic_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_clinic_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted_ids: Array[String] = []
	for npc_id in ["doctor_01", "cook_01"]:
		var interrupted := false
		if action_system != null and action_system.has_method("interrupt_npc_action"):
			interrupted = bool(action_system.interrupt_npc_action(npc_id, "gm_formal_clinic_work_stopped", true))
		if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
			npc_system.end_formal_workstation_action(npc_id, "gm_stopped", true)
		if interrupted:
			interrupted_ids.append(npc_id)
	_log("停止小诊所真实服务：%s" % _compact(interrupted_ids))
	_show_formal_clinic_work_snapshot()


func _show_formal_clinic_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var snapshot := {
		"doctor_runtime": action_system.get_runtime_action_snapshot("doctor_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"patient_runtime": action_system.get_runtime_action_snapshot("cook_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"doctor_formal": npc_system.get_formal_workstation_action_snapshot("doctor_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"patient_formal": npc_system.get_formal_workstation_action_snapshot("cook_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"doctor_state": npc_system.get_npc_state("doctor_01") if npc_system != null else {},
		"patient_state": npc_system.get_npc_state("cook_01") if npc_system != null else {},
		"clinic": building_system.get_building("clinic") if building_system != null else {},
		"money": resource_system.get_resource("money") if resource_system != null else 0,
		"team_hp_per_hour": action_system.get_clinic_team_hp_per_hour() if action_system != null and action_system.has_method("get_clinic_team_hp_per_hour") else 0.0
	}
	_log("小诊所真实服务快照：%s" % _compact(snapshot))


func _run_formal_training_instructor() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("艾达→训练场真实执教：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的训练场真实执教入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("veteran_deputy_01", "work_training_instructor"))
	_log("艾达→训练场真实执教：%s%s" % [
		_ok_text(started),
		"（艾达必须装备主武器或坐骑。）" if not started else ""
	])
	_show_formal_training_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _run_formal_training_student() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("格伦→训练场真实受训：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的训练场真实受训入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("blacksmith_01", "receive_weapon_training"))
	_log("格伦→训练场真实受训：%s%s" % [
		_ok_text(started),
		"（格伦必须已入伍并装备主武器或坐骑；艾达需在途或在岗。）" if not started else ""
	])
	_show_formal_training_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_training_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted_ids: Array[String] = []
	# 教官先离岗，以便沿用 ActionSystem 的“最后教官离开”失败事实；
	# 随后的学员清理只负责兜底尚在途的会话。
	for npc_id in ["veteran_deputy_01", "blacksmith_01"]:
		var interrupted := false
		if action_system != null and action_system.has_method("interrupt_npc_action"):
			interrupted = bool(action_system.interrupt_npc_action(npc_id, "gm_formal_training_work_stopped", true))
		if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
			npc_system.end_formal_workstation_action(npc_id, "gm_stopped", true)
		if interrupted:
			interrupted_ids.append(npc_id)
	_log("停止训练场真实训练：%s" % _compact(interrupted_ids))
	_show_formal_training_work_snapshot()


func _show_formal_training_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var snapshot := {
		"instructor_runtime": action_system.get_runtime_action_snapshot("veteran_deputy_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"student_runtime": action_system.get_runtime_action_snapshot("blacksmith_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"instructor_formal": npc_system.get_formal_workstation_action_snapshot("veteran_deputy_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"student_formal": npc_system.get_formal_workstation_action_snapshot("blacksmith_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"instructor": npc_system.get_npc("veteran_deputy_01") if npc_system != null else {},
		"student": npc_system.get_npc("blacksmith_01") if npc_system != null else {},
		"training_ground": building_system.get_building("training_ground") if building_system != null else {}
	}
	_log("训练场真实训练快照：%s" % _compact(snapshot))


func _run_formal_chapel_prayer() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("伊沃→小教堂真实祈祷：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的小教堂真实祈祷入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("gardener_01", "pray_at_chapel"))
	_log("伊沃→小教堂真实祈祷：%s" % _ok_text(started))
	_show_formal_chapel_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _run_formal_chapel_leader() -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("马塞尔→小教堂真实主持：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_action"):
		_log("ActionSystem 的小教堂真实主持入口不可用。")
		return
	var started := bool(action_system.debug_assign_action("priest_01", "lead_mass"))
	_log("马塞尔→小教堂真实主持：%s" % _ok_text(started))
	_show_formal_chapel_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_chapel_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted_ids: Array[String] = []
	# 主持者先离坛，让仍在席位上的祈祷者先走既有“恢复独祷”转换；
	# 随后的祈祷者中断只负责关闭完整 GM 样片。
	for npc_id in ["priest_01", "gardener_01"]:
		var interrupted := false
		if action_system != null and action_system.has_method("interrupt_npc_action"):
			interrupted = bool(action_system.interrupt_npc_action(npc_id, "gm_formal_chapel_work_stopped", true))
		if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
			npc_system.end_formal_workstation_action(npc_id, "gm_stopped", true)
		if interrupted:
			interrupted_ids.append(npc_id)
	_log("停止小教堂真实礼拜：%s" % _compact(interrupted_ids))
	_show_formal_chapel_work_snapshot()


func _show_formal_chapel_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var piety_system := get_node_or_null("/root/Main/Systems/PietySystem")
	var snapshot := {
		"leader_runtime": action_system.get_runtime_action_snapshot("priest_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"prayer_runtime": action_system.get_runtime_action_snapshot("gardener_01") if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"leader_formal": npc_system.get_formal_workstation_action_snapshot("priest_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"prayer_formal": npc_system.get_formal_workstation_action_snapshot("gardener_01") if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"leader": npc_system.get_npc("priest_01") if npc_system != null else {},
		"prayer": npc_system.get_npc("gardener_01") if npc_system != null else {},
		"prayer_character_art": npc_system.debug_get_npc_character_art_snapshot("gardener_01") if npc_system != null and npc_system.has_method("debug_get_npc_character_art_snapshot") else {},
		"chapel": building_system.get_building("chapel") if building_system != null else {},
		"piety": piety_system.get_piety_snapshot() if piety_system != null and piety_system.has_method("get_piety_snapshot") else {}
	}
	_log("小教堂真实礼拜快照：%s" % _compact(snapshot))


func _is_gameplay_time_paused_for_formal_work() -> bool:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	)


func _run_formal_blacksmith_work() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	):
		_log("格伦→正式铁匠制造：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if (
		crafting_system == null
		or not crafting_system.has_method("get_project_snapshot")
		or not crafting_system.has_method("set_target")
		or not crafting_system.has_method("can_start_work_cycle")
	):
		_log("格伦→正式铁匠制造：失败（CraftingSystem 接口不可用。）")
		return
	var target_prepare := _prepare_formal_crafting_target(crafting_system, "blacksmith")
	if not bool(target_prepare.get("ok", false)):
		_log("格伦→正式铁匠制造：失败（无法准备制造目标：%s）" % _compact(target_prepare))
		return
	if bool(target_prepare.get("auto_selected", false)):
		_log("格伦→正式铁匠制造：已自动设置目标 %s。" % str(target_prepare.get("recipe_id", "")))
	var crafting_preflight: Dictionary = crafting_system.can_start_work_cycle("blacksmith", "blacksmith_01")
	if not bool(crafting_preflight.get("ok", false)):
		_log("格伦→正式铁匠制造：失败（%s）" % _compact(crafting_preflight))
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_work"):
		_log("ActionSystem 的正式铁匠制造入口不可用。")
		return
	var started := bool(action_system.debug_assign_work("blacksmith_01", "blacksmith"))
	_log("格伦→正式铁匠制造：%s" % _ok_text(started))
	_show_formal_blacksmith_work_snapshot()
	if started and _panel != null:
		# This button is a visual acceptance entry. Reveal the formal scene as
		# soon as dispatch succeeds instead of leaving the large GM window over it.
		_panel.visible = false


func _prepare_formal_crafting_target(crafting_system: Node, building_id: String) -> Dictionary:
	var project: Dictionary = crafting_system.get_project_snapshot(building_id)
	var existing_recipe_id := str(project.get("target_recipe_id", ""))
	if not existing_recipe_id.is_empty():
		return {"ok": true, "auto_selected": false, "recipe_id": existing_recipe_id}
	var recipe_id := ""
	if (
		_crafting_building_select != null
		and _crafting_recipe_select != null
		and _selected_id(_crafting_building_select) == building_id
	):
		recipe_id = _selected_id(_crafting_recipe_select)
	if recipe_id.is_empty() and crafting_system.has_method("get_recipe_ids_for_building"):
		var recipe_ids: Array = crafting_system.get_recipe_ids_for_building(building_id)
		if not recipe_ids.is_empty():
			recipe_id = str(recipe_ids[0])
	if recipe_id.is_empty():
		return {"ok": false, "reason": "%s_recipe_missing" % building_id}
	var target_result: Dictionary = crafting_system.set_target(building_id, recipe_id, false)
	if not bool(target_result.get("ok", false)):
		return {
			"ok": false,
			"reason": "%s_target_rejected" % building_id,
			"recipe_id": recipe_id,
			"target_result": target_result
		}
	return {
		"ok": true,
		"auto_selected": true,
		"recipe_id": recipe_id,
		"target_result": target_result
	}


func _stop_formal_blacksmith_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("blacksmith_01", "gm_formal_blacksmith_work_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("blacksmith_01", "gm_stopped", true)
	_log("停止格伦正式铁匠制造：%s" % _ok_text(interrupted))
	_show_formal_blacksmith_work_snapshot()


func _show_formal_blacksmith_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "blacksmith_01",
		"runtime_action": (
			action_system.get_runtime_action_snapshot("blacksmith_01")
			if action_system != null and action_system.has_method("get_runtime_action_snapshot")
			else {}
		),
		"formal_session": (
			npc_system.get_formal_workstation_action_snapshot("blacksmith_01")
			if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
			else {}
		),
		"crafting_project": (
			crafting_system.get_project_snapshot("blacksmith")
			if crafting_system != null and crafting_system.has_method("get_project_snapshot")
			else {}
		)
	}
	_log("正式铁匠制造快照：%s" % _compact(snapshot))


func _run_formal_workshop_work() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	):
		_log("欧文→正式工械制造：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）")
		return
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if (
		crafting_system == null
		or not crafting_system.has_method("get_project_snapshot")
		or not crafting_system.has_method("set_target")
		or not crafting_system.has_method("can_start_work_cycle")
	):
		_log("欧文→正式工械制造：失败（CraftingSystem 接口不可用。）")
		return
	var target_prepare := _prepare_formal_crafting_target(crafting_system, "workshop")
	if not bool(target_prepare.get("ok", false)):
		_log("欧文→正式工械制造：失败（无法准备制造目标：%s）" % _compact(target_prepare))
		return
	if bool(target_prepare.get("auto_selected", false)):
		_log("欧文→正式工械制造：已自动设置目标 %s。" % str(target_prepare.get("recipe_id", "")))
	var crafting_preflight: Dictionary = crafting_system.can_start_work_cycle("workshop", "engineer_01")
	if not bool(crafting_preflight.get("ok", false)):
		_log("欧文→正式工械制造：失败（%s）" % _compact(crafting_preflight))
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_work"):
		_log("ActionSystem 的正式工械制造入口不可用。")
		return
	var started := bool(action_system.debug_assign_work("engineer_01", "workshop"))
	_log("欧文→正式工械制造：%s" % _ok_text(started))
	_show_formal_workshop_work_snapshot()
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_workshop_work() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action("engineer_01", "gm_formal_workshop_work_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action("engineer_01", "gm_stopped", true)
	_log("停止欧文正式工械制造：%s" % _ok_text(interrupted))
	_show_formal_workshop_work_snapshot()


func _show_formal_workshop_work_snapshot() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	var snapshot := {
		"npc_id": "engineer_01",
		"runtime_action": (
			action_system.get_runtime_action_snapshot("engineer_01")
			if action_system != null and action_system.has_method("get_runtime_action_snapshot")
			else {}
		),
		"formal_session": (
			npc_system.get_formal_workstation_action_snapshot("engineer_01")
			if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
			else {}
		),
		"crafting_project": (
			crafting_system.get_project_snapshot("workshop")
			if crafting_system != null and crafting_system.has_method("get_project_snapshot")
			else {}
		)
	}
	_log("正式工械制造快照：%s" % _compact(snapshot))


func _run_formal_navigation_pilot(pilot_id: String, label: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_run_formal_navigation_pilot"):
		_log("NPCSystem 的 A2b-P1–P6 数据驱动试运行入口不可用。")
		return
	_log("%s正式导航试运行：%s" % [label, _compact(npc_system.call("debug_run_formal_navigation_pilot", pilot_id))])


func _show_formal_navigation_pilot_snapshot() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_get_formal_navigation_pilots_snapshot"):
		_log("NPCSystem 的正式导航试运行快照不可用。")
		return
	_log("正式导航试运行快照：%s" % _compact(npc_system.call("debug_get_formal_navigation_pilots_snapshot")))


func _stop_formal_navigation_pilots() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_stop_all_formal_navigation_pilots"):
		_log("NPCSystem 的正式导航停止入口不可用。")
		return
	_log("停止正式导航试运行：%s" % _compact(npc_system.call("debug_stop_all_formal_navigation_pilots", "gm_stop")))


func _show_glen_navigation_pilot_snapshot() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_get_glen_blacksmith_navigation_pilot_snapshot"):
		_log("NPCSystem 的 A2b-P1 快照不可用。")
		return
	_log("格伦正式导航快照：%s" % _compact(npc_system.call("debug_get_glen_blacksmith_navigation_pilot_snapshot")))


func _stop_glen_navigation_pilot() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_stop_glen_blacksmith_navigation_pilot"):
		_log("NPCSystem 的 A2b-P1 停止入口不可用。")
		return
	_log("停止格伦正式导航试运行：%s" % _compact(npc_system.call("debug_stop_glen_blacksmith_navigation_pilot", "gm_stop")))


func _run_smithy_art_level(level: int) -> void:
	var art_view := get_node_or_null(BLACKSMITH_ART_VIEW_PATH)
	if art_view == null:
		art_view = get_node_or_null(LEGACY_BLACKSMITH_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("BlacksmithArtView 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("铁匠铺美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_workshop_art_level(level: int) -> void:
	var art_view := get_node_or_null(WORKSHOP_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("WorkshopArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("工械坊美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_chapel_art_level(level: int) -> void:
	var art_view := get_node_or_null(CHAPEL_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("ChapelArt 不可用。")
		return
	var preview_level := clampi(level, 1, 2)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("小教堂美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_clinic_art_level(level: int) -> void:
	var art_view := get_node_or_null(CLINIC_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("ClinicArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("小诊所美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_dining_hall_art_level(level: int) -> void:
	var art_view := get_node_or_null(DINING_HALL_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("DiningHallArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("食堂美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_dormitory_art_level(level: int) -> void:
	var art_view := get_node_or_null(DORMITORY_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("DormitoryArt 不可用。")
		return
	var preview_level := clampi(level, 1, 2)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("宿舍美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_tavern_art_level(level: int) -> void:
	var art_view := get_node_or_null(TAVERN_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("TavernArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("酒窖美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_garden_art_level(level: int) -> void:
	var art_view := get_node_or_null(GARDEN_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("GardenArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("菜园美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_training_ground_art_level(level: int) -> void:
	var art_view := get_node_or_null(TRAINING_GROUND_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("TrainingGroundArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("训练场美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_stable_art_level(level: int) -> void:
	var art_view := get_node_or_null(STABLE_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("StableArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("马厩美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_main_hall_art_level(level: int) -> void:
	var art_view := get_node_or_null(MAIN_HALL_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("MainHallArt 不可用。")
		return
	var preview_level := clampi(level, 1, 6)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("主厅美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_warehouse_art_level(level: int) -> void:
	var art_view := get_node_or_null(WAREHOUSE_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("WarehouseArt 不可用。")
		return
	var preview_level := clampi(level, 1, 3)
	art_view.call("debug_force_visual_level", preview_level)
	var snapshot: Dictionary = {}
	if art_view.has_method("get_art_slice_snapshot"):
		snapshot = art_view.call("get_art_slice_snapshot")
	_log("仓库美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _run_wall_art_level(level: int) -> void:
	var art_view := get_node_or_null(FORTIFICATION_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("debug_force_visual_level"):
		_log("FortificationArt 不可用。")
		return
	var preview_level := clampi(level, 1, 6)
	var snapshot: Dictionary = art_view.call("debug_force_visual_level", preview_level)
	_log("围墙美术预览等级 %d（仅表现）：%s" % [preview_level, _compact(snapshot)])


func _show_gate_art_snapshot() -> void:
	var art_view := get_node_or_null(FORTIFICATION_ART_VIEW_PATH)
	if art_view == null or not art_view.has_method("get_gate_snapshot"):
		_log("FortificationArt 不可用。")
		return
	_log("正门表现：%s" % _compact(art_view.call("get_gate_snapshot", "front_gate")))
	_log("后门表现：%s" % _compact(art_view.call("get_gate_snapshot", "back_gate")))


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
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	):
		_log("移动 NPC %s -> %s：失败（游戏当前暂停；请点击主界面左上“继续”后重试，未写入移动状态。）" % [npc_id, building_id])
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


func _show_spatial_migration(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_get_spatial_migration_snapshot"):
		_log("NPC 空间迁移快照不可用。")
		return
	_log("空间迁移快照 %s：%s" % [npc_id, _compact(npc_system.debug_get_spatial_migration_snapshot(npc_id))])


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
	if plan_system != null and plan_system.has_method("get_last_plan_revision_judgement_result"):
		_log("最近计划修改判别：%s" % _compact(plan_system.get_last_plan_revision_judgement_result()))
	elif plan_system != null and plan_system.has_method("get_last_dialogue_plan_judgement_result"):
		_log("最近对话后计划判别：%s" % _compact(plan_system.get_last_dialogue_plan_judgement_result()))
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
	if reflection_system.has_method("get_async_reflection_snapshot"):
		_log("首次睡眠总结并发：%s" % _compact(reflection_system.get_async_reflection_snapshot()))


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


func _run_npc_talk(speaker_npc_id: String, target_npc_id: String, opening_text: String = "") -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("assign_npc_dialogue"):
		_log("NPC-NPC 对话系统不可用。")
		return
	var clean_opening := opening_text.strip_edges()
	if clean_opening.is_empty():
		clean_opening = "我想和你谈谈眼下的安排。"
	var ok := bool(action_system.assign_npc_dialogue(
		speaker_npc_id,
		target_npc_id,
		clean_opening,
		5,
		true,
		{},
		true
	))
	var failure_reason := _npc_action_block_reason(speaker_npc_id)
	if failure_reason.is_empty():
		failure_reason = _npc_action_block_reason(target_npc_id)
	if failure_reason.is_empty():
		failure_reason = "发起者或目标已被其他对话占用，或当前对话系统正忙"
	_log("NPC-NPC 对话 %s -> %s：%s" % [
		speaker_npc_id,
		target_npc_id,
		_action_command_result_text(speaker_npc_id, ok, failure_reason)
	])


func _show_dialogue_carryover() -> void:
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if plan_system == null or not plan_system.has_method("get_dialogue_carryover_snapshot"):
		_log("日计划对话跨小时状态接口不可用。")
		return
	_log("日计划对话跨小时状态：%s" % _compact(
		plan_system.get_dialogue_carryover_snapshot()
	))


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


func _run_recruit_and_equip_all() -> void:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("debug_apply_combat_loadout_preset"):
		_log("EquipmentSystem 一键征召配装接口不可用。")
		return
	var result: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	_fill_horse_select()
	_log("一键征召&配装：%s" % _compact(result))


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
	var eligibility: Dictionary = (
		action_system.get_action_eligibility(npc_id, action_id)
		if action_system.has_method("get_action_eligibility")
		else {}
	)
	var unavailable_reason := _npc_action_block_reason(npc_id)
	if unavailable_reason.is_empty() and not eligibility.is_empty() and (
		not bool(eligibility.get("eligible", false))
		or not bool(eligibility.get("available_now", false))
	):
		unavailable_reason = str(eligibility.get("unavailable_reason", "行动前提不满足"))
	var started := bool(action_system.debug_assign_action(npc_id, action_id, true))
	_log("指派行动 %s -> %s：%s" % [
		npc_id,
		action_id,
		_action_command_result_text(npc_id, started, unavailable_reason)
	])


func _run_formal_visit_location(npc_id: String, location_id: String) -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("真实拜访 %s -> %s：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）" % [npc_id, location_id])
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("assign_visit_location"):
		_log("ActionSystem 的真实拜访入口不可用。")
		return
	var started := bool(action_system.assign_visit_location(npc_id, location_id, true))
	var failure_reason := _npc_action_block_reason(npc_id)
	if failure_reason.is_empty():
		failure_reason = "目标地点当前不可进入或正式路线不可用"
	_log("真实拜访 %s -> %s：%s" % [
		npc_id,
		location_id,
		_action_command_result_text(npc_id, started, failure_reason)
	])
	_show_formal_visit_location_snapshot(npc_id)
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_visit_location(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action(npc_id, "gm_formal_visit_stopped", true))
	if npc_system != null and npc_system.has_method("end_formal_location_action"):
		npc_system.end_formal_location_action(npc_id, "gm_stopped")
	_log("停止真实拜访 %s：%s" % [npc_id, _ok_text(interrupted)])
	_show_formal_visit_location_snapshot(npc_id)


func _show_formal_visit_location_snapshot(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var snapshot := {
		"npc_id": npc_id,
		"runtime_action": action_system.get_runtime_action_snapshot(npc_id) if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"formal_session": npc_system.get_formal_workstation_action_snapshot(npc_id) if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot") else {},
		"spatial": npc_system.debug_get_spatial_migration_snapshot(npc_id) if npc_system != null and npc_system.has_method("debug_get_spatial_migration_snapshot") else {},
		"npc": npc_system.get_npc(npc_id) if npc_system != null else {}
	}
	_log("真实拜访快照：%s" % _compact(snapshot))


func _run_formal_npc_dialogue(
	speaker_npc_id: String,
	target_npc_id: String,
	opening_text: String = ""
) -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("真实找人对话 %s -> %s：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）" % [speaker_npc_id, target_npc_id])
		return
	_run_npc_talk(speaker_npc_id, target_npc_id, opening_text)
	_show_formal_npc_dialogue_snapshot(speaker_npc_id)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if (
		action_system != null
		and action_system.has_method("get_runtime_action_snapshot")
		and str((action_system.get_runtime_action_snapshot(speaker_npc_id) as Dictionary).get("action_id", "")) == "talk_to_npc"
		and _panel != null
	):
		_panel.visible = false


func _stop_formal_npc_dialogue(speaker_npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action(speaker_npc_id, "gm_formal_npc_dialogue_stopped", true))
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("force_end_dialogue_for_npc"):
		var end_result: Dictionary = dialog_system.force_end_dialogue_for_npc(
			speaker_npc_id,
			"gm_formal_npc_dialogue_stopped"
		)
		interrupted = bool(end_result.get("ended", false)) or interrupted
	_log("停止真实找人对话 %s：%s" % [speaker_npc_id, _ok_text(interrupted)])
	_show_formal_npc_dialogue_snapshot(speaker_npc_id)


func _show_formal_npc_dialogue_snapshot(speaker_npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	var formal_session: Dictionary = (
		npc_system.get_formal_dialogue_approach_snapshot(speaker_npc_id)
		if npc_system != null and npc_system.has_method("get_formal_dialogue_approach_snapshot")
		else {}
	)
	var target_npc_id := ""
	if bool(formal_session.get("active", false)):
		target_npc_id = str((formal_session.get("session", {}) as Dictionary).get("target_npc_id", ""))
	var snapshot := {
		"speaker_npc_id": speaker_npc_id,
		"target_npc_id": target_npc_id,
		"runtime_action": action_system.get_runtime_action_snapshot(speaker_npc_id) if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"formal_dialogue_session": formal_session,
		"speaker_spatial": npc_system.debug_get_spatial_migration_snapshot(speaker_npc_id) if npc_system != null and npc_system.has_method("debug_get_spatial_migration_snapshot") else {},
		"target_spatial": npc_system.debug_get_spatial_migration_snapshot(target_npc_id) if npc_system != null and npc_system.has_method("debug_get_spatial_migration_snapshot") and not target_npc_id.is_empty() else {},
		"dialogue": dialog_system.get_dialogue_state() if dialog_system != null and dialog_system.has_method("get_dialogue_state") else {}
	}
	_log("真实找人对话快照：%s" % _compact(snapshot))


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
	if _is_gameplay_time_paused_for_formal_work():
		_log("真实协助修复 %s -> %s：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）" % [npc_id, building_id])
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	var started := bool(action_system.debug_assign_repair_assist(npc_id, building_id, true))
	var failure_reason := _npc_action_block_reason(npc_id)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if not started and failure_reason.is_empty() and (
		building_system == null
		or not building_system.has_method("is_repair_in_progress")
		or not bool(building_system.is_repair_in_progress(building_id))
	):
		failure_reason = "目标建筑没有进行中的修复工程"
	_log("真实协助修复 %s -> %s：%s" % [
		npc_id,
		building_id,
		_action_command_result_text(npc_id, started, failure_reason)
	])
	_show_formal_repair_assist_snapshot(npc_id, building_id)
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_repair_assist(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action(npc_id, "gm_formal_repair_assist_stopped", true))
	_log("停止真实协助修复 %s：%s" % [npc_id, _ok_text(interrupted)])
	_show_formal_repair_assist_snapshot(npc_id, "")


func _show_formal_repair_assist_snapshot(npc_id: String, building_id: String = "") -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var formal: Dictionary = (
		npc_system.get_formal_workstation_action_snapshot(npc_id)
		if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
		else {}
	)
	var session: Dictionary = formal.get("session", {}) if formal.get("session", {}) is Dictionary else {}
	var resolved_building_id := building_id
	if resolved_building_id.is_empty():
		resolved_building_id = str(session.get("building_id", ""))
	var snapshot := {
		"npc_id": npc_id,
		"building_id": resolved_building_id,
		"runtime_action": action_system.get_runtime_action_snapshot(npc_id) if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"formal_session": formal,
		"npc_state": npc_system.get_npc_state(npc_id) if npc_system != null else {},
		"repair": building_system.get_repair_status(resolved_building_id) if building_system != null and not resolved_building_id.is_empty() else {}
	}
	_log("真实协助修复快照：%s" % _compact(snapshot))


func _run_assist_upgrade(npc_id: String, building_id: String) -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("真实协助升级 %s -> %s：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）" % [npc_id, building_id])
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	var started := bool(action_system.debug_assign_upgrade_assist(npc_id, building_id, true))
	var failure_reason := _npc_action_block_reason(npc_id)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if not started and failure_reason.is_empty() and (
		building_system == null
		or not building_system.has_method("is_upgrade_in_progress")
		or not bool(building_system.is_upgrade_in_progress(building_id))
	):
		failure_reason = "目标建筑没有进行中的升级工程"
	_log("真实协助升级 %s -> %s：%s" % [
		npc_id,
		building_id,
		_action_command_result_text(npc_id, started, failure_reason)
	])
	_show_formal_upgrade_assist_snapshot(npc_id, building_id)
	if started and _panel != null:
		_panel.visible = false


func _stop_formal_upgrade_assist(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action(npc_id, "gm_formal_upgrade_assist_stopped", true))
	_log("停止真实协助升级 %s：%s" % [npc_id, _ok_text(interrupted)])
	_show_formal_upgrade_assist_snapshot(npc_id, "")


func _show_formal_upgrade_assist_snapshot(npc_id: String, building_id: String = "") -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var formal: Dictionary = (
		npc_system.get_formal_workstation_action_snapshot(npc_id)
		if npc_system != null and npc_system.has_method("get_formal_workstation_action_snapshot")
		else {}
	)
	var session: Dictionary = formal.get("session", {}) if formal.get("session", {}) is Dictionary else {}
	var resolved_building_id := building_id
	if resolved_building_id.is_empty():
		resolved_building_id = str(session.get("building_id", ""))
	var snapshot := {
		"npc_id": npc_id,
		"building_id": resolved_building_id,
		"runtime_action": action_system.get_runtime_action_snapshot(npc_id) if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"formal_session": formal,
		"npc_state": npc_system.get_npc_state(npc_id) if npc_system != null else {},
		"upgrade": building_system.get_upgrade_status(resolved_building_id) if building_system != null and not resolved_building_id.is_empty() else {}
	}
	_log("真实协助升级快照：%s" % _compact(snapshot))


func _run_assist_heal(healer_npc_id: String, target_npc_id: String) -> void:
	if _is_gameplay_time_paused_for_formal_work():
		_log("真实协助治疗 %s -> %s：失败（游戏当前暂停；请点击主界面左上“继续”后重试。）" % [healer_npc_id, target_npc_id])
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("debug_assign_heal_assist"):
		_log("ActionSystem 协助治疗接口不可用。")
		return
	var started := bool(action_system.debug_assign_heal_assist(healer_npc_id, target_npc_id, true))
	var failure_reason := _npc_action_block_reason(healer_npc_id)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if not started and failure_reason.is_empty() and npc_system != null:
		var target_state: Dictionary = npc_system.get_npc_state(target_npc_id)
		if not bool(target_state.get("unconscious", false)):
			failure_reason = "治疗目标没有昏迷"
	if started:
		# The formal route is intentionally launched after the preview/navigation
		# map has had one physics + process handoff. Do not print a bare success for
		# the preparatory session before that handoff has actually happened.
		await get_tree().physics_frame
		await get_tree().process_frame
	var route_confirmed := false
	var active_confirmed := false
	if started and npc_system != null:
		var runtime: Dictionary = (
			action_system.get_runtime_action_snapshot(healer_npc_id)
			if action_system.has_method("get_runtime_action_snapshot")
			else {}
		)
		active_confirmed = (
			str(runtime.get("phase", "")) == "active"
			and str(runtime.get("action_id", "")) == "assist_heal"
		)
		var formal: Dictionary = (
			npc_system.get_formal_healing_approach_snapshot(healer_npc_id)
			if npc_system.has_method("get_formal_healing_approach_snapshot")
			else {}
		)
		var session: Dictionary = formal.get("session", {}) if formal.get("session", {}) is Dictionary else {}
		var healer_state: Dictionary = npc_system.get_npc_state(healer_npc_id)
		route_confirmed = (
			bool(session.get("healing_route_started", false))
			and str(healer_state.get("movement_target", "")) == "healing_target_%s" % target_npc_id
		)
	var result_text := _action_command_result_text(healer_npc_id, started, failure_reason)
	if started:
		if active_confirmed:
			result_text = "成功（已到位并开始治疗）"
		elif route_confirmed:
			result_text = "成功（已开始前往伤员）"
		else:
			result_text = "等待（治疗会话已建立，但路线尚未启动；可再次点击重试）"
	_log("真实协助治疗 %s -> %s：%s" % [
		healer_npc_id,
		target_npc_id,
		result_text
	])
	_show_formal_heal_assist_snapshot(healer_npc_id, target_npc_id)
	if started and (route_confirmed or active_confirmed) and _panel != null:
		_panel.visible = false


func _stop_formal_heal_assist(healer_npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var interrupted := false
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		interrupted = bool(action_system.interrupt_npc_action(healer_npc_id, "gm_formal_heal_assist_stopped", true))
	_log("停止真实协助治疗 %s：%s" % [healer_npc_id, _ok_text(interrupted)])
	_show_formal_heal_assist_snapshot(healer_npc_id, "")


func _show_formal_heal_assist_snapshot(healer_npc_id: String, target_npc_id: String = "") -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var formal: Dictionary = (
		npc_system.get_formal_healing_approach_snapshot(healer_npc_id)
		if npc_system != null and npc_system.has_method("get_formal_healing_approach_snapshot")
		else {}
	)
	var resolved_target_id := target_npc_id
	if resolved_target_id.is_empty():
		resolved_target_id = str(formal.get("target_npc_id", ""))
	var snapshot := {
		"healer_npc_id": healer_npc_id,
		"target_npc_id": resolved_target_id,
		"runtime_action": action_system.get_runtime_action_snapshot(healer_npc_id) if action_system != null and action_system.has_method("get_runtime_action_snapshot") else {},
		"formal_session": formal,
		"healer_state": npc_system.get_npc_state(healer_npc_id) if npc_system != null else {},
		"target_state": npc_system.get_npc_state(resolved_target_id) if npc_system != null and not resolved_target_id.is_empty() else {},
		"active_helpers": action_system.get_healing_helpers_for_target(resolved_target_id) if action_system != null and action_system.has_method("get_healing_helpers_for_target") and not resolved_target_id.is_empty() else []
	}
	_log("真实协助治疗快照：%s" % _compact(snapshot))


func _run_spawn_enemy_wave(wave_number: int) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_spawn_wave"):
		_log("CombatSystem 敌人生成接口不可用。")
		return
	var result: Dictionary = combat_system.debug_spawn_wave(wave_number, false, true)
	_log("生成敌人波次 %d：%s" % [wave_number, _compact(result)])


func _run_trigger_next_wave() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_trigger_next_wave"):
		_log("CombatSystem 下一波调试接口不可用。")
		return
	var result: Dictionary = combat_system.debug_trigger_next_wave()
	_log("跳到下一波：%s" % _compact(result))


func _run_clear_enemies() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_clear_enemies"):
		_log("CombatSystem 清空敌人接口不可用。")
		return
	var result: Dictionary = combat_system.debug_clear_enemies()
	_log("清空敌人：%s" % _compact(result))


func _run_formal_enemy_navigation_pilot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_run_formal_enemy_navigation_pilot"):
		_log("CombatSystem 正式敌军导航试点接口不可用。")
		return
	_log("启动林下敌军→正门试点：%s" % _compact(combat_system.debug_run_formal_enemy_navigation_pilot()))


func _show_formal_enemy_navigation_pilot_snapshot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_get_formal_enemy_navigation_pilot_snapshot"):
		_log("CombatSystem 正式敌军导航试点快照不可用。")
		return
	_log("正式敌军导航试点：%s" % _compact(combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()))


func _stop_formal_enemy_navigation_pilot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_stop_formal_enemy_navigation_pilot"):
		_log("CombatSystem 正式敌军导航试点停止接口不可用。")
		return
	_log("停止正式敌军导航试点：%s" % _compact(combat_system.debug_stop_formal_enemy_navigation_pilot()))


func _run_formal_active_enemy_main_hall_slice() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_run_formal_active_enemy_main_hall_slice"):
		_log("CombatSystem 活动敌军推进主厅切片接口不可用。")
		return
	_log("启动活动敌军推进主厅切片：%s" % _compact(combat_system.debug_run_formal_active_enemy_main_hall_slice()))


func _show_formal_active_enemy_main_hall_slice_snapshot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_get_formal_active_enemy_main_hall_slice_snapshot"):
		_log("CombatSystem 活动敌军推进主厅切片快照不可用。")
		return
	_log("活动敌军推进主厅切片：%s" % _compact(combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot()))


func _stop_formal_active_enemy_main_hall_slice() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_stop_formal_active_enemy_main_hall_slice"):
		_log("CombatSystem 活动敌军推进主厅切片停止接口不可用。")
		return
	_log("停止活动敌军推进主厅切片：%s" % _compact(combat_system.debug_stop_formal_active_enemy_main_hall_slice()))


func _run_formal_first_wave_slice() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_run_formal_first_wave_slice"):
		_log("CombatSystem 第一波正式实体切片接口不可用。")
		return
	_log("启动第一波正式实体切片：%s" % _compact(combat_system.debug_run_formal_first_wave_slice()))


func _show_formal_first_wave_slice_snapshot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_get_formal_first_wave_slice_snapshot"):
		_log("CombatSystem 第一波正式实体快照不可用。")
		return
	_log("第一波正式实体切片：%s" % _compact(combat_system.debug_get_formal_first_wave_slice_snapshot()))


func _stop_formal_first_wave_slice() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_stop_formal_first_wave_slice"):
		_log("CombatSystem 第一波正式实体停止接口不可用。")
		return
	_log("停止第一波正式实体切片：%s" % _compact(combat_system.debug_stop_formal_first_wave_slice()))


func _run_formal_second_wave_slice() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_run_formal_second_wave_slice"):
		_log("CombatSystem 第二波正式实体切片接口不可用。")
		return
	_log("启动第二波混编正式实体切片：%s" % _compact(combat_system.debug_run_formal_second_wave_slice()))


func _show_formal_second_wave_slice_snapshot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_get_formal_second_wave_slice_snapshot"):
		_log("CombatSystem 第二波正式实体快照不可用。")
		return
	_log("第二波混编正式实体切片：%s" % _compact(combat_system.debug_get_formal_second_wave_slice_snapshot()))


func _stop_formal_second_wave_slice() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_stop_formal_second_wave_slice"):
		_log("CombatSystem 第二波正式实体停止接口不可用。")
		return
	_log("停止第二波混编正式实体切片：%s" % _compact(combat_system.debug_stop_formal_second_wave_slice()))


func _run_formal_dynamic_wave_slice(wave_number: int = -1) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_run_formal_dynamic_wave_slice"):
		_log("CombatSystem 动态群战正式实体接口不可用。")
		return
	var resolved_wave_number := wave_number if wave_number > 0 else _int_from_selected_id(_combat_wave_select, 1)
	_log("启动第 %d 波动态群战实体：%s" % [resolved_wave_number, _compact(combat_system.debug_run_formal_dynamic_wave_slice(resolved_wave_number, true))])


func _show_formal_dynamic_wave_slice_snapshot() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_get_formal_dynamic_wave_slice_snapshot"):
		_log("CombatSystem 动态群战快照不可用。")
		return
	_log("动态群战正式实体：%s" % _compact(combat_system.debug_get_formal_dynamic_wave_slice_snapshot()))


func _stop_formal_dynamic_wave_slice() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_stop_formal_dynamic_wave_slice"):
		_log("CombatSystem 动态群战停止接口不可用。")
		return
	_log("停止动态群战正式实体：%s" % _compact(combat_system.debug_stop_formal_dynamic_wave_slice()))


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


func _run_escape_npc(npc_id: String) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_start_npc_escape"):
		_log("CombatSystem 逃离调试接口不可用。")
		return
	var result: Dictionary = combat_system.debug_start_npc_escape(npc_id, "gm_debug")
	_log("触发逃离 %s：%s" % [npc_id, _compact(result)])


func _add_named_special_result_button(
	row: HBoxContainer,
	button_text: String,
	button_name: String,
	special_type: String,
	outcome: String
) -> Button:
	var button := _add_button(row, button_text, func() -> void:
		_run_special_result_preview(_selected_id(_ai_npc_select), special_type, outcome)
	)
	button.name = button_name
	button.tooltip_text = "通过正式系统接口应用该结果并在对话框中展示；不调用 LLM。"
	return button


func _run_special_result_preview(npc_id: String, special_type: String, outcome: String) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("debug_preview_special_interaction_result"):
		_log("DialogSystem 特殊交互结果展台不可用。")
		return
	var result: Dictionary = dialog_system.debug_preview_special_interaction_result(
		npc_id,
		special_type,
		outcome,
		"local_public"
	)
	_log("特殊交互结果 %s/%s %s：%s" % [special_type, outcome, npc_id, _compact(result)])


func _run_escape_intervention_preview(npc_id: String, outcome: String) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("debug_preview_escape_intervention_result"):
		_log("DialogSystem 挽留结果展台不可用。")
		return
	var result: Dictionary = dialog_system.debug_preview_escape_intervention_result(npc_id, outcome)
	_log("挽留结果 %s %s：%s" % [outcome, npc_id, _compact(result)])


func _run_dialogue_emotion_preview(npc_id: String, emotion_id: String) -> Dictionary:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("debug_present_npc_dialogue_emotion"):
		var missing_result := {"ok": false, "error": "dialogue_emotion_preview_missing"}
		_log("DialogSystem 情绪气泡展台不可用。")
		return missing_result
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_clicked"):
		event_bus.npc_clicked.emit(npc_id)
	var result: Dictionary = dialog_system.debug_present_npc_dialogue_emotion(npc_id, emotion_id)
	_log("情绪气泡 %s/%s：%s" % [npc_id, emotion_id, _compact(result)])
	return result


func _run_dialogue_emotion_sequence(npc_id: String) -> void:
	for emotion_id in ["happy", "surprised", "angry", "determined"]:
		var result := _run_dialogue_emotion_preview(npc_id, emotion_id)
		if not bool(result.get("ok", false)):
			return
		await get_tree().create_timer(0.65).timeout


func _run_clear_dialogue_buffs(npc_id: String) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var morale_result: Dictionary = (
		combat_system.debug_clear_morale_boost(npc_id)
		if combat_system != null and combat_system.has_method("debug_clear_morale_boost")
		else {"ok": false, "error": "combat_system_missing"}
	)
	var work_result: Dictionary = (
		npc_system.debug_clear_work_encouragement_boost(npc_id)
		if npc_system != null and npc_system.has_method("debug_clear_work_encouragement_boost")
		else {"ok": false, "error": "npc_system_missing"}
	)
	_log("清除对话增益 %s：士气=%s 工作=%s" % [npc_id, _compact(morale_result), _compact(work_result)])


func _run_advance_rally_wait(game_seconds: float) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("debug_advance_rally_wait"):
		_log("CombatSystem 集结等待推进接口不可用。")
		return
	var result: Dictionary = combat_system.debug_advance_rally_wait(game_seconds)
	_log("推进集结等待 %.1f 秒：%s" % [game_seconds, _compact(result)])


func _run_fill_piety() -> void:
	var piety_system := get_node_or_null(PIETY_SYSTEM_PATH)
	if piety_system == null or not piety_system.has_method("debug_fill_piety"):
		_log("PietySystem 充能接口不可用。")
		return
	_log("充满虔诚：%s" % _compact(piety_system.debug_fill_piety()))


func _run_set_piety(value: float) -> void:
	var piety_system := get_node_or_null(PIETY_SYSTEM_PATH)
	if piety_system == null or not piety_system.has_method("debug_set_piety"):
		_log("PietySystem 设置接口不可用。")
		return
	_log("设置虔诚 %.2f：%s" % [value, _compact(piety_system.debug_set_piety(value))])


func _show_piety_snapshot() -> void:
	var piety_system := get_node_or_null(PIETY_SYSTEM_PATH)
	if piety_system == null or not piety_system.has_method("get_piety_snapshot"):
		_log("PietySystem 快照不可用。")
		return
	_log("虔诚 / 陨石快照：%s" % _compact(piety_system.get_piety_snapshot()))


func _run_step_piety_effects(game_seconds: float) -> void:
	var piety_system := get_node_or_null(PIETY_SYSTEM_PATH)
	if piety_system == null or not piety_system.has_method("debug_advance_effects"):
		_log("PietySystem 陨石推进接口不可用。")
		return
	_log("推进陨石 / 燃烧 %.1f 游戏秒：%s" % [
		game_seconds,
		_compact(piety_system.debug_advance_effects(game_seconds))
	])


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


func _show_llm_usage() -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("debug_request_llm_usage"):
		_log("LLMBridge 成本统计接口不可用。")
		return
	var result: Dictionary = llm_bridge.debug_request_llm_usage()
	var runtime_snapshot: Dictionary = {}
	if llm_bridge.has_method("debug_get_llm_runtime_snapshot"):
		runtime_snapshot = llm_bridge.debug_get_llm_runtime_snapshot()
	_log("LLM 额度 / 调试信息：usage=%s runtime=%s" % [_compact(result), _compact(runtime_snapshot)])


func _connect_llm_usage_signal() -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_signal("llm_usage_response_received"):
		return
	var callback := Callable(self, "_on_llm_usage_response_received")
	if not llm_bridge.llm_usage_response_received.is_connected(callback):
		llm_bridge.llm_usage_response_received.connect(callback)


func _request_llm_usage_refresh() -> void:
	if _llm_usage_request_pending:
		return
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("debug_request_llm_usage_async"):
		if _llm_usage_summary_label != null:
			_llm_usage_summary_label.text = "本次运行：LLM 用量接口不可用"
		return
	_llm_usage_request_pending = true
	var start_result: Dictionary = llm_bridge.debug_request_llm_usage_async()
	if not bool(start_result.get("ok", false)):
		_llm_usage_request_pending = false
		if _llm_usage_summary_label != null:
			_llm_usage_summary_label.text = "本次运行：LLM 用量查询启动失败"


func _on_llm_usage_response_received(result: Dictionary) -> void:
	_llm_usage_request_pending = false
	if _llm_usage_summary_label == null:
		return
	if not bool(result.get("ok", false)):
		_llm_usage_summary_label.text = "本次运行：后端未连接，暂时无法读取 LLM 用量"
		return
	var body: Dictionary = result.get("body", result)
	var summary: Dictionary = body.get("summary", {})
	var provider_usage: Dictionary = summary.get("provider_usage", {})
	var session: Dictionary = provider_usage.get("session", {})
	var daily: Dictionary = provider_usage.get("daily", {})
	var total_tokens := int(session.get(
		"total_tokens",
		int(session.get("input_tokens", 0)) + int(session.get("output_tokens", 0))
	))
	var session_cost := float(session.get("estimated_cost_cny", summary.get("estimated_cost", 0.0)))
	var daily_cost := float(daily.get("estimated_cost_cny", 0.0))
	var daily_limit := float(provider_usage.get("daily_limit_cny", 0.0))
	var limit_text := "未启用"
	if daily_limit > 0.0:
		limit_text = "¥%.2f" % daily_limit
	_llm_usage_summary_label.text = (
		"运行：入 %s / 出 %s / 总 %s tokens｜¥%.4f　今日：¥%.4f / %s"
		% [
			_format_token_count(int(session.get("input_tokens", 0))),
			_format_token_count(int(session.get("output_tokens", 0))),
			_format_token_count(total_tokens),
			session_cost,
			daily_cost,
			limit_text
		]
	)


func _format_token_count(value: int) -> String:
	var digits := str(maxi(0, value))
	var parts: Array[String] = []
	while digits.length() > 3:
		parts.push_front(digits.right(3))
		digits = digits.left(digits.length() - 3)
	parts.push_front(digits)
	return ",".join(parts)


func _run_dialogue_mock(
	npc_id: String,
	text: String,
	is_recruitment_request: bool,
	is_morale_encouragement_request: bool = false,
	is_combat_strategy_request: bool = false,
	is_work_encouragement_request: bool = false
) -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("debug_request_dialogue"):
		_log("LLMBridge 对话接口不可用。")
		return
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		clean_text = "守备官需要你帮忙守住这里。"
	var combat_strategy_context := {}
	if is_combat_strategy_request:
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		if combat_system == null or not combat_system.has_method("get_npc_combat_strategy_dialogue_context"):
			_log("CombatSystem 策略对话接口不可用。")
			return
		combat_strategy_context = combat_system.get_npc_combat_strategy_dialogue_context(npc_id)
		if combat_strategy_context.is_empty():
			var eligibility: Dictionary = combat_system.get_combat_strategy_dialogue_eligibility(npc_id) if combat_system.has_method("get_combat_strategy_dialogue_eligibility") else {}
			_log("策略 Mock %s 不可用：%s" % [npc_id, str(eligibility.get("message", "当前 NPC 不符合条件。"))])
			return
	var result: Dictionary = llm_bridge.debug_request_dialogue(
		npc_id,
		clean_text,
		is_recruitment_request,
		"local_public" if is_morale_encouragement_request or is_combat_strategy_request else "private",
		is_morale_encouragement_request,
		"",
		is_combat_strategy_request,
		combat_strategy_context,
		is_work_encouragement_request
	)
	var mock_label := "工作鼓励 Mock" if is_work_encouragement_request else "策略 Mock" if is_combat_strategy_request else "鼓舞 Mock" if is_morale_encouragement_request else "对话 Mock"
	_log("%s %s：%s" % [mock_label, npc_id, _compact(result)])


func _run_open_work_encouragement_dialogue(npc_id: String) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_player_dialogue") or not dialog_system.has_method("set_work_encouragement_request_pending"):
		_log("DialogSystem 工作鼓励对话接口不可用。")
		return
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id, "private")
	if not bool(start_result.get("ok", false)):
		_log("打开工作鼓励对话 %s：%s" % [npc_id, _compact(start_result)])
		return
	var toggle_result: Dictionary = dialog_system.set_work_encouragement_request_pending(true)
	_log("打开工作鼓励对话 %s：%s" % [npc_id, _compact(toggle_result)])


func _run_open_morale_encouragement_dialogue(npc_id: String) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_player_dialogue") or not dialog_system.has_method("set_morale_encouragement_request_pending"):
		_log("DialogSystem 鼓舞对话接口不可用。")
		return
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id, "local_public")
	if not bool(start_result.get("ok", false)):
		_log("打开鼓舞对话 %s：%s" % [npc_id, _compact(start_result)])
		return
	var toggle_result: Dictionary = dialog_system.set_morale_encouragement_request_pending(true)
	_log("打开鼓舞对话 %s：%s" % [npc_id, _compact(toggle_result)])


func _run_open_combat_strategy_dialogue(npc_id: String) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_player_dialogue") or not dialog_system.has_method("set_combat_strategy_request_pending"):
		_log("DialogSystem 策略对话接口不可用。")
		return
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id, "local_public")
	if not bool(start_result.get("ok", false)):
		_log("打开策略对话 %s：%s" % [npc_id, _compact(start_result)])
		return
	var toggle_result: Dictionary = dialog_system.set_combat_strategy_request_pending(true)
	_log("打开策略对话 %s：%s" % [npc_id, _compact(toggle_result)])


func _show_last_npc_context_injection() -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("get_last_npc_context_injection"):
		_log("LLMBridge 指令注入快照不可用。")
		return
	_log("最近 NPC LLM 指令注入：%s" % _compact(llm_bridge.get_last_npc_context_injection()))


func _show_station_context() -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("debug_build_station_context"):
		_log("LLMBridge 驿站上下文快照不可用。")
		return
	var station_context: Dictionary = llm_bridge.debug_build_station_context()
	var residents: Array = station_context.get("resident_roster", [])
	var buildings: Array = station_context.get("building_roster", [])
	var work_actions: Array = station_context.get("work_mode_actions", [])
	var basic_resources: Array = station_context.get("basic_resource_reserves", [])
	var rules: Array = station_context.get("station_rules", [])
	_log("NPC LLM 驿站简介：%s" % str(station_context.get("setting_summary", "")))
	_log("当前在站成员（%d）：%s" % [residents.size(), _compact(residents)])
	_log("驿站建筑（%d）：%s" % [buildings.size(), _compact(buildings)])
	_log("工作模式行为（%d）：%s" % [work_actions.size(), _compact(work_actions)])
	_log("公开基础资源（%d）：%s" % [basic_resources.size(), _compact(basic_resources)])
	_log("精简驿站规则（%d）：%s" % [rules.size(), _compact(rules)])


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


func _show_dialogue_intent_revalidation(npc_id: String) -> void:
	var plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if (
		plan_system == null
		or not plan_system.has_method(
			"debug_get_dialogue_intent_revalidation_snapshot"
		)
	):
		_log("日计划对话意图复核状态接口不可用。")
		return
	_log(
		"对话意图复核 %s：%s"
		% [
			npc_id,
			_compact(
				plan_system.debug_get_dialogue_intent_revalidation_snapshot(
					npc_id
				)
			)
		]
	)


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
	var raw_memory: Dictionary = memory_system.debug_get_npc_short_term_memory(npc_id)
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	var prompt_memory: Dictionary = {}
	if llm_bridge != null and llm_bridge.has_method("debug_build_short_memory_context"):
		prompt_memory = llm_bridge.debug_build_short_memory_context(npc_id)
	_log("短期记忆 %s（原始事件 %d / 见闻 %d；LLM 全量紧凑投影）：%s" % [
		npc_id,
		int(raw_memory.get("event_count", 0)),
		int(raw_memory.get("witness_count", 0)),
		_compact(prompt_memory)
	])


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
		_llm_usage_refresh_elapsed = LLM_USAGE_REFRESH_SECONDS
		_request_llm_usage_refresh()
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
		var above_y := button_rect.position.y - panel_size.y - PANEL_BUTTON_GAP
		if above_y >= 0.0:
			desired_position.y = above_y
		else:
			var right_x := button_rect.position.x + button_rect.size.x + PANEL_BUTTON_GAP
			var left_x := button_rect.position.x - panel_size.x - PANEL_BUTTON_GAP
			desired_position.x = right_x if right_x + panel_size.x <= viewport_size.x else left_x
			desired_position.y = button_rect.position.y + button_rect.size.y * 0.5 - panel_size.y * 0.5

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


func _action_command_result_text(npc_id: String, ok: bool, fallback_reason: String = "") -> String:
	if ok:
		return "成功"
	var clean_fallback := fallback_reason.strip_edges()
	if not clean_fallback.is_empty():
		return "失败（%s）" % clean_fallback
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var context: Dictionary = (
			state.get("last_action_failure_context", {})
			if state.get("last_action_failure_context", {}) is Dictionary
			else {}
		)
		for key in ["failure_summary", "unavailable_reason", "failure_reason", "reason", "message"]:
			var detail := str(context.get(key, "")).strip_edges()
			if not detail.is_empty():
				return "失败（%s）" % detail
	return "失败（请查看紧随其后的正式行动快照）"


func _npc_action_block_reason(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return "NPCSystem 不可用"
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if state.is_empty():
		return "NPC 不存在"
	if bool(state.get("unconscious", false)):
		return "NPC 已昏迷"
	if bool(state.get("escaped", false)):
		return "NPC 已逃离驿站"
	if bool(state.get("first_sleep_summary_active", false)):
		return "NPC 正在完成首次睡眠总结"
	if npc_system.has_method("get_npc_behavior_mode_snapshot"):
		var mode: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
		var behavior_mode := str(mode.get("behavior_mode", "work"))
		if behavior_mode != "work":
			return "NPC 当前处于 %s 行为模式，不能执行日常正式行动" % behavior_mode
	return ""


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
		"空间检查点：formal_spatial_save [save|load|snapshot]",
		"refresh | snapshot | events | plaza_events | roof_visibility | station_layout [preview|legacy|snapshot] | motion_sandbox | character_pilot [glen|enemy|sandbox|snapshot] | formal_nav_pilot [glen|clinic_doctor|clinic_bed|dormitory_bed|dining_seat|chapel_prayer_seat|stable_care|stop|snapshot] | formal_visit [run <npc_id> <location_id>|stop <npc_id>|snapshot <npc_id>] | formal_npc_dialogue [run <speaker_id> <target_id> [opening]|stop <speaker_id>|snapshot <speaker_id>] | formal_repair_assist [run <npc_id> <building_id>|stop <npc_id>|snapshot <npc_id> [building_id]] | formal_upgrade_assist [run <npc_id> <building_id>|stop <npc_id>|snapshot <npc_id> [building_id]] | formal_heal_assist [run <healer_id> <target_id>|stop <healer_id>|snapshot <healer_id> [target_id]] | formal_stable_work [run|stop|snapshot] | formal_dining_work [run|stop|snapshot] | formal_dining_eat [run|stop|snapshot] | formal_dormitory_sleep [run|stop|snapshot] | formal_garden_work [run|stop|snapshot] | formal_tavern_work [run|stop|snapshot] | formal_clinic_work [doctor|patient|stop|snapshot] | formal_training_work [instructor|student|stop|snapshot] | formal_chapel_work [leader|prayer|stop|snapshot] | formal_blacksmith_work [run|stop|snapshot] | formal_workshop_work [run|stop|snapshot] | formal_dynamic_wave [run <1-5>|stop|snapshot] | formal_second_wave_slice [run|stop|snapshot]（兼容）",
		"add_resource <id> <amount> | spend_resource <id> <amount>",
		"set_time <day> <hour> <minute> <second> | advance_hour（推进模拟 1 小时） | time_snapshot | merchant_wagon [arrival|formal_arrival|departure|snapshot]",
		"slowdown [id] [scale] [reason] | release_slowdown <id> | clear_slowdowns",
		"backend_health | llm_usage | dialogue_mock <npc_id> <text> | dialogue_recruit <npc_id> <text> | dialogue_morale <npc_id> <text> | dialogue_strategy <npc_id> <text> | dialogue_work <npc_id> <text> | llm_state <npc_id> | intent_revalidation <npc_id> | last_order_injection | station_context",
		"select_npc <npc_id> | select_building <building_id>",
		"move_npc <npc_id> <building_id> | enter_location <npc_id> <location_id> | spatial <npc_id>",
		"set_npc_state <npc_id> <key> <value> | recruit_npc <npc_id> | recruit_equip_all | assign_attribute <npc_id> <strength|intelligence>",
		"publish_order <npc_id> <text> | order <npc_id> | plan_request | dialogue_carryover | plan_generate [npc_id|all] | plan_generate_rule [npc_id|all] | plan_execute [npc_id|all] | plan <npc_id> | plan_revise <npc_id> [reason]",
		"reflect_npc <npc_id> [force] | long_memory <npc_id> | reflection_result",
		"start_proactive <npc_id> <text> | proactive <npc_id>",
		"npc_talk <speaker_npc_id> <target_npc_id> [opening_text]",
		"equip_weapon <npc_id> <weapon_id> [visibility] | equip_armor <npc_id> <slot> [visibility] | unit_type <npc_id>",
		"craft_target <blacksmith|workshop> <recipe_id|none> [force] | craft_stage <building_id> [npc_id] | craft_snapshot [building_id]",
		"horse_snapshot [horse_id] | horse_damage <horse_id> <amount> | horse_advance <game_seconds> | horse_birth",
		"horse_assign <npc_id> <horse_id> [visibility] | horse_unassign <npc_id> [visibility]",
		"assign_action <npc_id> <action_id> | work <npc_id> <building_id> | train_instructor <npc_id> | train_student <npc_id> | assist_repair <npc_id> <building_id> | assist_upgrade <npc_id> <building_id> | assist_heal <healer_npc_id> <target_npc_id> | eat <npc_id> | sleep <npc_id>",
		"alarm | rally | spawn_wave [wave_number] | enemy_wave [wave_number] | next_wave | jump_wave | enemies | step_enemies [game_seconds] | clear_enemies | behavior_modes | avoid_npc <npc_id> | escape_npc <npc_id> | advance_rally_wait [game_seconds]",
		"piety_fill | piety_set <value> | piety_snapshot | piety_step [game_seconds]",
		"damage_building <building_id> <amount> | repair_building <building_id> | upgrade_building <building_id> | destroy_defense_device [deployment_id] | defense_device_ruins | smithy_art_level <1|2|3> | workshop_art_level <1|2|3> | chapel_art_level <1|2> | clinic_art_level <1|2|3> | dining_hall_art_level <1|2|3> | dormitory_art_level <1|2> | tavern_art_level <1|2|3> | garden_art_level <1|2|3> | training_ground_art_level <1|2|3> | stable_art_level <1|2|3> | main_hall_art_level <1|2|3|4|5|6> | warehouse_art_level <1|2|3> | wall_art_level <1|2|3|4|5|6> | gate_art_snapshot（仅表现预览）",
		"plaza_notice <text> | give_money <npc_id> <amount> [visibility] | attack_npc <npc_id> <damage> [visibility]",
		"damage_npc <npc_id> <damage> [visibility] 与 attack_npc 等价，会扣除 HP 并触发昏迷判定。",
		"recover_npc <npc_id> <game_seconds> 会用自然恢复规则推进昏迷恢复。",
		"memory <npc_id> | location <location_id>"
	])
