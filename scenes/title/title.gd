extends Control
## Title menu: continue the story autosave, start a new game, or open the Sandbox (its own save:
## unlimited money and instant building). Settings arrive with a later milestone.

@onready var _status: Label = %Status


func _ready() -> void:
	var new_game: Button = %NewGame
	var sandbox: Button = %Sandbox
	var settings: Button = %Settings
	var has_story := FileAccess.file_exists("%s/autosave.json" % SaveSystem.DIR)
	var has_sandbox := FileAccess.file_exists("%s/sandbox.json" % SaveSystem.DIR)
	if has_story:
		var cont := Button.new()
		cont.text = "Continue"
		cont.custom_minimum_size = Vector2(0, 52)
		cont.theme_type_variation = &"PrimaryButton"
		cont.pressed.connect(func() -> void: _load("autosave"))
		new_game.get_parent().add_child(cont)
		new_game.get_parent().move_child(cont, new_game.get_index())
		new_game.theme_type_variation = &""
	new_game.text = "New game"
	new_game.pressed.connect(_new_game.bind(GameState.MODE_STORY))
	sandbox.text = "Sandbox" if not has_sandbox else "Sandbox (continue)"
	sandbox.tooltip_text = "Unlimited money and instant building, for pure designing."
	sandbox.disabled = false
	sandbox.pressed.connect(func() -> void:
		if has_sandbox:
			_load("sandbox")
		else:
			_new_game(GameState.MODE_SANDBOX))
	settings.disabled = true
	_status.text = "Press Build (or B) to build. Right-drag or two fingers to look around, R for rain, F2 for photos."


func _load(slot: String) -> void:
	if SaveSystem.load_slot(slot):
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")


func _new_game(mode: String) -> void:
	GameState.reset()
	GameState.mode = mode
	Clock.from_dict({"day": 0, "minute": 360})
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")
