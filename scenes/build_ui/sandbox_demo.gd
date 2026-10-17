extends "res://scenes/build_ui/build_demo.gd"
## M3 acceptance demo: in a Sandbox save, builds a bare four-room cottage, then finishes it through
## the real tools: wallpaper, tiles and paint, a terracotta roof and chimney, a lace verandah with
## steps, trims, a gravel path, garden beds, plants, sheds, a Hills Hoist and fences with a gate. It
## exports the house as a share code, starts a fresh save and imports it, and checks the copy is
## identical. Prints HC_SHOT and HC_DEMO lines like the M2 demo (tools/look_test.mjs --scene sandbox_demo).

const SITE := Vector2(84, 47)


func _ready() -> void:
	GameState.reset()
	Settings.set_value("quality", "medium")
	GameState.mode = GameState.MODE_SANDBOX
	Clock.set_speed(0)
	Clock.set_minute(15 * 60 + 30)
	_make_world()
	_run_sandbox.call_deferred()


func _make_world() -> void:
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)


## Garden tools and placing work on the ground, not the floor.
func _plane_y(wx: float, wz: float) -> float:
	if build.placing != null or build.tool in BuildMode.GARDEN_TOOLS or build.house == null:
		var grid: WorldGrid = world.get("slice").grid
		return grid.height_at(wx, wz)
	return build.house.position.y + build.house.builder.level_y(build.level)


func w(x: float, z: float) -> Vector2:
	return Vector2(x, z)


func _run_sandbox() -> void:
	await _frames(5)
	build = world.get("build")
	rig = world.get("rig")
	world.call("enter_build_mode")
	await _frames(2)
	var grid: WorldGrid = world.get("slice").grid
	var focus := Vector3(88.5, grid.height_at(88, 50), 50.5)
	_check(GameState.is_sandbox(), "this is a Sandbox save")

	# A bare cottage: parlour, bedroom, kitchen and bathroom.
	await look(focus, 200.0, 60.0, 28.0)
	await tool("room", {"room_name": "Parlour", "room_paint": "cream", "room_height": 2.7, "room_floor": "floor_boards"})
	await drag(w(84, 47), w(89, 51))
	var hv: HouseView = build.house
	await tool("room", {"room_name": "Bedroom", "room_paint": "cream"})
	await drag(w(89, 47), w(93, 51))
	await tool("room", {"room_name": "Kitchen", "room_paint": "cream", "room_floor": "lino_checks"})
	await drag(w(84, 51), w(88, 54))
	await tool("room", {"room_name": "Bathroom", "room_paint": "white", "room_floor": "quarry_tiles"})
	await drag(w(88, 51), w(91, 54))
	_check(hv != null and hv.data.rooms(0).size() == 4, "four rooms")
	await tool("door", {"door_style": "front_door"})
	await click(w(86.0, 47))
	await tool("door", {"door_style": "four_panel"})
	await click(w(89, 49.0))
	await click(w(85.6, 51))
	await click(w(88, 52.5))
	await tool("door", {"door_style": "ledge_brace"})
	await click(w(85.0, 54))
	await tool("window", {"window_style": "double_hung"})
	await click(w(87.6, 47))
	await click(w(91.0, 47))
	await click(w(93, 49.0))
	await click(w(84, 52.5))
	await click(w(84, 49.0))
	await tool("window", {"window_style": "louvre"})
	await click(w(89.5, 54))
	_check(hv.data.openings(0).size() >= 11, "doors and windows in (%d)" % hv.data.openings(0).size())
	world.call("set_walls_mode", HouseView.WALLS_UP)
	await look(focus + Vector3(0, 0, -2), 195.0, 30.0, 26.0)
	await shot("m3_01_bare_cottage")
	world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)
	await look(focus, 200.0, 60.0, 24.0)

	# Inside: wallpaper in the parlour and bedroom, tiles to dado height in the kitchen, mint above.
	await tool("paint", {"paint_kind": "wallpaper", "wallpaper": "floral", "colourway": "cream_rose", "paint_scope": "room", "paint_part": "finish"})
	await click(w(85.5, 47.25))
	await tool("paint", {"wallpaper": "sprig", "colourway": "blue_white"})
	await click(w(91.5, 47.25))
	await tool("paint", {"paint_kind": "paint", "paint_colour": "mint"})
	await click(w(85.5, 53.75))
	await tool("paint", {"paint_kind": "lining", "lining": "wall_tiles", "paint_colour": "white", "paint_part": "dado", "dado_h": 1.2})
	await click(w(85.5, 53.75))
	var parlour := hv.data.room_at_tile(0, Vector2i(1, 1))
	var papered := 0
	for f: Array in BuildOps.room_faces(hv.data, 0, parlour):
		if str(BuildOps.pick_surface(hv.data, 0, f[0], f[1]).get("mat", "")) == "wallpaper":
			papered += 1
	_check(papered >= 14, "the parlour is papered all round (%d m)" % papered)
	var kitchen_face: Dictionary = BuildOps.pick_surface(hv.data, 0, HouseData.hkey(1, 7), "a")
	_check(kitchen_face.has("dado") and str(kitchen_face.get("paint", "")) == "mint", "kitchen tiled to dado height under mint paint")
	# Outside: cream weatherboards all round, Brunswick green trims.
	await tool("paint", {"paint_kind": "cladding", "cladding": "weatherboard", "paint_colour": "cream", "paint_scope": "house", "paint_part": "finish"})
	await click(w(88.0, 46.8))
	build.set_trim("brunswick_green")
	await _frames(1)
	await look(focus, 205.0, 62.0, 20.0)
	await shot("m3_02_interiors")

	# A terracotta hip roof, a chimney between the parlour and kitchen.
	await tool("roof", {"roof_mode": "auto", "roof_shape": "hip", "roof_material": "roof_terracotta", "roof_pitch": 30.0})
	await click(w(88.5, 50.0))
	var pieces := Roofs.pieces(hv.data)
	_check(not pieces.is_empty() and str(pieces[0]["material"]) == "roof_terracotta", "terracotta roof on")
	await tool("roof", {"roof_mode": "chimney"})
	await click(w(86.5, 51))
	_check(hv.data.chimneys.size() == 1, "chimney built")
	# A front verandah with cast iron lace, turned posts, a timber rail and lattice, and steps.
	await tool("verandah", {"v_mode": "add", "v_shape": "bullnose", "v_post": "turned_post", "v_lace": "lace", "v_rail": "timber",
		"v_lattice": true, "v_depth": 2.1, "v_colour": "cream"})
	await click(w(88.5, 46.8))
	_check(hv.data.verandahs.size() == 1, "front verandah added")
	await tool("verandah", {"v_mode": "steps"})
	await click(w(86.4, 45.6))
	_check(hv.data.verandahs.size() == 1 and (hv.data.verandahs[0]["steps"] as Array).size() == 1, "steps down from the front door")

	# The garden: a gravel path to the gate, beds, plants, sheds and the clothesline.
	await look(Vector3(88.5, grid.height_at(88, 46), 46.0), 200.0, 58.0, 34.0)
	await tool("terrain", {"terrain_op": "paint", "ground": "gravel"})
	await drag(w(86.5, 43.5), w(86.5, 36.5))
	await tool("terrain", {"terrain_op": "paint", "ground": "mud"})
	await drag(w(83.5, 41.5), w(85.5, 42.5))
	await drag(w(87.5, 41.5), w(90.5, 42.5))
	await tool("terrain", {"terrain_op": "raise", "terrain_radius": 2.5})
	await click(w(80.5, 45.5))
	await click(w(80.5, 45.5))
	await tool("terrain", {"terrain_op": "smooth"})
	await click(w(80.5, 45.5))
	_check(hv.data.ground.size() >= 15 and not hv.data.terrain.is_empty(), "path, beds and a rise in the front garden")
	var plants := [["rose", 84.0, 42.0], ["rose", 85.0, 42.0], ["rose", 88.0, 42.0], ["rose", 89.5, 42.0], ["lavender", 85.6, 39.0],
		["lavender", 87.4, 39.0], ["hydrangea", 82.5, 45.5], ["agapanthus", 91.5, 42.0], ["geranium", 92.5, 43.5], ["wattle", 80.5, 39.5],
		["apple_tree", 96.0, 40.5], ["birdbath", 82.0, 42.5], ["garden_bench", 91.5, 45.0], ["letterbox", 88.2, 36.8]]
	for p: Array in plants:
		await tool("garden", {"garden_kind": p[0], "garden_rot": 0.0})
		await click(w(p[1], p[2]))
	await look(Vector3(88.5, grid.height_at(88, 56), 56.0), 20.0, 55.0, 34.0)
	var back := [["hills_hoist", 86.0, 57.5], ["vegie_bed", 90.0, 57.5], ["lemon_tree", 81.5, 52.0], ["dunny", 96.0, 58.5],
		["woodshed", 81.5, 58.0], ["water_tank", 95.0, 52.5], ["woodpile", 84.0, 56.5], ["wheelbarrow", 92.5, 55.5]]
	for p2: Array in back:
		await tool("garden", {"garden_kind": p2[0], "garden_rot": 0.0})
		await click(w(p2[1], p2[2]))
	_check(hv.data.garden.size() >= 20, "plants, sheds and yard things placed (%d)" % hv.data.garden.size())
	# Fences: white pickets at the front with a gate on the path, palings down the sides, iron at the back.
	await look(Vector3(88.5, grid.height_at(88, 48), 48.0), 200.0, 62.0, 46.0)
	await tool("fence", {"fence_mode": "build", "fence_type": "picket"})
	await drag(w(79, 36), w(98, 36))
	await tool("fence", {"fence_type": "paling"})
	await drag(w(79, 36), w(79, 61))
	await drag(w(98, 36), w(98, 61))
	await tool("fence", {"fence_type": "corrugated"})
	await drag(w(79, 61), w(98, 61))
	await tool("fence", {"fence_mode": "gate"})
	await click(w(86.5, 36.0))
	var gate_key := HouseData.hkey(2, -11)
	_check(hv.data.fences.size() >= 60 and bool((hv.data.fences.get(gate_key, {}) as Dictionary).get("gate", false)), "fenced in, with a gate on the path (%d m)" % hv.data.fences.size())
	_check(hv.data.validate().is_empty(), "the house passes validation (%s)" % ", ".join(hv.data.validate()))
	build.selection.clear()
	world.call("set_walls_mode", HouseView.WALLS_UP)
	await look(Vector3(88.5, grid.height_at(88, 46), 46.0), 196.0, 26.0, 30.0)
	await shot("m3_03_finished_front")
	await look(Vector3(88.5, grid.height_at(88, 55), 55.0), 22.0, 34.0, 30.0)
	await shot("m3_04_backyard")
	await look(Vector3(86.0, grid.height_at(86, 45), 45.2), 205.0, 12.0, 9.0)
	await shot("m3_05_verandah")

	# Export, then import into a brand-new Sandbox save.
	var code := ShareCode.encode(hv.data)
	var fp := ShareCode.fingerprint(hv.data)
	var file := Blueprints.save("Demo cottage", hv.data)
	_check(code.length() > 100 and file != "", "share code made (%d characters) and saved to the library" % code.length())
	world.call("exit_build_mode")
	world.queue_free()
	await _frames(2)
	GameState.reset()
	GameState.mode = GameState.MODE_SANDBOX
	_make_world()
	await _frames(5)
	build = world.get("build")
	rig = world.get("rig")
	var fresh := (world.get("houses") as Array).filter(func(x: HouseView) -> bool: return not x.data.locked)
	_check(fresh.is_empty(), "the new save starts with an empty valley")
	world.call("enter_build_mode")
	await _frames(2)
	var design := ShareCode.decode(code)
	_check(design != null, "the share code reads back")
	build.start_placing(design, "the shared cottage")
	await look(focus, 200.0, 58.0, 34.0)
	await click(w(88, 50))
	var imported: HouseView = build.house
	_check(imported != null and ShareCode.fingerprint(imported.data) == fp, "the imported house and garden are identical to the original")
	_check(imported != null and imported.data.origin == Vector2i(SITE), "it stands where it was placed")
	world.call("exit_build_mode")
	world.call("set_walls_mode", HouseView.WALLS_UP)
	await look(Vector3(88.5, grid.height_at(88, 46), 46.0), 196.0, 26.0, 30.0)
	await shot("m3_06_imported_copy")
	Blueprints.remove(file)
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
