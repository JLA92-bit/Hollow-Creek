extends Node
## M2 acceptance demo: builds a two-storey shop with a residence above and a cottage on stumps from
## scratch by driving the real build tools with mouse events (press, drag, release), edits them (an
## L-shaped room, a pushed wall, a moved room, floors, stairs), then undoes every step. Prints
## HC_SHOT <name> for screenshots (tools/look_test.mjs --scene build_demo) and HC_DEMO lines with checks.

var world: Node3D
var build: BuildMode
var rig: CameraRig
var checks: Array[String] = []
var failures := 0


func _ready() -> void:
	GameState.reset()
	Settings.set_value("quality", "medium")
	GameState.mode = GameState.MODE_STORY
	GameState.money = 1500
	Clock.set_speed(0)
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, text: String) -> void:
	checks.append(("PASS " if ok else "FAIL ") + text)
	if not ok:
		failures += 1
	print("HC_DEMO ", "PASS " if ok else "FAIL ", text)


# --- Input ---------------------------------------------------------------------------------------

func _plane_y(wx: float, wz: float) -> float:
	if build.house != null:
		return build.house.position.y + build.house.builder.level_y(build.level)
	var grid: WorldGrid = world.get("slice").grid
	return grid.height_at(wx, wz)


func _screen(w: Vector2) -> Vector2:
	return rig.camera.unproject_position(Vector3(w.x, _plane_y(w.x, w.y), w.y))


func _send(ev: InputEvent) -> void:
	get_viewport().push_input(ev, true)


func _mouse_button(pos: Vector2, pressed: bool, shift: bool = false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.shift_pressed = shift
	_send(ev)


func _mouse_move(pos: Vector2, shift: bool = false) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.shift_pressed = shift
	_send(ev)


## Rectangles of the interface panels that would catch clicks.
func _panel_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var hud: Node = world.get("hud")
	if hud == null:
		return out
	for c in hud.find_children("*", "PanelContainer", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree():
			out.append(ctl.get_global_rect().grow(8.0))
	return out


## Like a player would, pull the camera back until the points to click are clear of the panels.
func _ensure_clear(points: Array[Vector2]) -> void:
	for attempt in 8:
		var blocked := false
		var vp := get_viewport().get_visible_rect()
		for w in points:
			var sp := _screen(w)
			if not vp.grow(-20.0).has_point(sp):
				blocked = true
			for r in _panel_rects():
				if r.has_point(sp):
					blocked = true
		if not blocked:
			return
		rig.set_view(rig.focus, rig.yaw, rig.pitch, rig.distance * 1.18)
		await _frames(2)


## Press at a, drag through a few points to b, release. Positions in world tiles (x, z).
func drag(a: Vector2, b: Vector2, shift: bool = false) -> void:
	await _ensure_clear([a, b, a.lerp(b, 0.5)] as Array[Vector2])
	var sa := _screen(a)
	_mouse_move(sa, shift)
	await _frames(1)
	_mouse_button(sa, true, shift)
	await _frames(1)
	for i in range(1, 5):
		var p := a.lerp(b, i / 4.0)
		_mouse_move(_screen(p), shift)
		await _frames(1)
	_mouse_button(_screen(b), false, shift)
	await _frames(2)


func click(a: Vector2) -> void:
	await drag(a, a)


func tool(t: String, opts: Dictionary = {}) -> void:
	build.set_tool(t)
	for k: String in opts:
		build.options[k] = opts[k]
	await _frames(1)


func look(focus: Vector3, yaw: float, pitch: float, dist: float) -> void:
	rig.set_view(focus, yaw, pitch, dist)
	await _frames(3)


func shot(name: String) -> void:
	await _frames(4)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 600:
		await get_tree().process_frame
	print("HC_SHOT ", name)
	if not OS.has_feature("web"):
		# Desktop runs (xvfb-run, opengl3) can save quick check shots: HC_SHOT_DIR=path.
		var dir := OS.get_environment("HC_SHOT_DIR")
		if dir != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
		await _frames(2)
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		if str(JavaScriptBridge.eval("window.hcAck || ''")) == name:
			return


# --- The demo ------------------------------------------------------------------------------------

func _run() -> void:
	await _frames(5)
	build = world.get("build")
	rig = world.get("rig")
	world.call("enter_build_mode")
	await _frames(2)
	var undo_start := build.undo.size()
	var money_start := GameState.money
	var grid: WorldGrid = world.get("slice").grid

	# The general store on the pegged plot: a shop, a storeroom and the exchange room.
	var shop_focus := Vector3(73.5, grid.height_at(73, 50), 50)
	await look(shop_focus, 200.0, 58.0, 30.0)
	await tool("room", {"room_name": "Shop", "room_paint": "cream", "room_height": 3.0, "room_floor": "floor_boards"})
	await drag(Vector2(69, 45), Vector2(77, 51))
	_check(build.house != null and build.house.data.rooms(0).size() == 1, "room tool made the shop")
	await tool("room", {"room_name": "Storeroom", "room_floor": "concrete"})
	await drag(Vector2(69, 51), Vector2(74, 54))
	await tool("room", {"room_name": "Exchange", "room_paint": "duck_egg", "room_floor": "lino_checks"})
	await drag(Vector2(74, 51), Vector2(77, 54))
	var shop: HouseView = build.house
	_check(shop.data.rooms(0).size() == 3, "three ground-floor rooms")
	# Front door, two shop windows, inner doors, a back door and windows.
	await tool("door", {"door_style": "front_door"})
	await click(Vector2(73.0, 45))
	await tool("window", {"window_style": "shop_window"})
	await click(Vector2(70.9, 45))
	await click(Vector2(75.3, 45))
	await tool("door", {"door_style": "four_panel"})
	await click(Vector2(71.5, 51))
	await click(Vector2(74, 52.5))
	await tool("door", {"door_style": "ledge_brace"})
	await click(Vector2(70.5, 54))
	await tool("window", {"window_style": "double_hung"})
	await click(Vector2(77, 52.5))
	await click(Vector2(69, 52.5))
	await click(Vector2(77, 47.5))
	_check(shop.data.openings(0).size() >= 9, "doors and windows placed on the ground floor (%d)" % shop.data.openings(0).size())
	await shot("m2_01_shop_ground_floor")

	# A residence upstairs.
	build.add_storey(true)
	await _frames(2)
	_check(build.level == 1 and shop.data.has_storey(1), "first floor added")
	await tool("room", {"room_name": "Living room", "room_paint": "butter", "room_height": 2.7, "room_floor": "floor_boards"})
	await drag(Vector2(69, 45), Vector2(74, 49))
	await tool("room", {"room_name": "Bedroom", "room_paint": "rose"})
	await drag(Vector2(74, 45), Vector2(77, 49))
	await tool("room", {"room_name": "Kitchen", "room_paint": "mint", "room_floor": "lino_checks"})
	await drag(Vector2(69, 49), Vector2(73, 54))
	await tool("room", {"room_name": "Second bedroom", "room_paint": "sky", "room_floor": "pine_boards"})
	await drag(Vector2(73, 49), Vector2(77, 54))
	_check(shop.data.rooms(1).size() == 4, "four rooms upstairs")
	await tool("door", {"door_style": "four_panel"})
	await click(Vector2(74, 47.0))
	await click(Vector2(71.0, 49))
	await click(Vector2(75.0, 49))
	await tool("window", {"window_style": "double_hung"})
	await click(Vector2(71.5, 45))
	await click(Vector2(75.5, 45))
	await click(Vector2(77, 51.5))
	await click(Vector2(70.5, 54))
	await click(Vector2(75.0, 54))
	# Stairs from the shop floor, rising north along the west wall.
	build.set_level(0)
	await _frames(1)
	await tool("stairs", {"stairs_kind": "straight", "stairs_dir": "N"})
	await click(Vector2(69.5, 50.5))
	_check(shop.data.stairs(0).size() == 1, "stairs placed")
	var path := HousePathing.build(shop.data)
	_check(path.reachable(0, Vector2i(4, -1), 1, Vector2i(6, 2)), "you can walk from the street, through the shop and up the stairs to the bedroom")
	build.set_level(1)
	await look(shop_focus + Vector3(0, 3.3, 0), 200.0, 60.0, 28.0)
	await shot("m2_02_shop_residence_above")
	build.set_level(0)
	await _frames(2)

	# A cottage on stumps, east of the store.
	var cottage_focus := Vector3(88.0, grid.height_at(88, 50), 50)
	await look(cottage_focus, 210.0, 58.0, 26.0)
	await tool("room", {"room_name": "Living room", "room_paint": "sage", "room_height": 2.7, "room_floor": "floor_boards"})
	await drag(Vector2(84, 47), Vector2(88, 51))
	var cottage: HouseView = build.house
	_check(cottage != shop and cottage != null, "a new house was started")
	await tool("room", {"room_name": "Bedroom", "room_paint": "rose"})
	await drag(Vector2(88, 47), Vector2(91, 51))
	# Extend the living room into an L-shape for the kitchen end.
	await tool("room", {"room_floor": "lino_checks"})
	await drag(Vector2(84, 51), Vector2(87, 53), true)
	_check(cottage.data.rooms(0).size() == 2, "L-shaped living and kitchen joined the living room")
	# Push the bedroom's east wall out a metre.
	await tool("select")
	await drag(Vector2(91, 49.0), Vector2(92, 49.0))
	var bed := cottage.data.room_at_tile(0, Vector2i(5, 1))
	_check(not bed.is_empty() and is_equal_approx(float(bed["area"]), 16.0), "pushed the bedroom wall out to 4 x 4")
	# Raise the stumps for the slope, then doors, windows and a lino floor.
	build.call("_commit", "Stump height", func(h: HouseData) -> Dictionary: return BuildOps.set_foundation(h, "stumps", 0.9))
	await tool("door", {"door_style": "front_door"})
	await click(Vector2(86.0, 47))
	await tool("door", {"door_style": "four_panel"})
	await click(Vector2(88, 49.5))
	await tool("door", {"door_style": "ledge_brace"})
	await click(Vector2(85.5, 53))
	await tool("window", {"window_style": "double_hung"})
	await click(Vector2(84, 49.0))
	await click(Vector2(90.0, 47))
	await click(Vector2(92, 49.0))
	await click(Vector2(87, 52.0))
	await tool("floor", {"floor": "quarry_tiles", "floor_mode": "tile"})
	await drag(Vector2(84.5, 52.5), Vector2(86.5, 52.5))
	_check(cottage.data.validate().is_empty(), "the cottage passes validation (%s)" % ", ".join(cottage.data.validate()))
	build.selection.clear()
	await look(cottage_focus, 210.0, 55.0, 24.0)
	await shot("m2_03_cottage_cutaway")
	world.call("set_walls_mode", HouseView.WALLS_UP)
	await look(Vector3(80.5, grid.height_at(80, 50), 50), 215.0, 32.0, 34.0)
	await shot("m2_04_shop_and_cottage")
	world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)

	# Undo every step.
	var steps := build.undo.size() - undo_start
	_check(steps >= 30, "recorded %d undo steps" % steps)
	while build.undo.size() > undo_start:
		build.do_undo()
		await _frames(1)
	var player_houses := (world.get("houses") as Array).filter(func(hv: HouseView) -> bool: return not hv.data.locked)
	_check(player_houses.is_empty(), "undoing every step leaves an empty valley")
	_check(GameState.money == money_start, "every pound refunded (£%d)" % GameState.money)
	await shot("m2_05_all_undone")
	# Redo them all to show the result is reproducible.
	while build.undo.can_redo():
		build.do_redo()
		await _frames(1)
	var again := (world.get("houses") as Array).filter(func(hv: HouseView) -> bool: return not hv.data.locked)
	_check(again.size() == 2, "redo rebuilds both houses")
	world.call("exit_build_mode")
	world.call("set_walls_mode", HouseView.WALLS_UP)
	await look(Vector3(80.5, grid.height_at(80, 50), 50), 215.0, 32.0, 34.0)
	await shot("m2_06_redone")
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
