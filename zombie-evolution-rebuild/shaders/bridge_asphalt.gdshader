shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// World-space detail avoids stretching the aggregate on individual bridge slabs.
uniform vec4 asphalt_color : source_color = vec4(0.31, 0.33, 0.33, 1.0);
varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 surface = world_pos.xz;
	float aggregate = hash21(floor(surface * 38.0));
	float weather = smooth_noise(surface * 0.65);
	float worn = smooth_noise(surface * 2.7);
	float brightness = 0.83 + aggregate * 0.13 + weather * 0.12 + worn * 0.06;
	ALBEDO = asphalt_color.rgb * brightness;
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
