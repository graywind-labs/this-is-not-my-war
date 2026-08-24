shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 rim_color : source_color = vec4(0.50, 0.85, 1.0, 0.85);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.55;
uniform float selection_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float selection_emphasis = mix(0.35, 1.0, selection_strength);
	float rim = pow(1.0 - facing, rim_power) * rim_strength * selection_emphasis;
	ALBEDO = rim_color.rgb;
	EMISSION = rim_color.rgb * rim;
	ALPHA = rim_color.a * rim;
}
