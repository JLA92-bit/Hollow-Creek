extends Node3D
## The valley: terrain, creek, trees, landmarks, Agnes's cottage, lighting, weather and the camera.
## Built from data at runtime so the grid stays the source of truth.

signal ready_to_play
signal photo_taken(file: String)

const COTTAGE_ID := "lm_agnes_cottage"

@export var look_test := false

var slice: MapSlice
var terrain: TerrainView
var creek: CreekView
var vegetation: Vegetation
var landmarks: Landmarks
var houses: Array[HouseView] = []
var env: Environment
var sun: DirectionalLight3D
var day: DayNight
var rig: CameraRig
var rain: Rain
var hud: Hud
var quality := "medium"
var quality_preset: Dictionary = {}
var walls_mode := HouseView.WALLS_UP
var build: BuildMode
var building := false
var _speed_before_build := 0
var _autosave_t := -1.0

var _bench_frames: Array[float] = []
var _benchmarking := false
var _bench_time := 0.0
var _sim_ms := 0.0
## The map's own terrain, before any garden edits (house terrain and ground are applied on top).
var _orig_heights: PackedFloat32Array
var _orig_ground: PackedByteArray
var _landscape_sig := ""
var photo_mode := false
var _work_cache: Dictionary = {}  ## house id -> Construction work list for its current plan
var residents: ResidentViews
var overlays: DebugOverlays
var case_screen: InvestigationScreen
var road: RoadMode
var lamp_mode: LampMode
var lamps_view: LampsView
var pause_menu: PauseMenu
var _walls_before := HouseView.WALLS_UP
var _follow := ""
var _press_at := Vector2(-1, -1)
var _photo_layer: CanvasLayer
var _photo_bar: PanelContainer


func _ready() -> void:
	slice = MapSlice.load_default()
	_orig_heights = slice.grid.heights.duplicate()
	_orig_ground = slice.grid.ground.duplicate()
	var we := WorldEnvironment.new()
	env = Environment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "SunMoon"
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.6
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	day = DayNight.new()
	day.name = "DayNight"
	add_child(day)
	day.setup(env, sun)
	terrain = TerrainView.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(slice.grid)
	creek = CreekView.new()
	creek.name = "Creek"
	add_child(creek)
	creek.setup(slice)
	vegetation = Vegetation.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.setup(slice, terrain.skirt_height)
	landmarks = Landmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.setup(slice)
	_build_houses()
	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.bounds = Rect2(0, 0, slice.grid.width, slice.grid.height)
	rig.height_fn = slice.grid.height_at
	add_child(rig)
	var c := cottage_centre()
	rig.set_view(c, 212.0, 26.0, 30.0)
	rig.view_changed.connect(_on_view_changed)
	for id: String in GameState.houses:
		add_house(HouseData.from_dict(GameState.houses[id]), false)
	apply_landscape()
	rain = Rain.new()
	rain.name = "Rain"
	add_child(rain)
	day.lamps_changed.connect(func(_l: float) -> void: _update_house_lighting())
	EventBus.time_changed.connect(_on_minute)
	build = BuildMode.new()
	build.name = "BuildMode"
	build.world = self
	build.rig = rig
	add_child(build)
	if not look_test:
		hud = Hud.new()
		hud.world = self
		add_child(hud)
	var q := str(Settings.get_value("quality"))
	if q == "" and not look_test:
		_start_benchmark()
	else:
		set_quality(q if q != "" else "medium")
	if Clock.day == 0 and Clock.minute == 360:
		Clock.set_minute(9 * 60 + 20)
	day.apply(Clock.minute_f())
	_update_house_lighting()
	if not look_test and not GameState.is_sandbox():
		_start_residents()
	ready_to_play.emit()
	if not look_test and UrlParams.read().get("build", "") == "1":
		enter_build_mode.call_deferred()


## The town's life: the sim gets its walk graph from this valley, and its people are drawn here.
func _start_residents() -> void:
	EventBus.settings_changed.connect(_on_setting_changed)
	SimHost.lights_changed.connect(_on_lights_changed)
	SimHost.case_opened.connect(_on_case_opened)
	SimHost.case_closed.connect(_on_case_closed)
	SimHost.start(self)
	residents = ResidentViews.new()
	residents.name = "Residents"
	residents.houses = houses
	residents.height_fn = slice.grid.height_at
	residents.lod = 1 if quality == "low" else 0
	add_child(residents)
	overlays = DebugOverlays.new()
	overlays.name = "Overlays"
	overlays.residents = residents
	overlays.focus_fn = func() -> Vector3: return rig.focus
	add_child(overlays)
	if hud:
		hud.call("_refresh_toolbar")
	road = RoadMode.new()
	road.world = self
	add_child(road)
	lamps_view = LampsView.new()
	lamps_view.grid = slice.grid
	lamps_view.world = self
	add_child(lamps_view)
	lamps_view.refresh()
	lamp_mode = LampMode.new()
	lamp_mode.world = self
	add_child(lamp_mode)
	var audio := AudioDirector.new()
	audio.world = self
	add_child(audio)
	if SimHost.prologue != null:
		var guides := PrologueGuides.new()
		guides.name = "PrologueGuides"
		guides.grid = slice.grid
		add_child(guides)
		add_child(PrologueHud.new())
		SimHost.refresh_story()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "quality" and str(value) != "" and str(value) != quality:
		set_quality(str(value))


## An incident alert opened a case: go to the scene.
func _on_case_opened(_inv: Investigation) -> void:
	show_case()


func _on_case_closed(_result: Dictionary) -> void:
	if hud:
		hud.call("_refresh_toolbar")


## Opens the investigation screen on the open case: walls down, the camera over the scene.
func show_case() -> void:
	var inv := SimHost.investigation
	if inv == null or hud == null:
		return
	var hid := str((inv.data.get("scene", {}) as Dictionary).get("house", ""))
	var origin := Vector2i.ZERO
	for hv in houses:
		if hv.data.id == hid:
			origin = hv.data.origin
	var base := slice.grid.height_at(origin.x, origin.y)
	var anchor := Vector3(origin.x, base, origin.y)
	if case_screen == null or not is_instance_valid(case_screen):
		case_screen = InvestigationScreen.new()
		var layer := CanvasLayer.new()
		layer.layer = 20
		layer.add_child(case_screen)
		add_child(layer)
		case_screen.open(inv, anchor)
		case_screen.closed.connect(_on_case_screen_closed)
		case_screen.finished.connect(func(_r: Dictionary) -> void: _on_case_screen_closed())
		_walls_before = walls_mode
	else:
		case_screen.visible = true
	hud.visible = false
	set_walls_mode(HouseView.WALLS_DOWN)
	rig.set_view(anchor + Vector3(2.0, 0.0, 8.5), 180.0, 66.0, 30.0, false)
	if hud:
		hud.call("_refresh_toolbar")


func _on_case_screen_closed() -> void:
	set_walls_mode(_walls_before)
	if hud:
		hud.visible = true
	if SimHost.investigation == null and case_screen != null:
		case_screen.get_parent().queue_free()
		case_screen = null
	if hud:
		hud.call("_refresh_toolbar")


func open_lamps() -> void:
	if lamp_mode == null or building:
		return
	if SimHost.prologue != null and SimHost.prologue.is_locked("street_lamps"):
		if hud:
			hud.show_toast("Street lamps come later. Sort out the town first.")
		return
	lamp_mode.open()


## Can't put a lamp in the water or inside a house.
func _lamp_blocked(p: Vector2) -> bool:
	var g := slice.grid
	var t := Vector2i(floori(p.x), floori(p.y))
	if not g.in_bounds(t.x, t.y) or g.get_ground(t.x, t.y) == Ground.Type.WATER:
		return true
	var sight := SimHost.sim.town.sight if SimHost.sim.town != null else null
	return sight != null and sight.room_at(t) != ""


func put_up_lamp(p: Vector2) -> Dictionary:
	if not GameState.is_sandbox() and GameState.money < LampOps.COST:
		return {"ok": false, "msg": "A lamp is £%d and you have £%d." % [LampOps.COST, GameState.money], "cost": 0}
	var r := LampOps.place(GameState.lamps, p, _lamp_blocked)
	if bool(r["ok"]):
		if not GameState.is_sandbox():
			GameState.money -= int(r["cost"])
		else:
			r["cost"] = 0
		_lamps_changed()
	return r


## Takes down the lamp near a point. Returns the refund, or -1 if there wasn't one.
func take_down_lamp(p: Vector2) -> int:
	var refund := LampOps.remove_at(GameState.lamps, p)
	if refund >= 0:
		if not GameState.is_sandbox():
			GameState.money += refund
		else:
			refund = 0
		_lamps_changed()
	return refund


func _lamps_changed() -> void:
	lamps_view.refresh()
	SimHost.rebuild_town()
	request_autosave()


func open_roads() -> void:
	if road != null and not building:
		road.open()


## Lays a road or path along waypoints [[x, y], ...]. Returns {ok, msg, cost}. Dirt is free; the rest
## costs money in the story. Footpaths are locked until The Cash Tin is solved.
func lay_road(points: Array, kind: String) -> Dictionary:
	if not RoadOps.KINDS.has(kind):
		return {"ok": false, "msg": "Unknown road.", "cost": 0}
	if kind == "footpath" and SimHost.prologue != null and SimHost.prologue.is_locked("footpaths"):
		return {"ok": false, "msg": "Footpaths come later. Sort out the town first.", "cost": 0}
	var tiles := RoadOps.tiles_along(points, int((RoadOps.KINDS[kind] as Dictionary)["width"]))
	var cost := RoadOps.cost(kind, GameState.roads, tiles)
	if not GameState.is_sandbox() and cost > GameState.money:
		return {"ok": false, "msg": "That's £%d and you have £%d." % [cost, GameState.money], "cost": cost}
	var n := RoadOps.lay(GameState.roads, kind, tiles, Vector2i(slice.grid.width, slice.grid.height))
	if n == 0:
		return {"ok": false, "msg": "That's already laid.", "cost": 0}
	if not GameState.is_sandbox():
		GameState.money -= cost
	apply_landscape()
	_clear_for_roads(tiles)
	SimHost.rebuild_town()
	request_autosave()
	return {"ok": true, "msg": "Laid %d tiles of %s%s." % [n, str((RoadOps.KINDS[kind] as Dictionary)["label"]).to_lower(), (" for £%d" % cost) if cost > 0 else ""], "cost": cost}


func _clear_for_roads(tiles: Array[Vector2i]) -> void:
	if vegetation == null:
		return
	for t in tiles:
		vegetation.clear_rect(Rect2(Vector2(t), Vector2.ONE))


## Cycles the debug overlays: light, sightlines, routes, prints, off. Returns the new mode.
func cycle_overlay() -> String:
	return overlays.cycle() if overlays else "off"


func _exit_tree() -> void:
	SimHost.stop()
	if EventBus.settings_changed.is_connected(_on_setting_changed):
		EventBus.settings_changed.disconnect(_on_setting_changed)
	if SimHost.lights_changed.is_connected(_on_lights_changed):
		SimHost.lights_changed.disconnect(_on_lights_changed)
	for sig: Signal in [SimHost.case_opened, SimHost.case_closed]:
		for c in sig.get_connections():
			if (c["callable"] as Callable).get_object() == self:
				sig.disconnect(c["callable"])


## Lamps burn only in rooms where somebody's up (the light grid), so what's drawn is what's seen.
func _on_lights_changed(lit: Dictionary) -> void:
	for hv in houses:
		var mine := {}
		var prefix := hv.data.id + ":"
		for rid: String in lit:
			if rid.begins_with(prefix):
				mine[rid.substr(prefix.length())] = true
		hv.lit_filter = mine
	_update_house_lighting()


func select_resident(rid: String) -> void:
	if residents:
		residents.selected = rid
	if rid == "" or rid != _follow:
		_follow = ""


func follow_resident(rid: String) -> void:
	_follow = rid


func _unhandled_input(event: InputEvent) -> void:
	if residents == null or building or photo_mode or (road != null and road.active) or (lamp_mode != null and lamp_mode.active):
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_at = mb.position
		return
	if _press_at.distance_to(mb.position) > 8.0:
		return
	var cam := rig.camera
	var rid := residents.pick(cam.project_ray_origin(mb.position), cam.project_ray_normal(mb.position))
	if rid != "" and hud:
		hud.show_resident(rid)


func _build_houses() -> void:
	for l: Dictionary in slice.data["landmarks"]:
		if l["kind"] != "house":
			continue
		var h := HouseData.load_file(str(l["house"]))
		var origin: Array = l["origin"]
		h.origin = Vector2i(int(origin[0]), int(origin[1]))
		h.locked = true
		var ox := float(origin[0])
		var oz := float(origin[1])
		var fp := h.footprint()
		var base := slice.grid.height_at(ox + fp.get_center().x, oz + fp.get_center().y)
		var view := HouseView.new()
		view.name = h.id
		view.position = Vector3(ox, base, oz)
		add_child(view)
		var grid := slice.grid
		view.setup(h, func(x: float, z: float) -> float: return grid.height_at(ox + x, oz + z) - base)
		houses.append(view)


## Adds a player's house to the town and returns its view.
func add_house(h: HouseData, save: bool = true) -> HouseView:
	var view := HouseView.new()
	view.name = h.id
	view.display_fn = _construction_display
	var grid := slice.grid
	var ox := float(h.origin.x)
	var oz := float(h.origin.y)
	if is_nan(h.base_y):
		# Stand the house on the highest corner of its footprint; stumps take up the slope.
		var b := h.bounds()
		var top := -INF
		for y in range(b.position.y, b.end.y + 1):
			for x in range(b.position.x, b.end.x + 1):
				top = maxf(top, grid.height_at(ox + x, oz + y))
		h.base_y = top
	var base: float = h.base_y
	view.position = Vector3(ox, base, oz)
	add_child(view)
	view.setup(h, func(x: float, z: float) -> float: return grid.height_at(ox + x, oz + z) - base)
	view.set_view(walls_mode, rig.forward_xz() if rig else Vector3(0, 0, -1))
	houses.append(view)
	if not h.locked:
		_clear_site(h)
	_update_house_lighting()
	if save:
		house_changed(h)
	return view


func remove_house(id: String) -> void:
	for hv in houses:
		if hv.data.id == id:
			houses.erase(hv)
			hv.queue_free()
			break
	GameState.houses.erase(id)
	GameState.construction.erase(id)
	_work_cache.erase(id)
	SimHost.rebuild_town()
	apply_landscape()
	request_autosave()


## Called after every edit: remember the house and save soon.
func house_changed(h: HouseData) -> void:
	if not h.locked:
		GameState.houses[h.id] = h.to_dict()
		_work_cache.erase(h.id)
		_clear_site(h)
	apply_landscape()
	request_autosave()
	_update_house_lighting()


func _clear_site(h: HouseData) -> void:
	var b := h.bounds()
	if b.size == Vector2i.ZERO:
		return
	var r := Rect2(Vector2(b.position + h.origin), Vector2(b.size)).grow(0.5)
	for v in h.verandahs:
		r = r.grow(float(v.get("depth", 2.0)))
	vegetation.clear_rect(r)
	var o := Vector2(h.origin)
	# Inside the fences is the yard: the bush is cleared back to the fence line.
	if not h.fences.is_empty():
		var fr := Rect2()
		var first := true
		for k: String in h.fences:
			for pt in HouseData.edge_points(k):
				fr = Rect2(Vector2(pt), Vector2.ZERO) if first else fr.expand(Vector2(pt))
				first = false
		vegetation.clear_rect(Rect2(fr.position + o, fr.size).grow(0.5))
	for it: Dictionary in h.garden:
		var ir := GardenOps.item_rect(it)
		vegetation.clear_rect(Rect2(ir.position + o, ir.size).grow(0.3))


## Puts every house's garden terrain and ground finishes onto the map, over the map's own terrain,
## and rebuilds the terrain (and the houses standing on it) when anything changed.
func apply_landscape() -> void:
	var parts: Array = []
	for hv in houses:
		if not hv.data.locked and (not hv.shown.terrain.is_empty() or not hv.shown.ground.is_empty()):
			parts.append([hv.data.id, hv.data.origin, hv.data.base_y, hv.shown.terrain, hv.shown.ground])
	var sig := JSON.stringify(parts) + "|" + str(GameState.roads.size()) + "|" + str(hash(JSON.stringify(GameState.roads)))
	if sig == _landscape_sig:
		return
	var terrain_before := _landscape_sig
	_landscape_sig = sig
	var grid := slice.grid
	grid.heights = _orig_heights.duplicate()
	grid.ground = _orig_ground.duplicate()
	for rk: String in GameState.roads:
		var rt := HouseData.parse_tile(rk)
		if grid.in_bounds(rt.x, rt.y):
			grid.set_ground(rt.x, rt.y, RoadOps.ground_of(str(GameState.roads[rk])))
	for hv2 in houses:
		var h := hv2.shown
		if h.locked or is_nan(h.base_y):
			continue
		for ck: String in h.terrain:
			var c := HouseData.parse_tile(ck) + h.origin
			if c.x >= 0 and c.y >= 0 and c.x <= grid.width and c.y <= grid.height:
				grid.set_corner_height(c.x, c.y, h.base_y + float(h.terrain[ck]))
		for tk: String in h.ground:
			var t := HouseData.parse_tile(tk) + h.origin
			if grid.in_bounds(t.x, t.y):
				grid.set_ground(t.x, t.y, Ground.from_name(str(h.ground[tk])))
	terrain.refresh_splat()
	terrain.rebuild()
	if terrain_before != "" or not parts.is_empty() or not GameState.roads.is_empty():
		for hv3 in houses:
			if not hv3.data.locked:
				hv3.rebuild_all()


# --- Construction (story mode) ------------------------------------------------------------------

## Called by build mode before an edit lands in story mode: the first edit to a house starts a
## project from how it stood before (nothing, for a new house); later edits extend it. Materials
## for the new work are ordered today and arrive at the siding tomorrow.
func order_construction(id: String, before: Variant) -> void:
	if GameState.is_sandbox():
		return
	if not GameState.construction.has(id):
		var built: Dictionary = before if before is Dictionary else {"id": id, "storeys": [HouseData.new_storey(0)]}
		GameState.construction[id] = Construction.new_project(built, Clock.day, Clock.minute)
	else:
		var p: Dictionary = GameState.construction[id]
		p["ordered_day"] = Clock.day
		p["ordered_minute"] = Clock.minute
	_work_cache.erase(id)


func _construction_work(hv: HouseView) -> Array[float]:
	var id := hv.data.id
	if not _work_cache.has(id):
		var p: Dictionary = GameState.construction[id]
		_work_cache[id] = Construction.work(HouseData.from_dict(p["built"]), hv.data)
	return _work_cache[id]


## What a house looks like while it's being built.
func _construction_display(plan: HouseData) -> HouseData:
	if not GameState.construction.has(plan.id):
		return plan
	var p: Dictionary = GameState.construction[plan.id]
	var before := HouseData.from_dict(p["built"])
	var w := Construction.work(before, plan)
	var delivered := Construction.delivered(p, Clock.day, Clock.minute)
	var stage := int(Construction.stage_at(w, float(p["done"]))["index"]) if delivered else -1
	p["shown_stage"] = stage
	if stage >= Construction.STAGES.size():
		return plan
	return Construction.display(before, plan, stage, delivered)


## Crews work through every project a minute at a time; the house is redrawn at each new stage.
func _on_minute(day: int, minute: int) -> void:
	if GameState.construction.is_empty():
		return
	var raining := rain != null and rain.intensity > 0.3
	for hv in houses:
		var id := hv.data.id
		if not GameState.construction.has(id):
			continue
		var p: Dictionary = GameState.construction[id]
		p["tier"] = hv.data.quality
		var stage := Construction.tick(p, _construction_work(hv), day, minute, GameState.crews, raining)
		if stage == int(p.get("shown_stage", -2)):
			continue
		if stage >= Construction.STAGES.size():
			GameState.construction.erase(id)
			_work_cache.erase(id)
			hv.refresh_display()
			HomeLife.record(GameState.history, id, day, "Built by the town's crews (%s work)." % hv.data.quality)
			SimHost.rebuild_town()
			if hud:
				hud.show_toast("%s is finished." % hv.data.name)
		else:
			hv.refresh_display()
			if hud and stage >= 0:
				hud.show_toast("%s: %s" % [hv.data.name, Construction.STAGE_NAMES[Construction.STAGES[stage]].to_lower()])
		apply_landscape()
		request_autosave()


## {stage name, percent, days left, waiting for materials} for a house being built, or {}.
func construction_status(id: String) -> Dictionary:
	if not GameState.construction.has(id):
		return {}
	var hv: HouseView = null
	for x in houses:
		if x.data.id == id:
			hv = x
	if hv == null:
		return {}
	var p: Dictionary = GameState.construction[id]
	var w := _construction_work(hv)
	var st := Construction.stage_at(w, float(p["done"]))
	var tot := Construction.total(w)
	return {"stage": str(Construction.STAGE_NAMES.get(str(st["name"]), "Finishing")), "percent": roundi(100.0 * float(p["done"]) / maxf(tot, 0.01)),
		"days": Construction.days_left(w, float(p["done"]), GameState.crews, hv.data.quality),
		"waiting": not Construction.delivered(p, Clock.day, Clock.minute)}


func request_autosave() -> void:
	_autosave_t = 1.0


func enter_build_mode() -> void:
	if building:
		return
	building = true
	_speed_before_build = Clock.speed
	if not Settings.get_value("build_while_time_runs"):
		Clock.set_speed(0)
	rig.one_finger_pan = false
	if walls_mode == HouseView.WALLS_UP:
		set_walls_mode(HouseView.WALLS_CUTAWAY)
	build.enter()
	if hud:
		hud.set_build_mode(true)


func exit_build_mode() -> void:
	if not building:
		return
	building = false
	build.exit()
	rig.one_finger_pan = true
	Clock.set_speed(_speed_before_build)
	if hud:
		hud.set_build_mode(false)
	request_autosave()


func cottage_centre() -> Vector3:
	for hv in houses:
		if hv.data.id == COTTAGE_ID:
			var fp := hv.data.footprint()
			return hv.position + Vector3(fp.get_center().x, 1.2, fp.get_center().y)
	return Vector3(60, 4, 50)


func set_quality(name: String) -> void:
	quality = name
	quality_preset = Quality.apply(name, get_viewport(), sun, env)
	terrain.set_detail(bool(quality_preset["terrain_detail"]))
	vegetation.set_detail(bool(quality_preset["tufts"]))
	rain.set_amount(500 if name == "low" else (1000 if name == "medium" else 1600))
	if residents:
		residents.set_lod(1 if name == "low" else 0)
	_update_house_lighting()


func set_walls_mode(mode: String) -> void:
	walls_mode = mode
	for h in houses:
		h.set_view(mode, rig.forward_xz())
	if hud:
		hud.call("_refresh_view_chips")


func cycle_walls_mode() -> void:
	var order := [HouseView.WALLS_UP, HouseView.WALLS_CUTAWAY, HouseView.WALLS_DOWN]
	set_walls_mode(order[(order.find(walls_mode) + 1) % order.size()])


func set_raining(on: bool) -> void:
	rain.target = 1.0 if on else 0.0


func _on_view_changed(forward: Vector3) -> void:
	if walls_mode == HouseView.WALLS_CUTAWAY:
		for h in houses:
			h.set_view(walls_mode, forward)


func _update_house_lighting() -> void:
	if quality_preset.is_empty():
		return
	for h in houses:
		h.set_lighting(day.lamp_level, day.daylight(), int(quality_preset["lamps"]), quality == "high")


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	rain.step(delta, rig.focus)
	vegetation.update_occlusion(rig.camera.global_position, rig.focus)
	day.rain = rain.intensity
	day.apply(Clock.minute_f())
	terrain.set_rain_wetness(rain.wetness)
	creek.set_rain(rain.intensity)
	if _follow != "" and residents:
		rig.follow_point(residents.position_of(_follow))
	_sim_ms = (Time.get_ticks_usec() - t0) / 1000.0 + SimHost.tick_ms
	if _autosave_t > 0.0:
		_autosave_t -= delta
		if _autosave_t <= 0.0:
			SaveSystem.save_slot(GameState.save_slot())
	if _benchmarking:
		_bench_time += delta
		if _bench_time > 0.5:
			_bench_frames.append(delta * 1000.0)
		if _bench_time >= 3.0:
			_finish_benchmark()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if photo_mode:
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_F2:
			toggle_photo_mode()
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			take_photo()
		get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_ESCAPE:
			if not building and (case_screen == null or not case_screen.visible) and (road == null or not road.active) and (lamp_mode == null or not lamp_mode.active) and pause_menu == null:
				pause_menu = PauseMenu.new()
				pause_menu.resumed.connect(func() -> void: pause_menu = null)
				add_child(pause_menu)
		KEY_B:
			if building:
				exit_build_mode()
			else:
				enter_build_mode()
		KEY_PAGEUP:
			if k.shift_pressed:
				return
			set_walls_mode(HouseView.WALLS_UP if walls_mode == HouseView.WALLS_CUTAWAY else HouseView.WALLS_CUTAWAY)
		KEY_PAGEDOWN:
			if k.shift_pressed:
				return
			set_walls_mode(HouseView.WALLS_DOWN if walls_mode == HouseView.WALLS_CUTAWAY else HouseView.WALLS_CUTAWAY)
		KEY_SPACE:
			Clock.set_speed(0 if Clock.speed > 0 else 1)
		KEY_1:
			Clock.set_speed(1)
		KEY_2:
			Clock.set_speed(2)
		KEY_3:
			Clock.set_speed(4)
		KEY_R:
			set_raining(rain.target < 0.5)
		KEY_F3:
			if hud:
				hud.toggle_debug()
		KEY_F2:
			toggle_photo_mode()
		KEY_P:
			if hud and residents:
				hud.toggle_residents()
		KEY_F4:
			var m := cycle_overlay()
			if hud:
				hud.show_toast(DebugOverlays.NAMES[m])


# --- Photo mode ----------------------------------------------------------------------------------

## Hides the interface for a clean view. Enter or the shutter button takes a picture; Esc returns.
func toggle_photo_mode() -> void:
	photo_mode = not photo_mode
	if hud:
		hud.visible = not photo_mode
	if building:
		build.active = not photo_mode
		build.call("_clear_preview")
	if photo_mode:
		if _photo_layer == null:
			_photo_layer = CanvasLayer.new()
			_photo_layer.layer = 5
			add_child(_photo_layer)
			var bar := PanelContainer.new()
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			bar.add_child(row)
			var snap := Button.new()
			snap.text = "Take photo"
			snap.theme_type_variation = &"PrimaryButton"
			snap.custom_minimum_size = Vector2(130, 46)
			snap.focus_mode = Control.FOCUS_NONE
			snap.pressed.connect(take_photo)
			row.add_child(snap)
			var back := Button.new()
			back.text = "Done"
			back.custom_minimum_size = Vector2(90, 46)
			back.focus_mode = Control.FOCUS_NONE
			back.pressed.connect(toggle_photo_mode)
			row.add_child(back)
			_photo_layer.add_child(bar)
			bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
			_photo_bar = bar
		_photo_layer.visible = true
	elif _photo_layer:
		_photo_layer.visible = false


## Saves what's on screen, without the interface, as a PNG: downloaded on the web, or written to
## user://screenshots elsewhere. Returns the file name.
func take_photo() -> String:
	if _photo_layer:
		_photo_layer.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _photo_layer and photo_mode:
		_photo_layer.visible = true
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file := "hollow-creek_%s.png" % stamp
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), file, "image/png")
	else:
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		img.save_png("user://screenshots/%s" % file)
	photo_taken.emit(file)
	return file


func sim_ms() -> float:
	return _sim_ms


# --- First-launch benchmark ----------------------------------------------------------------------

func _start_benchmark() -> void:
	set_quality("high")
	_benchmarking = true
	_bench_time = 0.0
	_bench_frames.clear()


func _finish_benchmark() -> void:
	_benchmarking = false
	_bench_frames.sort()
	var median := _bench_frames[_bench_frames.size() / 2] if not _bench_frames.is_empty() else 50.0
	var pick := Quality.pick_from_frame_ms(median)
	print("HC_BENCHMARK median_ms=%.1f preset=%s" % [median, pick])
	Settings.set_value("quality", pick)
	set_quality(pick)
	if hud:
		hud.show_toast("Graphics set to %s. Change it any time with the quality button." % pick.capitalize())
