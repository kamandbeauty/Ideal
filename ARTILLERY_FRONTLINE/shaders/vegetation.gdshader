shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_alpha_prepass;
uniform sampler2D card : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wind_strength = 0.10;
varying float tint;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.31 + world.z * 0.23;
	float sway = sin(TIME * 1.45 + phase) + sin(TIME * 2.3 + phase * 1.7) * 0.35;
	VERTEX.x += sway * wind_strength * UV.y * UV.y;
	VERTEX.z += cos(TIME * 1.1 + phase) * wind_strength * 0.45 * UV.y * UV.y;
	tint = 0.9 + 0.1 * sin(phase * 2.1);
}
void fragment() {
	vec4 tex = texture(card, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ALBEDO = tex.rgb * COLOR.rgb * tint;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}
