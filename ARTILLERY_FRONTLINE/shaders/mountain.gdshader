shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D ridge_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 base_color = vec3(0.16, 0.21, 0.24);
uniform vec3 peak_color = vec3(0.38, 0.44, 0.49);
uniform vec3 haze_color = vec3(0.55, 0.63, 0.69);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float view_distance = length(VERTEX);
	float altitude = clamp(world_position.y / 110.0, 0.0, 1.0);
	float slope = clamp(1.0 - world_normal.y, 0.0, 1.0);
	float n = texture(ridge_noise, world_position.xz * 0.004).r;
	float strata = texture(ridge_noise, vec2(world_position.x * 0.002, world_position.y * 0.02)).r;
	vec3 rock = mix(base_color, peak_color, altitude * 0.7 + n * 0.3);
	rock *= mix(0.82, 1.12, strata);
	rock = mix(rock, rock * 0.72, slope * 0.45);
	float haze = smoothstep(350.0, 1200.0, view_distance) * 0.72;
	ALBEDO = mix(rock, haze_color, haze);
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.08;
}
