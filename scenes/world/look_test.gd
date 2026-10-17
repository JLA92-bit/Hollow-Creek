extends Node
## The M1 look test: Agnes's cottage at morning, midday, dusk and night, outside and in cutaway,
## on Low, Medium and High. Prints HC_SHOT <name> and waits for the browser to answer through
## window.hcAck before moving on (tools/look_test.mjs). Ends with an HC_PERF line and HC_DONE.
## URL options: ?scene=look_test&qualities=low,medium,high&times=morning,midday&views=exterior,interior

const TIMES := {"morning": 7 * 60 + 40, "midday": 12 * 60 + 30, "dusk": 17 * 60 + 40, "night": 21 * 60 + 15}

var world: Node3D
var params: Dictionary = {}


func _ready() -> void:
	params = UrlParams.read()
	Clock.set_speed(0)
	var packed := load("res://scenes/world/world.tscn") as PackedScene
	world = packed.instantiate() as Node3D
	world.set("look_test", true)
	add_child(world)
	_run.call_deferred()


func _list(key: String, fallback: Array) -> Array:
	if params.has(key):
		return str(params[key]).split(",", false)
	return fallback


func _run() -> void:
	await _frames(10)
	var qualities := _list("qualities", ["low", "medium", "high"])
	var times := _list("times", ["morning", "midday", "dusk", "night"])
	var views := _list("views", ["exterior", "interior"])
	for q: String in qualities:
		world.call("set_quality", q)
		for t: String in times:
			Clock.set_minute(int(TIMES.get(t, 720)))
			(world.get("day") as DayNight).force_sky_update()
			for v: String in views:
				_set_view(v)
				await _settle()
				await _shot("%s_%s_%s" % [t, v, q])
	if params.get("wide", "1") == "1":
		world.call("set_quality", "medium")
		for t2: String in ["midday", "dusk"]:
			Clock.set_minute(int(TIMES[t2]))
			(world.get("day") as DayNight).force_sky_update()
			_set_view("wide")
			await _settle()
			await _shot("valley_%s_medium" % t2)
	await _perf()
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit()


func _set_view(v: String) -> void:
	var rig: CameraRig = world.get("rig")
	var c: Vector3 = world.call("cottage_centre")
	if v == "exterior":
		world.call("set_walls_mode", HouseView.WALLS_UP)
		rig.set_view(c + Vector3(0.5, 0.2, -1.0), 212.0, 20.0, 21.0)
	elif v == "wide":
		world.call("set_walls_mode", HouseView.WALLS_UP)
		rig.set_view(c + Vector3(-6, 0, 8), 200.0, 30.0, 70.0)
	else:
		rig.set_view(c + Vector3(0.4, -0.6, 0.5), 200.0, 52.0, 17.0)
		world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)
		world.call("set_walls_mode", HouseView.WALLS_CUTAWAY)


func _settle() -> void:
	# Let the sky radiance re-bake and the shadows settle.
	var start := Time.get_ticks_msec()
	await _frames(6)
	while Time.get_ticks_msec() - start < 800:
		await get_tree().process_frame


func _shot(name: String) -> void:
	print("HC_SHOT ", name)
	if not OS.has_feature("web"):
		await _frames(2)
		return
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 900000:
		await get_tree().process_frame
		var ack: Variant = JavaScriptBridge.eval("window.hcAck || ''")
		if str(ack) == name:
			return
	push_warning("No screenshot ack for %s" % name)


func _perf() -> void:
	var q := str(params.get("perf_quality", "medium"))
	world.call("set_quality", q)
	Clock.set_minute(TIMES["midday"])
	(world.get("day") as DayNight).force_sky_update()
	_set_view("exterior")
	await _settle()
	var frames: Array[float] = []
	var draw_calls := 0.0
	var tris := 0.0
	var start := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() - start < 5000 or frames.size() < 10:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		draw_calls = maxf(draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		tris = maxf(tris, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	frames.sort()
	var avg := 0.0
	for f in frames:
		avg += f
	avg /= frames.size()
	var vp := get_viewport().get_visible_rect().size
	print("HC_PERF ", JSON.stringify({"quality": q, "frames": frames.size(), "avg_ms": snappedf(avg, 0.1),
		"median_ms": snappedf(frames[frames.size() / 2], 0.1), "p95_ms": snappedf(frames[int(frames.size() * 0.95)], 0.1),
		"draw_calls": draw_calls, "triangles": tris, "viewport": [vp.x, vp.y], "sim_ms": world.call("sim_ms")}))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
