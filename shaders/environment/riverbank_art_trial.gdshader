shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 grass_dark : source_color;
uniform vec4 grass_light : source_color;
uniform vec4 soil_dark : source_color;
uniform vec4 soil_light : source_color;
uniform vec4 wet_color : source_color;
uniform vec4 gravel_color : source_color;
uniform float water_height = -1.2;
uniform vec3 environment_origin = vec3(0.0);
varying vec3 bank_position;
float hash2(vec2 p) {
    vec3 q = fract(vec3(p.xyx)*0.1031);
    q += dot(q, q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float noise2(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);
}
void vertex() { bank_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz-environment_origin; }
void fragment() {
    vec2 p=bank_position.xz;
    float broad=noise2(p*0.095);
    float medium=noise2(p*0.43+vec2(9.2,17.6));
    float fine=noise2(p*2.7);
    float bare=smoothstep(0.56,0.82,noise2(p*0.18+vec2(30,-9)))*0.18;
    vec3 grass=mix(grass_dark.rgb,grass_light.rgb,smoothstep(0.15,0.85,broad*0.65+medium*0.35));
    vec3 dirt=mix(soil_dark.rgb,soil_light.rgb,0.35+0.45*medium);
    vec3 ground=mix(grass,dirt,bare)*(0.965+fine*0.07);
    float wet=1.0-smoothstep(water_height+0.10,water_height+0.50,bank_position.y+(medium-0.5)*0.18);
    vec3 stone=mix(gravel_color.rgb*0.85,gravel_color.rgb,medium);
    stone=mix(stone,wet_color.rgb,wet*0.88);
    float upper=smoothstep(-0.70,-0.09,bank_position.y+(medium-0.5)*0.44);
    ALBEDO=mix(stone,ground,upper);
    ROUGHNESS=mix(0.78,1.0,upper);
}
