shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float grain = hash21(floor(p * 2.4));
	float broad = sin(p.x * 0.12 + sin(p.y * 0.08) * 2.0) * 0.5 + 0.5;
	vec3 sand = mix(vec3(0.25, 0.18, 0.10), vec3(0.40, 0.30, 0.18), broad * 0.38 + grain * 0.17);
	ALBEDO = sand;
	ROUGHNESS = 1.0;
}
