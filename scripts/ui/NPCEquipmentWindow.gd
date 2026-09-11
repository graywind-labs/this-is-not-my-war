class_name NPCEquipmentWindow
extends Control

signal slot_pressed(slot: String)
signal item_selected(slot: String, item: Dictionary)

const EquipmentSilhouetteScript = preload("res://scripts/ui/EquipmentSilhouette.gd")

const SLOT_ORDER: Array[String] = [
	"main_weapon",
	"helmet",
	"chest",
	"bracers",
	"greaves",
	"mount",
]
const SLOT_LABELS := {
	"main_weapon": "主武器",
	"helmet": "头盔",
	"chest": "胸甲",
	"bracers": "护臂",
	"greaves": "护腿",
	"mount": "坐骑",
}
const SLOT_POSITIONS := {
	"helmet": Vector2(116.0, 0.0),
	"chest": Vector2(116.0, 77.0),
	"bracers": Vector2(13.0, 103.0),
	"main_weapon": Vector2(219.0, 121.0),
	"greaves": Vector2(116.0, 164.0),
	"mount": Vector2(116.0, 233.0),
}
const WINDOW_SIZE := Vector2(316.0, 332.0)
const PICKER_SIZE := Vector2(245.0, 330.0)
const SLOT_BUTTON_SIZE := Vector2(68.0, 68.0)
const SLOT_ICON_MAX_WIDTH := 68
const PICKER_ITEM_BUTTON_SIZE := Vector2(68.0, 68.0)
const PICKER_ITEM_ICON_MAX_WIDTH := 66
const PICKER_GRID_COLUMNS := 3
const PICKER_ITEM_CONTENT_MARGIN := 1.0
const PICKER_ITEM_BORDER_WIDTH := 1
const PICKER_GAP := 8.0
const VIEWPORT_MARGIN := 8.0
const MIN_USABLE_VIEWPORT_SIZE := Vector2(320.0, 360.0)
const FALLBACK_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const LOCKED_MODULATE := Color(0.58, 0.58, 0.58, 0.72)

var _loadout: Dictionary = {}
var _options: Dictionary = {}
var _locked := false
var _lock_reason := ""
var _slot_buttons: Dictionary = {}
var _picker_panel: PanelContainer
var _picker_title: Label
var _picker_items: VBoxContainer
var _picker_slot := ""


func _ready() -> void:
	custom_minimum_size = WINDOW_SIZE
	size = WINDOW_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_equipment_panel()
	_build_picker_panel()
	_refresh_slot_buttons()


func set_loadout(loadout: Dictionary) -> void:
	_loadout = loadout.duplicate(true)
	_refresh_slot_buttons()


func set_options(options: Dictionary) -> void:
	_options = options.duplicate(true)
	if _picker_panel != null and _picker_panel.visible and not _picker_slot.is_empty():
		_populate_picker(_picker_slot)


func set_interaction_locked(locked: bool, reason: String = "") -> void:
	_locked = locked
	_lock_reason = reason
	_refresh_slot_buttons()
	if locked:
		close_picker()


func open_picker(slot: String) -> void:
	if not SLOT_ORDER.has(slot) or _picker_panel == null:
		return
	_picker_slot = slot
	_populate_picker(slot)
	_position_picker_in_viewport()
	_picker_panel.visible = true
	move_to_front()


func close_picker() -> void:
	_picker_slot = ""
	if _picker_panel != null:
		_picker_panel.visible = false


func is_picker_open() -> bool:
	return _picker_panel != null and _picker_panel.visible


func get_slot_button(slot: String) -> Button:
	return _slot_buttons.get(slot) as Button


func debug_get_snapshot() -> Dictionary:
	var slots := {}
	for slot in SLOT_ORDER:
		var button := _slot_buttons.get(slot) as Button
		var item: Dictionary = _loadout.get(slot, {}) if _loadout.get(slot, {}) is Dictionary else {}
		slots[slot] = {
			"item_id": str(item.get("horse_id", item.get("id", ""))) if slot == "mount" else str(item.get("id", "")),
			"empty": item.is_empty(),
			"clickable": button != null and not button.disabled,
			"dimmed": button != null and button.modulate == LOCKED_MODULATE,
		}
	return {
		"visible": visible,
		"locked": _locked,
		"picker_visible": is_picker_open(),
		"picker_slot": _picker_slot,
		"picker_global_rect": _picker_panel.get_global_rect() if _picker_panel != null else Rect2(),
		"picker_item_count": _get_picker_item_button_count(),
		"slots": slots,
		"global_rect": get_global_rect(),
	}


func _build_equipment_panel() -> void:
	var panel := _new_panel("EquipmentPanel")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var content := _panel_content(panel, 8)
	var mannequin := Control.new()
	mannequin.name = "EquipmentMannequin"
	mannequin.custom_minimum_size = Vector2(300.0, 300.0)
	content.add_child(mannequin)
	var silhouette := EquipmentSilhouetteScript.new() as Control
	silhouette.name = "TwoHeadSilhouette"
	silhouette.position = Vector2(10.0, 6.0)
	silhouette.size = Vector2(280.0, 250.0)
	mannequin.add_child(silhouette)
	for slot in SLOT_ORDER:
		var button := Button.new()
		button.name = "%sSlotButton" % slot.to_pascal_case()
		button.position = SLOT_POSITIONS[slot]
		button.size = SLOT_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_constant_override("icon_max_width", SLOT_ICON_MAX_WIDTH)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		mannequin.add_child(button)
		_apply_icon_button_style(button, 0.0, 0)
		_slot_buttons[slot] = button


func _build_picker_panel() -> void:
	_picker_panel = _new_panel("EquipmentPicker")
	_picker_panel.visible = false
	_picker_panel.position = Vector2(-PICKER_SIZE.x - PICKER_GAP, 0.0)
	_picker_panel.size = PICKER_SIZE
	add_child(_picker_panel)
	var content := _panel_content(_picker_panel, 8)
	var header := HBoxContainer.new()
	content.add_child(header)
	_picker_title = _new_label("选择装备", 18, Color("#f0cb7a"))
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_picker_title)
	var close := Button.new()
	close.name = "EquipmentPickerCloseButton"
	close.text = "×"
	close.tooltip_text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_picker)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_picker_items = VBoxContainer.new()
	_picker_items.name = "EquipmentPickerItems"
	_picker_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_items.add_theme_constant_override("separation", 6)
	scroll.add_child(_picker_items)


func _on_slot_pressed(slot: String) -> void:
	slot_pressed.emit(slot)


func _populate_picker(slot: String) -> void:
	for child in _picker_items.get_children():
		child.queue_free()
	_picker_title.text = "选择%s" % str(SLOT_LABELS.get(slot, slot))
	var options: Array = _options.get(slot, []) if _options.get(slot, []) is Array else []
	if options.is_empty():
		_picker_items.add_child(_new_label("暂无可用装备。", 13, Color("#c6aaa0")))
		return
	var grid := GridContainer.new()
	grid.name = "EquipmentPickerGrid"
	grid.columns = PICKER_GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_picker_items.add_child(grid)
	for raw_item in options:
		if not raw_item is Dictionary:
			continue
		var item := (raw_item as Dictionary).duplicate(true)
		var icon_button := Button.new()
		icon_button.name = "%sIconButton" % str(item.get("id", item.get("horse_id", "item"))).to_pascal_case()
		icon_button.custom_minimum_size = PICKER_ITEM_BUTTON_SIZE
		icon_button.icon = _load_item_icon(item)
		icon_button.expand_icon = true
		icon_button.add_theme_constant_override("icon_max_width", PICKER_ITEM_ICON_MAX_WIDTH)
		icon_button.focus_mode = Control.FOCUS_NONE
		icon_button.tooltip_text = str(item.get("name", item.get("horse_name", "装备")))
		icon_button.set_meta("equipment_picker_item", item.duplicate(true))
		icon_button.pressed.connect(_on_item_selected.bind(slot, item))
		grid.add_child(icon_button)
		_apply_icon_button_style(icon_button, PICKER_ITEM_CONTENT_MARGIN, PICKER_ITEM_BORDER_WIDTH)


func _on_item_selected(slot: String, item: Dictionary) -> void:
	item_selected.emit(slot, item.duplicate(true))


func _refresh_slot_buttons() -> void:
	for slot in SLOT_ORDER:
		var button := _slot_buttons.get(slot) as Button
		if button == null:
			continue
		var item: Dictionary = _loadout.get(slot, {}) if _loadout.get(slot, {}) is Dictionary else {}
		var label := str(SLOT_LABELS.get(slot, slot))
		button.disabled = false
		button.modulate = LOCKED_MODULATE if _locked else Color.WHITE
		button.tooltip_text = (
			_lock_reason if not _lock_reason.is_empty() else "当前无法更换装备。"
			if _locked
			else "选择%s" % label
			if item.is_empty()
			else "%s：%s" % [label, str(item.get("name", item.get("horse_name", "装备")))]
		)
		button.text = "+" if item.is_empty() else ""
		button.icon = null if item.is_empty() else _load_item_icon(item)
		button.expand_icon = not item.is_empty()


func _apply_icon_button_style(button: Button, content_margin: float, border_width: int) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var source_style := button.get_theme_stylebox(state)
		if source_style == null:
			continue
		var compact_style := source_style.duplicate() as StyleBox
		compact_style.content_margin_left = content_margin
		compact_style.content_margin_top = content_margin
		compact_style.content_margin_right = content_margin
		compact_style.content_margin_bottom = content_margin
		if compact_style is StyleBoxFlat:
			(compact_style as StyleBoxFlat).set_border_width_all(border_width)
		button.add_theme_stylebox_override(state, compact_style)


func _get_picker_item_button_count() -> int:
	if _picker_items == null:
		return 0
	var count := 0
	for child in _picker_items.find_children("*", "Button", true, false):
		if child.has_meta("equipment_picker_item"):
			count += 1
	return count


func _position_picker_in_viewport() -> void:
	if _picker_panel == null or not is_inside_tree():
		return
	var visible_rect := get_viewport().get_visible_rect()
	if visible_rect.size.x < MIN_USABLE_VIEWPORT_SIZE.x or visible_rect.size.y < MIN_USABLE_VIEWPORT_SIZE.y:
		visible_rect = Rect2(Vector2.ZERO, FALLBACK_VIEWPORT_SIZE)
	var window_rect := get_global_rect()
	var left_x := window_rect.position.x - PICKER_SIZE.x - PICKER_GAP
	var right_x := window_rect.end.x + PICKER_GAP
	var desired_x := left_x if left_x >= visible_rect.position.x + VIEWPORT_MARGIN else right_x
	var max_x := maxf(visible_rect.position.x + VIEWPORT_MARGIN, visible_rect.end.x - VIEWPORT_MARGIN - PICKER_SIZE.x)
	var max_y := maxf(visible_rect.position.y + VIEWPORT_MARGIN, visible_rect.end.y - VIEWPORT_MARGIN - PICKER_SIZE.y)
	_picker_panel.global_position = Vector2(
		clampf(desired_x, visible_rect.position.x + VIEWPORT_MARGIN, max_x),
		clampf(window_rect.position.y, visible_rect.position.y + VIEWPORT_MARGIN, max_y)
	)


func _load_item_icon(item: Dictionary) -> Texture2D:
	var icon_path := str(item.get("icon", "")).strip_edges()
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _new_panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel


func _panel_content(panel: PanelContainer, margin_size: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	return content


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.047, 0.047, 0.95)
	style.border_color = Color(0.55, 0.42, 0.24, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _new_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
