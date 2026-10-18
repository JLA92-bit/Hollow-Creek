extends "res://scenes/resident_ui/residents_demo.gd"
## M8 acceptance demo: the crime director running in the live game. The families move in, the
## director is switched on, and the town is left to live. Sooner or later somebody's pressure tips
## over, the director plans the night on snapshots and runs the best fair plan for real, the victim
## finds out in the morning, and the alert opens the investigation screen on a case nobody wrote.
## The solver bot then solves it with the rules alone, and the consequences land in the town.
## Prints HC_SHOT and HC_DEMO lines (?scene=director_demo).


func _ready() -> void:
	GameState.reset()
	SimHost.reset()
	Settings.set_value("quality", "medium")
	GameState.mode = GameState.MODE_STORY
	Clock.set_speed(0)
	Clock.day = 0
	Clock.set_minute(7 * 60)
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	_run_director.call_deferred()


func _run_director() -> void:
	await _frames(5)
	rig = world.get("rig")
	hud = world.get("hud")
	for h: HouseData in DemoTown.houses():
		world.call("add_house", h)
	await _frames(2)
	SimHost.rebuild_town()
	for hid: String in ["h_hayward", "h_pike", "h_kowalski"]:
		SimHost.offer_home(hid, DemoTown.homes()[hid])
	_check(SimHost.living_count() == 10, "ten residents at home")
	SimHost.director_enabled = true
	SimHost.director.last_incident_day = -100   # the demo doesn't wait out the first week
	var trust0 := GameState.town_trust
	var guard := 0
	while SimHost.investigation == null and Clock.day < 16 and guard < 400:
		await run_to(Clock.day + (1 if Clock.minute + 60 >= 1440 else 0), (Clock.minute + 60) % 1440)
		guard += 1
	var inv := SimHost.investigation
	_check(inv != null, "the director opened a case by day %d" % Clock.day)
	if inv == null:
		print("HC_DEMO_RESULT FAIL ", checks.size() - failures, "/", checks.size())
		print("HC_DONE")
		return
	var d := SimHost.director
	_check(bool(inv.data.get("generated", false)) and inv.data.has("plan"), "a generated case: %s" % inv.title())
	_check(Clock.speed == 0, "time pauses on the alert")
	_check(int(d.stats["shipped"]) == 1 and d.history.size() == 1, "one incident shipped; %d plans tried, %d discarded as unfair" % [int(d.stats["plans_tried"]), int(d.stats["plans_unsolvable"])])
	var a := Solvability.analyse(inv.data)
	_check(bool(a["solvable"]), "the case is solvable from its discoverable facts (%d facts)" % int(a["facts"]))
	_check(bool(a["interesting"]), "and has a red herring: %s" % str(a["herrings"]))
	var screen: InvestigationScreen = world.get("case_screen")
	_check(screen != null and screen.visible, "the alert opens the investigation screen")
	await _frames(6)
	await shot("m8_01_alert")
	# Work the case: a few taps by hand, then the bot takes over.
	var first_trace := str((inv.traces()[0] as Dictionary)["id"])
	if screen.hotspots.has(first_trace):
		(screen.hotspots[first_trace] as Button).pressed.emit()
	await _frames(3)
	var culprit := str(inv.data["culprit"])
	var res := SolverBot.play(inv)
	_check(bool(res.get("right", false)) and bool(res.get("complete", false)), "the solver bot convicts %s with the rules alone" % culprit)
	screen.call("_rebuild")
	await _frames(4)
	await shot("m8_02_solved")
	var latch_before := SimHost.sim.latch_until_day
	var trust_before := GameState.town_trust
	SimHost.bank_case()
	_check(GameState.town_trust == trust_before + 6 or GameState.town_trust == trust_before + 10, "Town Trust banked (%d)" % GameState.town_trust)
	_check(SimHost.sim.latch_until_day > latch_before, "the town starts latching its windows")
	_check(SimHost.investigation == null and d.open_case.is_empty(), "the case is closed and the director is free for the next one")
	await _frames(2)
	print("HC_DEMO director ", JSON.stringify({"day": Clock.day, "stats": d.stats, "culprit": culprit, "trust": GameState.town_trust, "from": trust0}))
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
