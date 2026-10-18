extends "res://scenes/resident_ui/residents_demo.gd"
## M6 acceptance demo: a scripted night. The families move in; on Tuesday night Agnes sits up late
## by her lamp while everyone else sleeps, so only her room is lit, inside and out. Just after
## midnight Frank goes past her window carrying a cash tin, and then drops it with a crash. Agnes
## remembers him with the confidence the rules give for that distance and light, the crash wakes
## the nearest sleepers, and the overlays show the light, her sightlines, the morning's routes and
## the bootprints after rain. Prints HC_SHOT and HC_DEMO lines (?scene=night_demo).


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
	_run_night.call_deferred()


## Agnes's lamp-lit room with a bare window: the tile inside, the tile outside, and which way is out.
func _agnes_window(sim: Sim) -> Dictionary:
	var sight := sim.town.sight
	var ids := sight.rooms.keys()
	ids.sort()
	for rid: String in ids:
		var room: Dictionary = sight.rooms[rid]
		if room["house"] != SimHost.COTTAGE_ID or int(room["lamps"]) == 0:
			continue
		for w: Dictionary in room["windows"]:
			if sight.curtains.has(str(w["edge"])):
				continue
			var out: Vector2i = w["out"]
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if sight.room_at(out + d) == rid and sight.room_at(out - d * 2) == "":
					return {"room": rid, "inside": out + d, "out": out, "dir": -d}
	return {}


func _lamps_on(house_id: String) -> int:
	for hv: HouseView in world.get("houses"):
		if hv.data.id == house_id:
			return (hv.lit_filter as Dictionary).size() if hv.lit_filter is Dictionary else -1
	return -1


func _run_night() -> void:
	await _frames(5)
	rig = world.get("rig")
	hud = world.get("hud")
	views = world.get("residents")
	var overlays: DebugOverlays = world.get("overlays")
	for h: HouseData in DemoTown.houses():
		world.call("add_house", h)
	await _frames(2)
	SimHost.rebuild_town()
	for hid: String in ["h_hayward", "h_pike", "h_kowalski"]:
		SimHost.offer_home(hid, DemoTown.homes()[hid])
	var sim := SimHost.sim
	_check(SimHost.living_count() == 10, "ten residents at home")

	# Tuesday night. Agnes sits up by her window; everyone else goes to bed.
	await run_to(1, 21 * 60)
	var w := _agnes_window(sim)
	_check(not w.is_empty(), "Agnes has a lamp-lit room with a window")
	var inside: Vector2i = w["inside"]
	sim.direct("r_agnes", [0, inside.x + 0.5, inside.y + 0.5], SimHost.COTTAGE_ID, "sit_up", 260)
	await run_to(2, 20)
	var awake := 0
	for rid: String in sim.residents:
		if Memories.state(sim.residents[rid])["awake"]:
			awake += 1
	_check(awake == 1 and Memories.state(sim.residents["r_agnes"])["awake"], "only Agnes is up at 12:20 am")
	var lit := SimHost.lit_rooms()
	_check(lit.size() == 1 and lit.has(w["room"]), "one lamp lit in the whole town: hers")
	_check(_lamps_on(SimHost.COTTAGE_ID) == 1 and _lamps_on("house_store") == 0 and _lamps_on("house_pike") == 0, "and only her lamp is drawn")
	var grid: WorldGrid = world.get("slice").grid
	var out: Vector2i = w["out"]
	var view_at := Vector3(out.x + 0.5, grid.height_at(out.x, out.y), out.y + 0.5)
	world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)
	overlays.set_mode("light")
	await look(view_at, 200.0, 55.0, 26.0)
	await shot("m6_01_light_at_night")

	# Frank comes past with the cash tin, 2 m outside her window.
	var past: Vector2i = out + (w["dir"] as Vector2i) * 2
	sim.direct("r_frank", [0, past.x + 0.5, past.y + 0.5], "", "loiter", 6, "a cash tin")
	await run_to(2, 32)
	var memory: Dictionary = {}
	for m: Dictionary in sim.residents["r_agnes"]["memories"]:
		if m["subject"] == "r_frank":
			memory = m
	_check(not memory.is_empty(), "Agnes saw Frank: %s" % Memories.describe(sim, memory) if not memory.is_empty() else "Agnes saw Frank")
	if not memory.is_empty():
		var seen_at := Vector2i(int(memory["tile"][0]), int(memory["tile"][1]))
		var d := Vector2(inside).distance_to(Vector2(seen_at))
		var lux := sim.light_now().at(seen_at)
		var expected := (0.9 - 0.4 * d / SightMap.NIGHT_LIT_RANGE) * lerpf(0.6, 1.0, lux) + 0.2 - 0.1
		print("HC_DEMO memory ", memory)
		_check(str(memory["detail"]) == "carrying a cash tin", "carrying a cash tin")
		_check(absf(float(memory["confidence"]) - expected) < 0.011, "with the confidence the rules give: %.2f (%.1f m, light %.2f, Observant, elderly at night) = %s" % [expected, d, lux, Memories.confidence_word(expected)])
	overlays.set_mode("sight")
	views.selected = "r_agnes"
	await shot("m6_02_agnes_sightlines")

	# He drops it: a crash in the night.
	var frank_tile := Memories.tile_of(sim.residents["r_frank"])
	var heard := Memories.noise(sim, frank_tile, "a crash of tin")
	print("HC_DEMO heard ", heard)
	_check(heard.has("r_agnes"), "Agnes heard the crash")
	var woke := 0
	for rid: String in heard:
		if rid != "r_agnes" and str(sim.residents[rid]["action"].get("kind", "")) == "idle":
			woke += 1
	_check(not heard.is_empty(), "%d heard it, %d woken" % [heard.size(), woke])
	sim.direct("r_frank", sim.town.homes["house_store"]["living"], "house_store", "potter", 5)
	overlays.set_mode("off")
	hud.show_resident("r_agnes")
	await look(Vector3(inside.x + 0.5, grid.height_at(inside.x, inside.y) + 0.8, inside.y + 0.5), 200.0, 40.0, 9.0)
	await shot("m6_03_agnes_remembers")
	hud.show_resident("")

	# Morning: the routes to work, and rain for the bootprints.
	await run_to(2, 6 * 60 + 45)
	overlays.set_mode("routes")
	world.call("set_walls_mode", HouseView.WALLS_UP)
	await look(Vector3(70.0, grid.height_at(70, 40), 40.0), 210.0, 62.0, 48.0)
	await shot("m6_04_routes")
	await run_to(2, 7 * 60)
	world.call("set_raining", true)
	await run_to(2, 12 * 60)
	world.call("set_raining", false)
	await run_to(2, 13 * 60)
	var prints := 0
	for k: String in sim.traces:
		prints += (sim.traces[k] as Array).size()
	_check(prints > 50, "bootprints all over town after a wet day (%d)" % prints)
	await run_to(2, 16 * 60)  # mill shifts end at 3:30 pm
	var cards := 0
	for c: Dictionary in sim.records["time_cards"]:
		if int(c["day"]) == 2 and int(c["out"]) > 0:
			cards += 1
	var hands := 0
	for rid: String in sim.residents:
		hands += 1 if str((sim.data["jobs"] as Dictionary).get(sim.residents[rid]["job"], {}).get("place", "")) == "lm_mill" else 0
	print("HC_DEMO time cards ", sim.records["time_cards"].filter(func(c: Dictionary) -> bool: return int(c["day"]) == 2))
	_check(cards == hands, "a time card for each of the %d mill hands on Wednesday" % hands)
	print("HC_DEMO ledger ", sim.records["ledger"].slice(0, 4))
	print("HC_DEMO exchange ", sim.records["exchange"].slice(0, 4))
	# Look where the most feet went.
	var busiest := ""
	for k: String in sim.traces:
		if busiest == "" or (sim.traces[k] as Array).size() > (sim.traces[busiest] as Array).size():
			busiest = k
	var bp := busiest.split(",")
	overlays.set_mode("prints")
	await look(Vector3(float(bp[0]), grid.height_at(float(bp[0]), float(bp[1])), float(bp[1])), 200.0, 65.0, 22.0)
	await shot("m6_05_prints_after_rain")
	overlays.set_mode("off")
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
