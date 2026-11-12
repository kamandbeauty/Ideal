shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D concrete_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 surface_position;
varying vec3 surface_normal;

void vertex() {
    surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    surface_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 weights = pow(abs(normalize(surface_normal)), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    vec3 color = texture(concrete_texture, surface_position.yz / 5.0).rgb * weights.x;
    color += texture(concrete_texture, surface_position.xz / 5.0).rgb * weights.y;
    color += texture(concrete_texture, surface_position.xy / 5.0).rgb * weights.z;
    ALBEDO = color * tint.rgb;
    ROUGHNESS = 0.88;
    SPECULAR = 0.16;
}
