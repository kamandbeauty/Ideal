shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Repeating world-space UVs keep each slab aligned without per-slab seams.
uniform sampler2D asphalt_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 asphalt_color : source_color = vec4(1.0);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = texture(asphalt_texture, world_pos.xz / 8.0).rgb * asphalt_color.rgb;
	// Wet asphalt: restrained reflections tuned for mobile rendering.
	ROUGHNESS = 0.34;
	SPECULAR = 0.58;
}
