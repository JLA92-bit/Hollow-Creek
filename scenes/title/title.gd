extends Control
## Title menu: continue the autosave, or start a new game in the valley. Sandbox and Settings arrive
## with later milestones.

@onready var _status: Label = %Status


func _ready() -> void:
	var new_game: Button = %NewGame
	var sandbox: Button = %Sandbox
	var settings: Button = %Settings
	var has_save := FileAccess.file_exists("%s/autosave.json" % SaveSystem.DIR)
	if has_save:
		new_game.text = "Continue"
		new_game.pressed.connect(func() -> void:
			if SaveSystem.load_slot("autosave"):
				get_tree().change_scene_to_file("res://scenes/world/world.tscn"))
		sandbox.text = "New game"
		sandbox.disabled = false
		sandbox.pressed.connect(_new_game)
	else:
		new_game.text = "New game"
		new_game.pressed.connect(_new_game)
		sandbox.disabled = true
	settings.disabled = true
	_status.text = "Press Build (or B) to build. Right-drag or two fingers to look around, R for rain."


func _new_game() -> void:
	GameState.reset()
	Clock.from_dict({"day": 0, "minute": 360})
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")
