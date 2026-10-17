class_name HouseMeshBuilder
extends RefCounted
## Generates a house's meshes from HouseData, one storey at a time. Walls are built per 1 m edge so
## every face keeps its own surface, and grouped into 8 x 8 m chunks so an edit rebuilds only the
## chunks it touched. Material keys are "library_id" or "library_id#RRGGBB"; "glass:<room>" is per-room
## glass whose glow follows the lamps.

const T := HouseData.WALL_THICKNESS
const CUT_HEIGHT := 0.5
const CHUNK := 8
const FLOOR_THICKNESS := 0.3

var house: HouseData
var mats: Dictionary = {}
var glass_materials: Dictionary = {}  ## room key -> StandardMaterial3D
var ground_fn: Callable
var fy: float        ## floor level of the storey being built (local y)
var wh: float        ## wall height of the storey being built
var level := 0
var trim_ext: Color
var cladding_tint: Color
var _gable_key := ""


func _init(p_house: HouseData, p_ground_fn: Callable = Callable()) -> void:
	house = p_house
	ground_fn = p_ground_fn if p_ground_fn.is_valid() else func(_x: float, _z: float) -> float: return 0.0
	trim_ext = MaterialLibrary.paint(str(house.exterior.get("trim", "white")))
	cladding_tint = MaterialLibrary.paint(str(house.exterior.get("paint", "cream")))
	set_level(0)


func set_level(l: int) -> void:
	level = l
	fy = level_y(l)
	wh = house.storey_height(l)
	trim_ext = _paint(str(house.exterior.get("trim", "white")))
	cladding_tint = _paint(str(house.exterior.get("paint", "cream")))


func level_y(l: int) -> float:
	return house.floor_y() + house.level_base(l)


static func chunk_of(t: Vector2i) -> Vector2i:
	return Vector2i(floori(float(t.x) / CHUNK), floori(float(t.y) / CHUNK))


## The chunks an edge belongs to (by its first point).
static func edge_chunk(k: String) -> Vector2i:
	return chunk_of(HouseData.edge_points(k)[0])


## Registers a material and returns its key.
func m(id: String, tint: Variant = null) -> String:
	var key := id if tint == null else "%s#%s" % [id, (tint as Color).to_html(false)]
	if not mats.has(key):
		mats[key] = MaterialLibrary.get_material(id, tint)
	return key


func glass(room_key: String) -> String:
	var key := "glass:%s" % room_key
	if not glass_materials.has(room_key):
		var g := MaterialLibrary.unique("glass")
		g.emission_enabled = true
		g.emission = Color(1.0, 0.68, 0.36)
		g.emission_energy_multiplier = 0.0
		glass_materials[room_key] = g
		mats[key] = g
	return key


## Paint of a room by its template id (M1 data) or by a room dictionary.
func room_paint(room_id: String) -> Color:
	for r in house.rooms(level):
		if str((r["props"] as Dictionary).get("id", "")) == room_id or str(r["key"]) == room_id:
			return _paint(house.room_paint(r))
	return _paint("cream")


static func _paint(p: String) -> Color:
	return Color(p) if p.begins_with("#") else MaterialLibrary.paint(p)


## The material for one face of a wall.
func face_material(k: String, side: String) -> String:
	var f := face_dict(k, side)
	var r := house.room_on_side(level, k, side)
	if f.has("mat"):
		return surface_key(f)
	if r.is_empty():
		return m(str(house.exterior.get("cladding", "weatherboard")), cladding_tint)
	return m("plaster", _paint(house.room_paint(r)))


func face_dict(k: String, side: String) -> Dictionary:
	var w := house.wall(level, k)
	return ((w.get("f", {}) as Dictionary).get(side, {}) as Dictionary)


## Registers the material for a surface dictionary ({mat, paint} or {mat: wallpaper, pattern, colourway}).
func surface_key(f: Dictionary) -> String:
	if str(f.get("mat", "")) == "wallpaper":
		var key := "wallpaper:%s:%s" % [f.get("pattern", "floral"), f.get("colourway", "")]
		if not mats.has(key):
			mats[key] = MaterialLibrary.wallpaper(str(f.get("pattern", "floral")), str(f.get("colourway", "")))
		return key
	return m(str(f["mat"]), _paint(str(f.get("paint", "white"))) if f.has("paint") else null)


## Boards run up and down on some materials (VJ panelling), so their UVs turn a quarter.
func _rotated(mat_key: String) -> bool:
	return bool(MaterialLibrary.def(mat_key.split("#")[0]).get("uv_rotate", false))


func _wall_quad(kit: MeshKit, mat: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, u_origin: float) -> void:
	if not _rotated(mat):
		face(kit, mat, p0, p1, p2, p3, n, 1.0, u_origin)
		return
	var l := p0.distance_to(p1)
	face_uv(kit, mat, p0, p1, p2, p3, n, Vector2(-p0.y, u_origin), Vector2(-p1.y, u_origin + l), Vector2(-p2.y, u_origin + l), Vector2(-p3.y, u_origin))


## Room trims: picture rails on tall walls by default, cornices and dado rails when asked for.
func _room_trim(k: String, side: String, key: String, default: bool) -> bool:
	var r := house.room_on_side(level, k, side)
	if r.is_empty():
		return false
	return bool((r["props"] as Dictionary).get(key, default))


func is_outside(k: String, side: String) -> bool:
	return house.room_on_side(level, k, side).is_empty()


# --- Helpers ------------------------------------------------------------------------------------

## A quad given in any winding; flips it so it faces along n.
func face(kit: MeshKit, mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv_scale: float = 1.0, u_origin: float = 0.0) -> void:
	if (b - a).cross(d - a).dot(n) < 0.0:
		kit.quad_auto(mat, b, a, d, c, uv_scale, u_origin)
	else:
		kit.quad_auto(mat, a, b, c, d, uv_scale, u_origin)


func face_uv(kit: MeshKit, mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	if (b - a).cross(d - a).dot(n) < 0.0:
		kit.quad(mat, b, a, d, c, ub, ua, ud, uc)
	else:
		kit.quad(mat, a, b, c, d, ua, ub, uc, ud)


func tri_n(kit: MeshKit, mat: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, u_axis: Vector3) -> void:
	var uv := func(p: Vector3) -> Vector2: return Vector2(u_axis.dot(p), -p.y)
	if (b - a).cross(c - a).dot(n) < 0.0:
		kit.tri(mat, a, c, b, uv.call(a), uv.call(c), uv.call(b))
	else:
		kit.tri(mat, a, b, c, uv.call(a), uv.call(b), uv.call(c))


func flat_box(kit: MeshKit, mat: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	kit.box(mat, Transform3D(Basis(), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)),
		Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)))


# --- Floors, ceilings, foundations ---------------------------------------------------------------

## Floors, ceilings, stumps (ground storey), stairs and posts for one storey.
func build_structure(kit: MeshKit, l: int) -> void:
	set_level(l)
	var floors := house.floors(l)
	var wells := house.stairwell_tiles(l)
	for tk: String in floors:
		if wells.has(tk):
			continue
		_floor_tile(kit, HouseData.parse_tile(tk), floors[tk])
	if l == 0:
		_foundations(kit)
	elif l > 0:
		_floor_edges(kit, floors, wells)
	_ceilings(kit, l)
	_stairs(kit, l)
	_stairwell_rails(kit, l)
	_columns(kit, l)
	_corner_boards(kit, l)
	for v in house.verandahs:
		if int(v.get("level", 0)) == l:
			_verandah_deck(kit, v)


func _floor_tile(kit: MeshKit, t: Vector2i, f: Dictionary) -> void:
	var y := fy
	match str(f.get("stage", "")):
		"blueprint":
			kit.quad(blueprint(), Vector3(t.x, y - 0.25, t.y + 1), Vector3(t.x + 1, y - 0.25, t.y + 1), Vector3(t.x + 1, y - 0.25, t.y), Vector3(t.x, y - 0.25, t.y),
				Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			return
		"stumps":
			return
		"frame":
			# Bearers and joists, no boards yet.
			var timber := m("decking", Color("#D8C29C"))
			for i in 3:
				var z := t.y + 0.17 + i * 0.33
				flat_box(kit, timber, t.x, t.x + 1, y - 0.16, y - 0.02, z - 0.025, z + 0.025)
			return
	var rot := int(f.get("rot", 0))
	var corners := [Vector3(t.x, y, t.y), Vector3(t.x + 1, y, t.y), Vector3(t.x + 1, y, t.y + 1), Vector3(t.x, y, t.y + 1)]
	var c := Vector3(t.x + 0.5, y, t.y + 0.5)
	var uv := func(p: Vector3) -> Vector2: return Vector2(p.x, p.z) if rot == 0 else Vector2(p.z, p.x)
	if f.get("m") is String:
		var key := m(str(f["m"]))
		kit.quad(key, corners[3], corners[2], corners[1], corners[0], uv.call(corners[3]), uv.call(corners[2]), uv.call(corners[1]), uv.call(corners[0]))
		return
	var qm: Array = f["m"]
	# Quarter triangles N, E, S, W, each with its own material.
	var tris := [[corners[0], corners[1]], [corners[1], corners[2]], [corners[2], corners[3]], [corners[3], corners[0]]]
	for q in 4:
		var a: Vector3 = tris[q][0]
		var b: Vector3 = tris[q][1]
		kit.tri(m(str(qm[q])), a, c, b, uv.call(a), uv.call(c), uv.call(b))


func _foundations(kit: MeshKit) -> void:
	var floors := house.floors(0)
	if floors.is_empty():
		return
	var type := str(house.foundation.get("type", "stumps"))
	var frame_bottom := fy - FLOOR_THICKNESS * 0.5 - 0.25
	var tiles: Array[Vector2i] = []
	for tk: String in floors:
		tiles.append(HouseData.parse_tile(tk))
	for t in tiles:
		if type == "slab":
			flat_box(kit, m("stump", Color("#B9B3A8")), t.x, t.x + 1, minf(float(ground_fn.call(t.x + 0.5, t.y + 0.5)) - 0.2, fy - 0.15), fy - 0.005, t.y, t.y + 1)
		else:
			flat_box(kit, m("stump"), t.x + 0.02, t.x + 0.98, frame_bottom, fy - 0.01, t.y + 0.02, t.y + 0.98)
	if type != "stumps":
		return
	# Stumps at every other tile corner under the floor.
	var corners: Dictionary = {}
	for t2 in tiles:
		for c: Vector2i in [t2, t2 + Vector2i(1, 0), t2 + Vector2i(0, 1), t2 + Vector2i(1, 1)]:
			if posmod(c.x, 2) == 0 and posmod(c.y, 2) == 0:
				corners[HouseData.tile_key(c.x, c.y)] = c
	for c2: Vector2i in corners.values():
		var x := clampf(c2.x, -1e9, 1e9)
		var g := float(ground_fn.call(x, c2.y)) - 0.15
		if frame_bottom - g > 0.02:
			flat_box(kit, m("stump"), x - 0.06, x + 0.06, g, frame_bottom, c2.y - 0.06, c2.y + 0.06)


## Edges of upper floors seen from outside: a band of cladding round the floor's thickness.
func _floor_edges(kit: MeshKit, floors: Dictionary, wells: Dictionary) -> void:
	var band := m(str(house.exterior.get("cladding", "weatherboard")), cladding_tint)
	var y0 := fy - FLOOR_THICKNESS
	for tk: String in floors:
		if wells.has(tk):
			continue
		var t := HouseData.parse_tile(tk)
		for nb: Array in [[Vector2i(0, -1), Vector3(t.x, 0, t.y), Vector3(t.x + 1, 0, t.y), Vector3(0, 0, -1)],
				[Vector2i(0, 1), Vector3(t.x + 1, 0, t.y + 1), Vector3(t.x, 0, t.y + 1), Vector3(0, 0, 1)],
				[Vector2i(-1, 0), Vector3(t.x, 0, t.y + 1), Vector3(t.x, 0, t.y), Vector3(-1, 0, 0)],
				[Vector2i(1, 0), Vector3(t.x + 1, 0, t.y), Vector3(t.x + 1, 0, t.y + 1), Vector3(1, 0, 0)]]:
			var o: Vector2i = t + (nb[0] as Vector2i)
			if floors.has(HouseData.tile_key(o.x, o.y)) and not wells.has(HouseData.tile_key(o.x, o.y)):
				continue
			var a: Vector3 = nb[1]
			var b: Vector3 = nb[2]
			var n: Vector3 = nb[3]
			face(kit, band, a + Vector3(0, y0, 0) + n * T * 0.5, b + Vector3(0, y0, 0) + n * T * 0.5, b + Vector3(0, fy, 0) + n * T * 0.5, a + Vector3(0, fy, 0) + n * T * 0.5, n)
			face(kit, m("trim_paint", Color("#EFE9DA")), a + Vector3(0, y0, 0), b + Vector3(0, y0, 0), b + Vector3(0, y0, 0) + n * T * 0.5, a + Vector3(0, y0, 0) + n * T * 0.5, Vector3.DOWN)


## Corner boards on the outside corners of timber-clad walls, in the trim colour.
func _corner_boards(kit: MeshKit, l: int) -> void:
	var ends: Dictionary = {}
	for f: Array in BuildOps.exterior_faces(house, l):
		var k: String = f[0]
		if HouseData.is_diagonal(k):
			continue
		var fd: Dictionary = ((house.walls(l)[k] as Dictionary).get("f", {}) as Dictionary).get(f[1], {})
		var mat := str(fd.get("mat", house.exterior.get("cladding", "weatherboard")))
		if mat not in ["weatherboard", "fibro"]:
			continue
		var horizontal := k.ends_with(",N")
		var n := (Vector2(0, -1) if f[1] == "a" else Vector2(0, 1)) if horizontal else (Vector2(-1, 0) if f[1] == "a" else Vector2(1, 0))
		for pnt: Vector2i in HouseData.edge_points(k):
			var key := HouseData.tile_key(pnt.x, pnt.y)
			if not ends.has(key):
				ends[key] = []
			(ends[key] as Array).append([n, horizontal, house.wall_h(l, k)])
	var board := m("trim_paint", trim_ext)
	for key2: String in ends:
		var list: Array = ends[key2]
		if list.size() != 2 or bool(list[0][1]) == bool(list[1][1]):
			continue
		var c := Vector2(HouseData.parse_tile(key2))
		var n2: Vector2 = (list[0][0] as Vector2) + (list[1][0] as Vector2)
		var p := c + n2 * (T * 0.5 + 0.012)
		var h := minf(float(list[0][2]), float(list[1][2]))
		flat_box(kit, board, p.x - 0.05, p.x + 0.05, fy - 0.12, fy + h, p.y - 0.05, p.y + 0.05)


## Ceilings face down, so they hide from the usual view from above and show from inside.
func _ceilings(kit: MeshKit, l: int) -> void:
	var y := fy + wh
	var above := house.floors(l + 1)
	var unbuilt: Dictionary = house.stage.get("new_tiles", {}) if int(house.stage.get("index", 99)) < 7 else {}
	for r in house.rooms(l):
		var key := m("plaster", Color("#F4F0E6"))
		for t: Vector2i in r["full_tiles"]:
			if unbuilt.has("%s:%d" % [HouseData.tile_key(t.x, t.y), l]):
				continue
			var yy := y if not above.has(HouseData.tile_key(t.x, t.y)) else level_y(l + 1) - FLOOR_THICKNESS
			kit.quad(key, Vector3(t.x, yy, t.y), Vector3(t.x + 1, yy, t.y), Vector3(t.x + 1, yy, t.y + 1), Vector3(t.x, yy, t.y + 1),
				Vector2(t.x, t.y), Vector2(t.x + 1, t.y), Vector2(t.x + 1, t.y + 1), Vector2(t.x, t.y + 1))


## The see-through sky-blue material for things that are still only on the plan.
func blueprint() -> String:
	if not mats.has("blueprint_ghost"):
		var g := StandardMaterial3D.new()
		g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.albedo_color = Color(0.294, 0.788, 0.961, 0.35)
		g.cull_mode = BaseMaterial3D.CULL_DISABLED
		mats["blueprint_ghost"] = g
	return "blueprint_ghost"


## A wall still being built: a blueprint outline, or a timber frame of plates and studs.
func _wall_in_progress(kit: MeshKit, k: String, a: Vector3, b: Vector3, stage: String) -> void:
	var h := house.wall_h(level, k)
	if stage == "blueprint":
		kit.beam(blueprint(), a + Vector3(0, fy + h * 0.5, 0), b + Vector3(0, fy + h * 0.5, 0), T, h)
		return
	var timber := m("decking", Color("#D8C29C"))
	var base := Vector3(0, fy, 0)
	kit.beam(timber, a + base + Vector3(0, 0.025, 0), b + base + Vector3(0, 0.025, 0), 0.09, 0.05)
	kit.beam(timber, a + base + Vector3(0, h - 0.025, 0), b + base + Vector3(0, h - 0.025, 0), 0.09, 0.05)
	var length := a.distance_to(b)
	var n := maxi(1, roundi(length / 0.45))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		kit.beam(timber, p + base + Vector3(0, 0.05, 0), p + base + Vector3(0, h - 0.05, 0), 0.045, 0.09)
	if length > 0.9:
		kit.beam(timber, a + base + Vector3(0, 0.05, 0), b + base + Vector3(0, h - 0.05, 0), 0.03, 0.09)


func _columns(kit: MeshKit, l: int) -> void:
	for c: Dictionary in house.storey(l).get("columns", []):
		var p := Vector3(float(c["x"]), fy, float(c["y"]))
		match str(c.get("kind", "timber_post")):
			"turned_post":
				kit.cylinder(m("trim_paint", MaterialLibrary.paint("white")), p, wh, 0.06, 0.05, 10)
				flat_box(kit, m("trim_paint", MaterialLibrary.paint("white")), p.x - 0.08, p.x + 0.08, fy, fy + 0.2, p.z - 0.08, p.z + 0.08)
			"brick_pier":
				flat_box(kit, m("brick_red"), p.x - 0.18, p.x + 0.18, fy, fy + wh, p.z - 0.18, p.z + 0.18)
			_:
				flat_box(kit, m("stump", Color("#A08C72")), p.x - 0.06, p.x + 0.06, fy, fy + wh, p.z - 0.06, p.z + 0.06)


# --- Stairs --------------------------------------------------------------------------------------

func _stairs(kit: MeshKit, l: int) -> void:
	if not house.has_storey(l + 1):
		return
	var rise_total := level_y(l + 1) - fy
	var tread := m("pine_boards")
	var stringer := m("trim_stain")
	for st: Dictionary in house.stairs(l):
		var info := house.stair_tiles(st, l)
		var path: Array = info["lower"]
		var kind := str(st.get("kind", "straight"))
		if kind == "ladder":
			_ladder(kit, path[0], info["arrival"], rise_total)
			continue
		# Walk the path: flights rise, landings stay level. The landing is the turning tile.
		var segments: Array = []
		var i := 0
		while i < path.size():
			var t: Vector2i = path[i]
			var nxt: Vector2i = path[i + 1] if i + 1 < path.size() else info["arrival"]
			var prv: Vector2i = path[i - 1] if i > 0 else info["approach"]
			var turning := (nxt - t) != (t - prv)
			segments.append({"t": t, "dir": nxt - t if not turning else t - prv, "landing": turning})
			i += 1
		var flight_tiles := segments.filter(func(s: Dictionary) -> bool: return not s["landing"]).size()
		var steps_per_tile := maxi(1, ceili(rise_total / 0.18 / maxf(flight_tiles, 1)))
		var rise := rise_total / float(flight_tiles * steps_per_tile + (1 if flight_tiles > 0 else 0))
		var y := fy
		for seg: Dictionary in segments:
			var t2: Vector2i = seg["t"]
			var d: Vector2i = seg["dir"]
			var centre := Vector3(t2.x + 0.5, 0, t2.y + 0.5)
			var dv := Vector3(d.x, 0, d.y)
			var side := Vector3(-d.y, 0, d.x)
			if seg["landing"]:
				y += rise
				flat_box(kit, tread, t2.x + 0.05, t2.x + 0.95, fy, y, t2.y + 0.05, t2.y + 0.95)
				continue
			for s in steps_per_tile:
				y += rise
				var p := centre - dv * 0.5 + dv * ((s + 0.5) / steps_per_tile)
				var going := 1.0 / steps_per_tile
				var sz := Vector3(0.9 if d.x == 0 else going + 0.02, 0.04, 0.9 if d.y == 0 else going + 0.02)
				kit.box(tread, Transform3D(Basis(), p + Vector3(0, y - 0.02, 0)), sz)
				# Riser.
				var rp := p - dv * (going * 0.5) + Vector3(0, y - rise * 0.5 - 0.02, 0)
				kit.box(stringer, Transform3D(Basis(), rp), Vector3(0.9 if d.x == 0 else 0.02, rise, 0.9 if d.y == 0 else 0.02))
			# Stringers both sides and a handrail on the open side.
			for sgn: float in [-1.0, 1.0]:
				var a := centre - dv * 0.5 + side * (0.47 * sgn) + Vector3(0, y - rise * steps_per_tile - 0.1, 0)
				var b := centre + dv * 0.5 + side * (0.47 * sgn) + Vector3(0, y - 0.1, 0)
				kit.beam(stringer, a, b, 0.04, 0.22)
				kit.beam(stringer, a + Vector3(0, 0.95, 0), b + Vector3(0, 0.95, 0), 0.05, 0.05)
				kit.beam(stringer, b, b + Vector3(0, 0.95, 0), 0.04, 0.04)


func _ladder(kit: MeshKit, t: Vector2i, arrival: Vector2i, rise_total: float) -> void:
	var d := Vector3(arrival.x - t.x, 0, arrival.y - t.y)
	var side := Vector3(-d.z, 0, d.x)
	var foot := Vector3(t.x + 0.5, fy, t.y + 0.5) - d * 0.3
	var top := Vector3(t.x + 0.5, fy + rise_total, t.y + 0.5) + d * 0.45
	var wood := m("trim_stain")
	for sgn: float in [-1.0, 1.0]:
		kit.beam(wood, foot + side * 0.22 * sgn, top + side * 0.22 * sgn, 0.05, 0.07)
	var rungs := int(rise_total / 0.28)
	for i in range(1, rungs):
		var p := foot.lerp(top, float(i) / rungs)
		kit.beam(wood, p - side * 0.22, p + side * 0.22, 0.035)


## A simple balustrade round stairwells upstairs, except where you step off.
func _stairwell_rails(kit: MeshKit, l: int) -> void:
	var wells := house.stairwell_tiles(l)
	if wells.is_empty():
		return
	var arrivals: Dictionary = {}
	for st: Dictionary in house.stairs(l - 1):
		var info := house.stair_tiles(st, l - 1)
		var path: Array = info["lower"]
		arrivals[HouseData.tile_key(path[path.size() - 1].x, path[path.size() - 1].y) + ">" + HouseData.tile_key(info["arrival"].x, info["arrival"].y)] = true
	var wood := m("trim_stain")
	for tk: String in wells:
		var t := HouseData.parse_tile(tk)
		for nb: Array in [[Vector2i(0, -1), HouseData.hkey(t.x, t.y)], [Vector2i(0, 1), HouseData.hkey(t.x, t.y + 1)],
				[Vector2i(-1, 0), HouseData.vkey(t.x, t.y)], [Vector2i(1, 0), HouseData.vkey(t.x + 1, t.y)]]:
			var o: Vector2i = t + (nb[0] as Vector2i)
			var ok := HouseData.tile_key(o.x, o.y)
			if wells.has(ok) or house.walls(l).has(str(nb[1])) or arrivals.has(tk + ">" + ok):
				continue
			if not house.floors(l).has(ok):
				continue
			var pts := HouseData.edge_points(str(nb[1]))
			var a := Vector3(pts[0].x, fy, pts[0].y)
			var b := Vector3(pts[1].x, fy, pts[1].y)
			kit.beam(wood, a + Vector3(0, 0.92, 0), b + Vector3(0, 0.92, 0), 0.06, 0.06)
			for f in 5:
				var p := a.lerp(b, (f + 0.5) / 5.0)
				kit.beam(wood, p, p + Vector3(0, 0.9, 0), 0.03)


# --- Walls ---------------------------------------------------------------------------------------

## Builds the walls (with joinery, curtains, chimney breasts and fixtures) of one storey, limited to
## one chunk when chunk is given. cut_fn(edge_key) -> bool lowers walls for the cutaway.
func build_walls(kit: MeshKit, l: int, cut_fn: Callable, chunk: Variant = null) -> void:
	set_level(l)
	var wd := house.walls(l)
	for k: String in wd:
		if chunk != null and edge_chunk(k) != chunk:
			continue
		var cut: bool = cut_fn.call(k)
		_wall_edge(kit, k, cut)
	for o: Dictionary in house.openings(l):
		var edges := HouseData.opening_edges(o)
		if edges.is_empty() or (chunk != null and edge_chunk(edges[0]) != chunk):
			continue
		_opening_joinery(kit, o, edges, cut_fn)
	if l == 0 and (chunk == null or chunk == Vector2i.ZERO):
		_chimney_breasts(kit, cut_fn)
		_fixtures(kit, cut_fn)


func _wall_edge(kit: MeshKit, k: String, cut: bool) -> void:
	var pts := HouseData.edge_points(k)
	var a := Vector3(pts[0].x, 0, pts[0].y)
	var b := Vector3(pts[1].x, 0, pts[1].y)
	var stage := str(house.wall(level, k).get("stage", ""))
	if stage != "":
		_wall_in_progress(kit, k, a, b, stage)
		return
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var na := _side_normal3(k)  # points out of side a
	var full_h := house.wall_h(level, k)
	var top_h := minf(full_h, CUT_HEIGHT) if cut else full_h
	var top := fy + top_h
	var e := T * 0.5
	# Corners: reach into the corner where another wall turns; cap free ends.
	var ext := [0.0, 0.0]
	var cap := [false, false]
	for end_i in 2:
		var v: Vector2i = pts[end_i]
		var other := pts[1 - end_i]
		var continues := house.walls(level).has(HouseData.edge_from_points(v, v + (v - other)))
		var others := _walls_at(v) - 1
		if continues:
			ext[end_i] = 0.0
		elif others > 0:
			ext[end_i] = e
		else:
			cap[end_i] = true
	var s_start := -float(ext[0])
	var s_end := length + float(ext[1])
	var ops := house.openings_on_edge(level, k)
	var cuts: Array[float] = [s_start, s_end]
	for op in ops:
		cuts.append(float(op["from"]))
		cuts.append(float(op["to"]))
	cuts.sort()
	var u_base := a.x if absf(dir.x) > absf(dir.z) else a.z
	for side: String in ["a", "b"]:
		var n := na if side == "a" else -na
		var outside := is_outside(k, side)
		var mat := face_material(k, side)
		var fd := face_dict(k, side)
		var dado: Dictionary = fd.get("dado", {})
		var dado_y := fy + float(dado.get("h", 1.0)) if not dado.is_empty() else -INF
		var dado_mat := surface_key(dado) if not dado.is_empty() else ""
		var y0 := fy - (0.32 if outside and level == 0 else (FLOOR_THICKNESS if outside else 0.0))
		var off := n * e
		for i in cuts.size() - 1:
			var s0 := cuts[i]
			var s1 := cuts[i + 1]
			if s1 - s0 < 0.0001:
				continue
			var hole := _hole_at(ops, (s0 + s1) * 0.5)
			var spans: Array[Vector2] = []
			if hole.is_empty():
				spans.append(Vector2(y0, top))
			else:
				var ob := fy + _o_bottom(hole)
				var ot := fy + _o_top(hole)
				if ob > y0 + 0.001:
					spans.append(Vector2(y0, minf(ob, top)))
				if ot < top - 0.001:
					spans.append(Vector2(ot, top))
			for sp in spans:
				if sp.y - sp.x < 0.001:
					continue
				# Split at the dado height: panelling or tiles below, the main finish above.
				var parts: Array = [[sp.x, sp.y, mat]]
				if dado_y > sp.x + 0.001 and dado_y < sp.y - 0.001:
					parts = [[sp.x, dado_y, dado_mat], [dado_y, sp.y, mat]]
				elif dado_y >= sp.y - 0.001:
					parts = [[sp.x, sp.y, dado_mat]]
				for part: Array in parts:
					var ya: float = part[0]
					var yb: float = part[1]
					var p0 := a + dir * s0 + off + Vector3(0, ya, 0)
					var p1 := a + dir * s1 + off + Vector3(0, ya, 0)
					var p2 := a + dir * s1 + off + Vector3(0, yb, 0)
					var p3 := a + dir * s0 + off + Vector3(0, yb, 0)
					_wall_quad(kit, str(part[2]), p0, p1, p2, p3, n, s0 + u_base)
			if not outside and hole.is_empty() and top_h > 0.2:
				var ra := a + dir * maxf(s0, 0.0) + off
				var rb := a + dir * minf(s1, length) + off
				_skirting(kit, ra, rb, n)
				var tall := top_h > 2.4 and str(house.wall(level, k).get("kind", "full")) == "full"
				if not cut and tall and _room_trim(k, side, "picture_rail", top_h >= 2.9):
					_picture_rail(kit, ra, rb, n, top_h)
				if not cut and tall and _room_trim(k, side, "cornice", false):
					_cornice(kit, ra, rb, n, top_h)
				if not dado.is_empty() and dado_y < fy + top_h:
					_rail_at(kit, ra, rb, n, dado_y)
	# Top cap and end caps.
	var capm := m("trim_paint", Color("#EFE9DA"))
	var c0 := a + dir * s_start + na * e + Vector3(0, top, 0)
	var c1 := a + dir * s_end + na * e + Vector3(0, top, 0)
	face(kit, capm, c0, c1, c1 - na * T, c0 - na * T, Vector3.UP)
	for end_i2 in 2:
		if not cap[end_i2]:
			continue
		var p := a if end_i2 == 0 else b
		var out_dir := -dir if end_i2 == 0 else dir
		face(kit, capm, p + na * e + Vector3(0, fy, 0), p - na * e + Vector3(0, fy, 0), p - na * e + Vector3(0, top, 0), p + na * e + Vector3(0, top, 0), out_dir)
	# Reveals round openings in this edge.
	for op2 in ops:
		_reveal(kit, a, dir, na, float(op2["from"]), float(op2["to"]), op2["o"], top)


func _walls_at(v: Vector2i) -> int:
	var n := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		if house.walls(level).has(HouseData.edge_from_points(v, v + d)):
			n += 1
	return n


static func _side_normal3(k: String) -> Vector3:
	if k.ends_with(",N"):
		return Vector3(0, 0, -1)
	if k.ends_with(",W"):
		return Vector3(-1, 0, 0)
	if k.ends_with(",D"):
		return Vector3(1, 0, -1).normalized()
	return Vector3(-1, 0, -1).normalized()


func _hole_at(ops: Array[Dictionary], s: float) -> Dictionary:
	for op in ops:
		if s > float(op["from"]) and s < float(op["to"]):
			return op["o"]
	return {}


func _o_bottom(o: Dictionary) -> float:
	return float(o.get("sill", 0.0)) if o["kind"] == "window" else 0.0


func _o_top(o: Dictionary) -> float:
	var h := float(o["height"])
	if o.get("fanlight", false):
		h += 0.42
	return _o_bottom(o) + h


func _skirting(kit: MeshKit, a: Vector3, b: Vector3, n: Vector3) -> void:
	if a.distance_to(b) < 0.01:
		return
	var mat := m("trim_stain")
	var h := 0.17
	var t := 0.022
	var p0 := a + n * t
	var p1 := b + n * t
	face(kit, mat, p0 + Vector3(0, fy, 0), p1 + Vector3(0, fy, 0), p1 + Vector3(0, fy + h, 0), p0 + Vector3(0, fy + h, 0), n)
	face(kit, mat, a + Vector3(0, fy + h, 0), b + Vector3(0, fy + h, 0), p1 + Vector3(0, fy + h, 0), p0 + Vector3(0, fy + h, 0), Vector3.UP)


func _picture_rail(kit: MeshKit, a: Vector3, b: Vector3, n: Vector3, top_h: float) -> void:
	if a.distance_to(b) < 0.01:
		return
	var mat := m("trim_stain")
	var y := fy + top_h - 0.42
	var t := 0.018
	face(kit, mat, a + n * t + Vector3(0, y, 0), b + n * t + Vector3(0, y, 0), b + n * t + Vector3(0, y + 0.045, 0), a + n * t + Vector3(0, y + 0.045, 0), n)
	face(kit, mat, a + Vector3(0, y + 0.045, 0), b + Vector3(0, y + 0.045, 0), b + n * t + Vector3(0, y + 0.045, 0), a + n * t + Vector3(0, y + 0.045, 0), Vector3.UP)
	face(kit, mat, a + Vector3(0, y, 0), b + Vector3(0, y, 0), b + n * t + Vector3(0, y, 0), a + n * t + Vector3(0, y, 0), Vector3.DOWN)


func _rail_at(kit: MeshKit, a: Vector3, b: Vector3, n: Vector3, y: float) -> void:
	if a.distance_to(b) < 0.01:
		return
	var mat := m("trim_stain")
	var t := 0.02
	face(kit, mat, a + n * t + Vector3(0, y - 0.02, 0), b + n * t + Vector3(0, y - 0.02, 0), b + n * t + Vector3(0, y + 0.03, 0), a + n * t + Vector3(0, y + 0.03, 0), n)
	face(kit, mat, a + Vector3(0, y + 0.03, 0), b + Vector3(0, y + 0.03, 0), b + n * t + Vector3(0, y + 0.03, 0), a + n * t + Vector3(0, y + 0.03, 0), Vector3.UP)


## A cornice: a cove strip where the wall meets the ceiling.
func _cornice(kit: MeshKit, a: Vector3, b: Vector3, n: Vector3, top_h: float) -> void:
	if a.distance_to(b) < 0.01:
		return
	var mat := m("trim_paint", Color("#F4F0E6"))
	var y := fy + top_h
	var pts: Array[Vector2] = [Vector2(0.0, -0.11), Vector2(0.03, -0.07), Vector2(0.07, -0.03), Vector2(0.11, 0.0)]
	for i in pts.size() - 1:
		var p := pts[i]
		var q := pts[i + 1]
		var nn := (n * (q.y - p.y) - Vector3.UP * (q.x - p.x)).normalized()
		face(kit, mat, a + n * p.x + Vector3(0, y + p.y, 0), b + n * p.x + Vector3(0, y + p.y, 0), b + n * q.x + Vector3(0, y + q.y, 0), a + n * q.x + Vector3(0, y + q.y, 0), nn)


## Jamb, head and sill faces of the part of an opening that falls in one edge.
func _reveal(kit: MeshKit, base: Vector3, dir: Vector3, nl: Vector3, s0: float, s1: float, o: Dictionary, top: float) -> void:
	var ob := fy + _o_bottom(o)
	var ot := fy + _o_top(o)
	var e := T * 0.5
	var reveal := m("trim_paint", Color("#EFE9DA"))
	var vis_top := minf(ot, top)
	# Jambs only where the opening actually starts or ends (not at an edge boundary inside it).
	var start := (float(o["x"]) if o["axis"] == "x" else float(o["z"]))
	var edge_pos := base.x if o["axis"] == "x" else base.z
	for s: float in [s0, s1]:
		var at := edge_pos + s
		if not (is_equal_approx(at, start) or is_equal_approx(at, start + float(o["width"]))):
			continue
		var into := dir if is_equal_approx(at, start) else -dir
		var p := base + dir * s
		if vis_top > ob:
			face(kit, reveal, p + nl * e + Vector3(0, ob, 0), p - nl * e + Vector3(0, ob, 0),
				p - nl * e + Vector3(0, vis_top, 0), p + nl * e + Vector3(0, vis_top, 0), into)
	if ot < top - 0.001:
		var a := base + dir * s0 + Vector3(0, ot, 0)
		var b := base + dir * s1 + Vector3(0, ot, 0)
		face(kit, reveal, a + nl * e, b + nl * e, b - nl * e, a - nl * e, Vector3.DOWN)
	if ob > fy + 0.001 and ob < top:
		var a2 := base + dir * s0 + Vector3(0, ob, 0)
		var b2 := base + dir * s1 + Vector3(0, ob, 0)
		face(kit, reveal, a2 + nl * e, b2 + nl * e, b2 - nl * e, a2 - nl * e, Vector3.UP)


## Window sashes, door leaves, frames and architraves for a whole opening.
func _opening_joinery(kit: MeshKit, o: Dictionary, edges: Array[String], cut_fn: Callable) -> void:
	for k in edges:
		if cut_fn.call(k) and _o_top(o) > CUT_HEIGHT:
			return
		if not house.walls(level).has(k):
			return
	var k0 := edges[0]
	var horizontal: bool = o["axis"] == "x"
	var line := float(o["z"]) if horizontal else float(o["x"])
	var base := Vector3(0, 0, line) if horizontal else Vector3(line, 0, 0)
	var dir := Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)
	var nl := _side_normal3(k0)
	var s0 := float(o["x"]) if horizontal else float(o["z"])
	var s1 := s0 + float(o["width"])
	var ob := fy + _o_bottom(o)
	var ot := fy + _o_top(o)
	var out_a := is_outside(k0, "a")
	var out_b := is_outside(k0, "b")
	var ext_side := 0.0
	if out_a and not out_b:
		ext_side = 1.0
	elif out_b and not out_a:
		ext_side = -1.0
	var inner_room := house.room_on_side(level, k0, "b" if ext_side > 0.0 else "a")
	var room_key := "%d:%s" % [level, str(inner_room.get("key", "none"))]
	match str(o["kind"]):
		"window":
			_window(kit, base, dir, nl, s0, s1, ob, ot, ext_side, room_key)
		"door":
			_door(kit, room_key, o, base, dir, nl, s0, s1, ob, ot, ext_side)
		_:
			_architraves(kit, base, dir, nl, s0, s1, ob, ot, ext_side, true)


func _fixtures(kit: MeshKit, cut_fn: Callable) -> void:
	for f in house.fixtures:
		match str(f["kind"]):
			"stove":
				_stove(kit, Vector3(float(f["x"]), fy, float(f["z"])))
			"rug":
				var tint: Variant = Color(str(f["tint"])) if f.has("tint") else null
				var rx := float(f["x"])
				var rz := float(f["z"])
				flat_box(kit, m(str(f["material"]), tint), rx - float(f["w"]) * 0.5, rx + float(f["w"]) * 0.5, fy + 0.002, fy + 0.012, rz - float(f["d"]) * 0.5, rz + float(f["d"]) * 0.5)
			"tablecloth":
				_tablecloth(kit, f)
			"curtains":
				_curtains(kit, f, cut_fn)


func _curtains(kit: MeshKit, f: Dictionary, cut_fn: Callable) -> void:
	var mat := m(str(f["material"]), Color(str(f.get("tint", "#F1EAD6"))))
	var pelmet := m("trim_stain")
	for o: Dictionary in house.openings(level):
		if o["kind"] != "window":
			continue
		var edges := HouseData.opening_edges(o)
		if edges.is_empty():
			continue
		var k0 := edges[0]
		var any_cut := false
		for k in edges:
			any_cut = any_cut or bool(cut_fn.call(k))
		var out_a := is_outside(k0, "a")
		var out_b := is_outside(k0, "b")
		if any_cut or out_a == out_b:
			continue
		var nl := _side_normal3(k0)
		var n := -nl if out_a else nl
		var horizontal: bool = o["axis"] == "x"
		var line := float(o["z"]) if horizontal else float(o["x"])
		var base := Vector3(0, 0, line) if horizontal else Vector3(line, 0, 0)
		var dir := Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)
		var s0 := float(o["x"]) if horizontal else float(o["z"])
		var s1 := s0 + float(o["width"])
		var ot := fy + _o_top(o)
		var ob := fy + _o_bottom(o)
		var off := n * (T * 0.5 + 0.05)
		kit.box(pelmet, Transform3D(Basis(), base + dir * ((s0 + s1) * 0.5) + off + Vector3(0, ot + 0.12, 0)), _oriented(dir, nl, s1 - s0 + 0.4, 0.14, 0.1))
		for side in 2:
			var a_s := s0 - 0.18 if side == 0 else s1 - 0.12
			var b_s := s0 + 0.12 if side == 0 else s1 + 0.18
			var folds := 6
			for i in folds:
				var t0 := float(i) / folds
				var t1 := float(i + 1) / folds
				var d0 := 0.035 if i % 2 == 0 else -0.01
				var d1 := 0.035 if (i + 1) % 2 == 0 else -0.01
				var p0 := base + dir * lerpf(a_s, b_s, t0) + off + n * d0
				var p1 := base + dir * lerpf(a_s, b_s, t1) + off + n * d1
				var y0 := ob - 0.12
				var y1 := ot + 0.08
				face(kit, mat, p0 + Vector3(0, y0, 0), p1 + Vector3(0, y0, 0), p1 + Vector3(0, y1, 0), p0 + Vector3(0, y1, 0), n)
				face(kit, mat, p1 + Vector3(0, y0, 0), p0 + Vector3(0, y0, 0), p0 + Vector3(0, y1, 0), p1 + Vector3(0, y1, 0), -n)


func _wall_cut_at(cut_fn: Callable, _axis: String, line: float, along: float) -> bool:
	var k := HouseData.hkey(floori(along), roundi(line))
	return house.walls(level).has(k) and bool(cut_fn.call(k))


# --- Roofs ---------------------------------------------------------------------------------------

## The roof sits on the top storey that has rooms. Verandahs and chimneys belong to the ground floor.
func build_roof(kit: MeshKit) -> void:
	var top := 0
	for l in house.levels():
		if l >= 0 and not house.rooms(l).is_empty():
			top = l
	_gable_key = ""
	for p: Dictionary in Roofs.pieces(house):
		set_level(int(p.get("level", 0)))
		_roof_piece(kit, p)
	set_level(0)
	for v in house.verandahs:
		set_level(int(v.get("level", 0)))
		_verandah_roof(kit, v)
	set_level(0)
	for c in house.chimneys:
		_chimney_stack(kit, c)



# --- Joinery (from M1) ----------------------------------------------------------------------------

func _architraves(kit: MeshKit, base: Vector3, dir: Vector3, nl: Vector3, s0: float, s1: float, ob: float, ot: float, ext_side: float, both_inside: bool) -> void:
	var e := T * 0.5
	var aw := 0.075
	for side: float in [1.0, -1.0]:
		var outside := side == ext_side
		if not outside and not both_inside and ext_side == 0.0:
			pass
		var mat := m("trim_paint", trim_ext.lightened(0.0)) if outside else m("trim_stain")
		if outside:
			mat = m("trim_paint", MaterialLibrary.paint("white"))
		var n := nl * side
		var off := n * (e + 0.012)
		var bottom := ob if ob > fy + 0.01 else fy
		for s: float in [s0 - aw * 0.5, s1 + aw * 0.5]:
			kit.box(mat, Transform3D(Basis(), base + dir * s + off + Vector3(0, (bottom + ot + aw) * 0.5, 0)),
				_oriented(dir, nl, aw, ot + aw - bottom, 0.024))
		kit.box(mat, Transform3D(Basis(), base + dir * ((s0 + s1) * 0.5) + off + Vector3(0, ot + aw * 0.5, 0)),
			_oriented(dir, nl, s1 - s0 + aw * 2.0, aw, 0.024))


## A box size for something running along dir (length) with given height and depth through the wall.
func _oriented(dir: Vector3, _nl: Vector3, length: float, height: float, depth: float) -> Vector3:
	return Vector3(length, height, depth) if absf(dir.x) > 0.5 else Vector3(depth, height, length)


func _window(kit: MeshKit, base: Vector3, dir: Vector3, nl: Vector3, s0: float, s1: float, ob: float, ot: float, ext_side: float, room_id: String) -> void:
	var sash := m("trim_paint", trim_ext)
	var frame := m("trim_paint", MaterialLibrary.paint("white"))
	var g := glass(room_id)
	var w := s1 - s0
	var mid_s := (s0 + s1) * 0.5
	var ext_n := nl * ext_side
	var fw := 0.045
	# Frame lining inside the opening.
	for s: float in [s0 + fw * 0.5, s1 - fw * 0.5]:
		kit.box(frame, Transform3D(Basis(), base + dir * s + Vector3(0, (ob + ot) * 0.5, 0)), _oriented(dir, nl, fw, ot - ob, T * 0.9))
	kit.box(frame, Transform3D(Basis(), base + dir * mid_s + Vector3(0, ot - fw * 0.5, 0)), _oriented(dir, nl, w, fw, T * 0.9))
	# Two sashes: the lower one towards the inside, the upper one towards the outside.
	var meet := (ob + ot) * 0.5
	var inner_w := w - fw * 2.0
	for k in 2:
		var y0 := ob + 0.02 if k == 0 else meet - 0.02
		var y1 := meet + 0.02 if k == 0 else ot - fw
		var plane := base + dir * mid_s + ext_n * (-0.012 if k == 0 else 0.022)
		var sw := 0.045
		var sd := 0.035
		kit.box(sash, Transform3D(Basis(), plane + Vector3(0, y0 + 0.03, 0)), _oriented(dir, nl, inner_w, 0.06, sd))
		kit.box(sash, Transform3D(Basis(), plane + Vector3(0, y1 - 0.02, 0)), _oriented(dir, nl, inner_w, 0.04, sd))
		for s: float in [-inner_w * 0.5 + sw * 0.5, inner_w * 0.5 - sw * 0.5]:
			kit.box(sash, Transform3D(Basis(), plane + dir * s + Vector3(0, (y0 + y1) * 0.5, 0)), _oriented(dir, nl, sw, y1 - y0, sd))
		# Glass in the sash. Two-sided material, so one quad will do.
		var ga := plane - dir * (inner_w * 0.5 - sw) + Vector3(0, y0 + 0.06, 0)
		var gb := plane + dir * (inner_w * 0.5 - sw) + Vector3(0, y0 + 0.06, 0)
		face(kit, g, ga, gb, gb + Vector3(0, y1 - y0 - 0.1, 0), ga + Vector3(0, y1 - y0 - 0.1, 0), ext_n if ext_side != 0.0 else nl)
	# Outside sill and architraves.
	if ext_side != 0.0:
		var e := T * 0.5
		kit.box(frame, Transform3D(Basis(), base + dir * mid_s + ext_n * (e + 0.03) + Vector3(0, ob - 0.02, 0)), _oriented(dir, nl, w + 0.16, 0.045, 0.1))
	_architraves(kit, base, dir, nl, s0, s1, ob, ot, ext_side, false)


func _door(kit: MeshKit, room_id: String, o: Dictionary, base: Vector3, dir: Vector3, nl: Vector3, s0: float, s1: float, ob: float, ot: float, ext_side: float) -> void:
	var exterior := ext_side != 0.0
	var door_mat := m("trim_paint", MaterialLibrary.paint(str(house.exterior.get("door", "brunswick_green")))) if exterior else m("trim_stain")
	var frame := m("trim_paint", MaterialLibrary.paint("white"))
	var width := s1 - s0
	var leaf_h := float(o["height"]) - 0.01
	var fw := 0.04
	for s: float in [s0 + fw * 0.5, s1 - fw * 0.5]:
		kit.box(frame, Transform3D(Basis(), base + dir * s + Vector3(0, (ob + ot) * 0.5, 0)), _oriented(dir, nl, fw, ot - ob, T + 0.01))
	kit.box(frame, Transform3D(Basis(), base + dir * ((s0 + s1) * 0.5) + Vector3(0, ot - fw * 0.5, 0)), _oriented(dir, nl, width, fw, T + 0.01))
	if o.get("fanlight", false):
		var transom_y := ob + float(o["height"])
		kit.box(frame, Transform3D(Basis(), base + dir * ((s0 + s1) * 0.5) + Vector3(0, transom_y + 0.025, 0)), _oriented(dir, nl, width, 0.05, T))
		var ga := base + dir * (s0 + fw) + Vector3(0, transom_y + 0.05, 0)
		var gb := base + dir * (s1 - fw) + Vector3(0, transom_y + 0.05, 0)
		face(kit, glass(room_id), ga, gb, gb + Vector3(0, ot - transom_y - 0.09, 0), ga + Vector3(0, ot - transom_y - 0.09, 0), nl * ext_side)
	# The leaf, hinged at s0, swung open by "open" degrees (positive towards the right-hand side).
	var leaf_w := width - fw * 2.0 - 0.006
	var hinge := base + dir * (s0 + fw + 0.003) + Vector3(0, ob + 0.005, 0)
	var angle := deg_to_rad(float(o.get("open", 0.0)))
	# Positive angles swing the leaf towards the right-hand side of the wall (south or east).
	var rot := Basis(Vector3.UP, -angle) if absf(dir.x) > 0.5 else Basis(Vector3.UP, angle)
	var leaf_xf := func(local: Vector3) -> Vector3: return hinge + rot * local
	var thick := 0.04
	var along := dir
	var mk_box := func(mat: String, centre: Vector3, l: float, h: float, d: float) -> void:
		kit.box(mat, Transform3D(rot, leaf_xf.call(centre)), _oriented(along, nl, l, h, d))
	mk_box.call(door_mat, along * (leaf_w * 0.5) + Vector3(0, leaf_h * 0.5, 0), leaf_w, leaf_h, thick)
	var style := str(o.get("style", "four_panel"))
	if style == "four_panel":
		var pw := (leaf_w - 0.3) * 0.5
		for col in 2:
			var cx := 0.1 + pw * 0.5 + col * (pw + 0.1)
			for spec: Vector2 in [Vector2(0.15, 0.95), Vector2(1.1, leaf_h - 0.12)]:
				var ph := spec.y - spec.x
				for side: float in [1.0, -1.0]:
					mk_box.call(door_mat, along * cx + Vector3(0, spec.x + ph * 0.5, 0) + nl * side * (thick * 0.5 + 0.004), pw, ph, 0.008)
	else:
		for y: float in [0.25, leaf_h * 0.5, leaf_h - 0.25]:
			mk_box.call(door_mat, along * (leaf_w * 0.5) + Vector3(0, y, 0) + nl * ext_side * -(thick * 0.5 + 0.012), leaf_w - 0.06, 0.12, 0.022)
	# Knob on both faces.
	for side2: float in [1.0, -1.0]:
		mk_box.call(m("brass"), along * (leaf_w - 0.07) + Vector3(0, 0.98, 0) + nl * side2 * (thick * 0.5 + 0.03), 0.045, 0.045, 0.05)
	_architraves(kit, base, dir, nl, s0, s1, ob, ot, ext_side, true)


# --- Fireplaces and fixtures ---------------------------------------------------------------------

func _chimney_breasts(kit: MeshKit, cut_fn: Callable) -> void:
	for c in house.chimneys:
		var line := float(c["z"]) + float(c["d"]) * 0.5
		for br: Dictionary in c.get("breast", []):
			var room_id := str(br["room"])
			var paint := m("plaster", room_paint(room_id))
			var x0 := float(br["x"])
			var x1 := x0 + float(br["w"])
			var depth := float(br["depth"])
			var facing_n := str(br["face"]) == "N"
			var wall_face := line - T * 0.5 if facing_n else line + T * 0.5
			var front := wall_face - depth if facing_n else wall_face + depth
			var cut := _wall_cut_at(cut_fn, "x", line, (x0 + x1) * 0.5)
			var top := fy + (CUT_HEIGHT if cut else wh)
			var n := Vector3(0, 0, -1) if facing_n else Vector3(0, 0, 1)
			if br.get("recess", false):
				# Two cheeks and a lintel, with brick at the back, for the kitchen stove.
				var cheek := 0.4
				for xr: Vector2 in [Vector2(x0, x0 + cheek), Vector2(x1 - cheek, x1)]:
					flat_box(kit, paint, xr.x, xr.y, fy, top, minf(wall_face, front), maxf(wall_face, front))
				if not cut:
					flat_box(kit, paint, x0 + cheek, x1 - cheek, fy + 1.55, top, minf(wall_face, front), maxf(wall_face, front))
				face(kit, m("brick_red"), Vector3(x0 + cheek, fy, wall_face + n.z * 0.002), Vector3(x1 - cheek, fy, wall_face + n.z * 0.002),
					Vector3(x1 - cheek, minf(top, fy + 1.55), wall_face + n.z * 0.002), Vector3(x0 + cheek, minf(top, fy + 1.55), wall_face + n.z * 0.002), n)
				flat_box(kit, m("brick_red"), x0 + cheek, x1 - cheek, fy, fy + 0.04, minf(wall_face, front), maxf(wall_face, front))
			else:
				flat_box(kit, paint, x0, x1, fy, top, minf(wall_face, front), maxf(wall_face, front))
				if br.get("fireplace", false):
					var cx := (x0 + x1) * 0.5
					var fz := front + n.z * 0.003
					face(kit, m("enamel_black"), Vector3(cx - 0.42, fy, fz), Vector3(cx + 0.42, fy, fz), Vector3(cx + 0.42, fy + 0.72, fz), Vector3(cx - 0.42, fy + 0.72, fz), n)
					flat_box(kit, m("brick_red"), cx - 0.8, cx + 0.8, fy, fy + 0.03, minf(front, front + n.z * 0.5), maxf(front, front + n.z * 0.5))
					if top > fy + 1.25:
						flat_box(kit, m("trim_stain"), x0 - 0.06, x1 + 0.06, fy + 1.17, fy + 1.22, minf(front, front + n.z * 0.2), maxf(front, front + n.z * 0.2))
					for px: float in [cx - 0.6, cx + 0.6]:
						flat_box(kit, m("trim_stain"), px - 0.09, px + 0.09, fy, minf(top, fy + 1.17), minf(front, front + n.z * 0.05), maxf(front, front + n.z * 0.05))
					flat_box(kit, m("trim_stain"), cx - 0.6, cx + 0.6, fy + 0.72, minf(top, fy + 0.86), minf(front, front + n.z * 0.05), maxf(front, front + n.z * 0.05))
					# Two logs in the grate.
					kit.frustum(m("bark_gum", Color("#6B5A4A")), Vector3(cx - 0.3, fy + 0.08, front - n.z * 0.15), Vector3(cx + 0.3, fy + 0.1, front - n.z * 0.2), 0.06, 0.05, 6)
					kit.frustum(m("bark_gum", Color("#5A4A3C")), Vector3(cx - 0.25, fy + 0.16, front - n.z * 0.22), Vector3(cx + 0.28, fy + 0.15, front - n.z * 0.12), 0.05, 0.05, 6)


func _stove(kit: MeshKit, p: Vector3) -> void:
	var body := m("enamel_black")
	var iron := m("cast_iron")
	var chrome := m("chrome")
	var w := 0.95
	var d := 0.58
	var h := 0.78
	var leg := 0.08
	for lx: float in [-w * 0.45, w * 0.45]:
		for lz: float in [-d * 0.4, d * 0.4]:
			flat_box(kit, iron, p.x + lx - 0.03, p.x + lx + 0.03, p.y, p.y + leg, p.z + lz - 0.03, p.z + lz + 0.03)
	flat_box(kit, body, p.x - w * 0.5, p.x + w * 0.5, p.y + leg, p.y + h, p.z - d * 0.5, p.z + d * 0.5)
	flat_box(kit, iron, p.x - w * 0.52, p.x + w * 0.52, p.y + h, p.y + h + 0.04, p.z - d * 0.52, p.z + d * 0.52)
	for hx: float in [-0.22, 0.2]:
		kit.cylinder(iron, Vector3(p.x + hx, p.y + h + 0.04, p.z + 0.02), 0.012, 0.11, 0.11, 12)
	# Oven door and firebox door with chrome handles, and the towel rail.
	var front := p.z + d * 0.5
	flat_box(kit, m("enamel_cream"), p.x - 0.05, p.x + 0.42, p.y + 0.18, p.y + 0.62, front, front + 0.015)
	flat_box(kit, iron, p.x - 0.42, p.x - 0.12, p.y + 0.38, p.y + 0.62, front, front + 0.02)
	flat_box(kit, chrome, p.x + 0.0, p.x + 0.36, p.y + 0.56, p.y + 0.58, front + 0.015, front + 0.04)
	kit.frustum(chrome, Vector3(p.x - w * 0.5, p.y + h - 0.06, front + 0.06), Vector3(p.x + w * 0.5, p.y + h - 0.06, front + 0.06), 0.012, 0.012, 8)
	# Flue up into the chimney.
	kit.cylinder(m("enamel_black"), Vector3(p.x + 0.25, p.y + h + 0.04, p.z - 0.12), 0.75, 0.075, 0.075, 12)


func _tablecloth(kit: MeshKit, f: Dictionary) -> void:
	var mat := m(str(f["material"]))
	var cx := float(f["x"])
	var cz := float(f["z"])
	var hw := float(f["w"]) * 0.5
	var hd := float(f["d"]) * 0.5
	var y := fy + float(f["h"])
	var drop := 0.24
	kit.quad(mat, Vector3(cx - hw, y, cz + hd), Vector3(cx + hw, y, cz + hd), Vector3(cx + hw, y, cz - hd), Vector3(cx - hw, y, cz - hd),
		Vector2(0, 2 * hd), Vector2(2 * hw, 2 * hd), Vector2(2 * hw, 0), Vector2(0, 0))
	var corners := [Vector3(cx - hw, y, cz + hd), Vector3(cx + hw, y, cz + hd), Vector3(cx + hw, y, cz - hd), Vector3(cx - hw, y, cz - hd)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var outn := ((a + b) * 0.5 - Vector3(cx, y, cz)).normalized()
		outn.y = 0.0
		var flare := outn.normalized() * 0.03
		face(kit, mat, a + flare + Vector3(0, -drop, 0), b + flare + Vector3(0, -drop, 0), b, a, outn.normalized())


# --- Verandahs, roofs and chimneys ----------------------------------------------------------------

func _verandah_deck(kit: MeshKit, v: Dictionary) -> void:
	set_level(int(v.get("level", 0)))
	var f := _vframe(v)
	var depth: float = f["depth"]
	var u0: float = f["u0"]
	var u1: float = f["u1"]
	var top := fy - 0.08
	var deck := m("decking")
	# Boards run out from the house.
	var c0 := _vp(f, u0, top, 0.0)
	var c1 := _vp(f, u1, top, 0.0)
	var c2 := _vp(f, u1, top, depth)
	var c3 := _vp(f, u0, top, depth)
	face_uv(kit, deck, c0, c1, c2, c3, Vector3.UP, Vector2(0.0, u0), Vector2(0.0, u1), Vector2(depth, u1), Vector2(depth, u0))
	var paint := m("trim_paint", _paint(str(v.get("colour", "cream"))))
	_vbox(kit, deck, f, u0, u1, top - 0.2, top - 0.005, depth - 0.05, depth)
	_vbox(kit, m("stump"), f, u0 + 0.05, u1 - 0.05, top - 0.35, top - 0.06, 0.1, depth - 0.05)
	var r: Rect2 = f["rect"]
	_stumps(kit, r.grow(-0.15), top - 0.35, 1.8)
	if bool(v.get("lattice", false)):
		_verandah_lattice(kit, v, f, top - 0.2)
	var steps := _verandah_steps(v)
	for st: Array in steps:
		var a := float(st[0])
		var b := float(st[1])
		var ground := float(ground_fn.call(_vp(f, (a + b) * 0.5, 0.0, depth + 0.6).x, _vp(f, (a + b) * 0.5, 0.0, depth + 0.6).z))
		var rise := top - ground
		var n := maxi(1, int(round(rise / 0.18)) - 1)
		for k in range(1, n + 1):
			var y_k := top - k * rise / (n + 1)
			_vbox(kit, deck, f, a, b, ground - 0.05, y_k, depth + 0.28 * (k - 1), depth + 0.28 * k)
		# Stringers either side.
		for su: float in [a - 0.04, b + 0.04]:
			kit.beam(paint, _vp(f, su, top - 0.02, depth), _vp(f, su, ground, depth + 0.28 * n), 0.05, 0.2)
	# Posts, beam, lace or brackets and rails stay visible when the roof is hidden.
	var post_h := _post_h(v)
	var posts := _verandah_posts(v)
	var beam_d := depth - 0.12
	var beam_y := top + post_h
	for pu: float in posts:
		_verandah_post(kit, v, f, pu, beam_d, top, post_h, paint)
	_vbox(kit, paint, f, u0, u1, beam_y, beam_y + 0.15, beam_d - 0.05, beam_d + 0.05)
	var lace := str(v.get("lace", "none"))
	var so: Dictionary = v.get("sleepout", {})
	if lace != "none":
		var frieze := _lace_mat("lace_frieze" if lace == "lace" else "fret_frieze", str(v.get("lace_colour", v.get("colour", "cream"))))
		var fh := 0.26
		var fa := _vp(f, u0, beam_y - fh, beam_d)
		var fb := _vp(f, u1, beam_y - fh, beam_d)
		var fc := _vp(f, u1, beam_y, beam_d)
		var fd := _vp(f, u0, beam_y, beam_d)
		var rep := 0.6
		face_uv(kit, frieze, fa, fb, fc, fd, f["out"], Vector2(u0 / rep, 1), Vector2(u1 / rep, 1), Vector2(u1 / rep, 0), Vector2(u0 / rep, 0))
	for pu2: float in posts:
		for dirn: float in [-1.0, 1.0]:
			if (dirn < 0.0 and pu2 < u0 + 0.3) or (dirn > 0.0 and pu2 > u1 - 0.3):
				continue
			if lace != "none":
				var br := _lace_mat("lace_bracket" if lace == "lace" else "fret_bracket", str(v.get("lace_colour", v.get("colour", "cream"))))
				var size := 0.42
				var top_y := beam_y - (0.26 if true else 0.0)
				var p0 := _vp(f, pu2 + dirn * 0.05, top_y, beam_d)
				var p1 := _vp(f, pu2 + dirn * (0.05 + size), top_y, beam_d)
				var p2 := _vp(f, pu2 + dirn * 0.05, top_y - size, beam_d)
				kit.tri(br, p0, p1, p2, Vector2(0, 0), Vector2(1, 0), Vector2(0, 1))
				kit.tri(br, p0, p2, p1, Vector2(0, 0), Vector2(0, 1), Vector2(1, 0))
			else:
				kit.beam(paint, _vp(f, pu2 + dirn * 0.05, beam_y - 0.32, beam_d), _vp(f, pu2 + dirn * 0.36, beam_y - 0.01, beam_d), 0.05, 0.04)
	var rail := str(v.get("rail", "none"))
	if rail != "none":
		_verandah_rails(kit, v, f, posts, top, beam_d, rail, paint, steps)


## The local frame of a verandah: u along the wall, d out from the wall face.
func _vframe(v: Dictionary) -> Dictionary:
	var r := BuildOps.verandah_rect(house, v)
	var side := str(v["side"])
	var f := {"side": side, "rect": r, "depth": float(v["depth"]), "u0": float(v["from"]), "u1": float(v["to"])}
	match side:
		"N":
			f["wall"] = r.end.y
			f["out"] = Vector3(0, 0, -1)
		"S":
			f["wall"] = r.position.y
			f["out"] = Vector3(0, 0, 1)
		"W":
			f["wall"] = r.end.x
			f["out"] = Vector3(-1, 0, 0)
		_:
			f["wall"] = r.position.x
			f["out"] = Vector3(1, 0, 0)
	return f


func _vp(f: Dictionary, u: float, y: float, d: float) -> Vector3:
	var w: float = f["wall"]
	match str(f["side"]):
		"N":
			return Vector3(u, y, w - d)
		"S":
			return Vector3(u, y, w + d)
		"W":
			return Vector3(w - d, y, u)
	return Vector3(w + d, y, u)


func _vbox(kit: MeshKit, mat: String, f: Dictionary, u0: float, u1: float, y0: float, y1: float, d0: float, d1: float) -> void:
	var a := _vp(f, u0, y0, d0)
	var b := _vp(f, u1, y1, d1)
	flat_box(kit, mat, minf(a.x, b.x), maxf(a.x, b.x), y0, y1, minf(a.z, b.z), maxf(a.z, b.z))


func _verandah_steps(v: Dictionary) -> Array:
	var st: Variant = v.get("steps", [])
	if st is Dictionary:
		return [[float(st["from"]), float(st["to"])]]
	return st as Array


func _verandah_posts(v: Dictionary) -> Array[float]:
	var out: Array[float] = []
	if v.has("posts") and v["posts"] is Array:
		for p: Variant in v["posts"]:
			out.append(float(p))
		return out
	var a := float(v["from"]) + 0.1
	var b := float(v["to"]) - 0.1
	var n := maxi(1, ceili((b - a) / 2.4))
	for i in n + 1:
		out.append(lerpf(a, b, float(i) / n))
	return out


## Post height: as asked, but low enough that the roof still falls to the beam from under the eaves.
func _post_h(v: Dictionary) -> float:
	var want := float(v.get("post_h", 2.1))
	var wall_y := fy + wh - 0.06
	var deck := fy - 0.08
	var room := wall_y - deck - 0.15 - float(v["depth"]) * 0.09
	if str(v.get("shape", "bullnose")) == "bullnose":
		room -= 0.36
	return clampf(want, 1.9, maxf(room, 1.9))


func _verandah_post(kit: MeshKit, v: Dictionary, f: Dictionary, u: float, d: float, top: float, h: float, paint: String) -> void:
	var c := _vp(f, u, top, d)
	match str(v.get("post", "timber_post")):
		"turned_post":
			kit.cylinder(paint, c, 0.5, 0.06, 0.06, 10)
			kit.frustum(paint, c + Vector3(0, 0.5, 0), c + Vector3(0, 0.62, 0), 0.06, 0.075, 10)
			kit.frustum(paint, c + Vector3(0, 0.62, 0), c + Vector3(0, 0.74, 0), 0.075, 0.045, 10)
			kit.cylinder(paint, c + Vector3(0, 0.74, 0), h - 0.98, 0.045, 0.045, 10)
			kit.frustum(paint, c + Vector3(0, h - 0.24, 0), c + Vector3(0, h - 0.12, 0), 0.045, 0.07, 10)
			kit.box(paint, Transform3D(Basis(), c + Vector3(0, h - 0.06, 0)), Vector3(0.14, 0.12, 0.14))
		"cast_iron":
			var iron := m("trim_paint", _paint(str(v.get("lace_colour", v.get("colour", "cream")))).darkened(0.0))
			kit.cylinder(iron, c, 0.12, 0.06, 0.05, 10)
			kit.cylinder(iron, c + Vector3(0, 0.12, 0), h - 0.3, 0.035, 0.035, 10)
			kit.frustum(iron, c + Vector3(0, h - 0.18, 0), c + Vector3(0, h, 0), 0.035, 0.08, 10)
		_:
			kit.box(paint, Transform3D(Basis(), c + Vector3(0, h * 0.5, 0)), Vector3(0.1, h, 0.1))
			kit.box(m("trim_paint", MaterialLibrary.paint("white")), Transform3D(Basis(), c + Vector3(0, 0.06, 0)), Vector3(0.14, 0.12, 0.14))


## Rails along the open edges (outer edge and ends), skipping the steps and any sleep-out.
func _verandah_rails(kit: MeshKit, v: Dictionary, f: Dictionary, posts: Array[float], top: float, d_edge: float, rail: String, paint: String, steps: Array) -> void:
	var so: Dictionary = v.get("sleepout", {})
	var gaps: Array = steps.duplicate()
	if not so.is_empty():
		gaps.append([float(so["from"]), float(so["to"])])
	var spans: Array = []
	for i in posts.size() - 1:
		var a := posts[i] + 0.05
		var b := posts[i + 1] - 0.05
		var cuts: Array = [[a, b]]
		for g: Array in gaps:
			var next: Array = []
			for c: Array in cuts:
				var ga := float(g[0]) - 0.05
				var gb := float(g[1]) + 0.05
				if gb <= float(c[0]) or ga >= float(c[1]):
					next.append(c)
					continue
				if ga > float(c[0]) + 0.2:
					next.append([c[0], ga])
				if gb < float(c[1]) - 0.2:
					next.append([gb, c[1]])
			cuts = next
		for c2: Array in cuts:
			spans.append([_vp(f, float(c2[0]), 0.0, d_edge), _vp(f, float(c2[1]), 0.0, d_edge)])
	# The open ends, from the wall out to the end posts.
	for u: float in [float(v["from"]) + 0.1, float(v["to"]) - 0.1]:
		if not so.is_empty() and u >= float(so["from"]) - 0.2 and u <= float(so["to"]) + 0.2:
			continue
		spans.append([_vp(f, u, 0.0, 0.1), _vp(f, u, 0.0, d_edge - 0.05)])
	var lace := _lace_mat("lace_rail", str(v.get("lace_colour", v.get("colour", "cream")))) if rail == "lace" else ""
	for sp: Array in spans:
		var a3: Vector3 = sp[0]
		var b3: Vector3 = sp[1]
		var len3 := a3.distance_to(b3)
		if len3 < 0.1:
			continue
		var dir := (b3 - a3) / len3
		kit.beam(paint, a3 + Vector3(0, top + 0.9, 0), b3 + Vector3(0, top + 0.9, 0), 0.07, 0.05)
		kit.beam(paint, a3 + Vector3(0, top + 0.1, 0), b3 + Vector3(0, top + 0.1, 0), 0.05, 0.05)
		if rail == "lace":
			var n3 := Vector3(-dir.z, 0, dir.x)
			face_uv(kit, lace, a3 + Vector3(0, top + 0.12, 0), b3 + Vector3(0, top + 0.12, 0), b3 + Vector3(0, top + 0.88, 0), a3 + Vector3(0, top + 0.88, 0), n3,
				Vector2(0, 1), Vector2(len3 / 0.6, 1), Vector2(len3 / 0.6, 0), Vector2(0, 0))
		else:
			var n := maxi(1, int(len3 / 0.11))
			for k in n:
				var q := a3 + dir * (len3 * (k + 0.5) / n)
				kit.box(paint, Transform3D(Basis(), q + Vector3(0, top + 0.5, 0)), Vector3(0.035, 0.76, 0.035))


## Lattice under the deck along the open edges.
func _verandah_lattice(kit: MeshKit, v: Dictionary, f: Dictionary, deck_bottom: float) -> void:
	var lat := _lace_mat("lattice", str(v.get("colour", "cream")))
	var depth: float = f["depth"]
	var edges := [[_vp(f, float(v["from"]), 0.0, depth), _vp(f, float(v["to"]), 0.0, depth)],
		[_vp(f, float(v["from"]), 0.0, 0.0), _vp(f, float(v["from"]), 0.0, depth)],
		[_vp(f, float(v["to"]), 0.0, 0.0), _vp(f, float(v["to"]), 0.0, depth)]]
	for e: Array in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var ga := float(ground_fn.call(a.x, a.z)) - 0.05
		var gb := float(ground_fn.call(b.x, b.z)) - 0.05
		var l := a.distance_to(b)
		var dir := (b - a) / maxf(l, 0.001)
		var n := Vector3(-dir.z, 0, dir.x)
		face_uv(kit, lat, Vector3(a.x, ga, a.z), Vector3(b.x, gb, b.z), Vector3(b.x, deck_bottom, b.z), Vector3(a.x, deck_bottom, a.z), n,
			Vector2(0, (deck_bottom - ga) / 0.4), Vector2(l / 0.4, (deck_bottom - gb) / 0.4), Vector2(l / 0.4, 0), Vector2(0, 0))


## An alpha-cut lace, fretwork or lattice material, two-sided and tinted.
func _lace_mat(tex: String, colour: String) -> String:
	var c := _paint(colour)
	var key := "lace:%s#%s" % [tex, c.to_html(false)]
	if not mats.has(key):
		mats[key] = MaterialLibrary.cutout("res://assets/materials/lace/%s.png" % tex, c)
	return key


## One roof piece from Roofs.geometry: roofing on top, lined underneath, gables clad to match the
## walls, fascias, gutters, barge boards, cappings and finials.
func _roof_piece(kit: MeshKit, p: Dictionary) -> void:
	var g := Roofs.geometry(p, Roofs.eave_y(house, p))
	if str(house.roof.get("stage", "")) == "frame":
		# Rafters on 0.6 m centres up each slope, with the ridge and hip beams.
		var timber := m("decking", Color("#D8C29C"))
		for f: Dictionary in g["roof"]:
			var pts: Array = f["pts"]
			if pts.size() < 4:
				continue
			var p0: Vector3 = pts[0]
			var p1: Vector3 = pts[1]
			var p2: Vector3 = pts[2]
			var p3: Vector3 = pts[3]
			var n := maxi(1, roundi(p0.distance_to(p1) / 0.6))
			for i in n + 1:
				var t := float(i) / n
				kit.beam(timber, p0.lerp(p1, t) - Vector3(0, 0.06, 0), p3.lerp(p2, t) - Vector3(0, 0.06, 0), 0.045, 0.12)
		for ed: Array in g["capping"]:
			kit.beam(timber, ed[0], ed[1], 0.06, 0.18)
		return
	var mat_id := str(p.get("material", "corrugated_iron"))
	var roofing := m(mat_id)
	var lining := m("trim_paint", MaterialLibrary.paint("white"))
	var gable := _gable_material()
	var fascia_vent := m("trim_paint", trim_ext)
	var fascia := m("trim_paint", trim_ext)
	var gutter := m("chrome", Color("#A9B0B2"))
	var iron := mat_id.begins_with("corrugated") or mat_id.begins_with("roof_paint")
	var capping := m(mat_id) if iron else m("roof_terracotta" if mat_id == "roof_terracotta" else mat_id, Color("#B8B0A8") if mat_id != "roof_terracotta" else null)
	if iron:
		capping = m("corrugated_iron", Color("#C9CFD2")) if mat_id == "corrugated_iron" else m(mat_id)
	for f: Dictionary in g["roof"]:
		var n: Vector3 = f["n"]
		_poly(kit, roofing, f["pts"], f["uv"], n)
		var under: Array = []
		for q: Vector3 in f["pts"]:
			under.append(q - n * 0.03)
		_poly(kit, lining, under, f["uv"], -n)
	for f2: Dictionary in g["gable"]:
		var uvs: Array = []
		var n2: Vector3 = f2["n"]
		var ax := Vector3(-n2.z, 0, n2.x)
		for q2: Vector3 in f2["pts"]:
			uvs.append(Vector2(ax.dot(q2), -q2.y))
		_poly(kit, gable, f2["pts"], uvs, n2)
		# A louvred vent under the apex of bigger gables.
		var apex := Vector3(0, -INF, 0)
		var low := INF
		for q3: Vector3 in f2["pts"]:
			if q3.y > apex.y:
				apex = q3
			low = minf(low, q3.y)
		if apex.y - low > 1.3 and not Roofs.is_mono(p):
			var vc := apex + Vector3(0, -0.75, 0) + n2 * 0.02
			kit.box(fascia_vent, Transform3D(Basis.looking_at(n2), vc), Vector3(0.5, 0.36, 0.04))
			for i3 in 4:
				kit.box(fascia_vent, Transform3D(Basis.looking_at(n2), vc + n2 * 0.03 + Vector3(0, -0.12 + i3 * 0.08, 0)), Vector3(0.44, 0.02, 0.03))
	var tanp := tan(deg_to_rad(Roofs.clamp_pitch(str(p.get("shape", "hip")), float(p.get("pitch", 28.0)))))
	var c := _piece_centre(p)
	for ed: Array in g["fascia"]:
		var a: Vector3 = ed[0]
		var b: Vector3 = ed[1]
		var outn := _outward((a + b) * 0.5, c)
		kit.beam(fascia, a + Vector3(0, -0.07, 0) + outn * 0.015, b + Vector3(0, -0.07, 0) + outn * 0.015, 0.03, 0.18)
		if ed[2]:
			kit.beam(gutter, a + outn * 0.08 + Vector3(0, -0.07, 0), b + outn * 0.08 + Vector3(0, -0.07, 0), 0.11, 0.1)
	for ed2: Array in g["barge"]:
		var a2: Vector3 = ed2[0]
		var b2: Vector3 = ed2[1]
		var drop := Vector3(0, -0.06 / maxf(cos(atan(tanp)), 0.2), 0)
		kit.beam(fascia, a2 + drop, b2 + drop, 0.03, 0.16)
	for ed3: Array in g["capping"]:
		kit.beam(capping, (ed3[0] as Vector3) + Vector3(0, 0.02, 0), (ed3[1] as Vector3) + Vector3(0, 0.02, 0), 0.06 if iron else 0.1, 0.22 if iron else 0.26)
	for fin: Vector3 in g["finials"]:
		kit.box(fascia, Transform3D(Basis(), fin + Vector3(0, 0.16, 0)), Vector3(0.07, 0.4, 0.07))
		kit.cylinder(fascia, fin + Vector3(0, 0.36, 0), 0.12, 0.06, 0.0, 8)


func _piece_centre(p: Dictionary) -> Vector3:
	var r := Roofs.rect_of(p)
	return Vector3(r.get_center().x, 0, r.get_center().y)


## The axis-aligned direction from c towards q.
func _outward(q: Vector3, c: Vector3) -> Vector3:
	var d := q - c
	if absf(d.x) > absf(d.z):
		return Vector3(signf(d.x), 0, 0)
	return Vector3(0, 0, signf(d.z))


## Gables take the house's most common outside finish (worked out once per roof build).
func _gable_material() -> String:
	if _gable_key == "":
		_gable_key = _find_gable_material()
	return _gable_key


func _find_gable_material() -> String:
	var counts: Dictionary = {}
	var dicts: Dictionary = {}
	for f: Array in BuildOps.exterior_faces(house):
		var face_d: Dictionary = ((house.walls(int(f[2]))[f[0]] as Dictionary).get("f", {}) as Dictionary).get(f[1], {})
		if face_d.has("mat"):
			var key := JSON.stringify(face_d)
			counts[key] = int(counts.get(key, 0)) + 1
			dicts[key] = face_d
	var best := ""
	var best_n := 0
	for k: String in counts:
		if int(counts[k]) > best_n:
			best_n = counts[k]
			best = k
	if best == "":
		return m(str(house.exterior.get("cladding", "weatherboard")), cladding_tint)
	return surface_key(dicts[best])


## A convex polygon (any winding) fanned into triangles facing n.
func _poly(kit: MeshKit, mat: String, pts: Array, uvs: Array, n: Vector3) -> void:
	var cnt := pts.size()
	if cnt < 3:
		return
	var flip := false
	for i in range(1, cnt - 1):
		var cr := ((pts[i] as Vector3) - (pts[0] as Vector3)).cross((pts[i + 1] as Vector3) - (pts[0] as Vector3))
		if cr.length_squared() > 0.000001:
			flip = cr.dot(n) < 0.0
			break
	for i2 in range(1, cnt - 1):
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[i2]
		var c3: Vector3 = pts[i2 + 1]
		if (b - a).cross(c3 - a).length_squared() < 0.0000001:
			continue
		if flip:
			kit.tri(mat, a, c3, b, uvs[0], uvs[i2 + 1], uvs[i2])
		else:
			kit.tri(mat, a, b, c3, uvs[0], uvs[i2], uvs[i2 + 1])


func _verandah_roof(kit: MeshKit, v: Dictionary) -> void:
	var f := _vframe(v)
	var depth: float = f["depth"]
	var u0: float = f["u0"]
	var u1: float = f["u1"]
	var deck := fy - 0.08
	var beam_top := deck + _post_h(v) + 0.15
	var iron := m(str(v.get("material", "corrugated_iron")))
	var lining := m("trim_paint", MaterialLibrary.paint("white"))
	var paint := m("trim_paint", _paint(str(v.get("colour", "cream"))))
	var wall_y := fy + wh - 0.06
	var shape := str(v.get("shape", "bullnose"))
	if shape == "gable":
		_verandah_gable(kit, v, f, beam_top, wall_y, iron, lining, paint)
		return
	# Profile in (d, y) from the wall out.
	var pts: Array[Vector2] = [Vector2(0.0, wall_y)]
	if shape == "bullnose":
		var radius := 0.36
		var dc := depth - radius - 0.06
		pts.append(Vector2(dc, beam_top + radius))
		for i in range(1, 9):
			var a := PI * 0.5 * i / 8
			pts.append(Vector2(dc + sin(a) * radius, beam_top + cos(a) * radius))
	else:
		var slope := (wall_y - beam_top) / maxf(depth - 0.12, 0.5)
		pts.append(Vector2(depth + 0.2, beam_top - slope * 0.32))
	var dist := 0.0
	for i in pts.size() - 1:
		var p := pts[i]
		var q := pts[i + 1]
		var dd := p.distance_to(q)
		var a3 := _vp(f, u0 - 0.05, p.y, p.x)
		var b3 := _vp(f, u1 + 0.05, p.y, p.x)
		var c3 := _vp(f, u1 + 0.05, q.y, q.x)
		var d3 := _vp(f, u0 - 0.05, q.y, q.x)
		var t2 := q - p
		var n3 := ((f["out"] as Vector3) * -t2.y + Vector3.UP * t2.x).normalized()
		face_uv(kit, iron, a3, b3, c3, d3, n3, Vector2(u0, dist), Vector2(u1, dist), Vector2(u1, dist + dd), Vector2(u0, dist + dd))
		var dn := Vector3(0, -0.012, 0)
		face_uv(kit, lining if shape == "skillion" else iron, a3 + dn, b3 + dn, c3 + dn, d3 + dn, -n3, Vector2(u0, dist), Vector2(u1, dist), Vector2(u1, dist + dd), Vector2(u0, dist + dd))
		dist += dd
	# Flashing where it meets the wall, and a gutter on a skillion.
	kit.beam(iron, _vp(f, u0 - 0.05, wall_y + 0.03, 0.04), _vp(f, u1 + 0.05, wall_y + 0.03, 0.04), 0.08, 0.04)
	if shape == "skillion":
		var e := pts[pts.size() - 1]
		kit.beam(paint, _vp(f, u0 - 0.05, e.y - 0.07, e.x), _vp(f, u1 + 0.05, e.y - 0.07, e.x), 0.03, 0.16)
		kit.beam(m("chrome", Color("#A9B0B2")), _vp(f, u0 - 0.05, e.y - 0.07, e.x + 0.08), _vp(f, u1 + 0.05, e.y - 0.07, e.x + 0.08), 0.11, 0.1)


## A gabled verandah: the ridge runs out from the house to a gable over the posts.
func _verandah_gable(kit: MeshKit, v: Dictionary, f: Dictionary, beam_top: float, wall_y: float, iron: String, lining: String, paint: String) -> void:
	var depth: float = f["depth"]
	var u0: float = float(f["u0"]) - 0.15
	var u1: float = float(f["u1"]) + 0.15
	var uc := (u0 + u1) * 0.5
	var hw := (u1 - u0) * 0.5
	var ridge := minf(beam_top + hw * tan(deg_to_rad(32.0)), wall_y)
	var d1 := depth + 0.3
	for side in 2:
		var ue := u0 if side == 0 else u1
		var a := _vp(f, ue, beam_top, 0.0)
		var b := _vp(f, ue, beam_top, d1)
		var c := _vp(f, uc, ridge, d1)
		var d := _vp(f, uc, ridge, 0.0)
		var along := (_vp(f, 1.0, 0.0, 0.0) - _vp(f, 0.0, 0.0, 0.0)) * (-1.0 if side == 0 else 1.0)
		var n := (along * (ridge - beam_top) + Vector3.UP * hw).normalized()
		var sl := sqrt(hw * hw + (ridge - beam_top) * (ridge - beam_top))
		face_uv(kit, iron, a, b, c, d, n, Vector2(0, sl), Vector2(d1, sl), Vector2(d1, 0), Vector2(0, 0))
		var dn := Vector3(0, -0.012, 0)
		face_uv(kit, lining, a + dn, b + dn, c + dn, d + dn, -n, Vector2(0, sl), Vector2(d1, sl), Vector2(d1, 0), Vector2(0, 0))
		kit.beam(m("chrome", Color("#A9B0B2")), a + Vector3(0, -0.07, 0) + along * 0.08, b + Vector3(0, -0.07, 0) + along * 0.08, 0.11, 0.1)
		kit.beam(paint, b + Vector3(0, -0.05, 0), c + Vector3(0, -0.05, 0), 0.03, 0.16)
	# The gable face over the beam, in timber with a finial.
	var g0 := _vp(f, u0 + 0.15, beam_top, depth - 0.1)
	var g1 := _vp(f, u1 - 0.15, beam_top, depth - 0.1)
	var g2 := _vp(f, uc, ridge - 0.1, depth - 0.1)
	var lace := str(v.get("lace", "none"))
	var gm := paint if lace == "none" else _lace_mat("fret_frieze" if lace == "fretwork" else "lace_frieze", str(v.get("lace_colour", v.get("colour", "cream"))))
	kit.tri(gm, g0, g1, g2, Vector2(u0 / 0.6, 1), Vector2(u1 / 0.6, 1), Vector2(uc / 0.6, 0))
	kit.tri(gm, g0, g2, g1, Vector2(u0 / 0.6, 1), Vector2(uc / 0.6, 0), Vector2(u1 / 0.6, 1))
	kit.beam(iron, _vp(f, uc, ridge + 0.02, 0.0), _vp(f, uc, ridge + 0.02, d1), 0.06, 0.22)
	var fin := _vp(f, uc, ridge, d1)
	kit.box(paint, Transform3D(Basis(), fin + Vector3(0, 0.16, 0)), Vector3(0.07, 0.4, 0.07))


func _chimney_stack(kit: MeshKit, c: Dictionary) -> void:
	var brick := m("brick_red")
	var x0 := float(c["x"])
	var z0 := float(c["z"])
	var x1 := x0 + float(c["w"])
	var z1 := z0 + float(c["d"])
	var l := int(c.get("level", 0))
	var base := level_y(l)
	var wall_top := base + house.storey_height(l)
	var top: float
	if c.has("top"):
		top = fy + float(c["top"])
	else:
		var roof_y := Roofs.height_over(house, Rect2(x0, z0, x1 - x0, z1 - z0).grow(0.3))
		top = (roof_y if not is_nan(roof_y) else wall_top) + 0.6
	var bottom := wall_top - 0.3
	if bool(c.get("outside", false)):
		# An outside chimney runs from the ground, with a wider breast up to the eaves.
		var g := float(ground_fn.call((x0 + x1) * 0.5, (z0 + z1) * 0.5)) - 0.1
		var grow := 0.12
		var gx := grow if float(c["w"]) > float(c["d"]) else 0.0
		var gz := grow if gx == 0.0 else 0.0
		flat_box(kit, brick, x0 - gx, x1 + gx, g, wall_top - 0.4, z0 - gz, z1 + gz)
		bottom = wall_top - 0.4
	flat_box(kit, brick, x0, x1, bottom, top, z0, z1)
	flat_box(kit, brick, x0 - 0.06, x1 + 0.06, top, top + 0.12, z0 - 0.06, z1 + 0.06)
	var long_x := (x1 - x0) >= (z1 - z0)
	for i in 2:
		var px := lerpf(x0, x1, 0.3 + 0.4 * i) if long_x else (x0 + x1) * 0.5
		var pz := (z0 + z1) * 0.5 if long_x else lerpf(z0, z1, 0.3 + 0.4 * i)
		kit.cylinder(m("brick_red", Color("#D08A5E")), Vector3(px, top + 0.12, pz), 0.32, 0.11, 0.09, 10)


func _stumps(kit: MeshKit, area: Rect2, top: float, spacing: float) -> void:
	var nx := maxi(2, ceili(area.size.x / spacing) + 1)
	var nz := maxi(2, ceili(area.size.y / spacing) + 1)
	for i in nx:
		for j in nz:
			var x := area.position.x + area.size.x * i / (nx - 1)
			var z := area.position.y + area.size.y * j / (nz - 1)
			var g := float(ground_fn.call(x, z)) - 0.15
			if top - g > 0.02:
				flat_box(kit, m("stump"), x - 0.06, x + 0.06, g, top, z - 0.06, z + 0.06)
