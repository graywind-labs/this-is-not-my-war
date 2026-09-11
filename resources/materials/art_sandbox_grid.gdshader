shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.314, 0.329, 0.278, 1.0);
uniform vec4 grid_color : source_color = vec4(0.78, 0.70, 0.50, 1.0);
uniform float grid_size = 2.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coordinate = world_position.xz / max(grid_size, 0.001);
	vec2 derivative = max(fwidth(coordinate), vec2(0.0001));
	vec2 grid = abs(fract(coordinate - 0.5) - 0.5) / derivative;
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	ALBEDO = mix(base_color.rgb, grid_color.rgb, line * 0.55);
	ROUGHNESS = 0.92;
}
