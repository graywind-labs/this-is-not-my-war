shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 0.0;
void fragment() {
 ALBEDO = tint.rgb;
 EMISSION = tint.rgb * glow;
 ALPHA = tint.a * COLOR.a;
}
