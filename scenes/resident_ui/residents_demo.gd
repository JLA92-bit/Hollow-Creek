extends "res://scenes/build_ui/build_demo.gd"
## M5 acceptance demo: a new story game with Agnes alone in the valley (the MPFB test character),
## three founding families waiting at the siding with their briefs, homes built for them, each family
## offered a house and reacting to it, then the clock runs: work at the mill and the store, visits,
## the wireless, bed. Marge gets her vegie patch, rent comes in on Monday, and a save round trip
## leaves the town exactly as it was. Prints HC_SHOT and HC_DEMO lines
## (tools/look_test.mjs --scene residents_demo).

var views: ResidentViews
var hud: Hud


func _ready() -> void:
	GameState.reset()
	SimHost.reset()
	Settings.set_value("quality", "medium")
	GameState.mode = GameState.MODE_STORY
	GameState.money = 1500
	Clock.set_speed(0)
	Clock.day = 0
	Clock.set_minute(7 * 60)
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	_run_town.call_deferred()


## Runs the clock to a day and minute, a game hour per frame so the figures keep up.
func run_to(day: int, minute: int) -> void:
	var target := day * 1440 + minute
	while Clock.day * 1440 + Clock.minute < target:
		var n := mini(60, target - (Clock.day * 1440 + Clock.minute))
		for i in n:
			Clock.advance_minute()
		await get_tree().process_frame


func _place(rid: String) -> String:
	var r: Dictionary = SimHost.sim.residents[rid]
	return str((r["action"] as Dictionary).get("place", "")) if (r["route"] as Array).is_empty() else "walking"


func _kind(rid: String) -> String:
	return str((SimHost.sim.residents[rid]["action"] as Dictionary).get("kind", ""))


func _triangles(n: Node) -> int:
	var t := 0
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var m := (c as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var arr := m.surface_get_arrays(i)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			t += idx.size() / 3 if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


func _perf(label: String) -> void:
	await _frames(20)
	print("HC_DEMO perf %s fps=%d draw_calls=%d triangles=%d sim_ms=%.2f" % [label, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), SimHost.tick_ms])


func _run_town() -> void:
	await _frames(5)
	rig = world.get("rig")
	hud = world.get("hud")
	views = world.get("residents")
	var sim := SimHost.sim
	var grid: WorldGrid = world.get("slice").grid
	_check(SimHost.active and views != null, "the town has its residents")
	_check(sim.residents["r_agnes"]["status"] == "living" and SimHost.living_count() == 1, "Agnes lives alone in the valley at first")
	_check(SimHost.waiting().size() == 3, "three founding families wait at the siding")
	await _frames(3)

	# Agnes, the MPFB test character, on Medium.
	var agnes := views.get_node("r_agnes") as Node3D
	var tris := _triangles(agnes)
	_check(agnes != null and agnes.scene_file_path.ends_with("agnes.glb"), "Agnes is drawn with her own MPFB model")
	_check(tris > 2000 and tris < 10000, "Agnes is under 10,000 triangles at LOD0 (%d)" % tris)
	var ap := agnes.find_children("*", "AnimationPlayer", true, false)
	_check(not ap.is_empty() and (ap[0] as AnimationPlayer).is_playing(), "and she's animated (%s)" % ((ap[0] as AnimationPlayer).current_animation if not ap.is_empty() else "none"))
	world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)
	hud.show_resident("r_agnes")
	var ap_pos := views.position_of("r_agnes")
	await look(ap_pos + Vector3(0, 0.9, 0), 215.0, 22.0, 5.5)
	await _perf("agnes_close")
	await shot("m5_01_agnes")

	# Houses for the families (built in Sandbox style here; M4 showed the crews at work).
	for h: HouseData in DemoTown.houses():
		world.call("add_house", h)
	await _frames(3)
	SimHost.rebuild_town()
	_check(SimHost.vacant_houses().size() == 3, "three empty houses ready")
	hud.show_resident("")
	hud.toggle_residents()
	await look(Vector3(84.0, grid.height_at(84, 50), 50.0), 200.0, 48.0, 40.0)
	await shot("m5_02_applications")
	var verdicts := {}
	for hid: String in ["h_hayward", "h_pike", "h_kowalski"]:
		var res := SimHost.offer_home(hid, DemoTown.homes()[hid])
		verdicts[hid] = str(res.get("verdict", ""))
		print("HC_DEMO %s: %s (%s)" % [hid, res.get("verdict", "?"), ", ".join(PackedStringArray((res.get("pros", []) as Array) + (res.get("cons", []) as Array)))])
	_check(SimHost.waiting().is_empty() and SimHost.living_count() == sim.residents.size(), "every family has moved in (%d residents)" % SimHost.living_count())
	_check(verdicts.values().all(func(v: String) -> bool: return v in HomeLife.VERDICTS), "each family reacted to their home: %s" % str(verdicts))
	_check((GameState.history.get("house_pike", []) as Array).size() == 1, "the Pikes' cottage has a history card")
	var rent_total := 0
	for hid: String in sim.households:
		rent_total += int(sim.households[hid].get("rent", 0))
	_check(rent_total > 0, "rent agreed: £%d a week in all" % rent_total)
	hud.toggle_residents()

	# Marge's vegie patch, dug into the Pikes' garden.
	var pike: HouseView = null
	for hv: HouseView in world.get("houses"):
		if hv.data.id == "house_pike":
			pike = hv
	var b := pike.data.bounds()
	var dug := 0
	for x in [b.position.x + 0.5, b.position.x + 3.0, b.position.x + 5.5]:
		if GardenOps.place_item(pike.data, "vegie_bed", Vector2(x + 1.0, b.end.y + 2.5))["ok"]:
			dug += 1
	world.call("house_changed", pike.data)
	pike.refresh_display()
	_check(dug >= 2, "two vegie beds dug behind the Pikes' cottage")
	var trust := GameState.town_trust

	# The working day: Tuesday morning at the mill and the store.
	await run_to(1, 6 * 60 + 30)
	_check(int(sim.wishes["w_marge_vegies"]["met"]) >= 0, "Marge's wish came true overnight")
	_check(GameState.town_trust > trust, "and the town trusts the Administrator a little more (%d to %d)" % [trust, GameState.town_trust])
	world.call("set_walls_mode", HouseView.WALLS_UP)
	# Trips are short at 72 m a minute; step the clock until somebody is out walking.
	var walker := ""
	for i in 180:
		for rid: String in ["r_len", "r_tomasz", "r_davey", "r_piotr", "r_june", "r_frank"]:
			if walker == "" and _place(rid) == "walking" and str(sim.residents[rid]["house"]) == "":
				walker = rid
		if walker != "":
			break
		Clock.advance_minute()
	await get_tree().process_frame
	_check(walker != "", "%s is out walking at %s" % [walker, Clock.time_label(Clock.minute)])
	hud.show_resident(walker)
	await look(views.position_of(walker) + Vector3(0, 0.8, 0), 200.0, 50.0, 16.0)
	await _perf("town_morning")
	await shot("m5_03_morning")
	hud.show_resident("")
	await run_to(1, 10 * 60)
	_check(_place("r_len") == "lm_mill" and _place("r_tomasz") == "lm_mill", "Len and Tomasz are at the mill at 10")
	_check(_place("r_frank") == "house_store:shop" and _place("r_edna") == "house_store:exchange", "Frank minds the shop, Edna the exchange")
	world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)
	hud.show_resident("r_edna")
	var store_at := views.position_of("r_edna")
	await look(store_at + Vector3(0, 0.8, 0), 200.0, 40.0, 14.0)
	await shot("m5_04_store")
	hud.show_resident("")

	# Evening and night.
	await run_to(1, 19 * 60 + 40)
	var home_now := 0
	for rid: String in sim.residents:
		if str(sim.residents[rid]["house"]) != "" and not ["work"].has(_kind(rid)):
			home_now += 1
	await look(Vector3(84.0, grid.height_at(84, 50), 50.0), 205.0, 52.0, 22.0)
	await _perf("evening")
	await shot("m5_05_evening")
	await run_to(2, 3 * 60)
	var asleep := 0
	for rid: String in sim.residents:
		if _kind(rid) == "sleep":
			asleep += 1
	_check(asleep == sim.residents.size(), "everyone is in bed at 3 am (%d of %d)" % [asleep, sim.residents.size()])
	await shot("m5_06_night")

	# Rent on Monday, and a save round trip.
	var money := GameState.money
	await run_to(7, 9 * 60)
	_check(GameState.money - money == rent_total, "Monday's rent banked: £%d" % (GameState.money - money))
	var before := JSON.stringify(SimHost.snapshot(), "", true, true)
	var save := SaveSystem.build_save()
	SaveSystem.apply_save(JSON.parse_string(JSON.stringify(save, "", true, true)))
	var after := JSON.stringify(SimHost.snapshot(), "", true, true)
	_check(JSON.stringify(JSON.parse_string(before)) == JSON.stringify(JSON.parse_string(after)), "a save and load leaves the town exactly as it was")
	SimHost.start(world)
	sim = SimHost.sim
	await run_to(7, 12 * 60)
	var lately: Array = []
	for e: Dictionary in sim.events.slice(maxi(0, sim.events.size() - 6)):
		lately.append(e["text"])
	print("HC_DEMO lately ", lately)
	hud.show_resident("r_marge")
	await look(views.position_of("r_marge") + Vector3(0, 0.8, 0), 200.0, 35.0, 12.0)
	await shot("m5_07_marge")
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
