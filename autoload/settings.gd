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
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	save_settings()
	EventBus.settings_changed.emit(key, value)


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
