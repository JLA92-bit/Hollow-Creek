// Leaf and grass cards: alpha-scissored, two-sided, wrapped diffuse with a little translucency,
// and a gentle wind sway that grows with height. Per-vertex colour varies each cluster.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.42;
uniform float wind_strength = 0.35;
uniform float sway_scale = 0.012;
uniform float translucency = 0.35;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float t = TIME;
	float sway = sin(t * 1.1 + wp.x * 0.13 + wp.z * 0.11) * 0.6 + sin(t * 2.3 + wp.x * 0.5 + wp.z * 0.7) * 0.25;
	VERTEX.x += sway * wind_strength * sway_scale * h;
	VERTEX.z += sway * wind_strength * sway_scale * 0.7 * h;
}

void fragment() {
	vec4 c = texture(leaf_tex, UV);
	ALBEDO = c.rgb * tint * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = c.rgb * translucency;
}
