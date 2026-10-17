// Wallpaper: a pattern mask (red = motif, green = accent) coloured by a colourway, over a soft paper
// texture. UVs are in metres from the wall builder; repeat_m is one pattern repeat.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform sampler2D pattern : filter_linear_mipmap, repeat_enable;
uniform sampler2D paper_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 ground : source_color = vec3(0.93, 0.9, 0.82);
uniform vec3 motif : source_color = vec3(0.7, 0.3, 0.3);
uniform vec3 accent : source_color = vec3(0.45, 0.55, 0.42);
uniform float repeat_m = 0.53;

void fragment() {
	vec3 m = texture(pattern, UV / repeat_m).rgb;
	vec3 c = mix(ground, motif, m.r);
	c = mix(c, accent, m.g);
	ALBEDO = c * COLOR.rgb;
	NORMAL_MAP = texture(paper_normal, UV / 2.0).rgb;
	NORMAL_MAP_DEPTH = 0.3;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
