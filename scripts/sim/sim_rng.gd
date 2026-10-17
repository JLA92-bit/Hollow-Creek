class_name SimRng
extends RefCounted
## The only source of randomness for the simulation and the crime director.
## Wraps Godot's PCG32 generator so the full state can be snapshotted and restored exactly.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## True with probability p (0 to 1).
func chance(p: float) -> bool:
	return _rng.randf() < p


## Picks an index using non-negative weights. Returns -1 if every weight is zero.
func weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var r := _rng.randf() * total
	for i in weights.size():
		r -= maxf(weights[i], 0.0)
		if r < 0.0:
			return i
	return weights.size() - 1


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## Fisher-Yates shuffle in place, using this generator.
func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


## A child generator with an independent stream, derived deterministically from this one.
func fork() -> SimRng:
	return SimRng.new(int(_rng.randi()) << 16 ^ int(_rng.randi()))


func snapshot() -> Dictionary:
	# Stored as strings: JSON numbers lose precision above 2^53.
	return {"seed": str(_rng.seed), "state": str(_rng.state)}


func restore(data: Dictionary) -> void:
	_rng.seed = int(str(data.get("seed", "0")))
	_rng.state = int(str(data.get("state", "0")))
