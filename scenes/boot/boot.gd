extends Control
## First screen: title, "Tap to begin" and the version. Any tap, click or key moves on to the title menu.

const NEXT_SCENE := "res://scenes/title/title.tscn"

@onready var _tap: Label = %Tap
@onready var _version: Label = %Version
var _leaving := false
var _t := 0.0


func _ready() -> void:
	_version.text = "Version %s" % GameState.version()
	# Test and preview hooks: ?scene=look_test or ?scene=world skips the menus.
	var target := str(UrlParams.read().get("scene", ""))
	var scenes := {"look_test": "res://scenes/world/look_test.tscn", "world": "res://scenes/world/world.tscn",
		"build_demo": "res://scenes/build_ui/build_demo.tscn"}
	if scenes.has(target):
		_leaving = true
		get_tree().change_scene_to_file.call_deferred(str(scenes[target]))


func _process(delta: float) -> void:
	_t += delta
	if not Settings.get_value("reduce_motion"):
		_tap.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.4))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_begin()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_begin()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed():
		_begin()


func _begin() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))
