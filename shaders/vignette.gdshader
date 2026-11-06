shader_type canvas_item;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.25);
	float vignette = smoothstep(0.23, 0.75, length(p));
	COLOR = vec4(0.025, 0.035, 0.025, vignette * 0.25);
}
