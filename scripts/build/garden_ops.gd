class_name GardenOps
extends RefCounted
## Landscaping edits on a house's lot: terrain shaping, ground finishes (lawn, paths, gravel, garden
## beds), plants, outbuildings, outdoor items, fences and gates. Like BuildOps, each op mutates the
## HouseData and returns {ok, msg, cost}; everything is in house-local coordinates.

const PATH := "res://data/garden.json"
## How far the lot reaches past the house, in metres.
const LOT_MARGIN := 12
const TERRAIN_STEP := 0.25
const TERRAIN_LIMIT := Vector2(-3.0, 2.5)

static var _data: Dictionary = {}


static func catalogue() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary
	return _data


## A plant, outbuilding or item definition, with its "category" (plants, outbuildings, items).
static func item_def(kind: String) -> Dictionary:
	for cat: String in ["plants", "outbuildings", "items"]:
		var c: Dictionary = catalogue()[cat]
		if c.has(kind):
			var d: Dictionary = (c[kind] as Dictionary).duplicate()
			d["category"] = cat
			return d
	return {}


static func lot(h: HouseData) -> Rect2i:
	return h.bounds().grow(LOT_MARGIN)


static func in_lot(h: HouseData, p: Vector2) -> bool:
	return Rect2(lot(h)).has_point(p)


## Where the house itself stands: its floors and verandahs (nothing grows or gets dug there).
static func _house_area(h: HouseData) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var b := h.bounds()
	if b.size != Vector2i.ZERO:
		out.append(Rect2(b).grow(0.15))
	for v: Dictionary in h.verandahs:
		out.append(BuildOps.verandah_rect(h, v).grow(0.3))
	return out


static func _under_house(h: HouseData, r: Rect2) -> bool:
	for a in _house_area(h):
		if a.intersects(r):
			return true
	return false


# --- Terrain -------------------------------------------------------------------------------------

## Shapes the ground round a point. op is raise, lower, flatten (to the height at the centre) or
## smooth. height_fn(cx, cy) gives the current ground height at a lot corner, relative to base_y.
## Ground under the house stays below its floor.
static func terrain_brush(h: HouseData, op: String, centre: Vector2, radius: float, height_fn: Callable, amount: float = TERRAIN_STEP) -> Dictionary:
	if is_nan(h.base_y):
		return BuildOps.fail("Build a room first; the garden belongs to a house.")
	if not in_lot(h, centre):
		return BuildOps.fail("That's past the edge of the lot.")
	var l := lot(h)
	var floor_limit := h.floor_y() - 0.3
	var target := float(height_fn.call(roundi(centre.x), roundi(centre.y)))
	var changed := 0
	var updates: Dictionary = {}
	var r := ceili(radius)
	for cy in range(roundi(centre.y) - r, roundi(centre.y) + r + 1):
		for cx in range(roundi(centre.x) - r, roundi(centre.x) + r + 1):
			if cx < l.position.x or cy < l.position.y or cx > l.end.x or cy > l.end.y:
				continue
			var d := Vector2(cx, cy).distance_to(centre)
			if d > radius:
				continue
			var w := 1.0 - smoothstep(radius * 0.5, radius, d)
			var cur := float(height_fn.call(cx, cy))
			var nh := cur
			match op:
				"raise":
					nh = cur + amount * w
				"lower":
					nh = cur - amount * w
				"flatten":
					nh = lerpf(cur, target, w)
				"smooth":
					var avg := 0.0
					for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
						avg += float(height_fn.call(cx + o.x, cy + o.y))
					nh = lerpf(cur, avg * 0.25, 0.7 * w)
				_:
					return BuildOps.fail("Unknown terrain tool.")
			nh = clampf(nh, TERRAIN_LIMIT.x, TERRAIN_LIMIT.y)
			if _under_house(h, Rect2(cx - 0.5, cy - 0.5, 1.0, 1.0)):
				nh = minf(nh, floor_limit)
			if absf(nh - cur) > 0.001:
				updates[HouseData.tile_key(cx, cy)] = snappedf(nh, 0.01)
				changed += 1
	if changed == 0:
		return BuildOps.fail("Nothing to change there.")
	h.terrain.merge(updates, true)
	h.touch()
	return BuildOps.ok(ceili(changed * 0.05))


## Lays a ground finish on tiles (lawn, dirt path, gravel or garden bed); not under the house.
static func paint_ground(h: HouseData, tiles: Array[Vector2i], ground_name: String) -> Dictionary:
	var grounds: Dictionary = catalogue()["grounds"]
	if not grounds.has(ground_name):
		return BuildOps.fail("Unknown ground.")
	var n := 0
	for t in tiles:
		if not in_lot(h, Vector2(t) + Vector2(0.5, 0.5)) or _under_house(h, Rect2(t.x + 0.1, t.y + 0.1, 0.8, 0.8)):
			continue
		h.ground[HouseData.tile_key(t.x, t.y)] = ground_name
		n += 1
	if n == 0:
		return BuildOps.fail("Paths and beds go in the yard, not under the house.")
	h.touch()
	return BuildOps.ok(ceili(n * float(grounds[ground_name]["cost"]) * 0.5))


# --- Plants, outbuildings and items --------------------------------------------------------------

static func item_rect(it: Dictionary) -> Rect2:
	var d := item_def(str(it["kind"]))
	var sz: Array = d.get("size", [1.0, 1.0])
	var w := float(sz[0])
	var dd := float(sz[1])
	var turned := posmod(roundi(float(it.get("rot", 0.0)) / 90.0), 2) == 1
	if turned:
		var t := w
		w = dd
		dd = t
	return Rect2(float(it["x"]) - w * 0.5, float(it["z"]) - dd * 0.5, w, dd)


## Places a plant, outbuilding or outdoor item centred at pos, turned rot degrees (90 degree steps).
static func place_item(h: HouseData, kind: String, pos: Vector2, rot: float = 0.0) -> Dictionary:
	var d := item_def(kind)
	if d.is_empty():
		return BuildOps.fail("Unknown garden item.")
	if is_nan(h.base_y):
		return BuildOps.fail("Build a room first; the garden belongs to a house.")
	var it := {"kind": kind, "x": snappedf(pos.x, 0.25), "z": snappedf(pos.y, 0.25), "rot": posmod(roundi(rot / 90.0), 4) * 90.0}
	var msg := _item_check(h, it, "")
	if msg != "":
		return BuildOps.fail(msg)
	it["id"] = h.new_id("g")
	h.garden.append(it)
	h.touch()
	return BuildOps.ok(int(d.get("cost", 1)), {"id": it["id"]})


static func _item_check(h: HouseData, it: Dictionary, skip_id: String) -> String:
	var r := item_rect(it)
	if not Rect2(lot(h)).encloses(r):
		return "That's past the edge of the lot."
	if _under_house(h, r.grow(-0.05)):
		return "That would be under the house."
	var cat := str(item_def(str(it["kind"])).get("category", ""))
	if cat == "plants" and str(it["kind"]) != "vegie_bed":
		return ""
	for o: Dictionary in h.garden:
		if str(o.get("id", "")) == skip_id:
			continue
		var oc := str(item_def(str(o["kind"])).get("category", ""))
		if (oc != "plants" or str(o["kind"]) == "vegie_bed") and item_rect(o).grow(-0.05).intersects(r.grow(-0.05)):
			return "Something's already there."
	return ""


static func item_by_id(h: HouseData, id: String) -> Dictionary:
	for it: Dictionary in h.garden:
		if str(it.get("id", "")) == id:
			return it
	return {}


## Moves or turns an item: changes may hold x, z and rot.
static func update_item(h: HouseData, id: String, changes: Dictionary) -> Dictionary:
	var it := item_by_id(h, id)
	if it.is_empty():
		return BuildOps.fail("That's gone.")
	var trial := it.duplicate()
	trial.merge(changes, true)
	trial["rot"] = posmod(roundi(float(trial.get("rot", 0.0)) / 90.0), 4) * 90.0
	var msg := _item_check(h, trial, id)
	if msg != "":
		return BuildOps.fail(msg)
	it.merge(trial, true)
	h.touch()
	return BuildOps.ok()


static func remove_item(h: HouseData, id: String) -> Dictionary:
	for i in h.garden.size():
		if str(h.garden[i].get("id", "")) == id:
			h.garden.remove_at(i)
			h.touch()
			return BuildOps.ok()
	return BuildOps.fail("That's gone.")


## The item under a plan point (smallest first, so a plant in front of a shed wins), or {}.
static func item_at(h: HouseData, p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_a := INF
	for it: Dictionary in h.garden:
		var r := item_rect(it).grow(0.15)
		if r.has_point(p) and r.get_area() < best_a:
			best_a = r.get_area()
			best = it
	return best


# --- Fences and gates ----------------------------------------------------------------------------

## Unit edges along a straight grid line from corner a to corner b (horizontal or vertical).
static func fence_edges(a: Vector2i, b: Vector2i) -> Array[String]:
	var out: Array[String] = []
	if a.y == b.y:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			out.append(HouseData.hkey(x, a.y))
	elif a.x == b.x:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y)):
			out.append(HouseData.vkey(a.x, y))
	return out


## Builds a fence run from corner a to corner b, skipping where the house's walls already are.
static func set_fence(h: HouseData, a: Vector2i, b: Vector2i, type: String) -> Dictionary:
	var fences: Dictionary = catalogue()["fences"]
	if not fences.has(type):
		return BuildOps.fail("Unknown fence.")
	if a.x != b.x and a.y != b.y:
		return BuildOps.fail("Fences run straight along the grid.")
	var edges := fence_edges(a, b)
	if edges.is_empty():
		return BuildOps.fail("Drag along the ground to run a fence.")
	var n := 0
	for k in edges:
		var pts := HouseData.edge_points(k)
		var mid := Vector2(pts[0] + pts[1]) * 0.5
		if not in_lot(h, mid) or h.walls(0).has(k) or _under_house(h, Rect2(mid - Vector2(0.3, 0.3), Vector2(0.6, 0.6))):
			continue
		var gate := bool((h.fences.get(k, {}) as Dictionary).get("gate", false))
		h.fences[k] = {"type": type, "gate": gate}
		n += 1
	if n == 0:
		return BuildOps.fail("Fences go round the yard, not through the house.")
	h.touch()
	return BuildOps.ok(n * int(fences[type]["cost"]))


static func remove_fence(h: HouseData, a: Vector2i, b: Vector2i) -> Dictionary:
	var n := 0
	for k in fence_edges(a, b):
		if h.fences.erase(k):
			n += 1
	if n == 0:
		return BuildOps.fail("There's no fence there.")
	h.touch()
	return BuildOps.ok()


## Turns one metre of fence into a gate, or back.
static func toggle_gate(h: HouseData, k: String) -> Dictionary:
	if not h.fences.has(k):
		return BuildOps.fail("Gates go in a fence.")
	var f: Dictionary = h.fences[k]
	f["gate"] = not bool(f.get("gate", false))
	h.touch()
	return BuildOps.ok(2 if f["gate"] else 0)


## The fence edge nearest a plan point (within radius), or "".
static func fence_at(h: HouseData, p: Vector2, radius: float = 0.4) -> String:
	var best := ""
	var best_d := radius
	for k: String in h.fences:
		var pts := HouseData.edge_points(k)
		var q := Geometry2D.get_closest_point_to_segment(p, Vector2(pts[0]), Vector2(pts[1]))
		if p.distance_to(q) < best_d:
			best_d = p.distance_to(q)
			best = k
	return best
