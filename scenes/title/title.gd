extends Control
## Title menu. M1 opens the valley as a free look-around; Sandbox and Settings arrive with later milestones.

@onready var _status: Label = %Status


func _ready() -> void:
	var new_game: Button = %NewGame
	new_game.text = "Visit the valley"
	new_game.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world/world.tscn"))
	for b: Button in [%Sandbox, %Settings]:
		b.disabled = true
	_status.text = "Building arrives in the next build. Right-drag or two fingers to look around, R for rain, Page Down for cutaway."
