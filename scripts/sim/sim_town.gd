class_name SimTown
extends RefCounted
## The town as the simulation sees it: one walk graph over the valley floor and every storey of
## every house, and the places that advertise what they satisfy (beds, stoves, the wireless, the
## mill, the store, the creek bank). Built from the map grid and the houses as they stand; plain
## class, deterministic (everything is visited in sorted order).
##
## Positions are [level, x, z] in world metres (tile centres). Ground costs follow
## docs/SIMULATION.md: roads and footpaths 1, grass 1.5, mud 2, water impassable.

const WALK_M_PER_MIN := 72.0  ## 1.2 m/s

var width := 0
var height := 0
var astar := AStar3D.new()
var _ids: Dictionary = {}       ## "level,x,z" -> point id (level -1000-based keys for house upper storeys)
var places: Array[Dictionary] = []
var homes: Dictionary = {}      ## house id -> {house_id, door: [level, x, z], living: [..], beds: [place ids]}
var landmark_tiles: Dictionary = {}  ## landmark id -> [level, x, z]
var grid: WorldGrid                 ## the valley floor (ground types, for bootprints)
var sight: SightMap                 ## what blocks the eye, rooms, windows and lamps (memories, light)


static func build(grid: WorldGrid, houses: Array, landmarks: Array = [], creek_points: PackedVector2Array = PackedVector2Array()) -> SimTown:
	var t := SimTown.new()
	t._build(grid, houses, landmarks, creek_points)
	t.grid = grid
	t.sight = SightMap.build(grid, houses)
	return t


func _key(level: int, x: int, z: int, house: String = "") -> String:
	return "%d,%d,%d" % [level, x, z] if level == 0 else "%s:%d,%d,%d" % [house, level, x, z]


func point_id(level: int, x: int, z: int, house: String = "") -> int:
	return int(_ids.get(_key(level, x, z, house), -1))


func _build(grid: WorldGrid, houses: Array, landmarks: Array, creek_points: PackedVector2Array) -> void:
	width = grid.width
	height = grid.height
	var sorted_houses: Array = houses.duplicate()
	sorted_houses.sort_custom(func(a: HouseData, b: HouseData) -> bool: return a.id < b.id)
	# Walls on the ground storey, in world edge keys, and the ones a door lets people through.
	var walls: Dictionary = {}
	for h: HouseData in sorted_houses:
		for k: String in h.walls(0):
			var pts := HouseData.edge_points(k)
			if HouseData.is_diagonal(k):
				continue
			var wk := HouseData.edge_from_points(pts[0] + h.origin, pts[1] + h.origin)
			if not _door_on(h, 0, k):
				walls[wk] = true
	var next := 0
	for z in height:
		for x in width:
			var g := grid.get_ground(x, z)
			if g == Ground.Type.WATER:
				continue
			astar.add_point(next, Vector3(x + 0.5, 0.0, z + 0.5), Ground.PATH_COST[g])
			_ids[_key(0, x, z)] = next
			next += 1
	for z2 in height:
		for x2 in width:
			var a := point_id(0, x2, z2)
			if a < 0:
				continue
			var e := point_id(0, x2 + 1, z2)
			if e >= 0 and not walls.has(HouseData.vkey(x2 + 1, z2)):
				astar.connect_points(a, e)
			var s := point_id(0, x2, z2 + 1)
			if s >= 0 and not walls.has(HouseData.hkey(x2, z2 + 1)):
				astar.connect_points(a, s)
	# Upper storeys of each house, joined by their stairs.
	for h2: HouseData in sorted_houses:
		var o := h2.origin
		for l in h2.levels():
			if l == 0:
				continue
			var keys: Array = h2.floors(l).keys()
			keys.sort()
			var wells := h2.stairwell_tiles(l)
			for tk: String in keys:
				if wells.has(tk):
					continue
				var tt := HouseData.parse_tile(tk) + o
				astar.add_point(next, Vector3(tt.x + 0.5, h2.level_base(l), tt.y + 0.5), 1.0)
				_ids[_key(l, tt.x, tt.y, h2.id)] = next
				next += 1
			for tk2: String in keys:
				var lt := HouseData.parse_tile(tk2)
				var a2 := point_id(l, lt.x + o.x, lt.y + o.y, h2.id)
				if a2 < 0:
					continue
				var e2 := point_id(l, lt.x + 1 + o.x, lt.y + o.y, h2.id)
				if e2 >= 0 and (not h2.walls(l).has(HouseData.vkey(lt.x + 1, lt.y)) or _door_on(h2, l, HouseData.vkey(lt.x + 1, lt.y))):
					astar.connect_points(a2, e2)
				var s2 := point_id(l, lt.x + o.x, lt.y + 1 + o.y, h2.id)
				if s2 >= 0 and (not h2.walls(l).has(HouseData.hkey(lt.x, lt.y + 1)) or _door_on(h2, l, HouseData.hkey(lt.x, lt.y + 1))):
					astar.connect_points(a2, s2)
		for l2 in h2.levels():
			for st: Dictionary in h2.stairs(l2):
				var info := h2.stair_tiles(st, l2)
				var lo: Vector2i = info["approach"] + o
				var hi: Vector2i = info["arrival"] + o
				var la := point_id(l2, lo.x, lo.y, h2.id) if l2 != 0 else point_id(0, lo.x, lo.y)
				var lb := point_id(l2 + 1, hi.x, hi.y, h2.id)
				if la >= 0 and lb >= 0:
					astar.connect_points(la, lb)
		_add_house_places(h2)
	for lm: Dictionary in landmarks:
		var r: Array = lm.get("rect", lm.get("lot", [0, 0, 1, 1]))
		var c := Vector2i(int(r[0]) + int(r[2]) / 2, int(r[1]) + int(r[3]) / 2)
		landmark_tiles[str(lm["id"])] = _nearest_walkable(c)
	if landmark_tiles.has("lm_mill"):
		_add_place("lm_mill", "work", "", landmark_tiles["lm_mill"], {}, 0, 40)
	# A few spots on the creek bank for fishing and yabbies.
	for i in range(0, creek_points.size(), maxi(1, creek_points.size() / 5)):
		var cp := creek_points[i]
		var bank := _nearest_walkable(Vector2i(roundi(cp.x), roundi(cp.y)))
		if not bank.is_empty():
			_add_place("creek_%d" % i, "fish", "", bank, {"fun": 30.0}, 90, 2)


func _door_on(h: HouseData, level: int, k: String) -> bool:
	for op in h.openings_on_edge(level, k):
		var kind := str((op["o"] as Dictionary)["kind"])
		if kind in ["door", "doorway", "arch"] and float(op["to"]) - float(op["from"]) >= 0.25:
			return true
	return false


func _nearest_walkable(c: Vector2i) -> Array:
	for r in 12:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				if point_id(0, c.x + dx, c.y + dz) >= 0:
					return [0, c.x + dx + 0.5, c.y + dz + 0.5]
	return []


func _add_place(id: String, kind: String, house: String, at: Array, advert: Dictionary, minutes: int, capacity: int, extra: Dictionary = {}) -> void:
	var p := {"id": id, "kind": kind, "house": house, "at": at, "advert": advert, "minutes": minutes, "capacity": capacity}
	p.merge(extra)
	places.append(p)


## Beds, stoves, ice chests, the wireless, seats and vegie patches in a house; shops and exchanges
## by room name.
func _add_house_places(h: HouseData) -> void:
	var o := h.origin
	var home := {"house_id": h.id, "beds": [], "rooms": []}
	var objs: Array = h.objects.duplicate()
	objs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", a.get("model", ""))) < str(b.get("id", b.get("model", ""))))
	var n := 0
	for ob: Dictionary in objs:
		var it := Catalogue.item(Catalogue.id_of(ob))
		if it.is_empty():
			continue
		var l := int(ob.get("level", 0))
		var at := [l, float(ob["x"]) + o.x, float(ob["z"]) + o.y]
		var pid := "%s:%s" % [h.id, ob.get("id", "o%d" % n)]
		n += 1
		var item := Catalogue.id_of(ob)
		# Where a figure goes to use it (drawing only): lying on a bed, sitting on a seat, standing at the front of anything else.
		var a := deg_to_rad(float(ob.get("rot", 0.0)))
		var fwd := Vector2(sin(a), cos(a))
		var depth := float((it.get("size", [0.5, 0.5]) as Array)[1])
		var pose := "lie" if int(it.get("sleeps", 0)) > 0 else "sit" if str(it.get("function", "")) == "seating" else "stand"
		var off := 0.05 if pose != "stand" else depth * 0.5 + 0.3
		var look := {"pose": pose, "stand": [l, float(at[1]) + fwd.x * off, float(at[2]) + fwd.y * off],
			"face": a if pose != "stand" else atan2(-fwd.x, -fwd.y)}
		if int(it.get("sleeps", 0)) > 0:
			_add_place(pid, "bed", h.id, at, {"energy": 100.0}, 0, int(it["sleeps"]), look)
			(home["beds"] as Array).append(pid)
		elif item == "wood_stove":
			_add_place(pid, "cook", h.id, at, {"hunger": 70.0}, 40, 2, look)
		elif item == "icebox":
			_add_place(pid, "snack", h.id, at, {"hunger": 25.0}, 10, 2, look)
		elif item == "wireless_set":
			_add_place(pid, "wireless", h.id, at, {"fun": 35.0, "social": 5.0}, 60, 4, look)
		elif str(it.get("function", "")) == "seating" and int(Catalogue.item(item).get("scores", {}).get("comfort", 0)) >= 3:
			_add_place(pid, "sit", h.id, at, {"fun": 12.0, "energy": 5.0}, 40, 2, look)
	for f: Dictionary in h.fixtures:
		if str(f.get("kind", "")) == "stove":
			_add_place("%s:stove" % h.id, "cook", h.id, [0, float(f["x"]) + o.x, float(f["z"]) + o.y], {"hunger": 70.0}, 40, 2)
	for it2: Dictionary in h.garden:
		if str(it2["kind"]) in ["vegie_bed", "chook_pen"]:
			_add_place("%s:%s" % [h.id, it2.get("id", it2["kind"])], "garden", h.id, [0, float(it2["x"]) + o.x, float(it2["z"]) + o.y], {"fun": 25.0}, 60, 2)
	for l2 in h.levels():
		for r in h.rooms(l2):
			var name := h.room_name(r).to_lower()
			var rb: Rect2i = r["bounds"]
			var centre := [l2, rb.get_center().x + o.x, rb.get_center().y + o.y]
			(home["rooms"] as Array).append({"name": name, "at": centre})
			if name.contains("shop") or name.contains("store"):
				_add_place("%s:shop" % h.id, "shop", h.id, centre, {"hunger": 30.0}, 15, 6, {"work": "store"})
			elif name.contains("exchange"):
				_add_place("%s:exchange" % h.id, "exchange", h.id, centre, {}, 0, 1, {"work": "exchange"})
			if not home.has("living") and (name.contains("living") or name.contains("sitting") or name.contains("kitchen") or name.contains("parlour")):
				home["living"] = centre
	if not home.has("living") and not (home["rooms"] as Array).is_empty():
		home["living"] = (home["rooms"] as Array)[0]["at"]
	homes[h.id] = home


func place(id: String) -> Dictionary:
	for p in places:
		if str(p["id"]) == id:
			return p
	return {}


## The point id nearest a position (its tile on its storey, or the nearest walkable ground tile).
func _point_at(pos: Array, house: String = "") -> int:
	var l := int(pos[0])
	var x := floori(float(pos[1]))
	var z := floori(float(pos[2]))
	if l == 0:
		var id := point_id(0, x, z)
		if id >= 0:
			return id
		var nw := _nearest_walkable(Vector2i(x, z))
		return point_id(0, int(float(nw[1])), int(float(nw[2]))) if not nw.is_empty() else -1
	return point_id(l, x, z, house)


## A walking route between two positions: [[level, x, z], ...], or [] when there's no way.
func route(from: Array, to: Array, from_house: String = "", to_house: String = "") -> Array:
	var a := _point_at(from, from_house)
	var b := _point_at(to, to_house)
	if a < 0 or b < 0:
		return []
	if a == b:
		return [[int(to[0]), float(to[1]), float(to[2])]]
	var path := astar.get_point_path(a, b)
	if path.is_empty():
		return []
	var out: Array = []
	for p: Vector3 in path:
		out.append([_level_of(p, from, to), p.x, p.z])
	return out


func _level_of(p: Vector3, from: Array, to: Array) -> int:
	if p.y <= 0.01:
		return 0
	return int(to[0]) if int(to[0]) > 0 else int(from[0])


static func route_length(r: Array) -> float:
	var d := 0.0
	for i in range(1, r.size()):
		d += Vector2(float(r[i][1]), float(r[i][2])).distance_to(Vector2(float(r[i - 1][1]), float(r[i - 1][2]))) + absf(float(r[i][0]) - float(r[i - 1][0])) * 3.0
	return d


## Where someone is after walking dist metres along a route.
static func along(r: Array, dist: float) -> Array:
	if r.is_empty():
		return []
	var left := dist
	for i in range(1, r.size()):
		var a := Vector2(float(r[i - 1][1]), float(r[i - 1][2]))
		var b := Vector2(float(r[i][1]), float(r[i][2]))
		var seg := a.distance_to(b) + absf(float(r[i][0]) - float(r[i - 1][0])) * 3.0
		if left <= seg:
			var p := a.lerp(b, left / maxf(seg, 0.001))
			# Positions on a 1/64 m grid read back exactly from a JSON snapshot.
			return [int(r[i][0]) if left > seg * 0.5 else int(r[i - 1][0]), roundf(p.x * 64.0) / 64.0, roundf(p.y * 64.0) / 64.0]
		left -= seg
	return (r[r.size() - 1] as Array).duplicate()
