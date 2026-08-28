class_name EquipmentSilhouette
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(280.0, 250.0)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 104.0)
	var fill := Color(0.27, 0.31, 0.30, 0.94)
	var edge := Color(0.72, 0.58, 0.34, 0.92)
	# A compact two-head-tall mannequin keeps the equipment locations readable
	# without introducing labels that would need localization in the formal UI.
	draw_circle(center + Vector2(0.0, -45.0), 34.0, fill)
	draw_arc(center + Vector2(0.0, -45.0), 34.0, 0.0, TAU, 32, edge, 3.0, true)
	var torso := Rect2(center + Vector2(-43.0, -8.0), Vector2(86.0, 96.0))
	draw_style_box(_rounded_box(fill, edge, 18.0), torso)
	draw_line(center + Vector2(-37.0, 12.0), center + Vector2(-72.0, 83.0), fill, 24.0, true)
	draw_line(center + Vector2(37.0, 12.0), center + Vector2(72.0, 83.0), fill, 24.0, true)
	draw_line(center + Vector2(-20.0, 82.0), center + Vector2(-30.0, 142.0), fill, 28.0, true)
	draw_line(center + Vector2(20.0, 82.0), center + Vector2(30.0, 142.0), fill, 28.0, true)


func _rounded_box(fill: Color, edge: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(radius))
	return box
