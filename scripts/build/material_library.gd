class_name MaterialLibrary
extends RefCounted
## Builds and caches StandardMaterial3D instances from data/materials.json.
## Paint colours tint a neutral base, so the whole paint chart costs no extra textures.

const PATH := "res://data/materials.json"
const PALETTES := "res://data/palettes.json"
const TEX_DIR := "res://assets/materials/%s/%s_%s.jpg"

static var _data: Dictionary = {}
static var _palettes: Dictionary = {}
static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary
	return _data


static func def(id: String) -> Dictionary:
	return (data()["materials"] as Dictionary).get(id, {})


static func palettes() -> Dictionary:
	if _palettes.is_empty():
		_palettes = JSON.parse_string(FileAccess.get_file_as_string(PALETTES)) as Dictionary
	return _palettes


## A paint by chart name, or a custom colour given as "#RRGGBB".
static func paint(name: String) -> Color:
	if name.begins_with("#"):
		return Color(name)
	return Color(str((palettes()["paint_chart"] as Dictionary).get(name, "#FF00FF")))


static func paint_names(group: String = "walls") -> Array:
	return (palettes()["paint_groups"] as Dictionary).get(group, [])


## A wallpaper material for a pattern and colourway: a shader mixes ground, motif and accent colours
## through the pattern's mask, over the paper's own texture.
static func wallpaper(pattern: String, colourway: String) -> ShaderMaterial:
	var key := "wallpaper|%s|%s" % [pattern, colourway]
	if _cache.has(key):
		return _cache[key]
	var p: Dictionary = (palettes()["wallpapers"] as Dictionary).get(pattern, {})
	var ways: Dictionary = p.get("colourways", {})
	var cols: Array = ways.get(colourway, ways.values()[0] if not ways.is_empty() else ["#EEE8D8", "#B05050", "#708A68"])
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/wallpaper.gdshader") as Shader
	m.set_shader_parameter("pattern", load("res://assets/materials/wallpaper/%s.png" % pattern))
	m.set_shader_parameter("paper_normal", load("res://assets/materials/plaster/plaster_normal.jpg"))
	m.set_shader_parameter("ground", Color(str(cols[0])))
	m.set_shader_parameter("motif", Color(str(cols[1])))
	m.set_shader_parameter("accent", Color(str(cols[2])))
	m.set_shader_parameter("repeat_m", float(p.get("repeat_m", 0.53)))
	_cache[key] = m
	return m


## The material for an id, optionally tinted. Cached per id and colour.
static func get_material(id: String, tint: Variant = null) -> StandardMaterial3D:
	var d := def(id)
	assert(not d.is_empty(), "Unknown material: %s" % id)
	var colour: Color = tint if tint is Color else Color(str(d.get("tint", "#FFFFFF")))
	var key := "%s|%s" % [id, colour.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.resource_name = id
	m.albedo_color = colour
	m.roughness = float(d.get("roughness", 0.8))
	m.metallic = float(d.get("metallic", 0.0))
	m.metallic_specular = float(d.get("specular", 0.5))
	if d.has("tex"):
		var tex := str(d["tex"])
		m.albedo_texture = load(TEX_DIR % [tex, tex, "albedo"]) as Texture2D
		var nrm := load(TEX_DIR % [tex, tex, "normal"]) as Texture2D
		if nrm:
			m.normal_enabled = true
			m.normal_texture = nrm
			m.normal_scale = float(d.get("normal_scale", 1.0))
		var orm := load(TEX_DIR % [tex, tex, "orm"]) as Texture2D
		if orm:
			m.ao_enabled = true
			m.ao_texture = orm
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.ao_light_affect = 0.6
			m.roughness_texture = orm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		# Geometry UVs are in metres; one texture tile covers size_m metres.
		var s := 1.0 / float(d.get("size_m", 1.0))
		m.uv1_scale = Vector3(s, s, s)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if d.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = float(d["alpha"])
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if d.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[key] = m
	return m


## A fresh, uncached copy (for materials that change at runtime, such as glowing windows).
static func unique(id: String, tint: Variant = null) -> StandardMaterial3D:
	return get_material(id, tint).duplicate() as StandardMaterial3D


## Alpha-cut lace, fretwork and lattice: white texture tinted with a paint colour, two-sided.
static func cutout(path: String, colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path) as Texture2D
	m.albedo_color = colour
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
