shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 rock_dark : source_color;
uniform vec4 rock_light : source_color;
uniform vec4 earth : source_color;
uniform vec4 moss : source_color;
uniform vec4 grass_dark : source_color;
uniform vec4 grass_light : source_color;
uniform vec4 soil_dark : source_color;
uniform vec4 soil_light : source_color;
uniform float strata_spacing = 3.8;
uniform float strata_strength = 0.13;
uniform float foot_height = 3.2;
uniform vec3 environment_origin = vec3(0.0);
varying vec3 terrain_position;
varying vec3 terrain_normal;

float hash2(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
        mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1)), f.x), f.y);
}
float facets(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    float a = hash2(i); float b = hash2(i + vec2(1, 0));
    float c = hash2(i + vec2(0, 1)); float d = hash2(i + vec2(1));
    return f.x + f.y < 1.0 ? a + (b-a)*f.x + (c-a)*f.y
        : d + (c-d)*(1.0-f.x) + (b-d)*(1.0-f.y);
}
void vertex() {
    terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz - environment_origin;
    terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 p = terrain_position;
    float broad = facets(p.xz * vec2(0.08, 0.026));
    float patches = facets(p.xz * vec2(0.28, 0.065) + vec2(18.2, 7.1));
    float strata = (p.y + p.z * 0.045 + (broad - 0.5) * 5.0) / strata_spacing;
    float band = fract(strata);
    float seam = 1.0 - smoothstep(0.02, 0.085 + fwidth(strata), band);
    seam *= smoothstep(0.25, 0.65, patches);
    float layer_tone = noise2(vec2(floor(strata) * 3.7, p.z * 0.012));
    vec3 stone = mix(rock_dark.rgb, rock_light.rgb, 0.10 + broad * 0.40 + layer_tone * 0.15 + patches * 0.26);
    stone *= 1.0 - seam * strata_strength;
    float ledge = smoothstep(0.80, 0.995, abs(terrain_normal.y));
    float foot = 1.0 - smoothstep(0.05, foot_height + (patches - 0.5) * 3.5, p.y);
    float weathering = smoothstep(0.50, 0.80, broad) * ledge * 0.24;
    vec3 soil = mix(earth.rgb, moss.rgb, smoothstep(0.22, 0.78, patches));
    ALBEDO = mix(stone, soil, clamp(foot + weathering, 0.0, 1.0));
    // Match the approved plain-ground palette and coordinates at the unchanged foot.
    float g_broad = noise2(p.xz * 0.095);
    float g_medium = noise2(p.xz * 0.43 + vec2(9.2, 17.6));
    float g_fine = noise2(p.xz * 2.7);
    float bare = smoothstep(0.56, 0.82, noise2(p.xz * 0.18 + vec2(30, -9))) * 0.18;
    vec3 grass = mix(grass_dark.rgb, grass_light.rgb, smoothstep(0.15, 0.85, g_broad * 0.65 + g_medium * 0.35));
    vec3 dirt = mix(soil_dark.rgb, soil_light.rgb, 0.35 + 0.45 * g_medium);
    vec3 ground = mix(grass, dirt, bare);
    ground *= 0.965 + g_fine * 0.07;
    ALBEDO = mix(ALBEDO, ground, 1.0 - smoothstep(0.03, 1.4 + patches, p.y));
    ROUGHNESS = 1.0;
}
