extends Control

var _elapsed := 0.0
var _cover_texture: Texture2D
var _cover_focus := Vector2(0.68, 0.50)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _cover_texture != null:
		_draw_cover_texture()
		return
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.105, 0.12, 0.13, 1.0))
	var horizon := size.y * 0.58
	for band in range(8):
		var t := float(band) / 7.0
		var top := size.y * t / 1.55
		var height := size.y / 7.0
		draw_rect(Rect2(0.0, top, size.x, height + 2.0), Color(0.16 - t * 0.07, 0.17 - t * 0.08, 0.16 - t * 0.08, 1.0))

	var far_shift := sin(_elapsed * 0.11) * 9.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30.0 + far_shift, horizon), Vector2(size.x * 0.15 + far_shift, size.y * 0.33),
		Vector2(size.x * 0.34 + far_shift, horizon), Vector2(size.x * 0.55 + far_shift, size.y * 0.38),
		Vector2(size.x + 30.0 + far_shift, horizon), Vector2(size.x + 30.0, size.y), Vector2(-30.0, size.y)
	]), Color(0.105, 0.105, 0.095, 1.0))
	draw_rect(Rect2(0.0, horizon, size.x, size.y - horizon), Color(0.055, 0.05, 0.043, 1.0))

	var fort := Color(0.075, 0.06, 0.047, 1.0)
	var wall_y := size.y * 0.61
	draw_rect(Rect2(size.x * 0.18, wall_y, size.x * 0.68, size.y * 0.18), fort)
	for x_ratio in [0.22, 0.43, 0.65, 0.80]:
		var tower_x := size.x * float(x_ratio)
		draw_rect(Rect2(tower_x, wall_y - size.y * 0.15, size.x * 0.095, size.y * 0.33), fort)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tower_x - size.x * 0.012, wall_y - size.y * 0.15),
			Vector2(tower_x + size.x * 0.0475, wall_y - size.y * 0.25),
			Vector2(tower_x + size.x * 0.107, wall_y - size.y * 0.15)
		]), fort)

	var gate_x := size.x * 0.50
	draw_rect(Rect2(gate_x, wall_y + size.y * 0.06, size.x * 0.11, size.y * 0.15), Color(0.025, 0.022, 0.019, 1.0))
	var glow := 0.62 + sin(_elapsed * 1.4) * 0.12
	draw_circle(Vector2(gate_x + size.x * 0.055, wall_y + size.y * 0.11), 8.0, Color(0.95, 0.38, 0.08, glow))

	for index in range(18):
		var seed := float(index * 71 % 97) / 97.0
		var rise := fmod(_elapsed * (9.0 + seed * 13.0) + seed * size.y, size.y * 0.58)
		var x := size.x * (0.36 + fmod(seed * 3.7, 0.55)) + sin(_elapsed * 0.8 + index) * 12.0
		var y := size.y * 0.88 - rise
		var alpha := clampf(0.72 - rise / maxf(1.0, size.y), 0.12, 0.65)
		draw_circle(Vector2(x, y), 1.0 + seed * 1.8, Color(1.0, 0.39, 0.09, alpha))

	var fog_y := size.y * 0.72 + sin(_elapsed * 0.19) * 7.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20.0, fog_y), Vector2(size.x * 0.25, fog_y - 18.0),
		Vector2(size.x * 0.56, fog_y + 9.0), Vector2(size.x + 20.0, fog_y - 10.0),
		Vector2(size.x + 20.0, fog_y + 42.0), Vector2(-20.0, fog_y + 48.0)
	]), Color(0.46, 0.45, 0.39, 0.075))

	draw_rect(bounds, Color(0.32, 0.18, 0.07, 0.035 + sin(_elapsed * 0.35) * 0.012))


func set_cover_texture(texture: Texture2D, focus: Vector2 = Vector2(0.68, 0.50)) -> void:
	_cover_texture = texture
	_cover_focus = Vector2(clampf(focus.x, 0.0, 1.0), clampf(focus.y, 0.0, 1.0))
	queue_redraw()


func clear_cover_texture() -> void:
	_cover_texture = null
	queue_redraw()


func debug_get_cover_snapshot() -> Dictionary:
	var source_size := _cover_texture.get_size() if _cover_texture != null else Vector2.ZERO
	return {
		"mode": "texture_cover" if _cover_texture != null else "procedural_fallback",
		"viewport_size": size,
		"source_size": source_size,
		"source_rect": _calculate_cover_source_rect(source_size, size) if _cover_texture != null else Rect2(),
		"focus": _cover_focus,
		"fills_viewport": size.x > 0.0 and size.y > 0.0,
	}


func _draw_cover_texture() -> void:
	var source_size := _cover_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	draw_texture_rect_region(_cover_texture, Rect2(Vector2.ZERO, size), _calculate_cover_source_rect(source_size, size))


func _calculate_cover_source_rect(source_size: Vector2, destination_size: Vector2) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or destination_size.x <= 0.0 or destination_size.y <= 0.0:
		return Rect2()
	var source_aspect := source_size.x / source_size.y
	var destination_aspect := destination_size.x / destination_size.y
	var crop_size := source_size
	if source_aspect > destination_aspect:
		crop_size.x = source_size.y * destination_aspect
	else:
		crop_size.y = source_size.x / destination_aspect
	var crop_origin := Vector2(
		clampf(_cover_focus.x * source_size.x - _cover_focus.x * crop_size.x, 0.0, source_size.x - crop_size.x),
		clampf(_cover_focus.y * source_size.y - _cover_focus.y * crop_size.y, 0.0, source_size.y - crop_size.y)
	)
	return Rect2(crop_origin, crop_size)
