class_name SightMap
extends RefCounted
## What blocks the eye in the town (docs/BUILDING.md "Sightlines"), on the ground storey: walls,
## closed doors, windows with their curtains drawn at night, solid fences on tile edges; tree trunks
## and tall furniture on tiles. Also every room's tiles, windows and lamps, for the light grid.
## Plain class, built from the grid and the houses as they stand, like SimTown.

const DAY_RANGE := 18.0
const NIGHT_LIT_RANGE := 9.0
const NIGHT_DARK_RANGE := 3.0
const LIT := 0.4                ## a tile at or above this light counts as lit
const SOLID_FENCE := 1.5        ## fences this tall or taller block sight
const TALL_ITEMS: Array[String] = ["wardrobe", "dresser"]

var width := 0
var height := 0
var edges: Dictionary = {}      ## world edge key -> "wall" | "door" | "window" | "fence"
var curtains: Dictionary = {}   ## window edge key -> true when its curtains are drawn at night
var tiles: Dictionary = {}      ## "x,y" -> "tree" | "furniture"
var room_of: Dictionary = {}    ## "x,y" -> room id ("house:level:key"), ground storey
var rooms: Dictionary = {}      ## room id -> {house, tiles: [Vector2i], windows: [{edge, out: Vector2i}], lamps: int}
var outdoor_lamps: Array = []   ## [{at: Vector2, radius}]
var house_names: Dictionary = {}  ## house id -> name


static func build(grid: WorldGrid, houses: Array) -> SightMap:
	var s := SightMap.new()
	s.width = grid.width
	s.height = grid.height
	for o: Dictionary in grid.objects:
		if bool(o.get("blocks", false)):
			s.tiles["%d,%d" % [floori(float(o["x"])), floori(float(o["y"]))]] = "tree"
	var sorted_houses: Array = houses.duplicate()
	sorted_houses.sort_custom(func(a: HouseData, b: HouseData) -> bool: return a.id < b.id)
	for h: HouseData in sorted_houses:
		s._add_house(h)
	return s


static func world_edge(h: HouseData, k: String) -> String:
	var pts := HouseData.edge_points(k)
	return HouseData.edge_from_points(pts[0] + h.origin, pts[1] + h.origin)


func _add_house(h: HouseData) -> void:
	var o := h.origin
	house_names[h.id] = h.name
	for k: String in h.walls(0):
		if HouseData.is_diagonal(k):
			continue
		edges[world_edge(h, k)] = "wall"
	for op: Dictionary in h.openings(0):
		var kind := str(op.get("kind", ""))
		var night: Dictionary = op.get("night", {})
		for k2: String in HouseData.opening_edges(op):
			var wk := world_edge(h, k2)
			if kind == "window":
				edges[wk] = "window"
				if bool(night.get("curtains", false)):
					curtains[wk] = true
			elif kind == "door":
				edges[wk] = "door"
			else:
				edges.erase(wk)
	for fk: String in h.fences:
		var f: Dictionary = h.fences[fk]
		var def: Dictionary = (GardenOps.catalogue()["fences"] as Dictionary).get(str(f.get("type", "")), {})
		if float(def.get("height", 1.0)) >= SOLID_FENCE and not bool(f.get("gate", false)):
			edges[world_edge(h, fk)] = "fence"
	for r: Dictionary in h.rooms(0):
		var rid := "%s:0:%s" % [h.id, r["key"]]
		var room := {"house": h.id, "name": h.room_name(r).to_lower(), "tiles": [], "windows": [], "lamps": 0}
		for t: Vector2i in r["tiles"]:
			var wt := t + o
			(room["tiles"] as Array).append(wt)
			room_of["%d,%d" % [wt.x, wt.y]] = rid
		rooms[rid] = room
	# Windows: which room is inside, and which tile is just outside.
	for op2: Dictionary in h.openings(0):
		if str(op2.get("kind", "")) != "window":
			continue
		for k3: String in HouseData.opening_edges(op2):
			var sides := HouseData.edge_sides(k3)
			var a := Vector2i(int(sides[0][0]), int(sides[0][1])) + o
			var b := Vector2i(int(sides[1][0]), int(sides[1][1])) + o
			var ra := str(room_of.get("%d,%d" % [a.x, a.y], ""))
			var rb := str(room_of.get("%d,%d" % [b.x, b.y], ""))
			var latched := bool(op2.get("latched", false))
			if ra != "" and rb == "":
				(rooms[ra]["windows"] as Array).append({"edge": world_edge(h, k3), "out": b, "in": a, "latched": latched})
			elif rb != "" and ra == "":
				(rooms[rb]["windows"] as Array).append({"edge": world_edge(h, k3), "out": a, "in": b, "latched": latched})
	for ob: Dictionary in h.objects:
		if int(ob.get("level", 0)) != 0:
			continue
		var id := Catalogue.id_of(ob)
		var p := Vector2(float(ob["x"]), float(ob["z"])) + Vector2(o)
		var key := "%d,%d" % [floori(p.x), floori(p.y)]
		if TALL_ITEMS.has(id):
			var rect := FurnitureOps.rect_of(ob)
			rect.position += Vector2(o)
			for y in range(floori(rect.position.y + 0.1), ceili(rect.end.y - 0.1)):
				for x in range(floori(rect.position.x + 0.1), ceili(rect.end.x - 0.1)):
					tiles["%d,%d" % [x, y]] = "furniture"
		if not Catalogue.light_of(ob).is_empty():
			if room_of.has(key):
				rooms[room_of[key]]["lamps"] = int(rooms[room_of[key]]["lamps"]) + 1
			else:
				outdoor_lamps.append({"at": p, "radius": 4.0})
	# Older houses (Agnes's cottage) list their lamps separately.
	for l: Dictionary in h.lights:
		var lp := Vector2(float(l.get("x", 0.0)), float(l.get("z", 0.0))) + Vector2(o)
		var lk := "%d,%d" % [floori(lp.x), floori(lp.y)]
		if room_of.has(lk):
			rooms[room_of[lk]]["lamps"] = int(rooms[room_of[lk]]["lamps"]) + 1


func room_at(t: Vector2i) -> String:
	return str(room_of.get("%d,%d" % [t.x, t.y], ""))


## What blocks a step between two neighbouring tiles (orthogonal), or "".
func _edge_between(a: Vector2i, b: Vector2i, night: bool) -> String:
	var k := ""
	if b.x != a.x:
		k = HouseData.vkey(maxi(a.x, b.x), a.y)
	else:
		k = HouseData.hkey(a.x, maxi(a.y, b.y))
	var e := str(edges.get(k, ""))
	if e == "window":
		return "curtains" if night and curtains.has(k) else ""
	return e


## The first thing in the way between two tiles, or "" if the line is clear. A Bresenham walk over
## tiles: edges crossed on each step, and blocking tiles passed through (not the two ends). A
## diagonal step through a corner is blocked only if both ways round it are.
func blocker(a: Vector2i, b: Vector2i, night: bool) -> String:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var cur := a
	while cur != b:
		var e2 := 2 * err
		var nx := cur.x
		var ny := cur.y
		if e2 >= dy:
			err += dy
			nx += sx
		if e2 <= dx:
			err += dx
			ny += sy
		var nxt := Vector2i(nx, ny)
		if nx != cur.x and ny != cur.y:
			var via_x := Vector2i(nx, cur.y)
			var via_y := Vector2i(cur.x, ny)
			var p1 := _edge_between(cur, via_x, night)
			if p1 == "":
				p1 = _edge_between(via_x, nxt, night)
			var p2 := _edge_between(cur, via_y, night)
			if p2 == "":
				p2 = _edge_between(via_y, nxt, night)
			if p1 != "" and p2 != "":
				return p1
		else:
			var e := _edge_between(cur, nxt, night)
			if e != "":
				return e
		cur = nxt
		if cur != b:
			var t := str(tiles.get("%d,%d" % [cur.x, cur.y], ""))
			if t != "":
				return t
	return ""


## Could an observer at one tile see a target at another? {seen, confidence, reason}.
## who: {awake, focused, observant, elderly, drunk}. light: the LightGrid for this minute.
func look(from: Vector2i, to: Vector2i, who: Dictionary, light: LightGrid) -> Dictionary:
	if not bool(who.get("awake", true)):
		return {"seen": false, "confidence": 0.0, "reason": "asleep"}
	if bool(who.get("focused", false)):
		return {"seen": false, "confidence": 0.0, "reason": "busy"}
	var night := light.night
	var lux := light.at(to)
	var dist := Vector2(from).distance_to(Vector2(to))
	var reach := DAY_RANGE if not night else (NIGHT_LIT_RANGE if lux >= LIT else NIGHT_DARK_RANGE)
	if dist > reach:
		return {"seen": false, "confidence": 0.0, "reason": "too far" if not night or lux >= LIT else "too dark"}
	var b := blocker(from, to, night)
	if b != "":
		return {"seen": false, "confidence": 0.0, "reason": b}
	var c := 0.9 - 0.4 * dist / reach
	if night:
		c *= lerpf(0.6, 1.0, clampf(lux, 0.0, 1.0))
	if bool(who.get("observant", false)):
		c += 0.2
	if bool(who.get("drunk", false)):
		c -= 0.4
	if night and bool(who.get("elderly", false)):
		c -= 0.1
	return {"seen": true, "confidence": snappedf(clampf(c, 0.05, 1.0), 0.01), "reason": ""}
