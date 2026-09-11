shader_type spatial;
render_mode diffuse_burley;

uniform vec4 ground_dark : source_color;
uniform vec4 ground_earth : source_color;
uniform vec4 ground_worn : source_color;
uniform vec4 work_patches[8];
uniform vec4 contact_boxes[16];
uniform int contact_count = 0;
varying vec2 ground_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}
float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b-a;
	return length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0));
}
void vertex() { ground_position = VERTEX.xz; }
void fragment() {
	vec2 p = ground_position;
	float broad = noise(p*0.19);
	float grain = noise(p*3.8);
	float wear = 0.0;
	for (int i=0; i<8; i++) {
		vec4 patch = work_patches[i];
		float d = length((p-patch.xy)/patch.zw);
		wear = max(wear, 1.0-smoothstep(0.45,1.25,d+(broad-0.5)*0.4));
	}
	float path = segment_distance(p,vec2(8.4,-3.0),vec2(8.2,8.0));
	wear = max(wear, (1.0-smoothstep(0.65,2.1,path+(broad-0.5)*1.4))*0.62);
	float wall = min(segment_distance(p,vec2(-13,-20),vec2(27,-20)),
		min(segment_distance(p,vec2(-13,-20),vec2(-13,10)),segment_distance(p,vec2(27,-20),vec2(27,10))));
	float contact = (1.0-smoothstep(0.3,1.35,wall+(broad-0.5)*0.4));
	for (int i=0; i<contact_count; i++) {
		vec4 box = contact_boxes[i];
		vec2 q = abs(p-box.xy)-box.zw;
		float d = length(max(q,vec2(0)))+min(max(q.x,q.y),0.0);
		contact = max(contact,1.0-smoothstep(0.02,0.68,d+(broad-0.5)*0.15));
	}
	vec3 earth = mix(ground_dark.rgb,ground_earth.rgb,smoothstep(0.2,0.85,broad)*0.65);
	earth = mix(earth,ground_worn.rgb,wear*0.64);
	earth *= 1.0-contact*0.30;
	ALBEDO = earth * (0.94+grain*0.12);
	ROUGHNESS = 0.97;
	SPECULAR = 0.12;
}
