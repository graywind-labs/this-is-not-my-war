extends Control

signal harvest_completed(building_id: String, collected_resources: Dictionary)

const CRAFTING_SYSTEM_PATH := "/root/Main/Systems/CraftingSystem"
const SUPPORTED_BUILDING_IDS := ["blacksmith", "workshop"]
const BUILDING_NAMES := {"blacksmith": "铁匠铺", "workshop": "工械坊"}
const ITEM_ICON_SIZE := Vector2(68.0, 68.0)

var _building_id := ""
var _title_label: Label
var _empty_label: Label
var _grid: GridContainer
var _collect_button: Button
var _last_result: Dictionary = {}
var _rendered_icon_count := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	_build_ui()
	visible = false
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system != null and crafting_system.has_signal("pending_outputs_changed"):
		crafting_system.pending_outputs_changed.connect(_on_pending_outputs_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "DimBackground"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.018, 0.014, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "HarvestPanel"
	panel.custom_minimum_size = Vector2(570.0, 390.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.87, 0.68, 1.0))
	header.add_child(_title_label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "关闭（不收取）"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(38.0, 34.0)
	close_button.pressed.connect(close_dialog)
	header.add_child(close_button)

	var divider := HSeparator.new()
	content.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "PendingItemsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "PendingItemsGrid"
	_grid.columns = 6
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	_empty_label = Label.new()
	_empty_label.text = "当前没有待收取成品"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.61, 1.0))
	_grid.add_child(_empty_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	var leave_button := Button.new()
	leave_button.name = "LeaveButton"
	leave_button.text = "暂不收取"
	leave_button.custom_minimum_size = Vector2(116.0, 42.0)
	leave_button.pressed.connect(close_dialog)
	footer.add_child(leave_button)
	_collect_button = Button.new()
	_collect_button.name = "CollectButton"
	_collect_button.text = "收下"
	_collect_button.custom_minimum_size = Vector2(116.0, 42.0)
	_collect_button.pressed.connect(_collect_all)
	footer.add_child(_collect_button)


func open_for_building(building_id: String) -> void:
	if not SUPPORTED_BUILDING_IDS.has(building_id):
		return
	_building_id = building_id
	_last_result = {}
	_refresh()
	visible = true
	_collect_button.grab_focus()


func close_dialog() -> void:
	visible = false
	_building_id = ""


func _refresh() -> void:
	if _title_label == null or _grid == null:
		return
	_title_label.text = "%s待收取成品" % str(BUILDING_NAMES.get(_building_id, _building_id))
	for child in _grid.get_children():
		if child != _empty_label:
			child.queue_free()
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	var entries: Array = []
	if crafting_system != null and crafting_system.has_method("get_pending_output_entries"):
		entries = crafting_system.get_pending_output_entries(_building_id)
	_empty_label.visible = entries.is_empty()
	_collect_button.disabled = entries.is_empty()
	_rendered_icon_count = 0
	for raw_entry in entries:
		if raw_entry is Dictionary:
			for _unit_index in range(maxi(0, int(raw_entry.get("amount", 0)))):
				_grid.add_child(_make_item_icon(raw_entry))
				_rendered_icon_count += 1


func _make_item_icon(entry: Dictionary) -> Button:
	var icon_button := Button.new()
	icon_button.name = "%sPendingIcon" % str(entry.get("item_id", "item")).to_pascal_case()
	icon_button.custom_minimum_size = ITEM_ICON_SIZE
	icon_button.size = ITEM_ICON_SIZE
	icon_button.focus_mode = Control.FOCUS_NONE
	icon_button.flat = true
	icon_button.expand_icon = true
	icon_button.add_theme_constant_override("icon_max_width", 66)
	icon_button.tooltip_text = str(entry.get("name", entry.get("item_id", "成品")))
	icon_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var icon_path := str(entry.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_button.icon = load(icon_path)
	var transparent := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		icon_button.add_theme_stylebox_override(state, transparent)
	return icon_button


func _collect_all() -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("collect_pending_outputs"):
		return
	var collecting_building_id := _building_id
	_last_result = crafting_system.collect_pending_outputs(collecting_building_id)
	if not bool(_last_result.get("ok", false)):
		_refresh()
		return
	var collected: Dictionary = _last_result.get("collected_resources", {}) if _last_result.get("collected_resources", {}) is Dictionary else {}
	harvest_completed.emit(collecting_building_id, collected.duplicate(true))
	close_dialog()


func _on_pending_outputs_changed(building_id: String, _pending_snapshot: Dictionary) -> void:
	if visible and building_id == _building_id:
		_refresh()


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.085, 0.06, 0.98)
	style.border_color = Color(0.57, 0.42, 0.25, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func debug_open_for_building(building_id: String) -> void:
	open_for_building(building_id)


func debug_close_without_collecting() -> void:
	close_dialog()


func debug_collect_all() -> Dictionary:
	_collect_all()
	return _last_result.duplicate(true)


func debug_get_snapshot() -> Dictionary:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	var entries: Array = []
	var icon_nodes: Array[Dictionary] = []
	if crafting_system != null and crafting_system.has_method("get_pending_output_entries") and not _building_id.is_empty():
		entries = crafting_system.get_pending_output_entries(_building_id)
	if _grid != null:
		for child in _grid.get_children():
			if child is Button:
				var button := child as Button
				icon_nodes.append({
					"text": button.text,
					"tooltip": button.tooltip_text,
					"has_icon": button.icon != null,
					"flat": button.flat
				})
	return {
		"visible": visible,
		"building_id": _building_id,
		"title": _title_label.text if _title_label != null else "",
		"entries": entries.duplicate(true),
		"icon_nodes": icon_nodes,
		"rendered_icon_count": _rendered_icon_count,
		"unit_icon_projection": true,
		"shows_item_names": false,
		"shows_quantity_badges": false,
		"collect_disabled": _collect_button.disabled if _collect_button != null else true,
		"last_result": _last_result.duplicate(true)
	}
