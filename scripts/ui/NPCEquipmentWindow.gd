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
	"helmet": Vector2(115.0, 0.0),
	"chest": Vector2(115.0, 82.0),
	"bracers": Vector2(12.0, 108.0),
	"main_weapon": Vector2(218.0, 126.0),
	"greaves": Vector2(115.0, 169.0),
	"mount": Vector2(115.0, 238.0),
}
const WINDOW_SIZE := Vector2(316.0, 332.0)
const PICKER_SIZE := Vector2(245.0, 330.0)
const LOCKED_MODULATE := Color(0.58, 0.58, 0.58, 0.72)

var _loadout: Dictionary = {}
var _options: Dictionary = {}
var _locked := false
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


func set_interaction_locked(locked: bool) -> void:
	_locked = locked
	_refresh_slot_buttons()
	if locked:
		close_picker()


func open_picker(slot: String) -> void:
	if not SLOT_ORDER.has(slot) or _picker_panel == null:
		return
	_picker_slot = slot
	_populate_picker(slot)
	_picker_panel.visible = true


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
		button.size = Vector2(70.0, 58.0)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_constant_override("icon_max_width", 52)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		mannequin.add_child(button)
		_slot_buttons[slot] = button


func _build_picker_panel() -> void:
	_picker_panel = _new_panel("EquipmentPicker")
	_picker_panel.visible = false
	_picker_panel.position = Vector2(-PICKER_SIZE.x - 8.0, 0.0)
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
	for raw_item in options:
		if not raw_item is Dictionary:
			continue
		var item := (raw_item as Dictionary).duplicate(true)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_picker_items.add_child(row)
		var icon_button := Button.new()
		icon_button.name = "%sIconButton" % str(item.get("id", item.get("horse_id", "item"))).to_pascal_case()
		icon_button.custom_minimum_size = Vector2(62.0, 62.0)
		icon_button.icon = _load_item_icon(item)
		icon_button.expand_icon = true
		icon_button.add_theme_constant_override("icon_max_width", 56)
		icon_button.focus_mode = Control.FOCUS_NONE
		icon_button.tooltip_text = str(item.get("name", item.get("horse_name", "装备")))
		icon_button.pressed.connect(_on_item_selected.bind(slot, item))
		row.add_child(icon_button)
		var name_button := Button.new()
		name_button.text = str(item.get("name", item.get("horse_name", item.get("id", "装备"))))
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.focus_mode = Control.FOCUS_NONE
		name_button.pressed.connect(_on_item_selected.bind(slot, item))
		row.add_child(name_button)


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
			"当前无法更换装备。"
			if _locked
			else "选择%s" % label
			if item.is_empty()
			else "%s：%s" % [label, str(item.get("name", item.get("horse_name", "装备")))]
		)
		button.text = "+" if item.is_empty() else ""
		button.icon = null if item.is_empty() else _load_item_icon(item)
		button.expand_icon = not item.is_empty()


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
