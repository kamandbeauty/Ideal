shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D ground_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 sand_light = vec3(0.69, 0.57, 0.39);
uniform vec3 sand_dark = vec3(0.43, 0.35, 0.25);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float macro = texture(ground_noise, world_position.xz * 0.006).r;
	float grit = texture(ground_noise, world_position.xz * 0.31).r;
	float ripple = sin(world_position.x * 1.7 + world_position.z * 0.45 + macro * 9.0) * 0.018;
	ALBEDO = mix(sand_dark, sand_light, smoothstep(0.2, 0.8, macro)) * (0.91 + grit * 0.16 + ripple) * COLOR.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
