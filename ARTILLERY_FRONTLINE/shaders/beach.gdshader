shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D ground_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool detail_enabled = true;
uniform float normal_depth = 1.05;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = world_position.xz * 0.17;
	float macro = texture(ground_noise, world_position.xz * 0.006).r;
	vec3 base = texture(sand_albedo, uv).rgb;
	vec3 broad = texture(sand_albedo, uv * 0.21 + vec2(3.1, 7.7)).rgb;
	ALBEDO = mix(base, broad, 0.25) * mix(0.88, 1.08, macro) * COLOR.rgb;
	float wet = 1.0 - smoothstep(0.05, 1.35, world_position.y);
	ALBEDO *= mix(1.0, 0.52, wet);
	float foam_band = 1.0 - smoothstep(0.0, 0.35, abs(world_position.y - 0.08));
	float foam_noise = texture(ground_noise, world_position.xz * 0.5 + vec2(TIME * 0.02, 0.0)).r;
	ALBEDO = mix(ALBEDO, vec3(0.86, 0.88, 0.84), foam_band * foam_noise * 0.55);
	METALLIC = 0.0;
	SPECULAR = mix(0.2, 0.5, wet);
	if (detail_enabled) {
		vec3 orm = texture(sand_orm, uv).rgb;
		ROUGHNESS = clamp(mix(orm.g, 0.35, wet), 0.0, 1.0);
		NORMAL_MAP = texture(sand_normal, uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	} else {
		ROUGHNESS = mix(0.94, 0.42, wet);
	}
}
