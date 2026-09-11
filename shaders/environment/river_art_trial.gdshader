shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep_color : source_color;
uniform vec4 shallow_color : source_color;
uniform vec4 foam_color : source_color;
uniform float flow_time = 0.0;
uniform float flow_speed = 2.8;
uniform float ripple_strength = 0.16;
uniform int rock_count = 0;
uniform vec4 rock_footprints[32];
uniform float foam_strength = 0.78;
uniform vec3 environment_origin = vec3(0.0);
uniform sampler2D shoreline_lookup : filter_linear, repeat_disable;
uniform vec2 shoreline_z_range = vec2(-335.0, 385.0);
varying vec2 water_position;

float hash2(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash2(i), hash2(i+vec2(1,0)), f.x), mix(hash2(i+vec2(0,1)), hash2(i+vec2(1)), f.x), f.y);
}
void vertex() {
    NORMAL = vec3(0, 1, 0);
    water_position = (MODEL_MATRIX * vec4(VERTEX, 1)).xz - environment_origin.xz;
}
void fragment() {
    float shore_u = clamp((UV.y-shoreline_z_range.x)/(shoreline_z_range.y-shoreline_z_range.x),0.0,1.0);
    vec2 insets = texture(shoreline_lookup,vec2((shore_u*2047.0+0.5)/2048.0,0.5)).rg;
    float bank_distance = min(UV.x*UV2.x-insets.x,(1.0-UV.x)*UV2.x-insets.y);
    float flow = UV.y - flow_time * flow_speed;
    float wash = noise2(vec2(UV.x*5.0, flow*0.24));
    float shore = 1.0-smoothstep(0.05, 0.85 + wash*0.6, bank_distance);
    vec3 water = mix(deep_color.rgb, shallow_color.rgb, shore*0.86 + wash*0.09);
    // Narrow across the river, long downstream: the marks follow the channel.
    float phase = UV.x*72.0 + noise2(vec2(UV.x*8.0, flow*0.18))*2.4;
    float ripple = smoothstep(0.93, 0.995, sin(phase));
    ripple *= smoothstep(0.48, 0.72, noise2(vec2(UV.x*24.0, flow*0.65)));
    ripple *= smoothstep(0.2, 1.1, bank_distance);
    // Small patches of wash at the irregular waterline, never an unbroken border.
    float edge_line = (1.0-smoothstep(0.02, 0.14, bank_distance));
    edge_line *= smoothstep(0.62, 0.83, noise2(vec2(UV.x*4.0, flow*0.8)));
    float stone_foam = 0.0;
    for (int i=0; i<rock_count; i++) {
        vec4 rock=rock_footprints[i];
        vec2 d=(water_position-rock.xy)/rock.zw;
        float radius=length(d);
        float breakup=noise2(water_position*3.0-vec2(0,flow_time*flow_speed*1.2));
        float ring=smoothstep(0.84,0.98,radius)*(1.0-smoothstep(1.10,1.32+breakup*0.10,radius));
        // Stronger on the upstream face and sides; a broken tail trails downstream.
        float upstream=0.55+0.45*(1.0-smoothstep(-0.1,0.8,d.y));
        float wake=(1.0-smoothstep(0.12,0.36,abs(abs(d.x)-0.72)));
        wake*=smoothstep(0.6,1.0,d.y)*(1.0-smoothstep(1.2,3.2,d.y));
        stone_foam=max(stone_foam,(ring*upstream+wake*0.32)*smoothstep(0.16,0.55,breakup));
    }
    ALBEDO = mix(water, foam_color.rgb, clamp(ripple*ripple_strength + edge_line*0.27, 0.0, 0.4));
    ALBEDO = mix(ALBEDO, vec3(0.78,0.84,0.78), clamp(stone_foam*foam_strength,0.0,0.90));
    ROUGHNESS = 0.40 + wash*0.12;
    SPECULAR = 0.28;
}
