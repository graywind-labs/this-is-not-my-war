extends ColorRect


const FOG_SHADER := preload("res://shaders/ui/menu_edge_fog.gdshader")
const LOOP_SECONDS := 12.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var fog_material := ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	fog_material.set_shader_parameter("cycle_seconds", LOOP_SECONDS)
	material = fog_material


func debug_get_snapshot() -> Dictionary:
	return {
		"full_rect": anchor_left == 0.0 and anchor_top == 0.0 and anchor_right == 1.0 and anchor_bottom == 1.0,
		"loop_seconds": LOOP_SECONDS,
		"screen_space": true,
		"uses_global_darkening": false,
		"edge_weights": {
			"left_lower": _region_weight(Vector2(0.01, 0.55)),
			"left_wall_end": _region_weight(Vector2(0.24, 0.42)),
			"left_ui_right": _region_weight(Vector2(0.31, 0.55)),
			"left_inner_limit": _region_weight(Vector2(0.50, 0.55)),
			"bottom_center": _region_weight(Vector2(0.55, 0.99)),
			"right_middle": _region_weight(Vector2(0.99, 0.50)),
			"top_right": _region_weight(Vector2(0.80, 0.01)),
			"center": _region_weight(Vector2(0.50, 0.50)),
			"title_zone": _region_weight(Vector2(0.12, 0.08)),
		},
	}


func _region_weight(uv: Vector2) -> float:
	var left_edge := (1.0 - smoothstep(0.16, 0.47, uv.x)) * smoothstep(0.10, 0.29, uv.y)
	var right_edge := smoothstep(0.64, 0.995, uv.x) * smoothstep(0.08, 0.24, uv.y)
	var bottom_edge := smoothstep(0.50, 0.995, uv.y) * (0.70 + 0.30 * smoothstep(0.03, 0.26, uv.x))
	var top_right := smoothstep(0.47, 0.68, uv.x) * (1.0 - smoothstep(0.015, 0.23, uv.y))
	return maxf(maxf(minf(left_edge * 1.18, 1.0), right_edge), maxf(bottom_edge, top_right))
