extends Control
## Read-only visual study. Values come from the production HUD, not new game state.

const PietyButton := preload("res://scripts/ui/PietyAbilityButton.gd")
const INK := Color("#e9e2cf")
const MUTED := Color("#aca996")
const GOLD := Color("#c7aa70")
const SURFACE := Color(0.105, 0.101, 0.088, 0.97)
const BORDER := Color("#49483c")
var source_hud: Control
var _panels: Array[PanelContainer] = []
var _resource_values: Dictionary = {}
var _day: Label
var _clock: Label
var _wave: Label
var _pause: Button
var _speed: Button
var _piety: Control
var _content: VBoxContainer
var _footer: HFlowContainer
var _last_available_width := -1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = source_hud.theme
	var panel := _panel("HUDCluster")
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	panel.add_child(_content)
	_build_clock()
	_build_resources()
	_footer = _flow(_content)
	_build_wave()
	_build_defense()
	_content.minimum_size_changed.connect(_fit_height)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_sync_values()

func _process(_delta: float) -> void:
	# Only refit when an existing detail panel changes the available left-hand space.
	var available := _available_width()
	if not is_equal_approx(available, _last_available_width):
		_layout()

func _flow(parent: Node) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	parent.add_child(flow)
	return flow

static func make_box(fill: Color, edge: Color, thickness: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(thickness)
	box.set_corner_radius_all(4)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 3
	return box

func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", make_box(SURFACE, BORDER))
	add_child(panel)
	_panels.append(panel)
	return panel

func _label(value: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _row(parent: Node, spacing: int = 8) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", spacing)
	parent.add_child(row)
	return row

func _button(value: String, width: float, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(width, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("#fff0cb"))
	var fill := Color("#50352a") if primary else Color("#262a24")
	var border := Color("#966a48") if primary else BORDER
	button.add_theme_stylebox_override("normal", make_box(fill, border))
	button.add_theme_stylebox_override("hover", make_box(fill.lightened(0.12), GOLD))
	button.add_theme_stylebox_override("pressed", make_box(fill.darkened(0.08), GOLD))
	button.tooltip_text = "独立美术样片：仅预览样式，不执行操作。"
	return button

func _separator(parent: Node) -> void:
	var spacer := VSeparator.new()
	spacer.custom_minimum_size.x = 8
	spacer.modulate = Color(0.7, 0.7, 0.6, 0.5)
	parent.add_child(spacer)

func _build_resources() -> void:
	var row := _flow(_content)
	for source_item in source_hud.get_node("ResourceStrip").get_children():
		if source_item is Button:
			continue
		var source_icon := source_item.get_node_or_null("Icon") as TextureRect
		if source_icon == null:
			continue
		var group := _row(row, 5)
		var icon := TextureRect.new()
		icon.texture = source_icon.texture
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.tooltip_text = source_icon.tooltip_text
		group.add_child(icon)
		var source_label := source_item.get_child(1) as Label
		var value := _label(source_label.text, 17)
		value.custom_minimum_size.x = 20
		group.add_child(value)
		_resource_values[str(source_item.name)] = {"source": source_label, "label": value}
	row.add_child(_button("装备", 52))
	row.add_child(_button("器械", 52))

func _build_clock() -> void:
	var row := _row(_content, 10)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	_day = _label("", 13, MUTED)
	_clock = _label("", 20)
	text.add_child(_day)
	text.add_child(_clock)
	_pause = _button("继续", 58)
	_speed = _button("×1", 44)
	row.add_child(_pause)
	row.add_child(_speed)

func _build_wave() -> void:
	_wave = _label("", 14, Color("#d0bb91"))
	_wave.custom_minimum_size.y = 48
	_footer.add_child(_wave)

func _build_defense() -> void:
	var row := _row(_footer, 8)
	row.add_child(_button("警报", 66, true))
	row.add_child(_button("解散", 58))
	_piety = PietyButton.new()
	row.add_child(_piety)
	# Reuse the actual ring / cross presentation without its authority connection.
	var source_piety = source_hud._piety_ability_button
	if source_piety != null:
		_piety.set_piety(source_piety._current_piety, source_piety._max_piety)

func _layout() -> void:
	_last_available_width = _available_width()
	_panels[0].position = Vector2(12, 8)
	_panels[0].size = Vector2(_last_available_width, 0)
	call_deferred("_fit_height")

func _available_width() -> float:
	var width := minf(564, get_viewport_rect().size.x - 24)
	for path in ["NPCPanel", "BuildingPanel"]:
		var detail := source_hud.get_parent().get_node_or_null(path) as Control
		if detail != null and detail.visible:
			width = minf(width, detail.global_position.x - 24)
	return maxf(280, width)

func _fit_height() -> void:
	if not _panels.is_empty():
		_panels[0].size.y = _panels[0].get_combined_minimum_size().y

func _sync_values() -> void:
	for entry in _resource_values.values():
		entry.label.text = entry.source.text
	_day.text = "%s · %s" % [source_hud.day_label.text, source_hud.phase_label.text]
	_clock.text = source_hud.time_label.text
	_pause.text = source_hud.pause_button.text
	_speed.text = source_hud.speed_button.text.replace("速度 x", "×")
	_wave.text = source_hud.wave_countdown_label.text

func debug_get_snapshot() -> Dictionary:
	var values := {}
	for key in _resource_values:
		values[key] = _resource_values[key].label.text
	var rects: Array[String] = []
	for panel in _panels:
		rects.append(str(panel.get_global_rect()))
	return {"resources": values, "day": _day.text, "clock": _clock.text,
		"wave": _wave.text, "rects": rects, "read_only": true}
