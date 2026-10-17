class_name HouseData
extends RefCounted
## One building: the single source of truth every mesh is generated from (docs/HOUSE_BUILDING.md).
##
## Coordinates are local tiles and metres: x east, y (z in 3D) south, origin at the house's origin tile.
## Each storey holds:
##   walls    edge key -> {kind: full|half|low, h: height, f: {a: face, b: face}}
##            "x,y,N" runs (x,y)->(x+1,y), side a is north.  "x,y,W" runs (x,y)->(x,y+1), side a is west.
##            "x,y,D" runs (x,y)->(x+1,y+1), side a is north-east.  "x,y,A" runs (x+1,y)->(x,y+1), side a is north-west.
##            A face is {} (use the default) or {mat, paint}. Faces belong to the wall, so they survive push and pull.
##   floors   "x,y" -> {m: material or [N, E, S, W] quarter materials, rot: 0|90}
##   openings [{id, kind: door|window|doorway|arch, style, axis: x|z, x, z, width, height, sill, ...}]
##            axis x: on the horizontal line y = z, spanning x .. x + width. axis z: on the vertical line x = x.
##   stairs   [{id, kind: straight|l|u|ladder, x, y, dir: N|E|S|W, turn: right|left}]  (rising in dir)
##   columns  [{x, y, kind}] on grid corners
##   labels   "x,y" -> {name, paint, needs_window}  room properties, found by any tile in the room
## Rooms are not stored: they are detected by flood fill over quarter-tile triangles bounded by full walls.

const WALL_THICKNESS := 0.12
const KIND_HEIGHTS := {"half": 1.0, "low": 0.6}
const QN := 0
const QE := 1
const QS := 2
const QW := 3
const DIRS := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const MIN_LEVEL := -1
const MAX_LEVEL := 2

var id: String = ""
var name: String = ""
var origin: Vector2i = Vector2i.ZERO
var locked := false
## World height the house stands at, fixed when its first room is built (NAN until then).
var base_y: float = NAN
var foundation: Dictionary = {"type": "stumps", "height": 0.6}
var storeys: Array[Dictionary] = []
var roof: Dictionary = {}
var verandahs: Array[Dictionary] = []
var chimneys: Array[Dictionary] = []
var fixtures: Array[Dictionary] = []
var objects: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var exterior: Dictionary = {"cladding": "weatherboard", "paint": "cream", "trim": "brunswick_green", "door": "brunswick_green"}
## Landscaping, all in house-local coordinates so a share code carries the garden with the house.
## Quality tier for building work: rough, standard or fine (cost, time and Style).
var quality := "standard"
var garden: Array[Dictionary] = []   ## plants, outbuildings and outdoor items: {id, kind, x, z, rot}
var fences: Dictionary = {}          ## edge key ("x,y,N" or "x,y,W") -> {type, gate}
var ground: Dictionary = {}          ## tile key -> ground name (paths, lawn, garden beds)
var terrain: Dictionary = {}         ## corner key -> height relative to base_y
var _next_id := 1
## While it's being built: {index (Construction stage), new_tiles}. Not saved; only for drawing.
var stage: Dictionary = {}
var _room_cache: Dictionary = {}  ## level -> Array[Dictionary]


func _init() -> void:
	storeys.append(new_storey(0))


static func new_storey(level: int, height: float = 2.7) -> Dictionary:
	return {"level": level, "height": height, "walls": {}, "floors": {}, "openings": [], "stairs": [], "columns": [], "labels": {}}


# --- Serialisation --------------------------------------------------------------------------------

static func from_dict(d: Dictionary) -> HouseData:
	var h := HouseData.new()
	h.storeys.clear()
	h.id = str(d.get("id", ""))
	h.name = str(d.get("name", ""))
	var o: Array = d.get("origin", [0, 0])
	h.origin = Vector2i(int(o[0]), int(o[1]))
	h.locked = bool(d.get("locked", false))
	if d.has("base_y") and d["base_y"] != null:
		h.base_y = float(d["base_y"])
	h.foundation = (d.get("foundation", h.foundation) as Dictionary).duplicate(true)
	h.exterior = (d.get("exterior", h.exterior) as Dictionary).duplicate(true)
	h.roof = (d.get("roof", {}) as Dictionary).duplicate(true)
	h._next_id = int(d.get("next_id", 1))
	h.quality = str(d.get("quality", "standard"))
	h.fences = (d.get("fences", {}) as Dictionary).duplicate(true)
	h.ground = (d.get("ground", {}) as Dictionary).duplicate(true)
	h.terrain = (d.get("terrain", {}) as Dictionary).duplicate(true)
	for key in ["verandahs", "chimneys", "fixtures", "objects", "lights", "garden"]:
		var target: Array[Dictionary] = h.get(key)
		for item: Dictionary in d.get(key, []):
			target.append(item.duplicate(true))
	for s: Dictionary in d.get("storeys", []):
		var st := s.duplicate(true)
		if st.has("rooms"):
			st = HouseData.convert_room_template(st)
		for k: String in ["walls", "floors", "labels"]:
			if not st.has(k):
				st[k] = {}
		for k2: String in ["openings", "stairs", "columns"]:
			if not st.has(k2):
				st[k2] = []
		if not st.has("height"):
			st["height"] = float(st.get("wall_height", 2.7))
		st.erase("wall_height")
		h.storeys.append(st)
	if h.storeys.is_empty():
		h.storeys.append(new_storey(0))
	h.storeys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	h._ensure_ids()
	return h


static func load_file(path: String) -> HouseData:
	return from_dict(JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary)


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "origin": [origin.x, origin.y], "locked": locked, "next_id": _next_id,
		"base_y": null if is_nan(base_y) else base_y,
		"foundation": foundation.duplicate(true), "exterior": exterior.duplicate(true),
		"storeys": storeys.duplicate(true), "roof": roof.duplicate(true),
		"verandahs": verandahs.duplicate(true), "chimneys": chimneys.duplicate(true),
		"fixtures": fixtures.duplicate(true), "objects": objects.duplicate(true), "lights": lights.duplicate(true),
		"garden": garden.duplicate(true), "fences": fences.duplicate(true), "ground": ground.duplicate(true),
		"terrain": terrain.duplicate(true), "quality": quality,
	}


func duplicate_house() -> HouseData:
	return HouseData.from_dict(JSON.parse_string(JSON.stringify(to_dict())) as Dictionary)


## Converts the M1 authoring format (a list of room rectangles) into walls, floors and labels.
static func convert_room_template(s: Dictionary) -> Dictionary:
	var out := new_storey(int(s.get("level", 0)), float(s.get("wall_height", s.get("height", 2.7))))
	var owner: Dictionary = {}  # "x,y" -> room dict
	for r: Dictionary in s["rooms"]:
		var a: Array = r["rect"]
		for y in range(int(a[1]), int(a[1]) + int(a[3])):
			for x in range(int(a[0]), int(a[0]) + int(a[2])):
				owner[tile_key(x, y)] = r
				(out["floors"] as Dictionary)[tile_key(x, y)] = {"m": str(r.get("floor", "floor_boards")), "rot": 0}
		(out["labels"] as Dictionary)[tile_key(int(a[0]), int(a[1]))] = {
			"name": str(r.get("name", r.get("id", "Room"))), "paint": str(r.get("paint", "cream")),
			"needs_window": bool(r.get("needs_window", true)), "id": str(r.get("id", ""))}
	var walls: Dictionary = out["walls"]
	var h := float(out["height"])
	for tk: String in owner:
		var t := parse_tile(tk)
		var r: Dictionary = owner[tk]
		var nbrs := {
			"N": [hkey(t.x, t.y), tile_key(t.x, t.y - 1), "b"], "S": [hkey(t.x, t.y + 1), tile_key(t.x, t.y + 1), "a"],
			"W": [vkey(t.x, t.y), tile_key(t.x - 1, t.y), "b"], "E": [vkey(t.x + 1, t.y), tile_key(t.x + 1, t.y), "a"],
		}
		for side: String in nbrs:
			var info: Array = nbrs[side]
			var other: Variant = owner.get(info[1])
			if other != null and other == r:
				continue
			var ek: String = info[0]
			if not walls.has(ek):
				walls[ek] = {"kind": "full", "h": h, "f": {"a": {}, "b": {}}}
			(walls[ek]["f"] as Dictionary)[info[2]] = {"mat": "plaster", "paint": str(r.get("paint", "cream"))}
	for o: Dictionary in s.get("openings", []):
		(out["openings"] as Array).append(o.duplicate(true))
	return out


func _ensure_ids() -> void:
	for s in storeys:
		for o: Dictionary in s["openings"]:
			if not o.has("id"):
				o["id"] = new_id("o")
		for st: Dictionary in s["stairs"]:
			if not st.has("id"):
				st["id"] = new_id("st")


func new_id(prefix: String) -> String:
	var out := "%s%d" % [prefix, _next_id]
	_next_id += 1
	return out


## Call after any edit so detected rooms are recomputed.
func touch() -> void:
	_room_cache.clear()


# --- Keys ---------------------------------------------------------------------------------------

static func tile_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func parse_tile(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


static func hkey(x: int, y: int) -> String:
	return "%d,%d,N" % [x, y]


static func vkey(x: int, y: int) -> String:
	return "%d,%d,W" % [x, y]


static func parse_edge(k: String) -> Dictionary:
	var p := k.split(",")
	return {"x": int(p[0]), "y": int(p[1]), "t": p[2]}


## The two end points of an edge, in tile-corner coordinates.
static func edge_points(k: String) -> Array[Vector2i]:
	var e := parse_edge(k)
	var x: int = e["x"]
	var y: int = e["y"]
	match str(e["t"]):
		"N":
			return [Vector2i(x, y), Vector2i(x + 1, y)]
		"W":
			return [Vector2i(x, y), Vector2i(x, y + 1)]
		"D":
			return [Vector2i(x, y), Vector2i(x + 1, y + 1)]
		_:
			return [Vector2i(x + 1, y), Vector2i(x, y + 1)]


## The edge key joining two adjacent corners (orthogonal or 45 degree), or "" if they aren't adjacent.
static func edge_from_points(a: Vector2i, b: Vector2i) -> String:
	var lo := a if (a.y < b.y or (a.y == b.y and a.x < b.x)) else b
	var hi := b if lo == a else a
	var d := hi - lo
	if d == Vector2i(1, 0):
		return hkey(lo.x, lo.y)
	if d == Vector2i(0, 1):
		return vkey(lo.x, lo.y)
	if d == Vector2i(1, 1):
		return "%d,%d,D" % [lo.x, lo.y]
	if d == Vector2i(-1, 1):
		return "%d,%d,A" % [hi.x, lo.y]
	return ""


static func is_diagonal(k: String) -> bool:
	return k.ends_with(",D") or k.ends_with(",A")


## Quarter cells on side a and side b of an edge: [x, y, q].
static func edge_sides(k: String) -> Array:
	var e := parse_edge(k)
	var x: int = e["x"]
	var y: int = e["y"]
	match str(e["t"]):
		"N":
			return [[x, y - 1, QS], [x, y, QN]]
		"W":
			return [[x - 1, y, QE], [x, y, QW]]
		"D":
			return [[x, y, QN], [x, y, QS]]
		_:
			return [[x, y, QN], [x, y, QS]]


# --- Storeys --------------------------------------------------------------------------------------

func storey(level: int) -> Dictionary:
	for s in storeys:
		if int(s["level"]) == level:
			return s
	return {}


func has_storey(level: int) -> bool:
	return not storey(level).is_empty()


func levels() -> Array[int]:
	var out: Array[int] = []
	for s in storeys:
		out.append(int(s["level"]))
	return out


func floor_y() -> float:
	return float(foundation.get("height", 0.0)) + 0.15


## Height of the storey's floor above the ground floor's floor level.
func level_base(level: int) -> float:
	var y := 0.0
	if level >= 0:
		for l in range(0, level):
			y += storey_height(l) + 0.3
	else:
		y = -(storey_height(level) + 0.3)
	return y


func storey_height(level: int) -> float:
	var s := storey(level)
	return float(s.get("height", 2.7)) if not s.is_empty() else 2.7


## M1 compatibility: wall height of the ground storey.
func wall_height(level: int = 0) -> float:
	return storey_height(level)


func walls(level: int = 0) -> Dictionary:
	return storey(level).get("walls", {})


func wall(level: int, k: String) -> Dictionary:
	return walls(level).get(k, {})


func wall_h(level: int, k: String) -> float:
	var w := wall(level, k)
	if w.is_empty():
		return 0.0
	var kind := str(w.get("kind", "full"))
	if KIND_HEIGHTS.has(kind):
		return float(KIND_HEIGHTS[kind])
	return float(w.get("h", storey_height(level)))


func floors(level: int = 0) -> Dictionary:
	return storey(level).get("floors", {})


func openings(level: int = 0) -> Array:
	return storey(level).get("openings", [])


func stairs(level: int = 0) -> Array:
	return storey(level).get("stairs", [])


func opening_by_id(oid: String) -> Dictionary:
	for s in storeys:
		for o: Dictionary in s["openings"]:
			if o["id"] == oid:
				return o
	return {}


func opening_level(oid: String) -> int:
	for s in storeys:
		for o: Dictionary in s["openings"]:
			if o["id"] == oid:
				return int(s["level"])
	return 0


# --- Footprint -----------------------------------------------------------------------------------

## Bounding rectangle (in tiles) of everything on a storey, or of all storeys with level = 99.
func bounds(level: int = 99) -> Rect2i:
	var out := Rect2i()
	var first := true
	for s in storeys:
		if level != 99 and int(s["level"]) != level:
			continue
		for k: String in s["walls"]:
			for p in edge_points(k):
				var r := Rect2i(p.x, p.y, 0, 0)
				out = r if first else out.merge(r)
				first = false
		for tk: String in s["floors"]:
			var t := parse_tile(tk)
			var r2 := Rect2i(t.x, t.y, 1, 1)
			out = r2 if first else out.merge(r2)
			first = false
	return out


## Footprint used for roofs and the floor frame: the ground storey's rooms.
func footprint(level: int = 0) -> Rect2i:
	var out := Rect2i()
	var first := true
	for r in rooms(level):
		var rb: Rect2i = r["bounds"]
		out = rb if first else out.merge(rb)
		first = false
	return out if not first else bounds(level)


# --- Rooms ---------------------------------------------------------------------------------------

func _blocks(walls_d: Dictionary, k: String) -> bool:
	return walls_d.has(k) and str((walls_d[k] as Dictionary).get("kind", "full")) == "full"


## Rooms on a storey: [{key, quarters: {qkey: true}, tiles: [Vector2i] (any quarter), full_tiles, area, bounds, props}]
func rooms(level: int = 0) -> Array:
	if _room_cache.has(level):
		return _room_cache[level]
	var s := storey(level)
	var out: Array = []
	if s.is_empty() or (s["walls"] as Dictionary).is_empty():
		_room_cache[level] = out
		return out
	var wd: Dictionary = s["walls"]
	var b := bounds(level).grow(1)
	var w := b.size.x
	var h := b.size.y
	var n := w * h * 4
	var label := PackedInt32Array()
	label.resize(n)
	label.fill(-1)
	var region := 0
	var regions: Array = []
	for start in n:
		if label[start] != -1:
			continue
		var stack: Array[int] = [start]
		label[start] = region
		var cells: Array[int] = []
		var touches_border := false
		while not stack.is_empty():
			var c: int = stack.pop_back()
			cells.append(c)
			var q := c % 4
			var ti := c / 4
			var lx := ti % w
			var ly := ti / w
			var x := lx + b.position.x
			var y := ly + b.position.y
			if lx == 0 or ly == 0 or lx == w - 1 or ly == h - 1:
				touches_border = true
			for nb: Array in _quarter_neighbours(x, y, q, wd):
				var nx: int = nb[0] - b.position.x
				var ny: int = nb[1] - b.position.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni: int = (ny * w + nx) * 4 + int(nb[2])
				if label[ni] == -1:
					label[ni] = region
					stack.append(ni)
		regions.append({"cells": cells, "outside": touches_border})
		region += 1
	var labels: Dictionary = s["labels"]
	for r: Dictionary in regions:
		if r["outside"]:
			continue
		var quarters: Dictionary = {}
		var tile_counts: Dictionary = {}
		for c: int in r["cells"]:
			var ti2 := c / 4
			var tx := ti2 % w + b.position.x
			var ty := ti2 / w + b.position.y
			quarters["%d,%d,%d" % [tx, ty, c % 4]] = true
			var tk := tile_key(tx, ty)
			tile_counts[tk] = int(tile_counts.get(tk, 0)) + 1
		var tiles: Array[Vector2i] = []
		var full_tiles: Array[Vector2i] = []
		var rb := Rect2i()
		var first := true
		var keys := tile_counts.keys()
		keys.sort()
		for tk2: String in keys:
			var t := parse_tile(tk2)
			tiles.append(t)
			if int(tile_counts[tk2]) == 4:
				full_tiles.append(t)
			rb = Rect2i(t.x, t.y, 1, 1) if first else rb.merge(Rect2i(t.x, t.y, 1, 1))
			first = false
		var props: Dictionary = {}
		var anchor := ""
		for tk3: String in keys:
			if labels.has(tk3):
				props = labels[tk3]
				anchor = tk3
				break
		out.append({"key": keys[0], "anchor": anchor, "quarters": quarters, "tiles": tiles, "full_tiles": full_tiles,
			"area": (r["cells"] as Array).size() / 4.0, "bounds": rb, "props": props})
	out.sort_custom(func(p: Dictionary, q2: Dictionary) -> bool: return str(p["key"]) < str(q2["key"]))
	_room_cache[level] = out
	return out


func _quarter_neighbours(x: int, y: int, q: int, wd: Dictionary) -> Array:
	var out: Array = []
	var d := "%d,%d,D" % [x, y]
	var a := "%d,%d,A" % [x, y]
	match q:
		QN:
			if not _blocks(wd, hkey(x, y)):
				out.append([x, y - 1, QS])
			if not _blocks(wd, a):
				out.append([x, y, QE])
			if not _blocks(wd, d):
				out.append([x, y, QW])
		QE:
			if not _blocks(wd, vkey(x + 1, y)):
				out.append([x + 1, y, QW])
			if not _blocks(wd, a):
				out.append([x, y, QN])
			if not _blocks(wd, d):
				out.append([x, y, QS])
		QS:
			if not _blocks(wd, hkey(x, y + 1)):
				out.append([x, y + 1, QN])
			if not _blocks(wd, d):
				out.append([x, y, QE])
			if not _blocks(wd, a):
				out.append([x, y, QW])
		_:
			if not _blocks(wd, vkey(x, y)):
				out.append([x - 1, y, QE])
			if not _blocks(wd, d):
				out.append([x, y, QN])
			if not _blocks(wd, a):
				out.append([x, y, QS])
	return out


## The room containing a tile (any quarter), or {}.
func room_at_tile(level: int, t: Vector2i) -> Dictionary:
	for r in rooms(level):
		for q in 4:
			if (r["quarters"] as Dictionary).has("%d,%d,%d" % [t.x, t.y, q]):
				return r
	return {}


## Room on a side of an edge ("a" or "b"), or {} for outside.
func room_on_side(level: int, k: String, side: String) -> Dictionary:
	var sides := edge_sides(k)
	var c: Array = sides[0] if side == "a" else sides[1]
	var qk := "%d,%d,%d" % [c[0], c[1], c[2]]
	for r in rooms(level):
		if (r["quarters"] as Dictionary).has(qk):
			return r
	return {}


func room_name(r: Dictionary) -> String:
	return str((r.get("props", {}) as Dictionary).get("name", "Room"))


func room_paint(r: Dictionary) -> String:
	return str((r.get("props", {}) as Dictionary).get("paint", "cream"))


## Edges of a room: walls with this room on at least one side.
func room_walls(level: int, r: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var qs: Dictionary = r["quarters"]
	for k: String in walls(level):
		for c: Array in edge_sides(k):
			if qs.has("%d,%d,%d" % [c[0], c[1], c[2]]):
				out.append(k)
				break
	return out


# --- Openings ------------------------------------------------------------------------------------

## The unit edges an opening sits on.
static func opening_edges(o: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var start := float(o["x"]) if o["axis"] == "x" else float(o["z"])
	var end := start + float(o["width"])
	var line := int(o["z"]) if o["axis"] == "x" else int(o["x"])
	for i in range(floori(start + 0.0001), ceili(end - 0.0001)):
		out.append(hkey(i, line) if o["axis"] == "x" else vkey(line, i))
	return out


## Openings overlapping a unit edge, with their span clipped to that edge: [{from, to, o}] in 0..1.
func openings_on_edge(level: int, k: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if is_diagonal(k):
		return out
	var e := parse_edge(k)
	var axis := "x" if e["t"] == "N" else "z"
	var line: int = e["y"] if axis == "x" else e["x"]
	var pos: int = e["x"] if axis == "x" else e["y"]
	for o: Dictionary in openings(level):
		if o["axis"] != axis:
			continue
		var oline := int(o["z"]) if axis == "x" else int(o["x"])
		if oline != line:
			continue
		var start := (float(o["x"]) if axis == "x" else float(o["z"])) - pos
		var end := start + float(o["width"])
		if end <= 0.0001 or start >= 0.9999:
			continue
		out.append({"from": maxf(start, 0.0), "to": minf(end, 1.0), "o": o})
	return out


# --- Stairs --------------------------------------------------------------------------------------

## Number of tiles a straight flight needs for a storey height (risers about 0.18 m, goings 0.25 m).
static func flight_tiles(height: float) -> int:
	var risers := ceili((height + 0.3) / 0.18)
	return clampi(ceili((risers - 1) * 0.25), 3, 5)


## Tiles a stair uses: {lower: occupied on its own storey, cut: openings in the floor above,
## approach: where you step on below, arrival: where you step off above, path: ordered centre line}.
func stair_tiles(st: Dictionary, level: int) -> Dictionary:
	var d: Vector2i = DIRS[str(st.get("dir", "N"))]
	var right := Vector2i(-d.y, d.x)
	if str(st.get("turn", "right")) == "left":
		right = -right
	var p0 := Vector2i(int(st["x"]), int(st["y"]))
	var lower: Array[Vector2i] = []
	var arrival: Vector2i
	var path: Array[Vector2i] = []
	match str(st.get("kind", "straight")):
		"ladder":
			lower = [p0]
			arrival = p0 + d
		"l":
			lower = [p0, p0 + d, p0 + d * 2, p0 + d * 2 + right, p0 + d * 2 + right * 2]
			arrival = p0 + d * 2 + right * 3
		"u":
			lower = [p0, p0 + d, p0 + d * 2, p0 + d * 2 + right, p0 + d + right, p0 + right]
			arrival = p0 + right - d
		_:
			var n := flight_tiles(storey_height(level))
			for i in n:
				lower.append(p0 + d * i)
			arrival = p0 + d * n
	path = lower.duplicate()
	return {"lower": lower, "cut": lower.duplicate(), "approach": p0 - d, "arrival": arrival, "path": path}


## Tiles of this storey that are stairwells (cut by a stair rising from the storey below).
func stairwell_tiles(level: int) -> Dictionary:
	var out: Dictionary = {}
	for st: Dictionary in stairs(level - 1):
		for t: Vector2i in stair_tiles(st, level - 1)["cut"]:
			out[tile_key(t.x, t.y)] = true
	return out


# --- Validation ----------------------------------------------------------------------------------

## Plain-language problems with the design (docs/BUILDING.md validation).
func validate() -> Array[String]:
	var hints: Array[String] = []
	for s in storeys:
		var level := int(s["level"])
		var prefix := "" if storeys.size() == 1 else ("%s: " % storey_name(level))
		for r in rooms(level):
			var has_door := false
			var has_window := false
			for k in room_walls(level, r):
				var outside := room_on_side(level, k, "a").is_empty() or room_on_side(level, k, "b").is_empty()
				for op in openings_on_edge(level, k):
					var kind := str((op["o"] as Dictionary)["kind"])
					has_door = has_door or kind in ["door", "doorway", "arch"]
					has_window = has_window or (kind == "window" and outside)
			for st: Dictionary in stairs(level):
				var info := stair_tiles(st, level)
				if r["tiles"].has(info["approach"]):
					has_door = true
			for st2: Dictionary in stairs(level - 1):
				var info2 := stair_tiles(st2, level - 1)
				if r["tiles"].has(info2["arrival"]):
					has_door = true
			var nm := room_name(r)
			if not has_door:
				hints.append("%sThe %s has no way in." % [prefix, nm.to_lower() if nm != "Room" else "room at %s" % r["key"]])
			if not has_window and (r.get("props", {}) as Dictionary).get("needs_window", true) and level >= 0:
				hints.append("%sThe %s has no window." % [prefix, nm.to_lower() if nm != "Room" else "room at %s" % r["key"]])
		for o: Dictionary in s["openings"]:
			for k2 in opening_edges(o):
				if not (s["walls"] as Dictionary).has(k2):
					hints.append("%sA %s isn't sitting on a wall." % [prefix, o["kind"]])
					break
		for st3: Dictionary in s["stairs"]:
			var above := storey(level + 1)
			var info3 := stair_tiles(st3, level)
			if above.is_empty() or not (above["floors"] as Dictionary).has(tile_key(info3["arrival"].x, info3["arrival"].y)):
				hints.append("%sA staircase doesn't arrive on a floor." % prefix)
	return hints


static func storey_name(level: int) -> String:
	match level:
		-1:
			return "Cellar"
		0:
			return "Ground floor"
		1:
			return "First floor"
		_:
			return "Second floor"
