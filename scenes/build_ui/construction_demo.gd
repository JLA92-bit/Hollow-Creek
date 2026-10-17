extends "res://scenes/build_ui/build_demo.gd"
## M4 acceptance demo: in the story, designs a three-room cottage with the real tools, furnishes it
## from the catalogue with live score previews, recolours pieces with the Design tool, checks the home
## scores, then runs the clock while the crews build it: blueprints, stumps, frames, roof, cladding,
## joinery and paint over in-game days. Prints HC_SHOT and HC_DEMO lines
## (tools/look_test.mjs --scene construction_demo).


func _ready() -> void:
	GameState.reset()
	Settings.set_value("quality", "medium")
	GameState.mode = GameState.MODE_STORY
	GameState.money = 1500
	Clock.set_speed(0)
	Clock.day = 0
	Clock.set_minute(9 * 60)
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	_run_story.call_deferred()


func _plane_y(wx: float, wz: float) -> float:
	if build.house == null or build.tool in BuildMode.GARDEN_TOOLS:
		var grid: WorldGrid = world.get("slice").grid
		return grid.height_at(wx, wz)
	return build.house.position.y + build.house.builder.level_y(build.level)


func w(x: float, z: float) -> Vector2:
	return Vector2(x, z)


func buy(item: String, at: Vector2, rot: float = 0.0) -> void:
	await tool("buy", {"buy_rot": rot, "buy_snap": "half"})
	build.choose_item(item)
	var n := build.house.data.objects.size() if build.house else 0
	await click(at)
	if build.house == null or build.house.data.objects.size() == n:
		print("HC_DEMO note: %s at %s didn't go in" % [item, at])


## Runs the clock until the house reaches a stage (or is finished), a few hours at a time.
func run_until(hv: HouseView, stage: int, max_days: int = 40) -> int:
	var limit := Clock.day + max_days
	while Clock.day < limit:
		for i in 120:
			Clock.advance_minute()
		await get_tree().process_frame
		var p: Dictionary = GameState.construction.get(hv.data.id, {})
		var s := int(p.get("shown_stage", Construction.STAGES.size())) if not p.is_empty() else Construction.STAGES.size()
		if s >= stage:
			return s
	return -99


func _run_story() -> void:
	await _frames(5)
	build = world.get("build")
	rig = world.get("rig")
	world.call("enter_build_mode")
	await _frames(2)
	var grid: WorldGrid = world.get("slice").grid
	var focus := Vector3(88.5, grid.height_at(88, 51), 51.0)
	_check(not GameState.is_sandbox(), "a story game")

	# Design the cottage.
	await look(focus, 200.0, 60.0, 28.0)
	await tool("room", {"room_name": "Kitchen", "room_paint": "mint", "room_height": 2.7, "room_floor": "lino_checks"})
	await drag(w(84, 47), w(89, 51))
	var hv: HouseView = build.house
	await tool("room", {"room_name": "Bedroom", "room_paint": "rose", "room_floor": "floor_boards"})
	await drag(w(89, 47), w(93, 51))
	await tool("room", {"room_name": "Living room", "room_paint": "cream", "room_floor": "floor_boards"})
	await drag(w(84, 51), w(89, 55))
	await tool("door", {"door_style": "front_door", "lock_night": true})
	await click(w(86.0, 47))
	await tool("door", {"door_style": "four_panel", "lock_night": false})
	await click(w(89, 49.0))
	await click(w(86.5, 51))
	await tool("window", {"window_style": "double_hung", "latch_night": true})
	await click(w(84, 49.0))
	await click(w(91.0, 47))
	await click(w(93, 49.0))
	await click(w(86.5, 55))
	await click(w(84, 53.0))
	_check(hv.data.rooms(0).size() == 3 and hv.data.openings(0).size() >= 8, "three rooms with doors and windows")
	_check(GameState.construction.has(hv.data.id), "the design went on the build queue")
	var status: Dictionary = world.call("construction_status", hv.data.id)
	_check(bool(status.get("waiting", false)), "materials ordered for tomorrow")
	world.call("set_walls_mode", HouseView.WALLS_UP)
	await look(focus, 200.0, 40.0, 26.0)
	await shot("m4_01_blueprints")
	world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)

	# Furnish it from the catalogue.
	await look(focus, 200.0, 62.0, 22.0)
	var money_before := GameState.money
	await buy("wood_stove", w(84.7, 50.4), 90.0)
	await buy("kitchen_sink", w(86.5, 47.5))
	await buy("icebox", w(88.5, 50.4), 180.0)
	await buy("laminex_table", w(86.5, 49.25))
	await buy("kitchen_chair", w(86.0, 48.5), 180.0)
	await buy("kitchen_chair", w(87.0, 50.0))
	await buy("wireless_set", w(86.75, 49.25))
	await buy("iron_bed", w(91.0, 49.75))
	await buy("wardrobe", w(92.5, 47.75), -90.0)
	await buy("chest_of_drawers", w(89.75, 47.5))
	await buy("settee", w(86.5, 54.25), 180.0)
	await buy("armchair", w(84.75, 52.25), 90.0)
	await buy("standard_lamp", w(88.5, 54.5))
	await buy("picture_frame", w(86.5, 51.2))
	await buy("pendant_light", w(86.5, 53.0))
	var placed := hv.data.objects.size()
	_check(placed >= 14, "furniture bought (%d pieces, £%d)" % [placed, money_before - GameState.money])
	var radio := {}
	for o: Dictionary in hv.data.objects:
		if Catalogue.id_of(o) == "wireless_set":
			radio = o
	_check(not radio.is_empty() and float(radio.get("y", 0.0)) > 0.7, "the wireless stands on the table")
	# The Design tool: a rose chenille bedspread, a red laminex table top.
	build.choose_item("")
	await click(w(91.0, 50.4))
	_check(build.selected_objects().size() == 1 and Catalogue.id_of(build.selected_objects()[0]) == "iron_bed", "the bed is selected")
	build.set_object_slot("blanket", {"mat": "chenille", "colour": "#E9C3C0"})
	await click(w(86.0, 49.6))
	build.set_object_slot("laminex", {"colour": "#4F86B0"})
	await _frames(2)
	var bed: Dictionary = {}
	for o2: Dictionary in hv.data.objects:
		if Catalogue.id_of(o2) == "iron_bed":
			bed = o2
	_check(str(Catalogue.slot_value(bed, "blanket")["colour"]) == "#E9C3C0", "the bedspread is rose")
	var scores := HomeScores.compute(hv.data)
	print("HC_DEMO scores ", scores)
	_check(int(scores["comfort"]) >= 70 and int(scores["warmth"]) >= 50 and int(scores["light"]) >= 50 and int(scores["space"]) >= 75 and int(scores["privacy"]) >= 60,
		"the furnished cottage scores as expected (%s)" % str(scores))
	build.selection.clear()
	world.call("exit_build_mode")

	# Run the clock: the crews build it in stages.
	world.call("set_walls_mode", HouseView.WALLS_UP)
	var outside := Vector3(88.5, grid.height_at(88, 48), 48.5)
	var start_day := Clock.day
	var s := await run_until(hv, Construction.STAGE_INDEX["floor_frame"])
	_check(s >= Construction.STAGE_INDEX["stumps"], "the materials came and the stumps went in")
	await look(outside, 205.0, 34.0, 22.0)
	await shot("m4_02_floor_frame")
	s = await run_until(hv, Construction.STAGE_INDEX["wall_frames"])
	await shot("m4_03_wall_frames")
	s = await run_until(hv, Construction.STAGE_INDEX["roofing"])
	await shot("m4_04_roof_frame")
	s = await run_until(hv, Construction.STAGE_INDEX["joinery"])
	_check(s >= Construction.STAGE_INDEX["cladding"], "clad and lined")
	await shot("m4_05_cladding")
	s = await run_until(hv, Construction.STAGES.size())
	_check(not GameState.construction.has(hv.data.id), "finished after %d days" % (Clock.day - start_day))
	_check(ShareCode.fingerprint(hv.shown) == ShareCode.fingerprint(hv.data), "the house as built matches the design")
	await shot("m4_06_finished")
	world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)
	Clock.set_minute(19 * 60 + 30)
	await look(focus, 205.0, 58.0, 18.0)
	await shot("m4_07_furnished_evening")
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
