extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const CRAFTING_SYSTEM_PATH := "/root/Main/Systems/CraftingSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const PANEL_SCREEN_MARGIN := 16.0
const PANEL_MIN_WIDTH := 360.0
const PANEL_MAX_WIDTH := 420.0
const PANEL_VIEWPORT_WIDTH_RATIO := 0.20
const PANEL_CONTENT_VERTICAL_PADDING := 24.0
const PANEL_LAYOUT_SETTLE_FRAME_LIMIT := 4
const HORSE_LIST_MIN_HEIGHT := 120.0
const HORSE_LIST_MAX_HEIGHT := 620.0
const WORKSTATION_TYPE_LABELS := {
	"rest": "床位",
	"cook": "厨师",
	"brew": "酿酒位",
	"farm": "耕作位",
	"forge": "锻造位",
	"training_instructor": "教官",
	"training_student": "受训者",
	"horse_care": "照料位",
	"pray": "祈祷",
	"clinic_doctor": "医生",
	"patient_bed": "病床",
	"engineering": "工程位",
	"command": "指挥",
	"storage": "储存",
	"repair": "修复",
	"gate": "城门",
	"chapel_altar": "祭坛",
	"chapel_prayer_seat": "祈祷席",
	"clinic_doctor_station": "诊疗位",
	"clinic_patient_bed": "病床",
	"training_instructor_station": "教官位",
	"training_practice_slot": "训练位",
	"dining_kitchen_station": "灶台",
	"dining_seat": "用餐席",
	"dormitory_bed": "床位",
	"general": "位置",
	"unknown": "位置"
}

var _current_building_id: String = ""
var _current_building: Dictionary = {}
var _action_hint_panel: PanelContainer
var _action_hint_label: Label
var _device_section: VBoxContainer
var _device_stock_label: Label
var _device_select: OptionButton
var _device_slot_select: OptionButton
var _device_deploy_button: Button
var _device_summary_label: Label
var _device_status_label: Label
var _warehouse_capacity_label: Label
var _crafting_section: VBoxContainer
var _crafting_target_select: OptionButton
var _crafting_recipe_label: Label
var _crafting_stage_label: Label
var _crafting_progress_bar: ProgressBar
var _crafting_worker_label: Label
var _crafting_status_label: Label
var _crafting_confirmation: ConfirmationDialog
var _crafting_pending_target_id := ""
var _is_filling_crafting_targets := false
var _horse_section: VBoxContainer
var _horse_summary_label: Label
var _horse_scroll: ScrollContainer
var _horse_list: VBoxContainer
var _horse_refresh_queued := false
var _panel_scroll: ScrollContainer
var _panel_fit_queued := false
var _layout_viewport_override := Vector2.ZERO
var _fitted_heights_by_building: Dictionary = {}
var _reveal_after_fit := false
var _panel_fit_generation := 0
var _drag_controller

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
	_set_panel_interaction_enabled(false)
	_setup_panel_scroll()
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, name_label.get_parent() as Control)
	close_button.pressed.connect(_on_close_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	repair_button.mouse_entered.connect(_show_repair_hint)
	repair_button.mouse_exited.connect(_hide_action_hint)
	upgrade_button.mouse_entered.connect(_show_upgrade_hint)
	upgrade_button.mouse_exited.connect(_hide_action_hint)
	_build_warehouse_capacity_label()
	_build_crafting_section()
	_build_horse_section()
	_build_defense_device_section()
	_build_action_hint()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.building_clicked.connect(_on_building_clicked)
		event_bus.building_state_changed.connect(_on_building_state_changed)
		if event_bus.has_signal("time_scale_changed"):
			event_bus.time_scale_changed.connect(_on_time_scale_changed)
		event_bus.npc_clicked.connect(_on_npc_clicked)
		if event_bus.has_signal("defense_device_state_changed"):
			event_bus.defense_device_state_changed.connect(_on_defense_device_state_changed)
		if event_bus.has_signal("crafting_state_changed"):
			event_bus.crafting_state_changed.connect(_on_crafting_state_changed)
		if event_bus.has_signal("horse_state_changed"):
			event_bus.horse_state_changed.connect(_on_horse_state_changed)
		if event_bus.has_signal("resource_changed") and not event_bus.resource_changed.is_connected(_on_resource_changed):
			event_bus.resource_changed.connect(_on_resource_changed)
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system != null and crafting_system.has_signal("work_cycle_progress_changed"):
		if not crafting_system.work_cycle_progress_changed.is_connected(_on_crafting_work_cycle_progress_changed):
			crafting_system.work_cycle_progress_changed.connect(_on_crafting_work_cycle_progress_changed)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_queue_panel_fit):
		viewport.size_changed.connect(_queue_panel_fit)
	_queue_panel_fit()


func _setup_panel_scroll() -> void:
	var content := location_label.get_parent() as VBoxContainer
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
	scroll.name = "BuildingPanelScroll"
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
	# Repair/upgrade signals can arrive several times before containers sort.
	# Apply the last stable per-building height immediately, then refine it below.
	_apply_provisional_panel_fit()
	if _panel_fit_queued:
		return
	_panel_fit_queued = true
	call_deferred("_fit_panel_width", _panel_fit_generation)


func debug_set_layout_viewport_override(viewport_size: Vector2) -> void:
	# SceneTree headless tests do not propagate the configured window size through
	# CanvasLayer consistently. Runtime always leaves this override at ZERO.
	_layout_viewport_override = viewport_size
	_queue_panel_fit()


func _get_layout_viewport_size() -> Vector2:
	if _layout_viewport_override.x > 0.0 and _layout_viewport_override.y > 0.0:
		return _layout_viewport_override
	return get_viewport_rect().size


func _fit_panel_width(fit_generation: int) -> void:
	if fit_generation != _panel_fit_generation:
		return
	if not is_inside_tree():
		_panel_fit_queued = false
		return
	_apply_provisional_panel_fit()
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		_finish_panel_fit()
		return
	# A queued container sort is not guaranteed to emit sort_children again. Waiting
	# for that signal directly can therefore strand the panel fully transparent.
	# Sample on later frames instead and always finish within a bounded frame count.
	if not await _await_stable_content_layout(content, fit_generation):
		return
	if _current_building_id == "stable":
		_fit_horse_list_height()
		if not await _await_stable_content_layout(content, fit_generation):
			return
	_fit_panel_height()


func _await_stable_content_layout(content: VBoxContainer, fit_generation: int) -> bool:
	var previous_minimum_height := -1.0
	for _pass in range(PANEL_LAYOUT_SETTLE_FRAME_LIMIT):
		content.queue_sort()
		await get_tree().process_frame
		if fit_generation != _panel_fit_generation or not is_instance_valid(content):
			return false
		var current_minimum_height := content.get_combined_minimum_size().y
		if is_equal_approx(current_minimum_height, previous_minimum_height):
			return true
		previous_minimum_height = current_minimum_height
	return true


func _apply_provisional_panel_fit() -> void:
	if not is_inside_tree():
		return
	var viewport_size := _get_layout_viewport_size()
	var preserved_drag_position: Vector2 = (
		_drag_controller.get_user_position()
		if _drag_controller != null and _drag_controller.has_user_position()
		else Vector2.INF
	)
	var target_width := clampf(
		viewport_size.x * PANEL_VIEWPORT_WIDTH_RATIO,
		PANEL_MIN_WIDTH,
		PANEL_MAX_WIDTH
	)
	set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	offset_right = -PANEL_SCREEN_MARGIN
	offset_left = offset_right - target_width
	offset_top = PANEL_SCREEN_MARGIN
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		return
	var available_height := maxf(1.0, viewport_size.y - PANEL_SCREEN_MARGIN * 2.0)
	# Container minimum sizes are stale until the next sort pass. During an
	# upgrade refresh they can briefly report the full scroll content height.
	# Reuse the last measured height for this building until the exact pass runs.
	var provisional_height := float(_fitted_heights_by_building.get(_current_building_id, 1.0))
	offset_bottom = offset_top + minf(available_height, maxf(1.0, provisional_height))
	if preserved_drag_position != Vector2.INF:
		_drag_controller.restore_user_position(preserved_drag_position)


func _fit_panel_height() -> void:
	if not is_inside_tree():
		_panel_fit_queued = false
		return
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		_finish_panel_fit()
		return
	var available_height := maxf(1.0, _get_layout_viewport_size().y - PANEL_SCREEN_MARGIN * 2.0)
	var natural_height := content.get_combined_minimum_size().y + PANEL_CONTENT_VERTICAL_PADDING
	var target_height := minf(available_height, natural_height)
	offset_bottom = offset_top + target_height
	if not _current_building_id.is_empty():
		_fitted_heights_by_building[_current_building_id] = target_height
	_finish_panel_fit()


func _finish_panel_fit() -> void:
	_panel_fit_queued = false
	if _reveal_after_fit and not _current_building_id.is_empty():
		_reveal_after_fit = false
		modulate.a = 1.0
		visible = true
	_set_panel_interaction_enabled(visible and not _current_building_id.is_empty())


func _set_panel_interaction_enabled(enabled: bool) -> void:
	mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_INHERITED
		if enabled
		else Control.MOUSE_BEHAVIOR_DISABLED
	)


func _is_panel_action_input_allowed() -> bool:
	return (
		visible
		and not _reveal_after_fit
		and modulate.a >= 0.99
		and mouse_behavior_recursive != Control.MOUSE_BEHAVIOR_DISABLED
	)


func _cancel_pending_panel_fit() -> void:
	_panel_fit_generation += 1
	_panel_fit_queued = false


func _on_building_clicked(building_id: String) -> void:
	show_building(building_id)


func _on_building_state_changed(building_id: String) -> void:
	if visible and building_id == _current_building_id:
		show_building(building_id)


func _on_time_scale_changed(
	_player_scale: float,
	_effective_scale: float,
	_numeric_multiplier: float,
	_reason: String
) -> void:
	if visible and not _current_building_id.is_empty():
		show_building(_current_building_id)


func _on_npc_clicked(_npc_id: String) -> void:
	_hide_action_hint()
	_cancel_pending_panel_fit()
	_reveal_after_fit = false
	modulate.a = 1.0
	visible = false
	_set_panel_interaction_enabled(false)


func _on_defense_device_state_changed(_snapshot: Dictionary) -> void:
	if visible and ["wall", "main_hall"].has(_current_building_id):
		_refresh_defense_device_section()
		_queue_panel_fit()


func _on_crafting_state_changed(building_id: String) -> void:
	if visible and building_id == _current_building_id:
		_refresh_crafting_section()
		_queue_panel_fit()


func _on_crafting_work_cycle_progress_changed(building_id: String, _npc_id: String, _progress: float) -> void:
	if visible and building_id == _current_building_id:
		_refresh_crafting_section()
		_queue_panel_fit()


func _on_horse_state_changed(_horse_id: String) -> void:
	if not visible or _current_building_id != "stable" or _horse_refresh_queued:
		return
	_horse_refresh_queued = true
	call_deferred("_flush_queued_horse_refresh")


func _flush_queued_horse_refresh() -> void:
	_horse_refresh_queued = false
	if visible and _current_building_id == "stable":
		_refresh_horse_section()


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	if visible and _current_building_id == "warehouse":
		_refresh_warehouse_capacity_label()
		_queue_panel_fit()
	if visible and ["wall", "main_hall"].has(_current_building_id):
		_refresh_defense_device_section()
		_queue_panel_fit()
	if visible and ["blacksmith", "workshop"].has(_current_building_id):
		_refresh_crafting_section()
		_queue_panel_fit()


func show_building(building_id: String) -> void:
	if building_id.is_empty():
		_cancel_pending_panel_fit()
		_current_building_id = ""
		_current_building = {}
		_hide_action_hint()
		_reveal_after_fit = false
		modulate.a = 1.0
		visible = false
		_set_panel_interaction_enabled(false)
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.get_building_ids().has(building_id):
		_cancel_pending_panel_fit()
		_current_building_id = ""
		_current_building = {}
		_hide_action_hint()
		_reveal_after_fit = false
		modulate.a = 1.0
		visible = false
		_set_panel_interaction_enabled(false)
		return

	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		_cancel_pending_panel_fit()
		_current_building_id = ""
		_current_building = {}
		_hide_action_hint()
		_reveal_after_fit = false
		modulate.a = 1.0
		visible = false
		_set_panel_interaction_enabled(false)
		return

	var needs_deferred_reveal := not visible or _current_building_id != building_id
	if needs_deferred_reveal:
		_cancel_pending_panel_fit()
		# Keep the control in the layout tree but transparent while containers sort.
		# Hidden controls do not receive container layout notifications in Godot.
		visible = true
		modulate.a = 0.0
		_reveal_after_fit = true
		_set_panel_interaction_enabled(false)
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
	_refresh_warehouse_capacity_label()
	_refresh_crafting_section()
	_refresh_horse_section()
	_refresh_defense_device_section()
	_queue_panel_fit()
	if not needs_deferred_reveal:
		visible = true
		_set_panel_interaction_enabled(true)


func _build_warehouse_capacity_label() -> void:
	if _warehouse_capacity_label != null:
		return
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		return
	_warehouse_capacity_label = Label.new()
	_warehouse_capacity_label.name = "WarehouseCapacityLabel"
	_warehouse_capacity_label.visible = false
	_warehouse_capacity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warehouse_capacity_label.tooltip_text = "储存上限随仓库等级提高"
	content.add_child(_warehouse_capacity_label)
	content.move_child(_warehouse_capacity_label, location_label.get_index() + 1)


func _refresh_warehouse_capacity_label() -> void:
	if _warehouse_capacity_label == null:
		return
	_warehouse_capacity_label.visible = _current_building_id == "warehouse"
	if not _warehouse_capacity_label.visible:
		return
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.has_method("get_warehouse_capacity_snapshot"):
		_warehouse_capacity_label.text = "储存上限：无法读取"
		return
	var parts: Array[String] = []
	for raw_item in resource_system.get_warehouse_capacity_snapshot():
		var item: Dictionary = raw_item if raw_item is Dictionary else {}
		parts.append("%s %d" % [
			str(item.get("name", item.get("resource_id", ""))),
			int(item.get("capacity", 0))
		])
	_warehouse_capacity_label.text = (
		"储存上限：%s" % " / ".join(parts)
		if not parts.is_empty()
		else "储存上限：无"
	)


func _build_crafting_section() -> void:
	_crafting_section = VBoxContainer.new()
	_crafting_section.name = "CraftingSection"
	_crafting_section.visible = false
	_crafting_section.add_theme_constant_override("separation", 5)
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		return
	content.add_child(_crafting_section)
	content.move_child(_crafting_section, repair_button.get_parent().get_index())

	_crafting_section.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "制造项目"
	title.add_theme_font_size_override("font_size", 16)
	_crafting_section.add_child(title)

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 6)
	_crafting_section.add_child(target_row)
	var target_label := Label.new()
	target_label.text = "目标："
	target_label.custom_minimum_size.x = 54.0
	target_row.add_child(target_label)
	_crafting_target_select = OptionButton.new()
	_crafting_target_select.name = "CraftingTargetSelect"
	_crafting_target_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafting_target_select.item_selected.connect(_on_crafting_target_selected)
	target_row.add_child(_crafting_target_select)

	_crafting_recipe_label = Label.new()
	_crafting_recipe_label.name = "CraftingRecipeLabel"
	_crafting_recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crafting_section.add_child(_crafting_recipe_label)
	_crafting_stage_label = Label.new()
	_crafting_stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crafting_section.add_child(_crafting_stage_label)
	_crafting_progress_bar = ProgressBar.new()
	_crafting_progress_bar.name = "CraftingProgressBar"
	_crafting_progress_bar.min_value = 0.0
	_crafting_progress_bar.max_value = 100.0
	_crafting_progress_bar.show_percentage = true
	_crafting_section.add_child(_crafting_progress_bar)
	_crafting_worker_label = Label.new()
	_crafting_worker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crafting_section.add_child(_crafting_worker_label)
	_crafting_status_label = Label.new()
	_crafting_status_label.name = "CraftingStatusLabel"
	_crafting_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crafting_section.add_child(_crafting_status_label)

	_crafting_confirmation = ConfirmationDialog.new()
	_crafting_confirmation.name = "CraftingTargetConfirmation"
	_crafting_confirmation.title = "更换制造目标"
	_crafting_confirmation.ok_button_text = "是"
	_crafting_confirmation.cancel_button_text = "否"
	_crafting_confirmation.confirmed.connect(_on_crafting_target_confirmed)
	_crafting_confirmation.canceled.connect(_on_crafting_target_canceled)
	add_child(_crafting_confirmation)


func _refresh_crafting_section() -> void:
	if _crafting_section == null:
		return
	_crafting_section.visible = ["blacksmith", "workshop"].has(_current_building_id)
	if not _crafting_section.visible:
		return
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null:
		_crafting_recipe_label.visible = false
		_crafting_status_label.text = "制造系统不可用"
		_crafting_status_label.visible = true
		_crafting_target_select.disabled = true
		return
	var project: Dictionary = crafting_system.get_project_snapshot(_current_building_id) if crafting_system.has_method("get_project_snapshot") else {}
	var current_recipe_id := str(project.get("target_recipe_id", project.get("recipe_id", "")))
	_fill_crafting_target_options(crafting_system, current_recipe_id)
	_crafting_target_select.disabled = false
	var target_item_id := str(project.get("target_item_id", ""))
	if current_recipe_id.is_empty() or target_item_id.is_empty():
		_crafting_recipe_label.text = ""
		_crafting_recipe_label.visible = false
		_crafting_stage_label.text = "阶段：0 / 0"
		_crafting_progress_bar.value = 0.0
		_crafting_worker_label.text = "当前工人：无"
		_crafting_status_label.text = ""
		_crafting_status_label.visible = false
		return
	var recipe: Dictionary = crafting_system.get_recipe(current_recipe_id) if crafting_system.has_method("get_recipe") else {}
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var stock_amount := int(resource_system.get_resource(target_item_id)) if resource_system != null else int(project.get("stock_amount", 0))
	_crafting_recipe_label.visible = true
	_crafting_recipe_label.text = "成品：%s｜库存 %d｜难度 %d 阶段｜总材料：%s" % [
		str(project.get("target_name", recipe.get("name", target_item_id))),
		stock_amount,
		int(project.get("total_stages", (recipe.get("stages", []) as Array).size())),
		_format_cost(_get_recipe_total_cost(recipe))
	]
	var stage_index := int(project.get("current_stage_index", 0))
	var total_stages := int(project.get("total_stages", 0))
	var stage_name := str(project.get("current_stage_name", ""))
	var stage_cost: Dictionary = project.get("current_stage_cost", {}) if project.get("current_stage_cost", {}) is Dictionary else {}
	_crafting_stage_label.text = "阶段：已完成 %d / %d；当前 %d. %s（%s）" % [
		int(project.get("completed_stages", 0)), total_stages, stage_index, stage_name, _format_cost(stage_cost)
	]
	var progress := clampf(float(project.get("progress", 0.0)), 0.0, 1.0)
	_crafting_progress_bar.value = progress * 100.0
	_crafting_worker_label.text = "当前工人：%s" % _format_crafting_workers(project.get("active_workers", []))
	_crafting_status_label.text = ""
	_crafting_status_label.visible = false


func _fill_crafting_target_options(crafting_system: Node, selected_recipe_id: String) -> void:
	var recipe_ids: Array[String] = [""]
	if crafting_system.has_method("get_recipe_ids_for_building"):
		for raw_recipe_id in crafting_system.get_recipe_ids_for_building(_current_building_id):
			recipe_ids.append(str(raw_recipe_id))
	var needs_rebuild := _crafting_target_select.item_count != recipe_ids.size()
	if not needs_rebuild:
		for index in range(recipe_ids.size()):
			if str(_crafting_target_select.get_item_metadata(index)) != recipe_ids[index]:
				needs_rebuild = true
				break
	_is_filling_crafting_targets = true
	if needs_rebuild:
		_crafting_target_select.clear()
		_crafting_target_select.add_item("未选择目标")
		_crafting_target_select.set_item_metadata(0, "")
		for recipe_id in recipe_ids.slice(1):
			var recipe: Dictionary = crafting_system.get_recipe(recipe_id) if crafting_system.has_method("get_recipe") else {}
			var index := _crafting_target_select.item_count
			_crafting_target_select.add_item("%s（%d阶段）" % [
				str(recipe.get("name", recipe.get("output_name", recipe_id))),
				(recipe.get("stages", []) as Array).size()
			])
			_crafting_target_select.set_item_metadata(index, recipe_id)
	if _get_selected_metadata(_crafting_target_select) != selected_recipe_id:
		_select_option_by_metadata(_crafting_target_select, selected_recipe_id)
	_is_filling_crafting_targets = false


func _on_crafting_target_selected(_index: int) -> void:
	if _is_filling_crafting_targets:
		return
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("set_target"):
		return
	var project: Dictionary = crafting_system.get_project_snapshot(_current_building_id)
	var current_recipe_id := str(project.get("target_recipe_id", project.get("recipe_id", "")))
	var requested_recipe_id := _get_selected_metadata(_crafting_target_select)
	if requested_recipe_id == current_recipe_id:
		return
	if float(project.get("progress", 0.0)) > 0.000001:
		_select_option_by_metadata(_crafting_target_select, current_recipe_id)
		_crafting_pending_target_id = requested_recipe_id
		var old_name := str(project.get("target_name", current_recipe_id))
		var new_name := "未选择目标"
		if not requested_recipe_id.is_empty() and crafting_system.has_method("get_recipe"):
			var next_recipe: Dictionary = crafting_system.get_recipe(requested_recipe_id)
			new_name = str(next_recipe.get("name", next_recipe.get("output_name", requested_recipe_id)))
		_crafting_confirmation.dialog_text = "将制造目标从“%s”更换为“%s”？\n当前：第 %d / %d 阶段“%s”，整件进度 %d%%（已完成 %d 阶段）。\n更换会让全部制造进度清零；已投入材料不返还。是否更换？" % [
			old_name,
			new_name,
			int(project.get("current_stage_index", 0)),
			int(project.get("total_stages", 0)),
			str(project.get("current_stage_name", "")),
			int(round(float(project.get("progress", 0.0)) * 100.0)),
			int(project.get("completed_stages", 0))
		]
		_crafting_confirmation.popup_centered(Vector2i(520, 220))
		return
	_apply_crafting_target(requested_recipe_id, false)


func _on_crafting_target_confirmed() -> void:
	var requested_recipe_id := _crafting_pending_target_id
	_crafting_pending_target_id = ""
	_apply_crafting_target(requested_recipe_id, true)


func _on_crafting_target_canceled() -> void:
	_crafting_pending_target_id = ""
	_refresh_crafting_section()


func _apply_crafting_target(recipe_id: String, force_change: bool) -> Dictionary:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("set_target"):
		return {"ok": false, "message": "制造系统不可用"}
	var result: Dictionary = crafting_system.set_target(_current_building_id, recipe_id, force_change)
	_crafting_status_label.text = str(result.get("message", "制造目标已更新。"))
	_refresh_crafting_section()
	return result


func _get_recipe_total_cost(recipe: Dictionary) -> Dictionary:
	var total := {}
	for raw_stage in recipe.get("stages", []):
		if not raw_stage is Dictionary:
			continue
		var cost: Dictionary = raw_stage.get("cost", {}) if raw_stage.get("cost", {}) is Dictionary else {}
		for raw_resource_id in cost.keys():
			var resource_id := str(raw_resource_id)
			total[resource_id] = int(total.get(resource_id, 0)) + int(cost.get(raw_resource_id, 0))
	return total


func _format_crafting_workers(raw_workers: Variant) -> String:
	if not raw_workers is Array or raw_workers.is_empty():
		return "无"
	var names: Array[String] = []
	for raw_worker in raw_workers:
		var npc_id := str(raw_worker.get("npc_id", "")) if raw_worker is Dictionary else str(raw_worker)
		if not npc_id.is_empty():
			names.append(_format_npc_name(npc_id))
	return "、".join(names) if not names.is_empty() else "无"


func debug_select_crafting_target(recipe_id: String, confirm_change: bool = false) -> Dictionary:
	return _apply_crafting_target(recipe_id, confirm_change)


func debug_get_crafting_panel_snapshot() -> Dictionary:
	return {
		"visible": _crafting_section != null and _crafting_section.visible,
		"building_id": _current_building_id,
		"selected_recipe_id": _get_selected_metadata(_crafting_target_select),
		"progress": float(_crafting_progress_bar.value) / 100.0 if _crafting_progress_bar != null else 0.0,
		"confirmation_visible": _crafting_confirmation != null and _crafting_confirmation.visible,
		"pending_recipe_id": _crafting_pending_target_id
	}


func _build_horse_section() -> void:
	_horse_section = VBoxContainer.new()
	_horse_section.name = "HorseSection"
	_horse_section.visible = false
	_horse_section.add_theme_constant_override("separation", 5)
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		return
	content.add_child(_horse_section)
	content.move_child(_horse_section, repair_button.get_parent().get_index())

	_horse_section.add_child(HSeparator.new())
	_horse_summary_label = Label.new()
	_horse_summary_label.name = "HorseSummaryLabel"
	_horse_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_horse_section.add_child(_horse_summary_label)
	_horse_scroll = ScrollContainer.new()
	_horse_scroll.name = "HorseListScroll"
	_horse_scroll.custom_minimum_size = Vector2(0.0, HORSE_LIST_MIN_HEIGHT)
	_horse_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_horse_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_horse_section.add_child(_horse_scroll)
	_horse_list = VBoxContainer.new()
	_horse_list.name = "HorseList"
	_horse_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_horse_list.add_theme_constant_override("separation", 6)
	_horse_scroll.add_child(_horse_list)


func _refresh_horse_section() -> void:
	if _horse_section == null:
		return
	_horse_section.visible = _current_building_id == "stable"
	if not _horse_section.visible:
		return
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null:
		_horse_summary_label.text = "马匹系统不可用"
		return
	var summary: Dictionary = horse_system.get_stable_summary() if horse_system.has_method("get_stable_summary") else {}
	_horse_summary_label.text = "在厩：%d 匹（成年 %d / 小马 %d）｜离厩：%d" % [
		int(summary.get("total", summary.get("stable_total", 0))),
		int(summary.get("adult", summary.get("stable_adult", 0))),
		int(summary.get("foal", summary.get("stable_foal", 0))),
		int(summary.get("outside", summary.get("ridden", 0)))
	]
	_clear_container(_horse_list)
	if not horse_system.has_method("get_horse_ids"):
		return
	for raw_horse_id in horse_system.get_horse_ids():
		var horse_id := str(raw_horse_id)
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id) if horse_system.has_method("get_horse_snapshot") else {}
		_add_horse_card(horse)
	call_deferred("_fit_horse_list_and_panel")


func _fit_horse_list_and_panel() -> void:
	_fit_horse_list_height()
	_queue_panel_fit()


func _fit_horse_list_height() -> void:
	if _horse_scroll == null or _horse_list == null:
		return
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		return
	var available_height := maxf(1.0, _get_layout_viewport_size().y - PANEL_SCREEN_MARGIN * 2.0)
	var current_list_height := _horse_scroll.custom_minimum_size.y
	var fixed_content_height := maxf(
		0.0,
		content.get_combined_minimum_size().y - current_list_height
	)
	# 给外层留 2px 排版余量，避免内容只超出几个像素时形成双重滚动条。
	var list_height_budget := maxf(
		HORSE_LIST_MIN_HEIGHT,
		available_height - PANEL_CONTENT_VERTICAL_PADDING - fixed_content_height - 2.0
	)
	var natural_height := _horse_list.get_combined_minimum_size().y
	_horse_scroll.custom_minimum_size.y = clampf(
		natural_height,
		HORSE_LIST_MIN_HEIGHT,
		minf(HORSE_LIST_MAX_HEIGHT, list_height_budget)
	)


func _add_horse_card(horse: Dictionary) -> void:
	if horse.is_empty() or _horse_list == null:
		return
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_horse_list.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	margin.add_child(content)
	var horse_id := str(horse.get("horse_id", horse.get("id", "")))
	var assigned_npc_id := str(horse.get("assigned_npc_id", ""))
	var location := str(horse.get("location", "stable"))
	var feeding: Dictionary = horse.get("feeding", {}) if horse.get("feeding", {}) is Dictionary else {}
	var status_parts: Array[String] = ["成年" if bool(horse.get("is_adult", false)) else "小马"]
	status_parts.append("在厩" if location == "stable" else "骑乘中" if location == "ridden" else "位置未知")
	if bool(feeding.get("active", false)):
		status_parts.append("进食 %d%%" % int(round(float(feeding.get("progress", 0.0)) * 100.0)))
	elif bool(feeding.get("waiting_for_grain", false)):
		status_parts.append("等待粮食")
	if bool(horse.get("recovering", false)):
		status_parts.append("缓慢恢复")
	var header := Label.new()
	header.text = "%s（%s）｜%s" % [str(horse.get("name", horse_id)), horse_id, "、".join(status_parts)]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(header)
	var base_hp := float(horse.get("base_hp", maxf(0.0, float(horse.get("hp", 0.0)) - float(horse.get("care_bonus_hp", 0.0)))))
	var natural_max_hp := float(horse.get("natural_max_hp", 0.0))
	var extra_hp := float(horse.get("extra_hp", horse.get("care_bonus_hp", 0.0)))
	var extra_hp_cap := float(horse.get("extra_hp_cap", horse.get("care_bonus_cap", 0.0)))
	_add_horse_progress(
		content,
		"基础 HP %.1f / %.1f" % [base_hp, natural_max_hp],
		base_hp,
		maxf(1.0, natural_max_hp),
		"HorseBaseHP_%s" % horse_id
	)
	_add_horse_progress(
		content,
		"照料额外 HP %.1f / %.1f" % [extra_hp, extra_hp_cap],
		extra_hp,
		maxf(1.0, extra_hp_cap),
		"HorseExtraHP_%s" % horse_id
	)
	_add_horse_progress(
		content,
		"饱食 %.1f / %.1f" % [float(horse.get("satiety", 0.0)), float(horse.get("max_satiety", 0.0))],
		float(horse.get("satiety", 0.0)),
		maxf(1.0, float(horse.get("max_satiety", 0.0))),
		"HorseSatiety_%s" % horse_id
	)
	_add_horse_progress(
		content,
		"成长 %d%%" % int(round(float(horse.get("growth", 0.0)) * 100.0)),
		float(horse.get("growth", 0.0)),
		1.0,
		"HorseGrowth_%s" % horse_id
	)
	var breeding_probability := clampf(float(horse.get("breeding_probability", 0.0)), 0.0, 1.0)
	var breeding_text := "繁育概率 %.2f%%" % (breeding_probability * 100.0)
	var cooldown_seconds := maxf(0.0, float(horse.get("breeding_cooldown_remaining_seconds", 0.0)))
	if cooldown_seconds > 0.0:
		breeding_text += "（冷却 %s）" % _format_horse_cooldown(cooldown_seconds)
	elif not bool(horse.get("is_adult", false)):
		breeding_text += "（未成年）"
	elif location != "stable":
		breeding_text += "（离厩暂停）"
	_add_horse_progress(
		content,
		breeding_text,
		breeding_probability,
		1.0,
		"HorseBreedingProbability_%s" % horse_id
	)
	var assignment := Label.new()
	assignment.name = "HorseAssignment_%s" % horse_id
	assignment.text = "分配：%s" % (
		"无" if assigned_npc_id.is_empty() else _format_npc_name(assigned_npc_id)
	)
	content.add_child(assignment)


func _add_horse_progress(
	parent: VBoxContainer,
	tooltip: String,
	value: float,
	max_value: float,
	control_name: String = ""
) -> void:
	var progress := ProgressBar.new()
	if not control_name.is_empty():
		progress.name = control_name
	progress.custom_minimum_size.y = 12.0
	progress.min_value = 0.0
	progress.max_value = max_value
	progress.value = clampf(value, 0.0, max_value)
	progress.show_percentage = false
	progress.tooltip_text = tooltip
	parent.add_child(progress)
	var label := Label.new()
	if not control_name.is_empty():
		label.name = "%sLabel" % control_name
	label.text = tooltip
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)


func _format_horse_cooldown(seconds: float) -> String:
	var total_minutes := maxi(1, int(ceil(seconds / 60.0)))
	var days := total_minutes / 1440
	var hours := (total_minutes % 1440) / 60
	var minutes := total_minutes % 60
	if days > 0:
		return "%d天%d小时" % [days, hours]
	if hours > 0:
		return "%d小时%d分" % [hours, minutes]
	return "%d分" % minutes


func _clear_container(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_defense_device_section() -> void:
	_device_section = VBoxContainer.new()
	_device_section.name = "DefenseDeviceSection"
	_device_section.visible = false
	_device_section.add_theme_constant_override("separation", 5)
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		return
	content.add_child(_device_section)
	content.move_child(_device_section, repair_button.get_parent().get_index())

	var separator := HSeparator.new()
	_device_section.add_child(separator)
	var title := Label.new()
	title.text = "防御器械部署"
	title.add_theme_font_size_override("font_size", 16)
	_device_section.add_child(title)

	_device_stock_label = Label.new()
	_device_section.add_child(_device_stock_label)
	_device_select = _add_device_option_row("器械")
	_device_slot_select = _add_device_option_row("槽位")
	_device_select.item_selected.connect(_on_device_selection_changed)
	_device_slot_select.item_selected.connect(_on_device_selection_changed)

	_device_deploy_button = Button.new()
	_device_deploy_button.text = "部署到当前建筑"
	_device_deploy_button.pressed.connect(_on_device_deploy_pressed)
	_device_section.add_child(_device_deploy_button)

	_device_summary_label = Label.new()
	_device_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_device_section.add_child(_device_summary_label)
	_device_status_label = Label.new()
	_device_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_device_section.add_child(_device_status_label)


func _add_device_option_row(label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_device_section.add_child(row)
	var label := Label.new()
	label.custom_minimum_size.x = 54.0
	label.text = "%s：" % label_text
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	return option


func _refresh_defense_device_section() -> void:
	if _device_section == null:
		return
	_device_section.visible = ["wall", "main_hall"].has(_current_building_id)
	if not _device_section.visible:
		return
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null:
		_device_stock_label.text = "工程器械系统不可用"
		_device_deploy_button.disabled = true
		return
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var building_name := _current_building_id
	if building_system != null and building_system.has_method("get_building"):
		var building: Dictionary = building_system.get_building(_current_building_id)
		building_name = str(building.get("name", _current_building_id))
	_device_deploy_button.text = "部署到%s" % building_name

	var selected_device_id := _get_selected_metadata(_device_select)
	var selected_slot_id := _get_selected_metadata(_device_slot_select)
	_populate_device_options(device_system, selected_device_id)
	selected_device_id = _get_selected_metadata(_device_select)
	_populate_device_slot_options(device_system, selected_device_id, selected_slot_id)

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var selected_definition: Dictionary = device_system.get_device_definition(selected_device_id)
	var inventory_cost: Dictionary = selected_definition.get("inventory_cost", {}) if selected_definition.get("inventory_cost", {}) is Dictionary else {}
	var inventory_resource_id := ""
	var inventory_required := 0
	if not inventory_cost.is_empty():
		inventory_resource_id = str(inventory_cost.keys()[0])
		inventory_required = int(inventory_cost[inventory_resource_id])
	var inventory_amount := int(resource_system.get_resource(inventory_resource_id)) if resource_system != null and not inventory_resource_id.is_empty() else 0
	var inventory_name := str(selected_definition.get("name", "工程器械"))
	if resource_system != null and not inventory_resource_id.is_empty():
		inventory_name = str(resource_system.get_resource_name(inventory_resource_id))
	_device_stock_label.text = "%s库存：%d" % [inventory_name, inventory_amount]
	_device_summary_label.text = _format_device_deployment_summary(device_system)

	selected_slot_id = _get_selected_metadata(_device_slot_select)
	if selected_device_id.is_empty() or selected_slot_id.is_empty():
		_device_deploy_button.disabled = true
		_device_deploy_button.tooltip_text = "需要器械类型和兼容的空闲槽位。"
		return
	var eligibility: Dictionary = device_system.get_deploy_eligibility(selected_device_id, selected_slot_id)
	_device_deploy_button.disabled = not bool(eligibility.get("ok", false))
	_device_deploy_button.tooltip_text = (
		"消耗 %d 件%s。" % [inventory_required, inventory_name]
		if bool(eligibility.get("ok", false))
		else str(eligibility.get("message", "当前不可部署。"))
	)


func _populate_device_options(device_system: Node, preferred_id: String) -> void:
	_device_select.clear()
	for device_id in device_system.get_device_ids():
		var definition: Dictionary = device_system.get_device_definition(device_id)
		var stock_amount := 0
		var inventory_cost: Dictionary = definition.get("inventory_cost", {}) if definition.get("inventory_cost", {}) is Dictionary else {}
		if not inventory_cost.is_empty():
			var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
			var inventory_resource_id := str(inventory_cost.keys()[0])
			if resource_system != null:
				stock_amount = int(resource_system.get_resource(inventory_resource_id))
		_device_select.add_item("%s（库存 %d）" % [str(definition.get("name", device_id)), stock_amount])
		_device_select.set_item_metadata(_device_select.item_count - 1, device_id)
	_select_option_by_metadata(_device_select, preferred_id)


func _populate_device_slot_options(device_system: Node, device_id: String, preferred_id: String) -> void:
	_device_slot_select.clear()
	for raw_slot in device_system.get_slots_for_device(device_id, true, _current_building_id):
		if not raw_slot is Dictionary:
			continue
		var slot: Dictionary = raw_slot
		_device_slot_select.add_item(str(slot.get("name", slot.get("id", "围墙槽位"))))
		_device_slot_select.set_item_metadata(_device_slot_select.item_count - 1, str(slot.get("id", "")))
	_select_option_by_metadata(_device_slot_select, preferred_id)


func _format_device_deployment_summary(device_system: Node) -> String:
	var deployments: Array = device_system.get_deployments()
	if deployments.is_empty():
		return "已部署：无"
	var lines: Array[String] = ["已部署："]
	for raw_deployment in deployments:
		if not raw_deployment is Dictionary:
			continue
		var deployment: Dictionary = raw_deployment
		if str(deployment.get("building_id", "")) != _current_building_id:
			continue
		lines.append("- %s / %s" % [
			str(deployment.get("device_name", "工程器械")),
			str(deployment.get("slot_name", "围墙槽位"))
		])
	return "\n".join(lines) if lines.size() > 1 else "已部署：无"


func _get_selected_metadata(option: OptionButton) -> String:
	if option == null or option.item_count <= 0 or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))


func _select_option_by_metadata(option: OptionButton, preferred_id: String) -> void:
	if option.item_count <= 0:
		return
	var target_index := 0
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == preferred_id:
			target_index = index
			break
	option.select(target_index)


func _on_device_selection_changed(_index: int) -> void:
	_refresh_defense_device_section()


func _on_device_deploy_pressed() -> void:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null:
		return
	var result: Dictionary = device_system.deploy_device(
		_get_selected_metadata(_device_select),
		_get_selected_metadata(_device_slot_select)
	)
	if bool(result.get("ok", false)):
		var deployment: Dictionary = result.get("deployment", {})
		_device_status_label.text = "已部署：%s → %s" % [
			str(deployment.get("device_name", "工程器械")),
			str(deployment.get("slot_name", "围墙槽位"))
		]
	else:
		_device_status_label.text = str(result.get("message", "部署失败。"))
	_refresh_defense_device_section()


func _format_workstations(raw_workstations: Variant) -> String:
	if not raw_workstations is Array or raw_workstations.is_empty():
		return "位置：无"

	var workstations: Array = raw_workstations
	var totals_by_type := {}
	for raw_station in workstations:
		if not raw_station is Dictionary:
			continue
		var station_type := str((raw_station as Dictionary).get("type", "unknown"))
		if station_type.is_empty():
			station_type = "unknown"
		totals_by_type[station_type] = int(totals_by_type.get(station_type, 0)) + 1

	var indices_by_type := {}
	var lines: Array[String] = []
	for raw_station in workstations:
		if not raw_station is Dictionary:
			continue
		var station: Dictionary = raw_station
		var station_type := str(station.get("type", "unknown"))
		if station_type.is_empty():
			station_type = "unknown"
		var station_index := int(indices_by_type.get(station_type, 0)) + 1
		indices_by_type[station_type] = station_index
		var station_name := _format_workstation_name(station, station_type)
		if int(totals_by_type.get(station_type, 0)) > 1 and not _has_numeric_suffix(station_name):
			station_name = "%s%d" % [station_name, station_index]
		var occupied_by := str(station.get("occupied_by", ""))
		if occupied_by.is_empty() or occupied_by == "<null>":
			lines.append("%s：空闲" % station_name)
		else:
			lines.append("%s：%s占用中" % [station_name, _format_npc_name(occupied_by)])
	if lines.is_empty():
		return "位置：无"
	return "\n".join(lines)


func _format_workstation_type_label(station_type: String) -> String:
	return str(WORKSTATION_TYPE_LABELS.get(station_type, "位置"))


func _format_workstation_name(station: Dictionary, station_type: String) -> String:
	var station_name := str(station.get("name", "")).strip_edges()
	# BuildingSystem historically generated missing names from the internal type.
	# Keep those keys in runtime data, but never expose them as player-facing text.
	if (
		station_name.is_empty()
		or station_name == station_type
		or station_name.begins_with("%s " % station_type)
	):
		return _format_workstation_type_label(station_type)
	return station_name


func _has_numeric_suffix(text: String) -> bool:
	if text.is_empty():
		return false
	var final_character := text.substr(text.length() - 1, 1)
	return final_character >= "0" and final_character <= "9"


func _format_npc_name(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc"):
		var npc: Dictionary = npc_system.get_npc(npc_id)
		if not npc.is_empty():
			var npc_name := str(npc.get("name", ""))
			if not npc_name.is_empty():
				return npc_name
	return "未知成员"


func _format_location_placeholder(building: Dictionary) -> String:
	var repair_status: Dictionary = building.get("repair_status", {})
	var upgrade_status: Dictionary = building.get("upgrade_status", {})
	var lines: Array[String] = []

	var condition := str(building.get("condition", "unknown"))
	var condition_label: String = str({
		"intact": "完好",
		"damaged": "受损",
		"repairing": "正在修复",
		"upgrading": "正在升级"
	}.get(condition, "未知"))
	lines.append("建筑状态：%s" % condition_label)
	lines.append("当前运行效率：%d%%" % int(round(
		float(building.get("operational_efficiency_multiplier", building.get("operational_efficiency", 1.0))) * 100.0
	)))
	if not bool(building.get("is_enterable", true)) and bool(building.get("has_enterable_interior", false)):
		lines.append("内部状态：封闭，无法进入或使用位置")

	if not repair_status.is_empty():
		lines.append("修复中：%d%%，剩余 %s，x%.2f，协助 %d 人" % [
			int(round(float(repair_status.get("progress", 0.0)) * 100.0)),
			_format_remaining_duration(repair_status),
			float(repair_status.get("speed_multiplier", 1.0)),
			int(repair_status.get("helper_count", 0))
		])
	if not upgrade_status.is_empty():
		lines.append("升级中：%d%%，剩余 %s，x%.2f，协助 %d 人" % [
			int(round(float(upgrade_status.get("progress", 0.0)) * 100.0)),
			_format_remaining_duration(upgrade_status),
			float(upgrade_status.get("speed_multiplier", 1.0)),
			int(upgrade_status.get("helper_count", 0))
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
	if resource_system != null and resource_system.has_method("get_resource_name"):
		var resource_name := str(resource_system.get_resource_name(resource_id)).strip_edges()
		if not resource_name.is_empty() and resource_name != resource_id:
			return resource_name
	return "未知资源"


func _update_action_buttons(building_system: Node, building_id: String, building: Dictionary) -> void:
	var hp := int(building.get("hp", 0))
	var max_hp := int(building.get("max_hp", 0))
	var repair_status: Dictionary = building.get("repair_status", {})
	var upgrade_status: Dictionary = building.get("upgrade_status", {})
	var upgrade_config: Dictionary = building.get("upgrade", {})
	var max_level := int(upgrade_config.get("max_level", int(building.get("level", 1))))

	repair_button.disabled = not building_system.can_repair_building(building_id)
	if not repair_status.is_empty():
		repair_button.text = "修复中 %s" % _format_remaining_duration(repair_status)
	else:
		repair_button.text = "修复" if hp < max_hp else "修复（已满）"

	upgrade_button.disabled = not building_system.can_upgrade_building(building_id)
	if not upgrade_status.is_empty():
		upgrade_button.text = "升级中 %s" % _format_remaining_duration(upgrade_status)
	else:
		upgrade_button.text = "升级" if int(building.get("level", 1)) < max_level else "升级（已满）"


func _format_remaining_duration(status: Dictionary) -> String:
	var formatted := str(status.get("remaining_text", ""))
	if not formatted.is_empty():
		return formatted
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	var remaining_seconds := float(status.get("remaining_seconds", 0.0))
	if time_system != null and time_system.has_method("format_game_duration"):
		return str(time_system.format_game_duration(remaining_seconds, true, true))
	var total_seconds := ceili(maxf(0.0, remaining_seconds))
	return "%d小时%d分%02d秒" % [
		total_seconds / 3600,
		(total_seconds % 3600) / 60,
		total_seconds % 60
	]


func _build_action_hint() -> void:
	_action_hint_panel = PanelContainer.new()
	_action_hint_panel.name = "BuildingActionHint"
	_action_hint_panel.visible = false
	_action_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_hint_panel.z_index = 100

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
	call_deferred("_attach_action_hint")


func _attach_action_hint() -> void:
	if not is_instance_valid(_action_hint_panel) or _action_hint_panel.get_parent() != null:
		return
	var overlay_parent := get_parent()
	if overlay_parent != null:
		overlay_parent.add_child(_action_hint_panel)
	else:
		add_child(_action_hint_panel)


func _exit_tree() -> void:
	if (
		is_instance_valid(_action_hint_panel)
		and _action_hint_panel.get_parent() != self
	):
		_action_hint_panel.queue_free()


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
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var repair_quote: Dictionary = {}
	if building_system != null and building_system.has_method("get_repair_quote"):
		repair_quote = building_system.get_repair_quote(_current_building_id)
	var cost: Dictionary = repair_quote.get("cost", repair_config.get("cost", {}))
	var lines: Array[String] = ["修复"]
	lines.append("消耗：%s" % _format_cost(cost))
	if int(repair_quote.get("repair_batches", 0)) > 0:
		lines.append("工程量：缺失 %d HP，共 %d 批（每批恢复 %d HP）" % [
			int(repair_quote.get("missing_hp", 0)),
			int(repair_quote.get("repair_batches", 0)),
			int(repair_quote.get("hp_restore", 0))
		])
	if repair_config.is_empty():
		lines.append("条件：该建筑不可修复")
	elif not _current_building.get("upgrade_status", {}).is_empty():
		lines.append("条件：正在升级中")
	elif not _current_building.get("repair_status", {}).is_empty():
		lines.append("条件：正在修复中")
	elif int(_current_building.get("hp", 0)) >= int(_current_building.get("max_hp", 0)):
		lines.append("条件：HP 已满")
	elif cost.is_empty():
		lines.append("条件：修复配置无效")
	elif not _can_afford(cost):
		lines.append("条件：资源不足")
	else:
		lines.append("条件：可执行")
	return "\n".join(lines)


func _format_upgrade_hint() -> String:
	if _current_building.is_empty():
		return ""

	var base_upgrade_config: Dictionary = _current_building.get("upgrade", {})
	var current_level := int(_current_building.get("level", 1))
	var max_level := int(base_upgrade_config.get("max_level", current_level))
	var target_level := current_level + 1
	var upgrade_config := _get_next_upgrade_effect(target_level)
	var cost: Dictionary = upgrade_config.get("cost", {}) if upgrade_config.get("cost", {}) is Dictionary else {}
	var lines: Array[String] = ["升级"]
	if current_level < max_level:
		lines[0] = "升级至 Lv.%d" % target_level
		lines.append("消耗：%s" % _format_cost(cost))
		var duration_seconds := float(upgrade_config.get("duration_seconds", 0.0))
		if duration_seconds > 0.0:
			lines.append("工期：%s" % _format_game_duration(duration_seconds))
		for benefit_line in _format_upgrade_benefits(upgrade_config, current_level, target_level):
			lines.append(benefit_line)
	if base_upgrade_config.is_empty():
		lines.append("条件：该建筑不可升级")
	elif not _current_building.get("upgrade_status", {}).is_empty():
		lines.append("条件：正在升级中")
	elif not _current_building.get("repair_status", {}).is_empty():
		lines.append("条件：正在修复中")
	elif int(_current_building.get("hp", 0)) < int(_current_building.get("max_hp", 0)):
		lines.append("条件：建筑受损，需先修复")
	elif current_level >= max_level:
		lines.append("条件：已达最高等级 Lv.%d" % max_level)
	elif cost.is_empty():
		lines.append("条件：该等级缺少升级消耗配置")
	elif not _can_afford(cost):
		lines.append("条件：资源不足")
	else:
		lines.append("条件：可执行，最高 Lv.%d" % max_level)
	return "\n".join(lines)


func _get_next_upgrade_effect(target_level: int) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if (
		building_system != null
		and building_system.has_method("get_upgrade_level_effect")
		and not _current_building_id.is_empty()
	):
		return building_system.get_upgrade_level_effect(_current_building_id, target_level)
	return _current_building.get("upgrade", {}).duplicate(true)


func _format_upgrade_benefits(
	upgrade_config: Dictionary,
	current_level: int,
	target_level: int
) -> Array[String]:
	var benefits: Array[String] = []
	var max_hp_bonus := maxi(0, int(upgrade_config.get("max_hp_bonus", 0)))
	if max_hp_bonus > 0:
		benefits.append("收益：Max HP +%d" % max_hp_bonus)
	var defense_device_range_bonus := maxf(
		0.0,
		float(upgrade_config.get("defense_device_range_bonus", 0.0))
	)
	if defense_device_range_bonus > 0.0:
		benefits.append("器械射程：+%d%%" % roundi(defense_device_range_bonus * 100.0))

	var workstation_delta := 0
	var raw_deltas: Variant = upgrade_config.get("workstation_deltas", [])
	if raw_deltas is Array:
		for raw_delta in raw_deltas:
			if raw_delta is Dictionary:
				workstation_delta += maxi(0, int((raw_delta as Dictionary).get("count", 0)))
	if workstation_delta > 0:
		benefits.append("功能位置：+%d" % workstation_delta)
	if (
		upgrade_config.get("efficiency_bonuses", {}) is Dictionary
		and not (upgrade_config.get("efficiency_bonuses", {}) as Dictionary).is_empty()
	):
		benefits.append("运行效率：提升")

	var current_slots := _count_unlocked_defense_slots_at_level(current_level)
	var target_slots := _count_unlocked_defense_slots_at_level(target_level)
	if target_slots > 0:
		var slot_delta := target_slots - current_slots
		var total_slots := _count_unlocked_defense_slots_at_level(999)
		if slot_delta > 0:
			benefits.append("部署槽：+%d（解锁至 %d/%d）" % [
				slot_delta,
				target_slots,
				total_slots
			])
		else:
			benefits.append("部署槽：本级不增加（%d/%d）" % [
				target_slots,
				total_slots
			])
	return benefits


func _count_unlocked_defense_slots_at_level(level: int) -> int:
	if _current_building_id not in ["wall", "main_hall"]:
		return 0
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("get_slots_for_building"):
		return 0
	var count := 0
	for raw_slot in device_system.get_slots_for_building(_current_building_id, true):
		var slot: Dictionary = raw_slot
		if int(slot.get("required_building_level", 1)) <= level:
			count += 1
	return count


func _format_game_duration(duration_seconds: float) -> String:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("format_game_duration"):
		return str(time_system.format_game_duration(duration_seconds, true, true))
	var total_seconds := ceili(maxf(0.0, duration_seconds))
	return "%d小时%d分%02d秒" % [
		total_seconds / 3600,
		(total_seconds % 3600) / 60,
		total_seconds % 60
	]


func _can_afford(cost: Dictionary) -> bool:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func _on_repair_pressed() -> void:
	if _current_building_id.is_empty() or not _is_panel_action_input_allowed():
		return

	_hide_action_hint()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.repair_building(_current_building_id):
		show_building(_current_building_id)


func _on_upgrade_pressed() -> void:
	if _current_building_id.is_empty() or not _is_panel_action_input_allowed():
		return

	_hide_action_hint()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.upgrade_building(_current_building_id):
		show_building(_current_building_id)


func _on_close_pressed() -> void:
	_hide_action_hint()
	_cancel_pending_panel_fit()
	_reveal_after_fit = false
	modulate.a = 1.0
	visible = false
	_set_panel_interaction_enabled(false)
