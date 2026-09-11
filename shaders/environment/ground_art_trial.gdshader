shader_type spatial;
// Existing plateau ribbons use a double-sided ground contract.
render_mode cull_disabled, specular_disabled;

uniform vec4 grass_dark : source_color;
uniform vec4 grass_light : source_color;
uniform vec4 soil_dark : source_color;
uniform vec4 soil_light : source_color;
uniform int road_count = 0;
uniform vec2 station_origin = vec2(0.0);
uniform vec4 road_segments[64];
uniform float road_widths[64];
uniform bool building_contact_enabled = false;
uniform sampler2D building_contact_map : filter_linear, repeat_disable;
uniform vec4 building_contact_bounds;
varying vec2 ground_position;

// Arithmetic hash avoids sine precision seams between adjacent cells on D3D12.
float hash2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x+p3.y)*p3.z);
}
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash2(i), hash2(i+vec2(1,0)), f.x), mix(hash2(i+vec2(0,1)), hash2(i+vec2(1,1)), f.x), f.y);
}
void vertex() { ground_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz - station_origin; }
void fragment() {
    vec2 p = ground_position;
    float broad = noise2(p*0.095);
    float medium = noise2(p*0.43 + vec2(9.2,17.6));
    float fine = noise2(p*2.7);
    float edge = (medium-0.5)*1.45 + (fine-0.5)*0.22;
    float distance_to_road = 1000.0;
    float rut = 0.0;
    for (int i=0; i<road_count; i++) {
        vec2 a=road_segments[i].xy; vec2 b=road_segments[i].zw;
        vec2 ab=b-a; float length_sq=max(dot(ab,ab),0.01);
        float t=clamp(dot(p-a,ab)/length_sq,0.0,1.0);
        float center_distance=length(p-a-ab*t);
        float d=center_distance-road_widths[i]*0.5;
        if (d < distance_to_road) {
            distance_to_road=d;
            float wavering = noise2(p*0.8)*0.13;
            float groove=1.0-smoothstep(0.06,0.20,abs(center_distance-min(road_widths[i]*0.23,0.92)+wavering));
            float breaks=smoothstep(0.36,0.68,noise2(p*vec2(0.6,1.1)));
            rut=groove*breaks*smoothstep(0.03,0.20,t)*(1.0-smoothstep(0.80,0.97,t));
        }
    }
    float road=1.0-smoothstep(-0.35,1.5,distance_to_road+edge);
    float bare=smoothstep(0.56,0.82,noise2(p*0.18+vec2(30,-9)))*0.18;
    vec3 grass=mix(grass_dark.rgb,grass_light.rgb,smoothstep(0.15,0.85,broad*0.65+medium*0.35));
    vec3 dirt=mix(soil_dark.rgb,soil_light.rgb,0.35+0.45*medium);
    dirt*=1.0-rut*0.16;
    ALBEDO=mix(grass,dirt,max(road,bare))*(0.965+fine*0.07);
    if (building_contact_enabled) {
        vec2 contact_uv=(p-building_contact_bounds.xy)/building_contact_bounds.zw;
        if (all(greaterThanEqual(contact_uv,vec2(0.0))) && all(lessThanEqual(contact_uv,vec2(1.0)))) {
            vec3 mask=texture(building_contact_map,contact_uv).rgb;
            float broken_edge=smoothstep(0.15+(medium-0.5)*0.70,0.93,mask.r);
            vec3 packed=dirt*mix(0.80,0.95,medium);
            ALBEDO=mix(ALBEDO,packed,broken_edge*0.88);
            ALBEDO*=1.0-mask.g*0.18;
            float grit=smoothstep(0.83,0.94,noise2(p*8.0))*broken_edge*(1.0-mask.b)*0.035;
            ALBEDO*=1.0+grit;
        }
    }
    ROUGHNESS=0.97;
}
