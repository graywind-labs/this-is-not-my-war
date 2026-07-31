extends Control

signal ability_requested

const EMPTY_RING_COLOR := Color(0.25, 0.25, 0.28, 0.9)
const CHARGING_COLOR := Color(0.78, 0.68, 0.28, 1.0)
const READY_COLOR := Color(1.0, 0.86, 0.34, 1.0)
const BACKGROUND_COLOR := Color(0.08, 0.07, 0.09, 0.94)

var _current_piety := 0.0
var _max_piety := 100.0
var _ready_to_cast := false
var _targeting := false
var _glyph_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(48.0, 48.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build_glyph()
	_refresh_tooltip()
	queue_redraw()


func _process(_delta: float) -> void:
	if _ready_to_cast:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if _ready_to_cast:
			ability_requested.emit()
		accept_event()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	var progress := clampf(_current_piety / maxf(0.001, _max_piety), 0.0, 1.0)
	var pulse := 0.0
	if _ready_to_cast:
		pulse = (sin(float(Time.get_ticks_msec()) * 0.007) + 1.0) * 0.5
		draw_circle(center, radius + 4.0 + pulse * 2.0, Color(1.0, 0.74, 0.18, 0.16 + pulse * 0.12))
	draw_circle(center, radius, BACKGROUND_COLOR)
	draw_arc(center, radius - 2.0, -PI * 0.5, PI * 1.5, 48, EMPTY_RING_COLOR, 5.0, true)
	if progress > 0.0:
		draw_arc(
			center,
			radius - 2.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			maxi(3, ceili(48.0 * progress)),
			READY_COLOR if _ready_to_cast else CHARGING_COLOR,
			5.0,
			true
		)
	if _targeting:
		draw_arc(center, radius + 1.0, 0.0, TAU, 48, Color(1.0, 0.34, 0.18, 1.0), 2.0, true)


func set_piety(current_piety: float, max_piety: float) -> void:
	_current_piety = maxf(0.0, current_piety)
	_max_piety = maxf(1.0, max_piety)
	_ready_to_cast = _current_piety >= _max_piety - 0.001
	if not _ready_to_cast:
		_targeting = false
	if _glyph_label != null:
		_glyph_label.modulate = READY_COLOR if _ready_to_cast else Color(0.9, 0.86, 0.72, 1.0)
	_refresh_tooltip()
	queue_redraw()


func set_targeting(active: bool) -> void:
	_targeting = active and _ready_to_cast
	_refresh_tooltip()
	queue_redraw()


func is_ready_to_cast() -> bool:
	return _ready_to_cast


func _build_glyph() -> void:
	_glyph_label = Label.new()
	_glyph_label.name = "PietyGlyph"
	_glyph_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph_label.add_theme_font_size_override("font_size", 17)
	_glyph_label.text = "祷"
	_glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph_label)


func _refresh_tooltip() -> void:
	var value_text := "%d / %d" % [floori(_current_piety + 0.001), ceili(_max_piety)]
	if _targeting:
		tooltip_text = "虔诚 %s\n左键选择地面召唤陨石；右键或 Esc 取消。" % value_text
	elif _ready_to_cast:
		tooltip_text = "虔诚 %s\n已充满，点击选择陨石落点。" % value_text
	else:
		tooltip_text = "虔诚 %s\nNPC 在小教堂祈祷或主持弥撒时共同积累。" % value_text
