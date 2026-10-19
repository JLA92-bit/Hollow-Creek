extends GutTest
## The scripted week of Case 0 enacted in the simulation, and the authored case fitted to the store.

static var _town: SimTown
var sim: Sim
var st: Dictionary
var discovered_at := -1


func before_all() -> void:
	var slice := MapSlice.load_default()
	var hs: Array = DemoTown.houses()
	for l: Dictionary in slice.data["landmarks"]:
		if l["kind"] == "house":
			var a := HouseData.load_file(str(l["house"]))
			var o: Array = l["origin"]
			a.origin = Vector2i(int(o[0]), int(o[1]))
			hs.append(a)
	_town = SimTown.build(slice.grid, hs, slice.data["landmarks"], slice.creek_points)


func _run_to(day: int, minute: int) -> void:
	while sim.day * 1440 + sim.minute < day * 1440 + minute:
		if CashTinNight.step(sim, st) == "discovery" and discovered_at < 0:
			discovered_at = sim.day * 1440 + sim.minute
		sim.tick()


func before_each() -> void:
	sim = Sim.new(1952)
	sim.setup(_town, Sim.load_data(), DemoTown.homes(), 3, 16 * 60 + 30)
	st = CashTinNight.new_state("house_store")
	discovered_at = -1


func test_thursdays_refusal_gives_len_his_grievance() -> void:
	_run_to(3, 17 * 60)
	var w := 0.0
	for g: Dictionary in sim.grievances:
		if g["owner"] == "r_len" and g["target"] == "r_frank":
			w += float(g["weight"])
	assert_gte(w, 60.0)


func test_almost_everyone_goes_to_the_dance_and_agnes_stays_home() -> void:
	_run_to(5, 20 * 60)
	var mill: Array = _town.landmark_tiles["lm_mill"]
	var at_dance := 0
	for rid: String in CashTinNight.DANCERS:
		var p: Array = sim.residents[rid]["pos"]
		if Vector2(float(p[1]), float(p[2])).distance_to(Vector2(float(mill[1]), float(mill[2]))) < 25.0:
			at_dance += 1
	assert_gte(at_dance, 8, "the town is at the dance")
	var a: Array = sim.residents["r_agnes"]["pos"]
	assert_gt(Vector2(float(a[1]), float(a[2])).distance_to(Vector2(float(mill[1]), float(mill[2]))), 25.0, "Agnes is at home")


func test_len_takes_the_tin_and_is_back_at_the_dance() -> void:
	_run_to(5, 22 * 60)
	assert_false((st["runner"] as Dictionary).is_empty())
	assert_eq(st["runner"]["state"], "done", str(st["runner"].get("why", "")))
	assert_gt(int(st["runner"]["crime_tick"]), 0)
	var mill: Array = _town.landmark_tiles["lm_mill"]
	var p: Array = sim.residents["r_len"]["pos"]
	assert_lt(Vector2(float(p[1]), float(p[2])).distance_to(Vector2(float(mill[1]), float(mill[2]))), 25.0)


func test_agnes_remembers_the_man_in_the_hat() -> void:
	_run_to(5, 22 * 60)
	var seen := false
	for m: Dictionary in sim.residents["r_agnes"]["memories"]:
		seen = seen or str(m.get("subject", "")) == "r_len"
	assert_true(seen)


func test_the_haywards_find_it_at_22_35_and_agnes_rings_ballarat() -> void:
	_run_to(5, 22 * 60 + 45)
	assert_eq(discovered_at, 5 * 1440 + 22 * 60 + 35)
	var rang := false
	for r: Dictionary in sim.records["exchange"]:
		rang = rang or (r["caller"] == "r_agnes" and int(r["minute"]) >= 22 * 60 + 40)
	assert_true(rang, "the exchange log has Agnes's call")


func test_the_authored_case_is_fitted_to_the_store_and_stays_solvable() -> void:
	var c := CashTinNight.case_for(sim, st)
	assert_eq(c["scene"]["house"], "house_store")
	var origin: Vector2i = _town.origins["house_store"]
	for t: Dictionary in c["traces"]:
		if t["id"] in ["t_window", "t_tin", "t_prints_in"]:
			var p: Array = t["pos"]
			assert_true(p[0] >= -1 and p[0] <= 12 and p[1] >= -1 and p[1] <= 12, "%s sits on the store: %s" % [t["id"], str(p)])
	var a := Solvability.analyse(c)
	assert_true(a["solvable"], str(a["reasons"]))
	assert_true(origin != Vector2i.ZERO)


func test_the_script_is_deterministic() -> void:
	_run_to(5, 23 * 60)
	var snap_a := sim.snapshot()
	var other := Sim.new(1952)
	other.setup(_town, Sim.load_data(), DemoTown.homes(), 3, 16 * 60 + 30)
	var st2 := CashTinNight.new_state("house_store")
	while other.day * 1440 + other.minute < 5 * 1440 + 23 * 60:
		CashTinNight.step(other, st2)
		other.tick()
	assert_eq(other.snapshot(), snap_a)
