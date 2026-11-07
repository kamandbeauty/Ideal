shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec3 deep_color = vec3(0.035, 0.11, 0.16);
uniform vec3 shallow_color = vec3(0.10, 0.32, 0.36);
uniform vec3 foam_color = vec3(0.82, 0.88, 0.88);
uniform float wave_height = 0.22;
uniform float wave_speed = 0.85;
varying vec3 world_position;
varying float wave_crest;

float wave_field(vec2 p, float t) {
	float a = sin(p.x * 0.075 + t * 1.10) * 0.55;
	float b = sin(p.y * 0.105 - t * 0.80 + p.x * 0.03) * 0.35;
	float c = sin((p.x + p.y) * 0.19 + t * 1.65) * 0.16;
	return a + b + c;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave_field(w.xz, t);
	float e = 0.9;
	float hx = wave_field(w.xz + vec2(e, 0.0), t);
	float hz = wave_field(w.xz + vec2(0.0, e), t);
	VERTEX.y += h * wave_height;
	NORMAL = normalize(vec3(-(hx - h) * wave_height / e, 1.0, -(hz - h) * wave_height / e));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_crest = h;
}

void fragment() {
	float shore = smoothstep(-70.0, 6.0, world_position.z);
	vec3 water = mix(deep_color, shallow_color, shore);
	float crest_foam = smoothstep(0.55, 0.92, wave_crest) * 0.30;
	float shore_foam = (1.0 - smoothstep(0.0, 10.0, abs(world_position.z - 1.5))) * 0.45;
	float ripple = sin(world_position.x * 1.7 + TIME * 1.2) * sin(world_position.z * 1.9 - TIME) * 0.04;
	float streak = smoothstep(0.75, 0.95, sin(world_position.z * 0.55 - TIME * 1.4 + sin(world_position.x * 0.08) * 2.0)) * shore * 0.18;
	ALBEDO = water + foam_color * clamp(crest_foam + shore_foam + ripple + streak, 0.0, 0.7);
	float nx = sin(world_position.x * 0.9 + TIME * 1.3) * 0.06 + sin(world_position.z * 1.7 - TIME) * 0.04;
	float nz = cos(world_position.z * 0.8 + TIME * 1.1) * 0.06;
	NORMAL_MAP = vec3(0.5 + nx, 0.5 + nz, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.14;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
