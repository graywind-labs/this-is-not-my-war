shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform float heat : hint_range(0.0, 1.0) = 1.0;
varying vec3 rock_position;
vec3 hash3(vec3 p) {
 return fract(sin(vec3(dot(p,vec3(127.1,311.7,74.7)),dot(p,vec3(269.5,183.3,246.1)),dot(p,vec3(113.5,271.9,124.6))))*43758.5453);
}
void vertex() { rock_position = VERTEX; }
void fragment() {
 vec3 p = rock_position * 0.76;
 vec3 cell = floor(p);
 vec3 f = fract(p);
 float first = 9.0;
 float second = 9.0;
 for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec3 o = vec3(float(x),float(y),float(z));
  vec3 q = o + 0.18 + hash3(cell+o)*0.64 - f;
  float d = dot(q,q);
  if(d<first) { second=first; first=d; } else { second=min(second,d); }
 }
 float edge = second-first;
 float width = 0.022 + 0.012*sin(p.x*2.1+p.z*3.7);
 float crack = 1.0-smoothstep(width*0.4,width*1.8,edge);
 float halo = (1.0-smoothstep(0.015,0.17,edge))*0.22;
 float grain = hash3(floor(rock_position*27.0)).x;
 vec3 stone = mix(vec3(0.035,0.043,0.046),vec3(0.135,0.12,0.10),COLOR.r);
 ALBEDO = stone*(0.92+grain*0.14) + vec3(0.16,0.035,0.006)*halo*heat;
 float hot = clamp(heat*(0.8+0.2*sin(p.y*2.0+p.z)),0.0,1.0);
 vec3 fire = mix(vec3(0.7,0.025,0.001),vec3(1.0,0.43,0.045),hot);
 EMISSION = fire*(crack*3.3+halo*0.6)*heat;
 ROUGHNESS = 0.96;
}
