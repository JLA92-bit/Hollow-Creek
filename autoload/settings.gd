extends Node
## Player settings, stored in user://settings.cfg (IndexedDB on the web).

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"quality": "",  # "", "low", "medium", "high". Empty means run the benchmark on first launch.
	"text_scale": 1.0,
	"master_volume": 0.8,
	"reduce_motion": false,
	"hints": true,
	"build_while_time_runs": false,
	"update_dismissed": "",  # the newest Android update the player said "Later" to
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()
	apply()
	get_tree().root.size_changed.connect(apply)


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	save_settings()
	if key in ["text_scale", "master_volume"]:
		apply()
	EventBus.settings_changed.emit(key, value)


## The game is laid out for 1280 x 720. On a short screen (a phone held sideways) that shrinks every
## button below a fingertip, so the UI is scaled up until a 48 px button is about 44 px on
## screen: 1 at 600 px tall or more, up to 1.8 on the smallest phones. `window_height` is in CSS
## pixels (see `css_height`): a 3x phone is 1170 physical pixels tall but only 390 CSS pixels.
static func auto_scale(window_height: float) -> float:
	if window_height >= 600.0 or window_height <= 0.0:
		return 1.0
	return clampf(720.0 / (1.1 * window_height), 1.0, 1.8)


## A compact screen is a phone held sideways (under 480 logical pixels tall): panels shrink, scroll or
## collapse so they never sit on top of each other.
static func is_compact(logical_height: float) -> bool:
	return logical_height < 480.0


## The window height in CSS (device independent) pixels: physical pixels over the screen's pixel ratio.
static func css_height(physical_height: float, pixel_ratio: float) -> float:
	return physical_height / maxf(pixel_ratio, 1.0)


## Puts the settings that act on the whole app into effect: text size (UI scale) and master volume.
func apply() -> void:
	var root := get_tree().root if is_inside_tree() else null
	if root != null:
		root.content_scale_factor = clampf(float(get_value("text_scale")), 0.8, 1.5) * auto_scale(css_height(root.size.y, DisplayServer.screen_get_scale()))
	if AudioServer.bus_count > 0:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(get_value("master_volume")), 0.0001)))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key: String in DEFAULTS:
		_values[key] = cfg.get_value("settings", key, DEFAULTS[key])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in _values:
		cfg.set_value("settings", key, _values[key])
	cfg.save(PATH)
