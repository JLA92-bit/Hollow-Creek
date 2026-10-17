extends GutTest


func test_snapshot_round_trip() -> void:
	var a := Sim.new(1952)
	a.run_ticks(600)
	var b := Sim.new(0)
	b.restore(JSON.parse_string(JSON.stringify(a.snapshot())) as Dictionary)
	assert_eq(b.snapshot(), a.snapshot())


func test_same_seed_same_snapshot() -> void:
	var a := Sim.new(77)
	var b := Sim.new(77)
	a.run_ticks(1440)
	b.run_ticks(1440)
	assert_eq(a.snapshot(), b.snapshot())
