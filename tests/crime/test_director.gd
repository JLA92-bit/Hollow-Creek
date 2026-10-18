extends GutTest
## The director's day: candidates, nightfall planning on snapshots, the live run matching the trial,
## fair cases only, the drama budget, consequences and saves.

static var _town: SimTown


func _sim(day: int = 5) -> Sim:
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
	s.setup(_town, Sim.load_data(), DemoTown.homes(), day, 5 * 60 + 59)
	return s


## Runs the town and the director for some days.
func _days(s: Sim, d: Director, days: int) -> void:
	for i in days * 1440:
		d.before_tick(s)
		s.tick()


func test_an_incident_is_planned_run_and_discovered() -> void:
	var s := _sim()
	var d := Director.new(1)
	_days(s, d, 2)
	assert_eq(int(d.stats["shipped"]), 1, "one incident in two days")
	assert_false(d.open_case.is_empty(), "the victim found it in the morning")
	assert_eq(d.history.size(), 1)


func test_every_shipped_case_is_solvable() -> void:
	var s := _sim()
	var d := Director.new(2)
	_days(s, d, 2)
	var a := Solvability.analyse(d.open_case)
	assert_true(a["solvable"], str(a["reasons"]))
	var inv := Investigation.new(d.open_case)
	var res := SolverBot.play(inv)
	assert_true(res["right"] and res["complete"], "the bot convicts the culprit: %s" % str(res))


func test_the_bot_cannot_convict_a_red_herring() -> void:
	var s := _sim()
	var d := Director.new(1)
	_days(s, d, 2)
	var inv := Investigation.new(d.open_case)
	SolverBot.play(inv, false)
	for pid: String in d.open_case["people"]:
		if pid != d.open_case["culprit"]:
			assert_false(inv.complete(pid), "%s must not be convictable" % pid)


func test_the_drama_budget_holds_back_the_next_incident() -> void:
	var s := _sim()
	var d := Director.new(1)
	_days(s, d, 5)
	assert_eq(int(d.stats["shipped"]), 1, "no second incident inside the gap")
	assert_gte(d.gap_days, 7)
	assert_lte(d.gap_days, 10)


func test_a_quiet_town_has_no_incidents() -> void:
	var s := _sim()
	s.secrets.erase("s_len_debts")
	s.grievances.clear()
	var d := Director.new(1)
	_days(s, d, 3)
	assert_eq(int(d.stats["shipped"]), 0)
	assert_eq(d.history.size(), 0)


func test_the_same_seed_gives_the_same_incident() -> void:
	var a := _sim()
	var da := Director.new(7)
	_days(a, da, 2)
	var b := _sim()
	var db := Director.new(7)
	_days(b, db, 2)
	assert_eq(da.history, db.history)
	assert_eq(da.open_case, db.open_case)
	assert_eq(a.snapshot(), b.snapshot())


func test_latched_windows_make_the_next_crime_harder() -> void:
	var s := _sim()
	var d := Director.new(1)
	_days(s, d, 2)
	var before := CrimePlan.entries(s, "house_store").size()
	d.apply_outcome(s, d.open_case, {"accused": d.open_case["culprit"], "resolution": "restitution"})
	assert_gt(s.latch_until_day, s.day)
	assert_lt(CrimePlan.entries(s, "house_store").size(), before)


func test_charging_the_culprit_sends_them_away_and_they_come_back() -> void:
	var s := _sim()
	var d := Director.new(1)
	_days(s, d, 2)
	var culprit := str(d.open_case["culprit"])
	d.apply_outcome(s, d.open_case, {"accused": culprit, "resolution": "charge"})
	assert_eq(s.residents[culprit]["status"], "away")
	assert_true(d.returns.has(culprit))
	s.day = int(d.returns[culprit])
	d.morning(s)
	assert_eq(s.residents[culprit]["status"], "living")


func test_a_wrong_accusation_costs_goodwill_and_relieves_the_culprit() -> void:
	var s := _sim()
	var d := Director.new(1)
	_days(s, d, 2)
	var culprit := str(d.open_case["culprit"])
	var other := "r_marge" if culprit != "r_marge" else "r_edna"
	d.apply_outcome(s, d.open_case, {"accused": other, "resolution": ""})
	var found := false
	for g: Dictionary in s.grievances:
		found = found or (str(g["owner"]) == other and str(g["target"]) == Sim.PLAYER)
	assert_true(found)
	assert_gt(float(d.relief.get(culprit, 0.0)), 0.0)


func test_director_state_survives_a_save() -> void:
	var s := _sim()
	var d := Director.new(1)
	_days(s, d, 2)
	var e := Director.new(1)
	e.restore(d.snapshot())
	assert_eq(e.snapshot(), d.snapshot())
