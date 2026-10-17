extends GutTest


func _sequence(rng: SimRng, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(rng.randi_range(0, 1_000_000))
	return out


func test_same_seed_same_sequence() -> void:
	assert_eq(_sequence(SimRng.new(42), 50), _sequence(SimRng.new(42), 50))


func test_different_seed_different_sequence() -> void:
	assert_ne(_sequence(SimRng.new(42), 50), _sequence(SimRng.new(43), 50))


func test_snapshot_round_trip_through_json() -> void:
	var a := SimRng.new(1952)
	_sequence(a, 17)
	var snap: Variant = JSON.parse_string(JSON.stringify(a.snapshot()))
	var b := SimRng.new(0)
	b.restore(snap as Dictionary)
	assert_eq(_sequence(b, 30), _sequence(a, 30))


func test_weighted_index_respects_zero_weights() -> void:
	var rng := SimRng.new(7)
	var weights: Array[float] = [0.0, 1.0, 0.0]
	for i in 100:
		assert_eq(rng.weighted_index(weights), 1)
	var none: Array[float] = [0.0, 0.0]
	assert_eq(rng.weighted_index(none), -1)


func test_shuffle_is_deterministic_permutation() -> void:
	var a := [1, 2, 3, 4, 5, 6, 7, 8]
	var b := a.duplicate()
	SimRng.new(9).shuffle(a)
	SimRng.new(9).shuffle(b)
	assert_eq(a, b)
	var sorted := a.duplicate()
	sorted.sort()
	assert_eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8])


func test_fork_is_deterministic() -> void:
	assert_eq(_sequence(SimRng.new(5).fork(), 20), _sequence(SimRng.new(5).fork(), 20))
