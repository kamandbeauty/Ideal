shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float opacity = 0.78;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float noise = fract(sin(dot(floor(UV * 42.0), vec2(12.9898, 78.233))) * 43758.5453);
	float edge = 1.0 - smoothstep(0.48 + noise * 0.15, 0.98, d);
	float rim = smoothstep(0.48, 0.7, d) * (1.0 - smoothstep(0.7, 0.95, d));
	ALBEDO = mix(vec3(0.075, 0.062, 0.047), vec3(0.34, 0.27, 0.18), rim);
	ALPHA = edge * opacity;
}
