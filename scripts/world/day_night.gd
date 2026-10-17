class_name DayNight
extends Node
## Drives the sun or moon, the HDRI sky blend, ambient light, fog, exposure, rain and lamps from the
## time of day, using the keyframes in data/time_of_day.json.

const PATH := "res://data/time_of_day.json"

signal lamps_changed(level: float)

var env: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var data: Dictionary
var keys: Array = []
var skies: Dictionary = {}
var rain: float = 0.0  ## 0 to 1, eased by the weather
var lamp_level: float = 0.0
var _last_sky_minute: float = -999.0
var _state: Dictionary = {}


func setup(p_env: Environment, p_sun: DirectionalLight3D) -> void:
	env = p_env
	sun = p_sun
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary
	keys = data["keys"]
	for k: String in data["skies"]:
		skies[k] = load(str(data["skies"][k])) as Texture2D
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky_blend.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.05
	env.fog_aerial_perspective = 0.1
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.12


## Applies the time of day. Minute is fractional (0 to 1440).
func apply(minute: float) -> void:
	var s := sample(minute)
	_state = s
	var is_moon: bool = s["moon"]
	var el := deg_to_rad(float(s["sun_el"]))
	var az := deg_to_rad(float(s["sun_az"]))
	if is_moon:
		el = deg_to_rad(float(data["moon"]["elevation"]))
		az = deg_to_rad(float(data["moon"]["azimuth"]))
	# Never let the light come from below the horizon; it fades out instead.
	el = maxf(el, deg_to_rad(3.0))
	var to_sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	var rain_sun := lerpf(1.0, float(data["rain"]["sun_mult"]), rain)
	sun.light_color = s["sun"]
	sun.light_energy = float(s["sun_e"]) * rain_sun
	sun.shadow_enabled = sun.light_energy > 0.02
	env.ambient_light_energy = float(s["amb_e"])
	env.ambient_light_sky_contribution = 1.0
	env.fog_light_color = (s["fog"] as Color).lerp(Color(str(data["rain"]["fog"])) * (s["fog"] as Color).get_luminance() * 2.2, rain)
	env.fog_density = lerpf(0.0012, float(data["rain"]["fog_density"]), rain)
	env.tonemap_exposure = float(s["exposure"])
	# Updating the sky re-bakes its radiance, so do it every few game minutes, not every frame.
	if absf(minute - _last_sky_minute) >= 4.0 or minute < _last_sky_minute:
		_last_sky_minute = minute
		sky_material.set_shader_parameter("sky_a", skies[s["sky_a"]])
		sky_material.set_shader_parameter("sky_b", skies[s["sky_b"]])
		sky_material.set_shader_parameter("blend", float(s["blend"]))
		sky_material.set_shader_parameter("energy", float(s["sky_e"]) * lerpf(1.0, float(data["rain"]["sky_mult"]), rain))
		sky_material.set_shader_parameter("desaturate", float(data["rain"]["sky_desaturate"]) * rain)
		sky_material.set_shader_parameter("rotation", 0.25)
		sky_material.set_shader_parameter("tint", s["tint"])
	var lamps := float(s["lamps"])
	if not is_equal_approx(lamps, lamp_level):
		lamp_level = lamps
		lamps_changed.emit(lamp_level)


func force_sky_update() -> void:
	_last_sky_minute = -999.0


func daylight() -> float:
	if _state.is_empty() or _state["moon"]:
		return 0.0
	return clampf(float(_state["sun_e"]) / 2.6, 0.0, 1.0)


## Interpolates the keyframes. Colours lerp, skies switch at the earlier key.
func sample(minute: float) -> Dictionary:
	minute = fposmod(minute, 1440.0)
	var i := 0
	while i < keys.size() - 2 and float(keys[i + 1]["m"]) <= minute:
		i += 1
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[i + 1]
	var t := clampf((minute - float(a["m"])) / maxf(float(b["m"]) - float(a["m"]), 1.0), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var out := {}
	for k: String in ["sun_el", "sun_e", "sky_e", "amb_e", "exposure", "lamps"]:
		out[k] = lerpf(float(a[k]), float(b[k]), t)
	var az_a := float(a["sun_az"])
	var az_b := float(b["sun_az"])
	out["sun_az"] = az_a + wrapf(az_b - az_a, -180.0, 180.0) * t
	for k2: String in ["sun", "fog", "tint"]:
		out[k2] = Color(str(a[k2])).lerp(Color(str(b[k2])), t)
	out["moon"] = a["moon"] if t < 0.5 else b["moon"]
	# Sky: blend within key a's pair, moving towards key b's blend.
	out["sky_a"] = a["sky_a"]
	out["sky_b"] = a["sky_b"]
	if a["sky_a"] == b["sky_a"] and a["sky_b"] == b["sky_b"]:
		out["blend"] = lerpf(float(a["blend"]), float(b["blend"]), t)
	elif a["sky_b"] == b["sky_a"]:
		out["blend"] = lerpf(float(a["blend"]), 1.0, t)
	else:
		out["blend"] = float(a["blend"])
	return out
