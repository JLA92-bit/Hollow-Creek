// The creek: dark, slow water with two scrolling ripple layers, soft banks (alpha falls off at the
// edges, from the UV.y across the ribbon) and sky reflections from the environment.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep_colour : source_color = vec3(0.10, 0.12, 0.08);
uniform vec3 shallow_colour : source_color = vec3(0.32, 0.30, 0.20);
uniform float flow_speed = 0.06;
uniform float rain = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 r1 = texture(ripple, p / 5.0 + vec2(TIME * flow_speed, TIME * 0.013)).rgb;
	vec3 r2 = texture(ripple, p / 2.3 - vec2(TIME * flow_speed * 0.7, -TIME * 0.021)).rgb;
	vec3 r3 = texture(ripple, p / 0.6 + vec2(TIME * 0.3, TIME * 0.25)).rgb;
	vec3 n = normalize(mix(r1, r2, 0.5) + (r3 - 0.5) * rain * 0.8);
	float across = abs(UV.y * 2.0 - 1.0);
	float edge = smoothstep(1.0, 0.55, across);
	ALBEDO = mix(shallow_colour, deep_colour, edge);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = mix(0.0, 0.92, smoothstep(1.0, 0.7, across));
}
