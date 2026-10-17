class_name DebugOverlays
extends Node3D
## Debug views over the town (docs/PLAN.md M6): the logical light per tile, what the selected
## resident can see from where they stand, everyone's routes as dotted lines, and bootprints.
## Drawn as tile-sized quads just above the ground or floor, refreshed twice a second.

const MODES: Array[String] = ["off", "light", "sight", "routes", "prints"]
const NAMES := {"off": "Overlay: off", "light": "Overlay: light", "sight": "Overlay: sightlines", "routes": "Overlay: routes", "prints": "Overlay: prints"}
const RADIUS := 24
const DARK := Color("#00294D")
const LIT := Color("#FBAD45")
const SEEN := Color("#5CBD6C")
const ROUTE_COLOURS: Array[Color] = [Color("#940E16"), Color("#4BC9F5"), Color("#F26839"), Color("#5CBD6C"), Color("#00294D"), Color("#FBAD45")]

var mode := "off"
var residents: ResidentViews
var focus_fn: Callable  ## () -> Vector3, the camera focus
var _mm: MultiMeshInstance3D
var _t := 0.0


func _ready() -> void:
	_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.92, 0.92)
	quad.orientation = PlaneMesh.FACE_Y
	mm.mesh = quad
	_mm.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.render_priority = 2
	_mm.material_override = mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)


func cycle() -> String:
	set_mode(MODES[(MODES.find(mode) + 1) % MODES.size()])
	return mode


func set_mode(m: String) -> void:
	mode = m
	_t = 0.0
	refresh()


func _process(delta: float) -> void:
	if mode == "off":
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		refresh()


func refresh() -> void:
	var cells: Array = []  ## [Vector3 position, Color, scale]
	if mode != "off" and SimHost.active and SimHost.sim.town != null and residents != null:
		match mode:
			"light":
				cells = _light_cells()
			"sight":
				cells = _sight_cells()
			"routes":
				cells = _route_cells()
			"prints":
				cells = _print_cells()
	var mm := _mm.multimesh
	mm.instance_count = cells.size()
	for i in cells.size():
		var c: Array = cells[i]
		var s := float(c[2])
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, 1.0, s)), c[0]))
		mm.set_instance_color(i, c[1])
	_mm.visible = not cells.is_empty()


func _centre() -> Vector2i:
	var f: Vector3 = focus_fn.call() if focus_fn.is_valid() else Vector3.ZERO
	return Vector2i(floori(f.x), floori(f.z))


func _at(t: Vector2i, lift: float = 0.06) -> Vector3:
	return Vector3(t.x + 0.5, residents.height_at([0, t.x + 0.5, t.y + 0.5]) + lift, t.y + 0.5)


func _light_cells() -> Array:
	var out: Array = []
	var light := SimHost.sim.light_now()
	var c := _centre()
	var town := SimHost.sim.town
	for y in range(c.y - RADIUS, c.y + RADIUS):
		for x in range(c.x - RADIUS, c.x + RADIUS):
			if x < 0 or y < 0 or x >= town.width or y >= town.height:
				continue
			var v := light.at(Vector2i(x, y))
			var col := DARK.lerp(LIT, clampf(v, 0.0, 1.0))
			col.a = 0.55 if v >= SightMap.LIT else 0.35
			out.append([_at(Vector2i(x, y)), col, 1.0])
	return out


## Tiles the selected resident (or whoever is nearest the focus) could see somebody standing on.
func _sight_cells() -> Array:
	var sim := SimHost.sim
	var rid := residents.selected
	if rid == "" or not sim.residents.has(rid) or sim.residents[rid]["status"] != "living":
		return []
	var r: Dictionary = sim.residents[rid]
	var from := Memories.tile_of(r)
	var who := Memories.state(r)
	who["awake"] = true
	who["focused"] = false
	var light := sim.light_now()
	var out: Array = [[_at(from, 0.08), Color("#940E16"), 1.0]]
	var reach := ceili(SightMap.DAY_RANGE)
	for y in range(from.y - reach, from.y + reach + 1):
		for x in range(from.x - reach, from.x + reach + 1):
			var t := Vector2i(x, y)
			if t == from or x < 0 or y < 0 or x >= sim.town.width or y >= sim.town.height:
				continue
			var seen := sim.town.sight.look(from, t, who, light)
			if seen["seen"]:
				var col := SEEN
				col.a = 0.25 + 0.4 * float(seen["confidence"])
				out.append([_at(t), col, 1.0])
	return out


func _route_cells() -> Array:
	var out: Array = []
	var sim := SimHost.sim
	var ids := sim.residents.keys()
	ids.sort()
	for i in ids.size():
		var r: Dictionary = sim.residents[ids[i]]
		var route: Array = r["route"]
		if route.is_empty():
			continue
		var col := ROUTE_COLOURS[i % ROUTE_COLOURS.size()]
		var length := SimTown.route_length(route)
		var d := 0.0
		while d <= length:
			var p := SimTown.along(route, d)
			out.append([Vector3(float(p[1]), residents.height_at(p) + 0.08, float(p[2])), col, 0.35])
			d += 1.0
	return out


func _print_cells() -> Array:
	var out: Array = []
	var sim := SimHost.sim
	for key: String in sim.traces:
		var parts := key.split(",")
		var t := Vector2i(int(parts[0]), int(parts[1]))
		var list: Array = sim.traces[key]
		var p: Dictionary = list[list.size() - 1]
		var col := Color("#5A3E2A") if not bool(p["muddy"]) else Color("#940E16")
		col.a = 0.85 if str(p["clarity"]) == "clear" else 0.45
		out.append([_at(t, 0.07), col, 0.4])
	return out
