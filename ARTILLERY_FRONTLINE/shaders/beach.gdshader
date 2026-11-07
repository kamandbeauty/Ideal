shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D ground_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool detail_enabled = true;
uniform float normal_depth = 0.16;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float view_distance = length(VERTEX);
	vec2 uv = world_position.xz * 0.11;
	float macro = texture(ground_noise, world_position.xz * 0.004).r;
	float patch = texture(ground_noise, world_position.xz * 0.021 + vec2(8.3, 2.1)).r;
	vec2 ruv = vec2(uv.x * 0.5 - uv.y * 0.866, uv.x * 0.866 + uv.y * 0.5) * 1.7 + vec2(4.8, 9.2);
	vec3 a = texture(sand_albedo, uv).rgb;
	vec3 b = texture(sand_albedo, ruv).rgb;
	vec3 base = mix(a, b, 0.45);
	float detail_fade = 1.0 - smoothstep(35.0, 160.0, view_distance);
	vec3 flat_color = vec3(0.55, 0.47, 0.35) * mix(0.86, 1.10, macro);
	ALBEDO = mix(flat_color, base * mix(0.84, 1.06, macro) * mix(0.92, 1.08, patch), detail_fade) * COLOR.rgb;
	float wet = 1.0 - smoothstep(0.0, 1.6, world_position.y);
	ALBEDO *= mix(1.0, 0.48, wet);
	float foam_noise = texture(ground_noise, world_position.xz * 0.35 + vec2(TIME * 0.015, 0.0)).r;
	float foam_band = 1.0 - smoothstep(0.0, 0.5, abs(world_position.y - 0.05));
	ALBEDO = mix(ALBEDO, vec3(0.78, 0.80, 0.76), foam_band * smoothstep(0.45, 0.75, foam_noise) * 0.5);
	METALLIC = 0.0;
	SPECULAR = mix(0.18, 0.45, wet);
	if (detail_enabled) {
		vec3 orm = texture(sand_orm, uv).rgb;
		ROUGHNESS = clamp(mix(orm.g, 0.32, wet), 0.0, 1.0);
		NORMAL_MAP = texture(sand_normal, uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth * detail_fade;
	} else {
		ROUGHNESS = mix(0.95, 0.4, wet);
	}
}
