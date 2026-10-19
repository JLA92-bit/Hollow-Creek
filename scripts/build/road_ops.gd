class_name RoadOps
extends RefCounted
## Town roads (docs/BUILDING.md "Roads"): ground laid along a path of waypoints, a few tiles wide.
## Dirt is free but turns to mud in the rain; gravel is 2 a tile; a footpath is 1. Plain functions.

const KINDS := {"dirt": {"label": "Dirt road", "cost": 0, "width": 3}, "gravel": {"label": "Gravel road", "cost": 2, "width": 3},
	"footpath": {"label": "Footpath", "cost": 1, "width": 1}}


## The tiles a path covers, `width` wide, without duplicates, in order.
static func tiles_along(points: Array, width: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	var half := (width - 1) / 2.0
	for i in range(points.size() - 1):
		var a := Vector2(float(points[i][0]), float(points[i][1]))
		var b := Vector2(float(points[i + 1][0]), float(points[i + 1][1]))
		var steps := int(ceil(a.distance_to(b) * 2.0))
		for s in steps + 1:
			var p := a.lerp(b, float(s) / float(maxi(1, steps)))
			for dy in range(-ceili(half), ceili(half) + 1):
				for dx in range(-ceili(half), ceili(half) + 1):
					if Vector2(dx, dy).length() > half + 0.5:
						continue
					var t := Vector2i(floori(p.x) + dx, floori(p.y) + dy)
					var key := (t.x << 16) | t.y
					if not seen.has(key):
						seen[key] = true
						out.append(t)
	return out


## Price of laying `tiles` of a kind that aren't already that ground.
static func cost(kind: String, roads: Dictionary, tiles: Array[Vector2i]) -> int:
	var per := int((KINDS[kind] as Dictionary)["cost"])
	var n := 0
	for t in tiles:
		if str(roads.get("%d,%d" % [t.x, t.y], "")) != kind:
			n += 1
	return n * per


## Lays the tiles into the roads map ("x,y" -> kind). Returns how many changed.
static func lay(roads: Dictionary, kind: String, tiles: Array[Vector2i], bounds: Vector2i) -> int:
	var n := 0
	for t in tiles:
		if t.x < 0 or t.y < 0 or t.x >= bounds.x or t.y >= bounds.y:
			continue
		var key := "%d,%d" % [t.x, t.y]
		if str(roads.get(key, "")) != kind:
			roads[key] = kind
			n += 1
	return n


static func ground_of(kind: String) -> Ground.Type:
	return {"dirt": Ground.Type.DIRT, "gravel": Ground.Type.GRAVEL, "footpath": Ground.Type.FOOTPATH}[kind]
