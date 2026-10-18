extends GutTest
## Motives, plan generation and running a plan in the simulation.

static var _town: SimTown


func _sim(start_day: int = 5, start_minute: int = 21 * 60) -> Sim:
	if _town == null:
		var slice := MapSlice.load_default()
		var hs: Array = DemoTown.houses()
		for l: Dictionary in slice.data["landmarks"]:
			if l["kind"] == "house":
				var a := HouseData.load_file(str(l["house"]))
				var o: Array = l["origin"]
				a.origin = Vector2i(int(o[0]), int(o[1]))
				hs.append(a)
		_town = SimTown.build(slice.grid, hs, slice.data["landmarks"], slice.creek_points)
	var s := Sim.new(1952)
	s.setup(_town, Sim.load_data(), DemoTown.homes(), start_day, start_minute)
	return s


func _len_frank() -> Dictionary:
	return {"culprit": "r_len", "target": "r_frank", "motive": "money", "crime": "theft", "pressure": 80.0}


func test_len_is_a_candidate_for_theft_from_frank() -> void:
	var s := _sim()
	var c := Motives.candidates(s, "theft")
	var found := false
	for x: Dictionary in c:
		if x["culprit"] == "r_len" and x["target"] == "r_frank":
			found = true
	assert_true(found, "Len's hidden debts point him at the shopkeeper")
	assert_gt(Motives.money_worry(s, "r_len"), 60.0)


func test_a_content_honest_resident_is_not_a_candidate() -> void:
	var s := _sim()
	for x: Dictionary in Motives.candidates(s, "theft"):
		assert_ne(x["culprit"], "r_tomasz", "honest Tomasz is under no pressure")


func test_honest_residents_need_ninety() -> void:
	var s := _sim()
	s.add_grievance("r_tomasz", "r_frank", "test", 60.0)
	for x: Dictionary in Motives.candidates(s, "theft"):
		assert_ne(x["culprit"], "r_tomasz", "pressure 60 isn't enough for an honest man")


func test_grievance_makes_a_candidate() -> void:
	var s := _sim()
	s.add_grievance("r_marge", "r_frank", "test", 80.0)
	var seen := false
	for x: Dictionary in Motives.candidates(s, "theft"):
		if x["culprit"] == "r_marge":
			seen = true
	assert_true(seen)


func test_the_store_has_ways_in_and_loot() -> void:
	var s := _sim()
	assert_gt(CrimePlan.entries(s, "house_store").size(), 0)
	var loot := CrimePlan.loot_for(s, "house_store")
	assert_eq(loot["loot"], "the cash tin")


func test_latched_windows_are_not_ways_in() -> void:
	var s := _sim()
	var before := CrimePlan.entries(s, "house_store").size()
	s.latch_until_day = 99
	assert_lt(CrimePlan.entries(s, "house_store").size(), before)


func test_plans_are_generated_deterministically() -> void:
	var a := CrimePlan.generate(_sim(), _len_frank())
	var b := CrimePlan.generate(_sim(), _len_frank())
	assert_gt(a.size(), 3)
	assert_lte(a.size(), 12)
	assert_eq(a, b)


func test_a_plan_runs_and_leaves_real_traces() -> void:
	var s := _sim()
	var plans := CrimePlan.generate(s, _len_frank())
	var plan := plans[0]
	var st := PlanRunner.run(s, plan)
	assert_eq(st["state"], "done", "why: %s" % st["why"])
	assert_gt(int(st["crime_tick"]), 0)
	assert_eq(str(s.residents["r_len"]["carrying"]), "")


func test_a_trial_on_a_snapshot_leaves_the_live_sim_alone() -> void:
	var s := _sim()
	var before := s.snapshot()
	var plan := CrimePlan.generate(s, _len_frank())[0]
	var snap := s.snapshot()
	PlanRunner.run(s, plan)
	s.restore(snap)
	assert_eq(s.snapshot(), before)


func test_the_live_run_matches_the_trial() -> void:
	var a := _sim()
	var plan := CrimePlan.generate(a, _len_frank())[0]
	var snap := a.snapshot()
	var st_a := PlanRunner.run(a, plan)
	var b := _sim()
	b.restore(snap)
	var st_b := PlanRunner.run(b, plan)
	assert_eq(st_a, st_b)
	assert_eq(a.snapshot(), b.snapshot())
