// Sky from two HDRI panoramas, blended for the time of day, with energy and tint. The lower half
// is replaced by an earthy ground colour so ambient light from below feels like grass and dirt.
shader_type sky;
render_mode use_debanding;

uniform sampler2D sky_a : filter_linear, repeat_enable;
uniform sampler2D sky_b : filter_linear, repeat_enable;
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform float energy = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float rotation = 0.0;
uniform vec3 ground_colour : source_color = vec3(0.24, 0.21, 0.15);
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;

void sky() {
	vec3 d = EYEDIR;
	float u = atan(d.x, -d.z) / (2.0 * PI) + 0.5 + rotation;
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
	vec2 uv = vec2(fract(u), v);
	vec3 a = texture(sky_a, uv).rgb;
	vec3 b = texture(sky_b, uv).rgb;
	vec3 c = mix(a, b, blend);
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(grey) * 0.85, desaturate);
	vec3 horizon = mix(texture(sky_a, vec2(uv.x, 0.495)).rgb, texture(sky_b, vec2(uv.x, 0.495)).rgb, blend);
	vec3 ground = mix(horizon * 0.5, ground_colour * (grey * 0.0 + dot(horizon, vec3(0.33))), 0.7);
	c = mix(c, ground, smoothstep(0.0, -0.08, d.y));
	COLOR = c * tint * energy;
}
