shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D water_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color = vec3(0.025, 0.085, 0.125);
uniform vec3 shallow_color = vec3(0.075, 0.24, 0.27);
uniform vec3 foam_color = vec3(0.80, 0.86, 0.86);
uniform float wave_height = 0.18;
uniform float wave_speed = 0.75;
varying vec3 world_position;
varying float wave_crest;
varying float view_distance;

float wave_field(vec2 p, float t) {
	float a = sin(p.x * 0.052 + t * 0.95) * 0.48;
	float b = sin(p.y * 0.083 - t * 0.72 + p.x * 0.021) * 0.34;
	float c = sin((p.x * 0.7 + p.y) * 0.137 + t * 1.31) * 0.18;
	return a + b + c;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave_field(w.xz, t);
	float e = 1.2;
	float hx = wave_field(w.xz + vec2(e, 0.0), t);
	float hz = wave_field(w.xz + vec2(0.0, e), t);
	float shore_damp = smoothstep(-90.0, -5.0, w.z);
	VERTEX.y += h * wave_height * mix(0.35, 1.0, shore_damp);
	NORMAL = normalize(vec3(-(hx - h) * wave_height / e, 1.0, -(hz - h) * wave_height / e));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_crest = h;
}

void fragment() {
	view_distance = distance(CAMERA_POSITION_WORLD, world_position);
	float shore = smoothstep(-85.0, 4.0, world_position.z);
	vec3 water = mix(deep_color, shallow_color, shore);
	float n1 = texture(water_noise, world_position.xz * 0.045 + vec2(TIME * 0.012, TIME * 0.008)).r;
	float n2 = texture(water_noise, world_position.xz * 0.13 - vec2(TIME * 0.017, TIME * 0.011)).r;
	float ripple = (n1 - 0.5) * 0.10 + (n2 - 0.5) * 0.06;
	float crest_foam = smoothstep(0.62, 0.95, wave_crest + (n1 - 0.5) * 0.5) * 0.22;
	float shore_noise = texture(water_noise, world_position.xz * 0.18 + vec2(TIME * 0.03, 0.0)).r;
	float shore_foam = (1.0 - smoothstep(0.0, 12.0, abs(world_position.z - 1.0))) * smoothstep(0.42, 0.72, shore_noise) * 0.55;
	float distance_fade = 1.0 - smoothstep(120.0, 650.0, view_distance);
	ALBEDO = water + foam_color * clamp((crest_foam + shore_foam + ripple) * mix(0.45, 1.0, distance_fade), 0.0, 0.65);
	float nx = (n1 - 0.5) * 0.22 + (n2 - 0.5) * 0.14;
	float nz = (texture(water_noise, world_position.zx * 0.09 + vec2(0.0, TIME * 0.014)).r - 0.5) * 0.20;
	NORMAL_MAP = normalize(vec3(0.5 + nx, 0.5 + nz, 1.0));
	NORMAL_MAP_DEPTH = 0.45 * distance_fade;
	ROUGHNESS = mix(0.16, 0.30, 1.0 - distance_fade);
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
