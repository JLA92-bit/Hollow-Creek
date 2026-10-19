class_name StoryChecks
extends RefCounted
## Questions the prologue asks about what the player has built (docs/CASE_00_CASH_TIN.md step 3):
## does the store have a front door onto the road, a back window facing the creek and an exchange
## room? Plain functions over HouseData and the grid, so they're testable without a scene.

const ROAD_GROUNDS: Array[int] = [Ground.Type.DIRT, Ground.Type.GRAVEL, Ground.Type.FOOTPATH, Ground.Type.ROAD_SEALED]
const NEAR_ROAD := 3.5


## Openings of one kind on the ground storey, as world tiles: [{out: Vector2i, in: Vector2i}].
static func openings_of(h: HouseData, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inside: Dictionary = {}
	for r: Dictionary in h.rooms(0):
		for t: Vector2i in r["tiles"]:
			inside["%d,%d" % [t.x, t.y]] = true
	for op: Dictionary in h.openings(0):
		if str(op.get("kind", "")) != kind:
			continue
		for k: String in HouseData.opening_edges(op):
			var sides := HouseData.edge_sides(k)
			var a := Vector2i(int(sides[0][0]), int(sides[0][1]))
			var b := Vector2i(int(sides[1][0]), int(sides[1][1]))
			var ia := inside.has("%d,%d" % [a.x, a.y])
			var ib := inside.has("%d,%d" % [b.x, b.y])
			if ia and not ib:
				out.append({"out": b + h.origin, "in": a + h.origin})
			elif ib and not ia:
				out.append({"out": a + h.origin, "in": b + h.origin})
	return out


## The centre of the house's ground floor, in world tiles.
static func centre(h: HouseData) -> Vector2:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for r: Dictionary in h.rooms(0):
		for t: Vector2i in r["tiles"]:
			lo = Vector2(minf(lo.x, t.x), minf(lo.y, t.y))
			hi = Vector2(maxf(hi.x, t.x + 1), maxf(hi.y, t.y + 1))
	return (lo + hi) * 0.5 + Vector2(h.origin) if hi.x > lo.x else Vector2(h.origin)


static func is_road(grid: WorldGrid, t: Vector2i) -> bool:
	return grid.in_bounds(t.x, t.y) and ROAD_GROUNDS.has(int(grid.get_ground(t.x, t.y)))


static func near_road(grid: WorldGrid, t: Vector2i) -> bool:
	var r := ceili(NEAR_ROAD)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dy).length() <= NEAR_ROAD and is_road(grid, t + Vector2i(dx, dy)):
				return true
	return false


## The direction from a house towards the nearest creek point (a unit vector).
static func creek_dir(h: HouseData, creek: PackedVector2Array) -> Vector2:
	var c := centre(h)
	var best := Vector2.ZERO
	var best_d := 1e18
	for p in creek:
		var d := c.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p - c
	return best.normalized()


## {door, window, exchange}: the three things the store needs.
static func store(h: HouseData, grid: WorldGrid, creek: PackedVector2Array) -> Dictionary:
	var door := false
	for d in openings_of(h, "door"):
		if near_road(grid, d["out"]):
			door = true
	var window := false
	var away := creek_dir(h, creek)
	var c := centre(h)
	for w in openings_of(h, "window"):
		var n := (Vector2(w["out"]) - Vector2(w["in"])).normalized()
		if n.dot(away) >= 0.5 and Vector2(w["out"]).distance_to(c) > 0.0:
			window = true
	var exchange := false
	for r: Dictionary in h.rooms(0):
		if h.room_name(r).to_lower().contains("exchange"):
			exchange = true
	for ob: Dictionary in h.objects:
		if Catalogue.id_of(ob).contains("switchboard"):
			exchange = true
	return {"door": door, "window": window, "exchange": exchange}


## A house with somewhere to sleep: something with "bed" in its name among its furniture.
static func has_bed(h: HouseData) -> bool:
	for ob: Dictionary in h.objects:
		if Catalogue.id_of(ob).contains("bed"):
			return true
	return false


## Is the store on the marked plot? (Its centre is inside the plot rectangle.)
static func on_plot(h: HouseData, rect: Rect2i) -> bool:
	return rect.has_point(Vector2i(floori(centre(h).x), floori(centre(h).y)))


## How much of the guided road has been laid, 0 to 1: the share of the ghost path's tiles (with the
## road's width) that are now road ground.
static func road_done(grid: WorldGrid, points: Array, width: int) -> float:
	var total := 0
	var laid := 0
	var seen: Dictionary = {}
	for i in range(points.size() - 1):
		var a := Vector2(float(points[i][0]), float(points[i][1]))
		var b := Vector2(float(points[i + 1][0]), float(points[i + 1][1]))
		var steps := int(ceil(a.distance_to(b)))
		for s in steps + 1:
			var p := a.lerp(b, float(s) / float(maxi(1, steps)))
			var t := Vector2i(floori(p.x), floori(p.y))
			var key := "%d,%d" % [t.x, t.y]
			if seen.has(key):
				continue
			seen[key] = true
			total += 1
			if is_road(grid, t):
				laid += 1
	return float(laid) / float(maxi(1, total))
