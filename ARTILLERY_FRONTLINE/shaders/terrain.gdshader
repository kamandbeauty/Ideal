shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D ground_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_depth = 1.15;
uniform float macro_contrast = 0.22;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = world_position.xz * 0.16;
	float macro = texture(ground_noise, world_position.xz * 0.0045).r;
	float patch = texture(ground_noise, world_position.xz * 0.021 + vec2(17.3, 9.1)).r;
	vec3 base = texture(sand_albedo, uv).rgb;
	vec3 broad = texture(sand_albedo, uv * 0.23 + vec2(5.7, 2.2)).rgb;
	float variation = mix(1.0 - macro_contrast, 1.0 + macro_contrast, smoothstep(0.18, 0.82, macro));
	variation *= mix(0.94, 1.06, patch);
	ALBEDO = mix(base, broad, 0.28) * variation * COLOR.rgb;
	vec3 orm = texture(sand_orm, uv).rgb;
	ROUGHNESS = clamp(orm.g * 0.96 + 0.02, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.22;
	NORMAL_MAP = texture(sand_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}
