// Terrain: four ground layers (dry grass, dirt, gravel, mud) from Texture2DArrays, blended by a splat
// map from the logical grid, with height-aware blending, anti-tiling and wetness. Compatibility-safe.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_array : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_array : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D splat : filter_linear, repeat_disable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(144.0, 96.0);
uniform vec4 layer_size = vec4(4.0, 3.0, 3.0, 3.0);
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform float rain_wetness : hint_range(0.0, 1.0) = 0.0;
uniform bool detail = true;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec4 layer(int i, vec2 p, float size, out vec3 nrm, out vec3 orm, float n) {
	vec2 uv = p / size;
	vec4 a = texture(albedo_array, vec3(uv, float(i)));
	nrm = texture(normal_array, vec3(uv, float(i))).rgb;
	orm = texture(orm_array, vec3(uv, float(i))).rgb;
	if (detail) {
		// A second, rotated and scaled sample hides the repeat.
		vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37 + 0.31;
		vec4 a2 = texture(albedo_array, vec3(uv2, float(i)));
		vec3 n2 = texture(normal_array, vec3(uv2, float(i))).rgb;
		float k = smoothstep(0.35, 0.65, n);
		a = mix(a, a2, k * 0.6);
		nrm = mix(nrm, n2, k * 0.6);
	}
	return a;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 mn = texture(macro_noise, p / 41.0).rgb;
	vec3 fine = texture(macro_noise, p / 6.3).rgb;
	// Wobble the splat lookup so ground edges are organic, not tile-shaped.
	vec2 suv = (p + (fine.rg - 0.5) * 1.6) / map_size;
	vec4 s = texture(splat, suv);
	vec4 w = vec4(max(0.0, 1.0 - s.r - s.g - s.b), s.r, s.g, s.b);
	vec3 n0; vec3 n1; vec3 n2; vec3 n3;
	vec3 o0; vec3 o1; vec3 o2; vec3 o3;
	vec4 a0 = layer(0, p, layer_size.x, n0, o0, mn.b);
	vec4 a1 = layer(1, p, layer_size.y, n1, o1, mn.b);
	vec4 a2 = layer(2, p, layer_size.z, n2, o2, mn.b);
	vec4 a3 = layer(3, p, layer_size.w, n3, o3, mn.b);
	// Height-aware blend using albedo brightness as a stand-in for height.
	vec4 h = vec4(dot(a0.rgb, vec3(0.33)), dot(a1.rgb, vec3(0.33)), dot(a2.rgb, vec3(0.33)), dot(a3.rgb, vec3(0.33)));
	vec4 bw = w * (0.4 + h);
	float mx = max(max(bw.x, bw.y), max(bw.z, bw.w));
	bw = max(bw - (mx - 0.25), vec4(0.0));
	bw /= max(dot(bw, vec4(1.0)), 0.0001);
	vec3 alb = a0.rgb * grass_tint * bw.x + a1.rgb * bw.y + a2.rgb * bw.z + a3.rgb * bw.w;
	// Large-scale colour variation: patches of paler and greener grass.
	alb *= mix(0.86, 1.12, mn.r);
	alb = mix(alb, alb * vec3(0.92, 1.03, 0.9), smoothstep(0.55, 0.8, mn.g) * bw.x);
	vec3 nrm = n0 * bw.x + n1 * bw.y + n2 * bw.z + n3 * bw.w;
	vec3 orm = o0 * bw.x + o1 * bw.y + o2 * bw.z + o3 * bw.w;
	float wet = clamp(max(s.a, rain_wetness * (0.6 + 0.4 * mn.b)), 0.0, 1.0);
	alb *= mix(1.0, 0.62, wet);
	ALBEDO = alb;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.2;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = mix(orm.g, 0.25, wet * 0.8);
	METALLIC = 0.0;
	SPECULAR = 0.35 + wet * 0.3;
}
