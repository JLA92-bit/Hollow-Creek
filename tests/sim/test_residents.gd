extends GutTest
## docs/SIMULATION.md: residents live in the demo town deterministically. Same seed, same week;
## routines hold (work, sleep, meals); friends visit; grievances fade; wages come in.

static var _town: SimTown
static var _slice: MapSlice


func _make_town() -> SimTown:
	if _town == null:
		_slice = MapSlice.load_default()
		var hs: Array = DemoTown.houses()
		for l: Dictionary in _slice.data["landmarks"]:
			if l["kind"] == "house":
				var a := HouseData.load_file(str(l["house"]))
				var o: Array = l["origin"]
				a.origin = Vector2i(int(o[0]), int(o[1]))
				hs.append(a)
		_town = SimTown.build(_slice.grid, hs, _slice.data["landmarks"], _slice.creek_points)
	return _town


## JSON text with numbers in one form, so 0 and 0.0 compare equal.
func _canon(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d, "", true, true)), "", true, true)


func _sim(seed_value: int) -> Sim:
	var s := Sim.new(seed_value)
	s.setup(_make_town(), Sim.load_data(), DemoTown.homes(), 0, 6 * 60)
	return s


func _where(s: Sim, rid: String) -> Dictionary:
	var r: Dictionary = s.residents[rid]
	return {"action": str(r["action"].get("kind", "")), "place": str(r["action"].get("place", "")), "walking": not (r["route"] as Array).is_empty()}


func test_town_has_homes_and_places() -> void:
	var t := _make_town()
	for hid: String in DemoTown.homes():
		var home: String = DemoTown.homes()[hid]
		assert_true(t.homes.has(home), "%s has a home" % hid)
		assert_false(((t.homes[home] as Dictionary)["beds"] as Array).is_empty(), "%s has a bed" % home)
	var kinds := {}
	for p in t.places:
		kinds[p["kind"]] = true
	for k in ["bed", "cook", "snack", "wireless", "sit", "work", "shop", "exchange", "fish", "garden"]:
		assert_true(kinds.has(k), "somewhere to %s" % k)
	var r := t.route(t.homes["house_pike"]["living"], t.place("lm_mill")["at"], "house_pike", "")
	assert_gt(r.size(), 10, "a walk from the Pikes' to the mill")


func test_same_seed_same_week() -> void:
	var a := _sim(1952)
	var b := _sim(1952)
	a.run_ticks(7 * 1440)
	b.run_ticks(7 * 1440)
	assert_eq(JSON.stringify(a.snapshot()), JSON.stringify(b.snapshot()), "7 days from a fixed seed give identical snapshots")
	var c := _sim(1953)
	c.run_ticks(1440)
	var a1 := _sim(1952)
	a1.run_ticks(1440)
	assert_ne(JSON.stringify(c.snapshot()["residents"]), JSON.stringify(a1.snapshot()["residents"]), "another seed, another day")


func test_snapshot_restores_mid_week() -> void:
	var a := _sim(7)
	a.run_ticks(2 * 1440 + 333)
	var b := Sim.new(0)
	b.town = _make_town()
	b.data = Sim.load_data()
	b.restore(JSON.parse_string(JSON.stringify(a.snapshot(), "", true, true)))
	a.run_ticks(600)
	b.run_ticks(600)
	assert_eq(_canon(b.snapshot()), _canon(a.snapshot()), "restored and carried on identically")


func test_routines() -> void:
	var s := _sim(1952)
	# Tuesday 10 am: mill hands at the mill, the shopkeeper in the shop, Edna at the exchange.
	s.run_ticks(1440 + 4 * 60)
	assert_eq(s.minute, 10 * 60)
	assert_eq(_where(s, "r_len")["place"], "lm_mill")
	assert_eq(_where(s, "r_tomasz")["place"], "lm_mill")
	assert_eq(_where(s, "r_frank")["place"], "house_store:shop")
	assert_eq(_where(s, "r_edna")["place"], "house_store:exchange")
	assert_ne(_where(s, "r_agnes")["action"], "work", "Agnes is retired")
	# 3 am Wednesday: everyone in bed.
	s.run_ticks(17 * 60)
	for rid: String in s.residents:
		assert_eq(_where(s, rid)["action"], "sleep", "%s is asleep at 3 am" % rid)
	# The night owls are still up at 11 pm.
	s.run_ticks(20 * 60)
	assert_ne(_where(s, "r_davey")["action"], "sleep", "Davey is up at 11 pm")


func test_needs_are_met_over_a_week() -> void:
	var s := _sim(42)
	var low := {}
	for i in 7 * 24:
		s.run_ticks(60)
		for rid: String in s.residents:
			for n in Sim.NEEDS:
				low[n] = minf(float(low.get(n, 100.0)), float(s.residents[rid]["needs"][n]))
	gut.p("Lowest needs over the week: %s" % low)
	assert_gt(float(low["hunger"]), 5.0, "nobody starves")
	assert_gt(float(low["energy"]), 5.0, "everyone sleeps")


func test_friends_visit_and_grievances_fade() -> void:
	var s := _sim(1952)
	s.run_ticks(7 * 1440)
	var visits := 0
	for e: Dictionary in s.events:
		if str(e["text"]).contains("went to visit"):
			visits += 1
	assert_gt(visits, 0, "friends visit each other")
	var davey := 0.0
	for g: Dictionary in s.grievances:
		if g["owner"] == "r_davey":
			davey = float(g["weight"])
	assert_almost_eq(davey, 40.0 - 14.0, 0.01, "Davey's grievance fades by 2 a day")
	assert_eq(s.rel_label("r_marge", "r_agnes"), "Close friend")
	assert_eq(s.rel_label("r_june", "r_piotr"), "Sweethearts")


func test_weekly_wages() -> void:
	var s := _sim(5)
	var before := float(s.households["h_pike"]["money"])
	s.run_ticks(7 * 1440)
	var after := float(s.households["h_pike"]["money"])
	var wk: Dictionary = s.households["h_pike"]["last_week"]
	assert_eq(float(wk["income"]), 12.0, "Len's wages and Davey's apprentice pay")
	assert_ne(after, before)
