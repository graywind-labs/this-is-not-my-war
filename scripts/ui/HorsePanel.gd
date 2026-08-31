extends Control


const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const HorsePortraitViewport = preload("res://scripts/ui/HorsePortraitViewport.gd")
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const PANEL_SCREEN_MARGIN := 16.0
const PANEL_WIDTH := 650.0
const PANEL_HEIGHT := 520.0
const PORTRAIT_GAP := 12.0
const PORTRAIT_MIN_WIDTH := 190.0
const PORTRAIT_MAX_WIDTH := 210.0
const PORTRAIT_VIEWPORT_WIDTH_RATIO := 0.11
const PORTRAIT_MIN_HEIGHT := 300.0
const PORTRAIT_MAX_HEIGHT := 420.0
const PORTRAIT_VIEWPORT_HEIGHT_RATIO := 0.5
const NORMAL_PROGRESS_FILL_COLOR := Color("#71865a")
const DANGER_PROGRESS_FILL_COLOR := Color("#a7433b")
const DANGER_LABEL_COLOR := Color("#dc6157")
const SATIETY_DANGER_RATIO := 0.20
const BASE_HP_DANGER_RATIO := 0.30

var _current_horse_id := ""
var _portrait_view
var _name_label: Label
var _identity_label: Label
var _status_label: Label
var _assignment_label: Label
var _slot_label: Label
var _base_hp: ProgressBar
var _base_hp_label: Label
var _extra_hp: ProgressBar
var _extra_hp_label: Label
var _satiety: ProgressBar
var _satiety_label: Label
var _growth: ProgressBar
var _growth_label: Label
var _breeding: ProgressBar
var _breeding_label: Label
var _drag_controller
var _layout_viewport_override := Vector2.ZERO
var _normal_progress_fill_style: StyleBoxFlat
var _danger_progress_fill_style: StyleBoxFlat


func _ready() -> void:
	visible = false
	_build_panel()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if event_bus.has_signal("horse_clicked"):
			event_bus.horse_clicked.connect(_on_horse_clicked)
		if event_bus.has_signal("horse_state_changed"):
			event_bus.horse_state_changed.connect(_on_horse_state_changed)
		if event_bus.has_signal("horse_assignment_changed"):
			event_bus.horse_assignment_changed.connect(_on_horse_assignment_changed)
		event_bus.npc_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("enemy_clicked"):
			event_bus.enemy_clicked.connect(_on_other_world_selection)
		event_bus.building_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("defense_device_clicked"):
			event_bus.defense_device_clicked.connect(_on_other_world_selection)
		if event_bus.has_signal("world_selection_cleared"):
			event_bus.world_selection_cleared.connect(_on_world_selection_cleared)
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _build_panel() -> void:
	var row := HBoxContainer.new()
	row.name = "HorsePanelRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", int(PORTRAIT_GAP))
	add_child(row)
	_portrait_view = HorsePortraitViewport.new()
	_portrait_view.custom_minimum_size = Vector2(PORTRAIT_MIN_WIDTH, PORTRAIT_MIN_HEIGHT)
	_portrait_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait_view)
	var panel := PanelContainer.new()
	panel.name = "HorseInfoPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "HorseInfoContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	_name_label = Label.new()
	_name_label.name = "HorseNameLabel"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_name_label)
	var close_button := Button.new()
	close_button.name = "HorsePanelCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, header)
	_identity_label = _make_info_label(content, "HorseIdentityLabel")
	_status_label = _make_info_label(content, "HorseStatusLabel")
	_slot_label = _make_info_label(content, "HorseSlotLabel")
	_assignment_label = _make_info_label(content, "HorseAssignmentLabel")
	content.add_child(HSeparator.new())
	var base_pair := _make_progress(content, "HorseBaseHP")
	_base_hp = base_pair[0]
	_base_hp_label = base_pair[1]
	var extra_pair := _make_progress(content, "HorseExtraHP")
	_extra_hp = extra_pair[0]
	_extra_hp_label = extra_pair[1]
	var satiety_pair := _make_progress(content, "HorseSatiety")
	_satiety = satiety_pair[0]
	_satiety_label = satiety_pair[1]
	var growth_pair := _make_progress(content, "HorseGrowth")
	_growth = growth_pair[0]
	_growth_label = growth_pair[1]
	var breeding_pair := _make_progress(content, "HorseBreedingProbability")
	_breeding = breeding_pair[0]
	_breeding_label = breeding_pair[1]


func _make_info_label(parent: VBoxContainer, control_name: String) -> Label:
	var label := Label.new()
	label.name = control_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _make_progress(parent: VBoxContainer, control_name: String) -> Array:
	var label := Label.new()
	label.name = "%sLabel" % control_name
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	var progress := ProgressBar.new()
	progress.name = control_name
	progress.custom_minimum_size.y = 16.0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("fill", _get_progress_fill_style(false))
	parent.add_child(progress)
	return [progress, label]


func show_horse(horse_id: String) -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("get_horse_snapshot"):
		return
	var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	if horse.is_empty():
		return
	_current_horse_id = horse_id
	_refresh(horse)
	visible = true
	_portrait_view.show_horse(horse_id)
	_fit_to_viewport()


func _refresh(horse: Dictionary) -> void:
	var horse_id := str(horse.get("horse_id", _current_horse_id))
	_name_label.text = str(horse.get("name", horse_id))
	_identity_label.text = "毛色：%s" % str(horse.get("coat_name", "未知"))
	var feeding: Dictionary = horse.get("feeding", {}) if horse.get("feeding", {}) is Dictionary else {}
	var status_parts: Array[String] = ["成年" if bool(horse.get("is_adult", false)) else "小马"]
	if bool(feeding.get("active", false)):
		status_parts.append("进食 %d%%" % int(round(float(feeding.get("progress", 0.0)) * 100.0)))
	elif bool(feeding.get("waiting_for_grain", false)):
		status_parts.append("等待粮食")
	if bool(horse.get("recovering", false)):
		status_parts.append("缓慢恢复")
	_status_label.text = "状态：%s" % "、".join(status_parts)
	_slot_label.text = "马槽：%s｜占用 %d / %d%s" % [
		_format_stable_slot_id(str(horse.get("stable_slot_id", ""))),
		int(horse.get("stable_occupied_slots", 0)),
		int(horse.get("stable_capacity", 0)),
		"（已满，繁育暂停）" if bool(horse.get("stable_full", false)) else ""
	]
	var assigned_npc_id := str(horse.get("assigned_npc_id", ""))
	_assignment_label.text = "分配：%s" % ("无" if assigned_npc_id.is_empty() else _format_npc_name(assigned_npc_id))
	_set_progress(_base_hp, _base_hp_label, float(horse.get("base_hp", 0.0)), float(horse.get("natural_max_hp", 1.0)), "基础 HP %.1f / %.1f", 1.0, BASE_HP_DANGER_RATIO)
	_set_progress(_extra_hp, _extra_hp_label, float(horse.get("extra_hp", 0.0)), float(horse.get("extra_hp_cap", 1.0)), "照料额外 HP %.1f / %.1f")
	_set_progress(_satiety, _satiety_label, float(horse.get("satiety", 0.0)), float(horse.get("max_satiety", 1.0)), "饱食 %.1f / %.1f", 1.0, SATIETY_DANGER_RATIO)
	var growth := clampf(float(horse.get("growth", 0.0)), 0.0, 1.0)
	_set_progress(_growth, _growth_label, growth, 1.0, "成长 %.0f%% / %.0f%%", 100.0)
	var probability := clampf(float(horse.get("breeding_probability", 0.0)), 0.0, 1.0)
	_set_progress(_breeding, _breeding_label, probability, 1.0, "繁育概率 %.2f%% / %.0f%%", 100.0)
	var cooldown := maxf(0.0, float(horse.get("breeding_cooldown_remaining_seconds", 0.0)))
	if cooldown > 0.0:
		_breeding_label.text += "｜冷却 %s" % _format_cooldown(cooldown)
	elif not bool(horse.get("is_adult", false)):
		_breeding_label.text += "｜未成年"


func _set_progress(
	progress: ProgressBar,
	label: Label,
	value: float,
	maximum: float,
	format_text: String,
	display_scale: float = 1.0,
	danger_below_ratio: float = -1.0
) -> void:
	progress.max_value = maxf(1.0, maximum)
	progress.value = clampf(value, 0.0, progress.max_value)
	label.text = format_text % [value * display_scale, maximum * display_scale]
	progress.tooltip_text = label.text
	var ratio := clampf(value / maxf(0.001, maximum), 0.0, 1.0)
	var danger := danger_below_ratio >= 0.0 and ratio < danger_below_ratio
	progress.add_theme_stylebox_override("fill", _get_progress_fill_style(danger))
	progress.set_meta("danger_state", danger)
	if danger:
		label.add_theme_color_override("font_color", DANGER_LABEL_COLOR)
	else:
		label.remove_theme_color_override("font_color")


func _get_progress_fill_style(danger: bool) -> StyleBoxFlat:
	if _normal_progress_fill_style == null:
		_normal_progress_fill_style = _make_progress_fill_style(NORMAL_PROGRESS_FILL_COLOR)
	if _danger_progress_fill_style == null:
		_danger_progress_fill_style = _make_progress_fill_style(DANGER_PROGRESS_FILL_COLOR)
	return _danger_progress_fill_style if danger else _normal_progress_fill_style


func _make_progress_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	return style


func _format_stable_slot_id(slot_id: String) -> String:
	var normalized := slot_id.strip_edges()
	if normalized.is_empty() or normalized == "已释放":
		return "无"
	var parts := normalized.split("_", false)
	if not parts.is_empty():
		var suffix := str(parts[parts.size() - 1])
		if suffix.is_valid_int():
			return "%d号" % int(suffix)
	return "未知"


func _format_npc_name(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc"):
		var npc: Dictionary = npc_system.get_npc(npc_id)
		if not npc.is_empty():
			return "%s（%s）" % [str(npc.get("name", npc_id)), npc_id]
	return npc_id


func _format_cooldown(seconds: float) -> String:
	var total_minutes := maxi(1, int(ceil(seconds / 60.0)))
	var days := total_minutes / 1440
	var hours := (total_minutes % 1440) / 60
	var minutes := total_minutes % 60
	if days > 0: return "%d天%d小时" % [days, hours]
	if hours > 0: return "%d小时%d分" % [hours, minutes]
	return "%d分" % minutes


func _fit_to_viewport() -> void:
	var viewport_size := _get_layout_viewport_size()
	var width := minf(PANEL_WIDTH, maxf(440.0, viewport_size.x - PANEL_SCREEN_MARGIN * 2.0))
	var height := minf(PANEL_HEIGHT, maxf(320.0, viewport_size.y - PANEL_SCREEN_MARGIN * 2.0))
	var portrait_width := clampf(
		viewport_size.x * PORTRAIT_VIEWPORT_WIDTH_RATIO,
		PORTRAIT_MIN_WIDTH,
		PORTRAIT_MAX_WIDTH
	)
	var portrait_height := minf(
		height,
		clampf(
			viewport_size.y * PORTRAIT_VIEWPORT_HEIGHT_RATIO,
			PORTRAIT_MIN_HEIGHT,
			PORTRAIT_MAX_HEIGHT
		)
	)
	if _portrait_view != null:
		_portrait_view.custom_minimum_size = Vector2(portrait_width, portrait_height)
	set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	offset_right = -PANEL_SCREEN_MARGIN
	offset_left = offset_right - width
	offset_top = PANEL_SCREEN_MARGIN
	offset_bottom = offset_top + height


func _get_layout_viewport_size() -> Vector2:
	if _layout_viewport_override.x > 0.0 and _layout_viewport_override.y > 0.0:
		return _layout_viewport_override
	return get_viewport_rect().size


func debug_set_layout_viewport_override(viewport_size: Vector2) -> void:
	_layout_viewport_override = viewport_size
	_fit_to_viewport()


func _on_horse_clicked(horse_id: String) -> void:
	show_horse(horse_id)


func _on_horse_state_changed(horse_id: String) -> void:
	if visible and horse_id == _current_horse_id:
		var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
		if horse_system != null:
			_refresh(horse_system.get_horse_snapshot(horse_id))


func _on_horse_assignment_changed(horse_id: String, _npc_id: String) -> void:
	_on_horse_state_changed(horse_id)


func _on_other_world_selection(_selection_id: String) -> void:
	_hide_panel()


func _on_world_selection_cleared() -> void:
	_hide_panel()


func _on_close_pressed() -> void:
	_hide_panel()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("world_selection_cleared"):
		event_bus.world_selection_cleared.emit()


func _hide_panel() -> void:
	visible = false
	_current_horse_id = ""
	if _portrait_view != null:
		_portrait_view.hide_preview()


func debug_get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"horse_id": _current_horse_id,
		"name": _name_label.text if _name_label != null else "",
		"identity": _identity_label.text if _identity_label != null else "",
		"status": _status_label.text if _status_label != null else "",
		"slot": _slot_label.text if _slot_label != null else "",
		"portrait": _portrait_view.debug_get_snapshot() if _portrait_view != null else {},
		"progress_rows": {
			"base_hp": _debug_progress_row(_base_hp, _base_hp_label),
			"extra_hp": _debug_progress_row(_extra_hp, _extra_hp_label),
			"satiety": _debug_progress_row(_satiety, _satiety_label),
			"growth": _debug_progress_row(_growth, _growth_label),
			"breeding": _debug_progress_row(_breeding, _breeding_label),
		},
		"rect": get_global_rect(),
	}


func _debug_progress_row(progress: ProgressBar, label: Label) -> Dictionary:
	if progress == null or label == null:
		return {}
	var fill := progress.get_theme_stylebox("fill") as StyleBoxFlat
	return {
		"label_text": label.text,
		"label_before_progress": label.get_index() + 1 == progress.get_index(),
		"danger": bool(progress.get_meta("danger_state", false)),
		"fill_color": fill.bg_color.to_html(true) if fill != null else "",
		"label_color": label.get_theme_color("font_color").to_html(true),
		"value": progress.value,
		"max_value": progress.max_value,
	}
