extends Node3D
## The valley: terrain, creek, trees, landmarks, Agnes's cottage, lighting, weather and the camera.
## Built from data at runtime so the grid stays the source of truth.

signal ready_to_play

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
	ready_to_play.emit()
	if not look_test and UrlParams.read().get("build", "") == "1":
		enter_build_mode.call_deferred()


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
	apply_landscape()
	request_autosave()


## Called after every edit: remember the house and save soon.
func house_changed(h: HouseData) -> void:
	if not h.locked:
		GameState.houses[h.id] = h.to_dict()
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
	for it: Dictionary in h.garden:
		var ir := GardenOps.item_rect(it)
		vegetation.clear_rect(Rect2(ir.position + o, ir.size).grow(0.3))


## Puts every house's garden terrain and ground finishes onto the map, over the map's own terrain,
## and rebuilds the terrain (and the houses standing on it) when anything changed.
func apply_landscape() -> void:
	var parts: Array = []
	for hv in houses:
		if not hv.data.locked and (not hv.data.terrain.is_empty() or not hv.data.ground.is_empty()):
			parts.append([hv.data.id, hv.data.origin, hv.data.base_y, hv.data.terrain, hv.data.ground])
	var sig := JSON.stringify(parts)
	if sig == _landscape_sig:
		return
	var terrain_before := _landscape_sig
	_landscape_sig = sig
	var grid := slice.grid
	grid.heights = _orig_heights.duplicate()
	grid.ground = _orig_ground.duplicate()
	for hv2 in houses:
		var h := hv2.data
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
	if terrain_before != "" or not parts.is_empty():
		for hv3 in houses:
			if not hv3.data.locked:
				hv3.rebuild_all()


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
	_update_house_lighting()


func set_walls_mode(mode: String) -> void:
	walls_mode = mode
	for h in houses:
		h.set_view(mode, rig.forward_xz())


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
	_sim_ms = (Time.get_ticks_usec() - t0) / 1000.0
	if _autosave_t > 0.0:
		_autosave_t -= delta
		if _autosave_t <= 0.0:
			SaveSystem.save_slot("autosave")
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
	match k.keycode:
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
