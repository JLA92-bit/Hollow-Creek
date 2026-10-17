extends Node
## Owns the live simulation and feeds it ticks from the Clock. The Sim itself is a plain class (scripts/sim/).

var sim: Sim = Sim.new(GameState.seed_value if GameState else 1952)


func _ready() -> void:
	EventBus.time_changed.connect(_on_time_changed)


func _on_time_changed(_day: int, _minute: int) -> void:
	sim.tick()


func snapshot() -> Dictionary:
	return sim.snapshot()


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	sim.restore(data)
