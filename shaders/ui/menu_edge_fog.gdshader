shader_type canvas_item;
render_mode unshaded;

uniform vec4 fog_color : source_color = vec4(0.40, 0.43, 0.48, 0.93);
uniform float fog_strength : hint_range(0.0, 1.0) = 0.96;
uniform float cycle_seconds : hint_range(4.0, 30.0) = 12.0;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fog_noise(vec2 point) {
	float result = 0.0;
	float amplitude = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		result += value_noise(point) * amplitude;
		point = point * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.5;
	}
	return result;
}

void fragment() {
	vec2 uv = UV;
	float phase = TIME * 6.28318530718 / max(cycle_seconds, 0.001);
	vec2 loop_drift = vec2(cos(phase), sin(phase)) * 0.24;
	float broad_noise = fog_noise(uv * vec2(3.8, 3.0) + loop_drift);
	float detail_noise = fog_noise(uv * vec2(8.5, 6.2) - loop_drift * 1.7);
	float wisps = smoothstep(0.30, 0.83, broad_noise * 0.72 + detail_noise * 0.28);

	float left_edge = (1.0 - smoothstep(0.16, 0.47, uv.x)) * smoothstep(0.10, 0.29, uv.y);
	float right_edge = smoothstep(0.64, 0.995, uv.x) * smoothstep(0.08, 0.24, uv.y);
	float bottom_edge = smoothstep(0.50, 0.995, uv.y) * (0.70 + 0.30 * smoothstep(0.03, 0.26, uv.x));
	float top_right = smoothstep(0.47, 0.68, uv.x) * (1.0 - smoothstep(0.015, 0.23, uv.y));
	float region_mask = max(max(clamp(left_edge * 1.18, 0.0, 1.0), right_edge), max(bottom_edge, top_right));
	float edge_distance = 1.0 - clamp(min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)) * 2.0, 0.0, 1.0);
	float density = region_mask * mix(0.54, 1.0, wisps) * mix(0.88, 1.0, edge_distance);
	COLOR = vec4(fog_color.rgb, fog_color.a * density * fog_strength);
}
