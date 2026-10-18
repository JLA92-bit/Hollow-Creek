extends SceneTree
## Soak test for the crime director (docs/CRIME_DIRECTOR.md "Testing"):
##   tools/bin/godot --headless --path . -s tools/director_soak.gd -- --seeds 500 [--from 0] [--days 28] [--det-every 50]
## For each seed: a small town from the slice templates with seed-driven grievances, money and
## weather, run for --days with the director, and check every shipped case with the solver bot.
## Prints one `SOAK seed ...` line per seed and a `SOAK_SUMMARY` JSON line; exit code 1 on failure.

var _town: SimTown
var _args := {"seeds": 20, "from": 0, "days": 28, "det_every": 50}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		match a[i]:
			"--seeds": _args["seeds"] = int(a[i + 1])
			"--from": _args["from"] = int(a[i + 1])
			"--days": _args["days"] = int(a[i + 1])
			"--det-every": _args["det_every"] = int(a[i + 1])
	var slice := MapSlice.load_default()
	var hs: Array = DemoTown.houses()
	for l: Dictionary in slice.data["landmarks"]:
		if l["kind"] == "house":
			var h := HouseData.load_file(str(l["house"]))
			var o: Array = l["origin"]
			h.origin = Vector2i(int(o[0]), int(o[1]))
			hs.append(h)
	_town = SimTown.build(slice.grid, hs, slice.data["landmarks"], slice.creek_points)
	var t := {"seeds": 0, "incidents": 0, "unsolvable_shipped": 0, "bot_failed": 0, "herring_convicted": 0, "plans_tried": 0, "plans_unsolvable": 0,
		"facts": 0, "with_herring": 0, "planning_days": 0, "night_ms": 0.0, "morning_ms": 0.0, "morning_n": 0, "cancelled": 0, "determinism_checked": 0,
		"determinism_failed": 0, "seeds_with_incident": 0, "days": 0}
	var started := Time.get_ticks_msec()
	for seed_i in int(_args["seeds"]):
		var seed_v := int(_args["from"]) + seed_i
		var r := _run_seed(seed_v)
		t["seeds"] += 1
		t["days"] += int(_args["days"])
		var d: Director = r["director"]
		t["incidents"] += int(d.stats["shipped"])
		t["seeds_with_incident"] += 1 if int(d.stats["shipped"]) > 0 else 0
		t["plans_tried"] += int(d.stats["plans_tried"])
		t["plans_unsolvable"] += int(d.stats["plans_unsolvable"])
		t["facts"] += int(d.stats["facts"])
		t["with_herring"] += int(d.stats["with_herring"])
		t["planning_days"] += int(d.stats["planning_days"])
		t["night_ms"] += float(d.stats["night_ms"])
		t["morning_ms"] += float(d.stats["morning_ms"])
		t["morning_n"] += int(d.stats["morning_n"])
		t["cancelled"] += int(d.stats["cancelled"])
		t["unsolvable_shipped"] += int(r["unsolvable"])
		t["bot_failed"] += int(r["bot_failed"])
		t["herring_convicted"] += int(r["herring_convicted"])
		if int(_args["det_every"]) > 0 and seed_v % int(_args["det_every"]) == 0:
			t["determinism_checked"] += 1
			var r2 := _run_seed(seed_v)
			if (r2["director"] as Director).history != d.history or r2["hash"] != r["hash"]:
				t["determinism_failed"] += 1
		print("SOAK seed ", seed_v, " incidents=", d.stats["shipped"], " tried=", d.stats["plans_tried"], " unsolvable_plans=", d.stats["plans_unsolvable"],
			" cancelled=", d.stats["cancelled"], " ship_bad=", r["unsolvable"], " bot_bad=", r["bot_failed"], " herring_bad=", r["herring_convicted"])
	var secs := float(Time.get_ticks_msec() - started) / 1000.0
	var inc: int = maxi(1, int(t["incidents"]))
	var summary := {"seeds": t["seeds"], "days": t["days"], "incidents": t["incidents"], "seeds_with_incident": t["seeds_with_incident"],
		"unsolvable_shipped": t["unsolvable_shipped"], "bot_failed": t["bot_failed"], "herring_convicted": t["herring_convicted"],
		"plans_tried": t["plans_tried"], "plans_discarded_unsolvable": t["plans_unsolvable"], "cancelled": t["cancelled"],
		"avg_facts": snappedf(float(t["facts"]) / float(inc), 0.01), "pct_with_herring": snappedf(100.0 * float(t["with_herring"]) / float(inc), 0.1),
		"ms_per_planning_night": snappedf(float(t["night_ms"]) / maxf(1.0, float(t["planning_days"])), 0.1),
		"ms_per_day_all": snappedf((float(t["night_ms"]) + float(t["morning_ms"])) / maxf(1.0, float(t["days"])), 0.1),
		"determinism_checked": t["determinism_checked"], "determinism_failed": t["determinism_failed"], "seconds": snappedf(secs, 0.1)}
	print("SOAK_SUMMARY ", JSON.stringify(summary))
	var ok: bool = int(t["unsolvable_shipped"]) == 0 and int(t["bot_failed"]) == 0 and int(t["herring_convicted"]) == 0 and int(t["determinism_failed"]) == 0
	quit(0 if ok else 1)


## One town for 28 days with the director on. Checks every shipped case as it opens.
func _run_seed(seed_v: int) -> Dictionary:
	var s := Sim.new(seed_v)
	s.setup(_town, Sim.load_data(), DemoTown.homes(), 0, 5 * 60 + 59)
	var rng := SimRng.new(seed_v * 7919 + 13)
	_perturb(s, rng)
	var weather: Array[bool] = []
	for i in int(_args["days"]) + 2:
		weather.append(rng.chance(0.25))
	var d := Director.new(seed_v)
	var bad := {"unsolvable": 0, "bot_failed": 0, "herring_convicted": 0}
	var checked := {}
	for i in int(_args["days"]) * 1440:
		var wet: bool = weather[s.day] and s.minute >= 2 * 60 and s.minute < 5 * 60
		s.raining = wet
		d.before_tick(s)
		s.tick()
		if not d.open_case.is_empty() and not checked.has(str(d.open_case["id"])):
			checked[str(d.open_case["id"])] = true
			_check(d.open_case, bad)
			# The player solves it (or doesn't); either way the town moves on.
			d.apply_outcome(s, d.open_case, {"accused": str(d.open_case["culprit"]), "resolution": "restitution"})
	return {"director": d, "unsolvable": bad["unsolvable"], "bot_failed": bad["bot_failed"], "herring_convicted": bad["herring_convicted"], "hash": hash(JSON.stringify(s.snapshot()))}


func _check(case_data: Dictionary, bad: Dictionary) -> void:
	if not bool(Solvability.analyse(case_data)["solvable"]):
		bad["unsolvable"] += 1
	var inv := Investigation.new(case_data)
	var res := SolverBot.play(inv)
	if not (bool(res.get("right", false)) and bool(res.get("complete", false))):
		bad["bot_failed"] += 1
	var inv2 := Investigation.new(case_data)
	SolverBot.play(inv2, false)
	for pid: String in case_data["people"]:
		if pid != str(case_data["culprit"]) and inv2.complete(pid):
			bad["herring_convicted"] += 1


## Make each seed its own town: a few grievances, household money, who's hiding what.
func _perturb(s: Sim, rng: SimRng) -> void:
	var ids := s.residents.keys()
	ids.sort()
	for i in rng.randi_range(1, 4):
		var a: String = ids[rng.randi_range(0, ids.size() - 1)]
		var b: String = ids[rng.randi_range(0, ids.size() - 1)]
		if a != b:
			s.grievances.append({"owner": a, "target": b, "reason": ["a dispute over a fence", "an unpaid debt", "a harsh word"][rng.randi_range(0, 2)], "weight": float(rng.randi_range(20, 75)), "day": 0})
	for hid: String in s.households:
		s.households[hid]["money"] = float(rng.randi_range(2, 40))
	for sid: String in s.secrets:
		s.secrets[sid]["exposure_risk"] = float(rng.randi_range(5, 35))
