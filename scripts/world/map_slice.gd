class_name MapSlice
extends RefCounted
## Builds the valley WorldGrid from data/map_slice.json. Deterministic for a given file and seed.

const PATH := "res://data/map_slice.json"

var data: Dictionary
var grid: WorldGrid
var creek_points: PackedVector2Array = PackedVector2Array()
## Water surface height along the creek, one per resampled creek point.
var creek_levels: PackedFloat32Array = PackedFloat32Array()
var shrubs: Array[Dictionary] = []
var tufts: Array[Dictionary] = []


static func load_default() -> MapSlice:
	var text := FileAccess.get_file_as_string(PATH)
	return MapSlice.from_data(JSON.parse_string(text) as Dictionary)


static func from_data(d: Dictionary) -> MapSlice:
	var m := MapSlice.new()
	m.data = d
	m._build()
	return m


func landmark(id: String) -> Dictionary:
	for l: Dictionary in data.get("landmarks", []):
		if l["id"] == id:
			return l
	return {}


func _build() -> void:
	var size: Array = data["size"]
	grid = WorldGrid.new(int(size[0]), int(size[1]))
	var base := Ground.from_name(str(data.get("base_ground", "grass")))
	grid.ground.fill(base)
	_resample_creek()
	_terrain()
	_paint_areas()
	_paint_tracks()
	_paint_creek()
	_scatter_trees()
	_scatter_ground_cover()


# --- Terrain -------------------------------------------------------------------------------------

func _base_height(x: float, y: float, noise: FastNoiseLite) -> float:
	var t: Dictionary = data["terrain"]
	var h := float(t["base"])
	h += float(t["slope_north"]) * (1.0 - y / grid.height)
	h += float(t.get("slope_east", 0.0)) * (x / grid.width)
	for hill: Dictionary in t.get("hills", []):
		var dx := x - float(hill["x"])
		var dy := y - float(hill["y"])
		var r := float(hill["r"])
		h += float(hill["h"]) * exp(-(dx * dx + dy * dy) / (r * r))
	h += noise.get_noise_2d(x, y) * float(t.get("noise_amp", 0.0))
	return h


func _terrain() -> void:
	var t: Dictionary = data["terrain"]
	var noise := FastNoiseLite.new()
	noise.seed = int(data.get("seed", 0))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / float(t.get("noise_period", 40.0))
	var c: Dictionary = data["creek"]
	var half_w := float(c["water_width"]) * 0.5
	var bank := float(c["bank_width"])
	var drop := float(c["bank_drop"])
	var depth := float(c["depth"])
	# Water level along the creek follows the uncut terrain, a little below the banks.
	creek_levels.resize(creek_points.size())
	for i in creek_points.size():
		var p := creek_points[i]
		creek_levels[i] = _base_height(p.x, p.y, noise) - drop * 0.8
	for cy in grid.height + 1:
		for cx in grid.width + 1:
			var h := _base_height(cx, cy, noise)
			h = _apply_flatten(cx, cy, h, noise)
			var near := _nearest_creek(Vector2(cx, cy))
			var d: float = near.x
			var level := creek_levels[int(near.y)]
			if d < half_w + bank + 4.0:
				# Carve the banks down to the water, then the bed below it.
				var bank_t := smoothstep(half_w + bank + 4.0, half_w, d)
				h = lerpf(h, level + 0.15, bank_t)
				if d < half_w:
					h = level - depth * (1.0 - (d / half_w) * (d / half_w)) - 0.05
			grid.set_corner_height(cx, cy, h)


func _apply_flatten(x: float, y: float, h: float, noise: FastNoiseLite) -> float:
	for f: Dictionary in data.get("flatten", []):
		var r: Array = f["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var falloff := float(f.get("falloff", 4.0))
		var centre := rect.get_center()
		var target := _base_height(centre.x, centre.y, noise)
		var dx := maxf(maxf(rect.position.x - x, x - rect.end.x), 0.0)
		var dy := maxf(maxf(rect.position.y - y, y - rect.end.y), 0.0)
		var dist := sqrt(dx * dx + dy * dy)
		if dist < falloff:
			h = lerpf(target, h, smoothstep(0.0, falloff, dist))
	return h


# --- Ground paint --------------------------------------------------------------------------------

func _paint_rect(r: Array, t: Ground.Type) -> void:
	for y in range(int(r[1]), int(r[1]) + int(r[3])):
		for x in range(int(r[0]), int(r[0]) + int(r[2])):
			if grid.in_bounds(x, y):
				grid.set_ground(x, y, t)


func _paint_areas() -> void:
	for a: Dictionary in data.get("areas", []):
		_paint_rect(a["rect"] as Array, Ground.from_name(str(a["ground"])))


func _paint_tracks() -> void:
	for tr: Dictionary in data.get("tracks", []):
		var pts := _to_points(tr["points"] as Array)
		var half := float(tr["width"]) * 0.5
		var t := Ground.from_name(str(tr["ground"]))
		for y in grid.height:
			for x in grid.width:
				if _dist_to_polyline(Vector2(x + 0.5, y + 0.5), pts) <= half:
					grid.set_ground(x, y, t)


func _paint_creek() -> void:
	var c: Dictionary = data["creek"]
	var half_w := float(c["water_width"]) * 0.5
	var bank := float(c["bank_width"])
	var reach := float(c.get("wet_reach", 3.0))
	for y in grid.height:
		for x in grid.width:
			var d: float = _nearest_creek(Vector2(x + 0.5, y + 0.5)).x
			if d < half_w:
				grid.set_ground(x, y, Ground.Type.WATER)
				grid.set_wet(x, y, 1.0)
			elif d < half_w + bank:
				grid.set_ground(x, y, Ground.Type.MUD)
				grid.set_wet(x, y, 1.0)
			elif d < half_w + bank + reach:
				grid.set_wet(x, y, 1.0 - (d - half_w - bank) / reach)
			if grid.get_ground(x, y) == Ground.Type.MUD:
				grid.set_wet(x, y, maxf(grid.get_wet(x, y), 0.8))


# --- Trees and ground cover ----------------------------------------------------------------------

func _blocked_for_planting(x: float, y: float, margin: float) -> bool:
	var tx := int(x)
	var ty := int(y)
	if not grid.in_bounds(tx, ty):
		return true
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var nx := clampi(tx + ox, 0, grid.width - 1)
			var ny := clampi(ty + oy, 0, grid.height - 1)
			if grid.get_ground(nx, ny) != Ground.Type.GRASS:
				return true
	for l: Dictionary in data.get("landmarks", []):
		var r: Array = l.get("lot", l.get("rect", [0, 0, 0, 0]))
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(margin)
		if rect.has_point(Vector2(x, y)) and not l.get("hidden", false):
			return true
	for a: Dictionary in data.get("areas", []):
		var r2: Array = a["rect"]
		if Rect2(float(r2[0]), float(r2[1]), float(r2[2]), float(r2[3])).grow(margin).has_point(Vector2(x, y)):
			return true
	return false


func _far_enough(p: Vector2, placed: Array[Vector2], spacing: float) -> bool:
	for q in placed:
		if p.distance_squared_to(q) < spacing * spacing:
			return false
	return true


func _scatter_trees() -> void:
	var rng := SimRng.new(int(data.get("seed", 0)) + 101)
	var cfg: Dictionary = data["trees"]
	var margin := float(cfg.get("keep_clear_margin", 2.0))
	var placed: Array[Vector2] = []
	var n := 0
	for e: Dictionary in cfg.get("explicit", []):
		var p := Vector2(float(e["x"]), float(e["y"]))
		placed.append(p)
		_add_tree(n, str(e["kind"]), p, float(e.get("scale", 1.0)), rng)
		n += 1
	for s: Dictionary in cfg.get("scatter", []):
		var target := int(s["count"])
		var spacing := float(s.get("min_spacing", 5.0))
		var sc: Array = s.get("scale", [1.0, 1.0])
		var made := 0
		var attempts := 0
		while made < target and attempts < target * 60:
			attempts += 1
			var p: Vector2
			if s.get("along_creek", false):
				var i := rng.randi_range(0, creek_points.size() - 1)
				var off := rng.randf_range(-float(s["band"]), float(s["band"]))
				var side := 1.0 if off >= 0.0 else -1.0
				var cpos := creek_points[i]
				var tangent := (creek_points[mini(i + 1, creek_points.size() - 1)] - creek_points[maxi(i - 1, 0)]).normalized()
				var normal := Vector2(-tangent.y, tangent.x)
				p = cpos + normal * (side * 4.8 + off)
			else:
				p = Vector2(rng.randf_range(0.0, grid.width), rng.randf_range(0.0, grid.height))
				var clearing: Dictionary = s.get("town_clearing", {})
				if not clearing.is_empty():
					var d := p.distance_to(Vector2(float(clearing["x"]), float(clearing["y"])))
					# Sparse near the town, denser towards the bush on the edges.
					if rng.randf() > smoothstep(float(clearing["r"]) * 0.6, float(clearing["r"]) * 1.6, d) * 0.95 + 0.03:
						continue
			if _blocked_for_planting(p.x, p.y, margin) or not _far_enough(p, placed, spacing):
				continue
			placed.append(p)
			_add_tree(n, str(s["kind"]), p, rng.randf_range(float(sc[0]), float(sc[1])), rng)
			n += 1
			made += 1


func _add_tree(n: int, kind: String, p: Vector2, scale: float, rng: SimRng) -> void:
	grid.add_object({
		"id": "tree_%d" % n, "kind": kind, "x": p.x, "y": p.y,
		"scale": snappedf(scale, 0.01), "rot": snappedf(rng.randf_range(0.0, TAU), 0.001),
		"variant": rng.randi_range(0, 3), "blocks": true,
	})


func _scatter_ground_cover() -> void:
	var rng := SimRng.new(int(data.get("seed", 0)) + 202)
	var sh: Dictionary = data.get("shrubs", {})
	var placed: Array[Vector2] = []
	var attempts := 0
	while shrubs.size() < int(sh.get("count", 0)) and attempts < 20000:
		attempts += 1
		var p := Vector2(rng.randf_range(0.0, grid.width), rng.randf_range(0.0, grid.height))
		if _blocked_for_planting(p.x, p.y, 1.0) or not _far_enough(p, placed, float(sh.get("min_spacing", 2.0))):
			continue
		placed.append(p)
		shrubs.append({"x": p.x, "y": p.y, "scale": rng.randf_range(0.6, 1.3), "rot": rng.randf_range(0.0, TAU), "variant": rng.randi_range(0, 2)})
	var tc: Dictionary = data.get("tufts", {})
	attempts = 0
	while tufts.size() < int(tc.get("count", 0)) and attempts < 60000:
		attempts += 1
		var q := Vector2(rng.randf_range(0.0, grid.width), rng.randf_range(0.0, grid.height))
		var tx := int(q.x)
		var ty := int(q.y)
		if not grid.in_bounds(tx, ty):
			continue
		var g := grid.get_ground(tx, ty)
		if g != Ground.Type.GRASS and not (g == Ground.Type.MUD and rng.chance(0.3)):
			continue
		if _blocked_for_planting(q.x, q.y, 0.3) and g == Ground.Type.GRASS and rng.chance(0.8):
			continue
		tufts.append({"x": q.x, "y": q.y, "scale": rng.randf_range(0.45, 1.0), "rot": rng.randf_range(0.0, TAU), "green": g == Ground.Type.MUD})


# --- Geometry helpers ----------------------------------------------------------------------------

func _to_points(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in arr:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


## Resamples the creek polyline into a smooth Catmull-Rom curve with points about 1 m apart.
func _resample_creek() -> void:
	var ctrl := _to_points(data["creek"]["points"] as Array)
	creek_points = PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, ctrl.size() - 1)]
		var steps := maxi(2, int(p1.distance_to(p2)))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			creek_points.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	creek_points.append(ctrl[ctrl.size() - 1])


## Returns Vector2(distance, index of the nearest resampled creek point).
func _nearest_creek(p: Vector2) -> Vector2:
	var best := INF
	var best_i := 0
	for i in creek_points.size() - 1:
		var a := creek_points[i]
		var b := creek_points[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			best_i = i if q.distance_squared_to(a) < q.distance_squared_to(b) else i + 1
	return Vector2(sqrt(best), best_i)


func creek_level_at(p: Vector2) -> float:
	return creek_levels[int(_nearest_creek(p).y)]


static func _dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best
