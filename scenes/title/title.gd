extends Control
## Title menu. Game modes open up as milestones land; M0 shows the shell.

@onready var _status: Label = %Status


func _ready() -> void:
	for b: Button in [%NewGame, %Sandbox, %Settings]:
		b.disabled = true
	_status.text = "The valley opens in the next build."
