shader_type canvas_item;
render_mode unshaded;

uniform sampler2D density_texture : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.32,0.37,0.44,0.93);
uniform float cycle_seconds = 12.0;

void fragment() {
	vec2 uv = UV;
	float phase = TIME*6.28318530718/cycle_seconds;
	vec2 drift = vec2(cos(phase),sin(phase))*0.025;
	// A filtered CPU noise texture avoids D3D12 arithmetic-hash block boundaries.
	float broad = texture(density_texture,uv*vec2(0.72,0.54)+vec2(0.12,0.22)+drift).r;
	float detail = texture(density_texture,uv.yx*0.83+vec2(0.07)-drift).r;
	float wisps = smoothstep(0.12,0.90,broad*0.80+detail*0.20);
	float left_edge = (1.0-smoothstep(0.16,0.47,uv.x))*smoothstep(0.10,0.29,uv.y);
	float right_edge = smoothstep(0.64,0.995,uv.x)*smoothstep(0.08,0.24,uv.y);
	float bottom_edge = smoothstep(0.50,0.995,uv.y)*(0.70+0.30*smoothstep(0.03,0.26,uv.x));
	float top_right = smoothstep(0.47,0.68,uv.x)*(1.0-smoothstep(0.015,0.23,uv.y));
	float mask = max(max(clamp(left_edge*1.18,0.0,1.0),right_edge),max(bottom_edge,top_right));
	float minimum_density = mix(0.34,0.60,left_edge);
	COLOR = vec4(fog_color.rgb,fog_color.a*mask*mix(minimum_density,1.0,wisps));
}
