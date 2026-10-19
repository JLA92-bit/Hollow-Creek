extends "res://scenes/build_ui/construction_demo.gd"
## M9 acceptance playtest: the whole prologue, played through the real game. A new story game
## arrives at the siding, lays the road by following the ghost path, places the store and three
## houses from the templates, waits while the crews build them, approves the families, lives the
## week to the welcome dance, and is called to The Cash Tin. The case is worked at the investigation
## screen (a few taps, then the solver bot) and the lesson closes the prologue. Prints HC_SHOT and
## HC_DEMO lines (?scene=prologue_demo).

var hud_card: PrologueHud


func _ready() -> void:
	GameState.reset()
	SimHost.reset()
	Settings.set_value("quality", "medium")
	GameState.mode = GameState.MODE_STORY
	SimHost.begin_prologue()
	Clock.set_speed(0)
	Clock.day = 0
	Clock.set_minute(6 * 60)
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	_run_prologue.call_deferred()


func _step_is(id: String) -> bool:
	return SimHost.prologue != null and SimHost.prologue.current_id() == id


func _run_clock(minutes: int) -> void:
	var left := minutes
	while left > 0:
		var n := mini(60, left)
		for i in n:
			Clock.advance_minute()
		left -= n
		await get_tree().process_frame


func _run_to(day: int, minute: int) -> void:
	var target := day * 1440 + minute
	while Clock.day * 1440 + Clock.minute < target:
		await _run_clock(mini(60, target - (Clock.day * 1440 + Clock.minute)))


## Place a template at a world point and wait for the crews to finish it. Returns the house.
func _place(file: String, at: Vector2, label: String) -> HouseView:
	var tpl: Dictionary = {}
	for e: Dictionary in Blueprints.templates():
		if str(e["file"]) == file:
			tpl = e
	var design := ShareCode.decode(str(tpl["code"]))
	build.start_placing(design, label)
	await _frames(2)
	await click(at)
	var hv: HouseView = build.house
	_check(hv != null and GameState.construction.has(hv.data.id), "%s placed and on the build queue" % label)
	return hv


func _run_prologue() -> void:
	await _frames(5)
	build = world.get("build")
	rig = world.get("rig")
	var grid: WorldGrid = world.get("slice").grid
	for i in 120:
		for c in world.get_children():
			if c is PrologueHud:
				hud_card = c
		if hud_card != null:
			break
		await _frames(1)
	_check(SimHost.prologue != null and hud_card != null and hud_card.visible, "a new story game opens the prologue with its card")
	_check(_step_is("arrive"), "step 1: arrival")
	await look(Vector3(30.0, grid.height_at(30, 36), 36.0), 120.0, 50.0, 60.0)
	await _frames(6)
	await shot("m9_01_arrival")
	hud_card.call("_refresh")
	_check(hud_card.continue_button != null, "arrival waits for Continue")
	hud_card.continue_button.pressed.emit()
	await _frames(3)
	_check(_step_is("road"), "step 2: lay the main road")

	# The road: the ghost path first, then laid.
	await look(Vector3(40.0, grid.height_at(40, 36), 36.0), 180.0, 55.0, 55.0)
	await _frames(4)
	await shot("m9_02_ghost_path")
	world.call("open_roads")
	var road: RoadMode = world.get("road")
	_check(road.active and road.ghost_button.visible, "the Roads tool offers the ghost path")
	road.ghost_button.pressed.emit()
	await _frames(4)
	_check(SimHost.story_ctx.get("road", false), "the road is laid: %s" % road.message)
	road.close()
	await _frames(3)
	await shot("m9_03_road")
	_check(_step_is("store"), "step 3: build the general store")

	# The store, from the template, on the marked plot.
	world.call("enter_build_mode")
	await _frames(2)
	await look(Vector3(76.0, grid.height_at(76, 50), 50.0), 200.0, 58.0, 34.0)
	var store := await _place("general_store.json", Vector2(74.5, 51.0), "General store")
	var store_id: String = store.data.id
	hud_card.call("_refresh")
	await shot("m9_04_store_plan")
	for i in 240:
		await _run_clock(240)
		if not GameState.construction.has(store_id):
			break
	_check(not GameState.construction.has(store_id), "the crews finished the store by day %d (%s)" % [Clock.day, str(world.call("construction_status", store_id))])
	SimHost.refresh_story()
	var sc: Dictionary = SimHost.story_ctx.get("store", {})
	_check(bool(sc.get("door")) and bool(sc.get("window")) and bool(sc.get("exchange")), "the store has its front door, back window and exchange: %s" % str(sc))
	_check(_step_is("houses"), "step 4: three houses")
	_check(SimHost.household_in(store_id) == "h_hayward", "the Haywards move in to run the store")

	# Three houses.
	var ids: Array[String] = []
	for spot: Vector2 in [Vector2(88.5, 50.0), Vector2(98.5, 50.0), Vector2(88.5, 61.0)]:
		await look(Vector3(spot.x, grid.height_at(spot.x, spot.y), spot.y), 200.0, 58.0, 30.0)
		var hv := await _place("cottage_2br.json", spot, "Cottage")
		if hv != null:
			ids.append(hv.data.id)
	for i in 400:
		var pending := 0
		for id in ids:
			pending += 1 if GameState.construction.has(id) else 0
		if pending == 0:
			break
		await _run_clock(240)
	_check(ids.size() == 3, "three houses placed")
	SimHost.refresh_story()
	_check(int(SimHost.story_ctx.get("houses", 0)) >= 3, "three houses built and furnished by day %d" % Clock.day)
	_check(_step_is("families"), "step 5: approve the families")
	world.call("exit_build_mode")
	await _frames(3)
	await shot("m9_05_town_built")

	# Approve the families.
	var r1 := SimHost.offer_home("h_pike", ids[0])
	var r2 := SimHost.offer_home("h_kowalski", ids[1])
	_check(SimHost.living_count() == 10, "all ten residents live in the valley (%s, %s)" % [str(r1.get("reaction", "")), str(r2.get("reaction", ""))])
	SimHost.refresh_story()
	_check(_step_is("week"), "step 6: the first week")
	var anchor := int(SimHost.night["anchor"])
	_check(posmod(anchor, 7) == 5 and anchor >= Clock.day + 3, "the welcome dance is Saturday, day %d" % anchor)

	# The week, to the dance.
	await _run_to(anchor, 20 * 60 + 15)
	var mill: Array = SimHost.sim.town.landmark_tiles["lm_mill"]
	await look(Vector3(float(mill[1]), grid.height_at(mill[1], mill[2]), float(mill[2])), 200.0, 55.0, 40.0)
	await shot("m9_06_dance")
	await _run_to(anchor, 21 * 60 + 5)
	var st_run: Dictionary = SimHost.night.get("runner", {})
	_check(not st_run.is_empty(), "Len has slipped out of the dance")
	await _run_to(anchor, 22 * 60 + 36)
	var screen: InvestigationScreen = world.get("case_screen")
	_check(SimHost.investigation != null and screen != null and screen.visible, "the Haywards find the window open: the case opens")
	_check(_step_is("solve"), "step 8: The Cash Tin")
	_check(Clock.speed == 0, "time pauses on the alert")
	await _frames(6)
	await shot("m9_07_alert")

	# The case: a few taps, then the bot.
	var inv := SimHost.investigation
	var t0 := str((inv.traces()[0] as Dictionary)["id"])
	if screen.hotspots.has(t0):
		(screen.hotspots[t0] as Button).pressed.emit()
	await _frames(3)
	_check(inv.found.has(t0), "the first search turns up a trace")
	var res := SolverBot.play(inv)
	_check(bool(res.get("right", false)) and bool(res.get("complete", false)), "the case is solved: Len Pike, with every requirement proven")
	screen.call("_rebuild")
	await _frames(4)
	await shot("m9_08_solved")
	var trust0 := GameState.town_trust
	SimHost.bank_case()
	_check(GameState.town_trust > trust0, "Town Trust rises (%d to %d)" % [trust0, GameState.town_trust])
	_check(SimHost.case_done("case_00_cash_tin") and SimHost.investigation == null, "the case is closed")
	SimHost.refresh_story()
	_check(_step_is("lesson"), "step 9: a lesson learned")
	_check(not SimHost.prologue.is_locked("footpaths"), "footpaths and street lamps are unlocked")
	screen.visible = false   # the player closes the case file
	screen.closed.emit()
	await _frames(3)
	await look(Vector3(74.0, grid.height_at(74, 52), 52.0), 200.0, 52.0, 28.0)
	hud_card.call("_refresh")
	await shot("m9_09_lesson")
	hud_card.continue_button.pressed.emit()
	await _frames(3)
	_check(SimHost.prologue == null and SimHost.director_enabled, "the prologue is over and the crime director is on")
	print("HC_DEMO prologue day=%d trust=%d money=%d" % [Clock.day, GameState.town_trust, GameState.money])
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
