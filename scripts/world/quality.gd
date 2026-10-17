class_name Quality
extends RefCounted
## Applies the Low, Medium or High preset (data/quality_presets.json) to the viewport, sun and
## environment, and picks a preset from a short benchmark on first launch.

const PATH := "res://data/quality_presets.json"
const NAMES: Array[String] = ["low", "medium", "high"]

static var _presets: Dictionary = {}


static func presets() -> Dictionary:
	if _presets.is_empty():
		_presets = JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary
	return _presets


static func preset(name: String) -> Dictionary:
	return presets().get(name, presets()["medium"])


static func apply(name: String, viewport: Viewport, sun: DirectionalLight3D, env: Environment) -> Dictionary:
	var p := preset(name)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = float(p["render_scale"])
	match int(p["msaa"]):
		2:
			viewport.msaa_3d = Viewport.MSAA_2X
		4:
			viewport.msaa_3d = Viewport.MSAA_4X
		_:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(int(p["shadow_size"]), true)
	match int(p["shadow_splits"]):
		1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		2:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = float(p["shadow_distance"])
	sun.shadow_blur = 1.5 if p["soft_shadows"] else 1.0
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if p["soft_shadows"] else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if p["soft_shadows"] else RenderingServer.SHADOW_QUALITY_HARD)
	var ssao := str(p["ssao"])
	env.ssao_enabled = ssao != "off"
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM if ssao == "full" else RenderingServer.ENV_SSAO_QUALITY_LOW,
		ssao == "half", 0.5, 2, 50, 300)
	env.glow_enabled = bool(p["glow"])
	return p


## Picks a preset from the average frame time of a short run at the current settings.
static func pick_from_frame_ms(avg_ms: float) -> String:
	if avg_ms <= 14.0:
		return "high"
	if avg_ms <= 28.0:
		return "medium"
	return "low"
