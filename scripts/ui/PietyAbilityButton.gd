extends Control

signal ability_requested

const EMPTY_RING_COLOR := Color(0.25, 0.25, 0.28, 0.9)
const CHARGING_COLOR := Color(0.78, 0.68, 0.28, 1.0)
const READY_COLOR := Color(1.0, 0.86, 0.34, 1.0)
const BACKGROUND_COLOR := Color(0.08, 0.07, 0.09, 0.94)
const CROSS_OUTLINE_COLOR := Color(0.11, 0.08, 0.03, 0.92)
const ICON_KIND := "latin_cross"

var _current_piety := 0.0
var _max_piety := 100.0
var _ready_to_cast := false
var _targeting := false


func _ready() -> void:
	custom_minimum_size = Vector2(48.0, 48.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
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
	_draw_cross_icon(center, READY_COLOR if _ready_to_cast else Color(0.9, 0.86, 0.72, 1.0))


func set_piety(current_piety: float, max_piety: float) -> void:
	_current_piety = maxf(0.0, current_piety)
	_max_piety = maxf(1.0, max_piety)
	_ready_to_cast = _current_piety >= _max_piety - 0.001
	if not _ready_to_cast:
		_targeting = false
	_refresh_tooltip()
	queue_redraw()


func set_targeting(active: bool) -> void:
	_targeting = active and _ready_to_cast
	_refresh_tooltip()
	queue_redraw()


func is_ready_to_cast() -> bool:
	return _ready_to_cast


func get_icon_kind() -> String:
	return ICON_KIND


func _draw_cross_icon(center: Vector2, color: Color) -> void:
	# Draw the symbol geometrically so the religious cross never depends on a font glyph.
	var vertical_start := center + Vector2(0.0, -10.0)
	var vertical_end := center + Vector2(0.0, 10.0)
	var horizontal_y := center.y - 3.0
	var horizontal_start := Vector2(center.x - 7.0, horizontal_y)
	var horizontal_end := Vector2(center.x + 7.0, horizontal_y)
	draw_line(vertical_start, vertical_end, CROSS_OUTLINE_COLOR, 6.0, true)
	draw_line(horizontal_start, horizontal_end, CROSS_OUTLINE_COLOR, 6.0, true)
	draw_line(vertical_start, vertical_end, color, 3.5, true)
	draw_line(horizontal_start, horizontal_end, color, 3.5, true)


func _refresh_tooltip() -> void:
	var value_text := "%d / %d" % [floori(_current_piety + 0.001), ceili(_max_piety)]
	if _targeting:
		tooltip_text = "虔诚 %s\n左键选择地面召唤陨石；右键或 Esc 取消。" % value_text
	elif _ready_to_cast:
		tooltip_text = "虔诚 %s\n已充满，点击选择陨石落点。" % value_text
	else:
		tooltip_text = "虔诚 %s" % value_text
