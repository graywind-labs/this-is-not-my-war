shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform float opacity = 1.0;
void fragment() {
 ALBEDO = COLOR.rgb * 0.38;
 ROUGHNESS = 1.0;
 ALPHA = COLOR.a * opacity;
}
