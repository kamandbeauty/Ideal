shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, shadows_disabled;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D edge_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(1.25, 1.18, 1.02);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = vec2(UV.x * 2.4, UV.y);
	vec3 base = texture(gravel_albedo, uv).rgb * tint;
	float track_a = 1.0 - smoothstep(0.035, 0.11, abs(UV.x - 0.27));
	float track_b = 1.0 - smoothstep(0.035, 0.11, abs(UV.x - 0.73));
	float tracks = clamp(track_a + track_b, 0.0, 1.0);
	float center_crown = 1.0 - smoothstep(0.0, 0.22, abs(UV.x - 0.5));
	base *= 1.0 - tracks * 0.20 + center_crown * 0.05;
	float rag = texture(edge_noise, world_position.xz * 0.35).r;
	float edge = smoothstep(0.0, 0.075, UV.x) * smoothstep(1.0, 0.925, UV.x);
	ALPHA = clamp(edge + (rag - 0.5) * 0.22, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	ALBEDO = base;
	vec3 orm = texture(gravel_orm, uv).rgb;
	ROUGHNESS = clamp(orm.g - tracks * 0.08, 0.0, 1.0);
	SPECULAR = 0.18;
	NORMAL_MAP = texture(gravel_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 1.25;
}
