extends RefCounted

const DANGER_NORMAL := Color(0.34, 0.075, 0.055, 1.0)
const DANGER_HOVER := Color(0.52, 0.105, 0.07, 1.0)
const DANGER_PRESSED := Color(0.64, 0.12, 0.075, 1.0)
const DANGER_BORDER := Color(0.82, 0.28, 0.18, 1.0)
const FOCUS_BORDER := Color(1.0, 0.58, 0.08, 1.0)


static func apply_danger_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.84, 1.0))
	button.add_theme_stylebox_override("normal", _button_box(DANGER_NORMAL, DANGER_BORDER, 1))
	button.add_theme_stylebox_override("hover", _button_box(DANGER_HOVER, Color(1.0, 0.42, 0.28, 1.0), 2))
	button.add_theme_stylebox_override("pressed", _button_box(DANGER_PRESSED, Color(1.0, 0.55, 0.32, 1.0), 2))


static func apply_button_focus(button: Button) -> void:
	# Godot 默认 focus StyleBox 带不透明灰底，会盖住按钮的正常/危险底色。
	# 只保留一圈高亮边框，兼顾键盘导航与既有视觉主题。
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus.border_color = FOCUS_BORDER
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	button.add_theme_stylebox_override("focus", focus)


static func apply_tab_button(button: Button, active: bool) -> void:
	button.toggle_mode = true
	button.button_pressed = active
	button.custom_minimum_size = Vector2(150.0, 42.0)
	if active:
		button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72, 1.0))


static func make_overlay_color() -> Color:
	return Color(0.09, 0.095, 0.10, 0.67)


static func make_status_color(is_warning := false) -> Color:
	return Color(0.94, 0.47, 0.34, 1.0) if is_warning else Color(0.76, 0.72, 0.62, 1.0)


static func _button_box(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style
