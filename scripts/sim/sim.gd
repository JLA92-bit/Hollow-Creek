class_name Sim
extends RefCounted
## The resident simulation. Plain class, no scene dependencies. One tick is one game minute.
## Residents, needs and actions arrive in M5; for now it owns the RNG and the tick count.

var rng: SimRng
var ticks: int = 0
var seed_value: int = 0


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	rng = SimRng.new(p_seed)


func tick() -> void:
	ticks += 1


func run_ticks(n: int) -> void:
	for i in n:
		tick()


func snapshot() -> Dictionary:
	return {"seed": seed_value, "ticks": ticks, "rng": rng.snapshot()}


func restore(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	ticks = int(data.get("ticks", 0))
	rng.restore(data.get("rng", {}))
