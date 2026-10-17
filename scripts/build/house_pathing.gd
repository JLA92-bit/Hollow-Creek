class_name HousePathing
extends RefCounted
## Walkable graph of a house across storeys, for residents and tests. Tiles are nodes; neighbours
## connect unless a wall stands between them (doors, doorways and arches let people through).
## Stairs join the tile before the bottom step to the tile after the top step.
## The ground storey also includes a margin of outdoor tiles round the house.

const MARGIN := 2

var house: HouseData
var astar := AStar3D.new()
var _ids: Dictionary = {}  ## "level,x,y" -> id


static func build(h: HouseData) -> HousePathing:
	var p := HousePathing.new()
	p.house = h
	p._build()
	return p


func _id(level: int, t: Vector2i) -> int:
	return int(_ids.get("%d,%d,%d" % [level, t.x, t.y], -1))


func _build() -> void:
	var next := 0
	var b := house.bounds().grow(MARGIN)
	for level in house.levels():
		var floors := house.floors(level)
		var wells := house.stairwell_tiles(level)
		var blocked: Dictionary = {}
		for st: Dictionary in house.stairs(level):
			for t: Vector2i in house.stair_tiles(st, level)["lower"]:
				blocked[HouseData.tile_key(t.x, t.y)] = true
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				var tk := HouseData.tile_key(x, y)
				var walkable := floors.has(tk) if level != 0 else true
				if wells.has(tk) or blocked.has(tk):
					walkable = false
				if not walkable:
					continue
				astar.add_point(next, Vector3(x + 0.5, house.level_base(level), y + 0.5))
				_ids["%d,%d,%d" % [level, x, y]] = next
				next += 1
		for y2 in range(b.position.y, b.end.y):
			for x2 in range(b.position.x, b.end.x):
				var a := _id(level, Vector2i(x2, y2))
				if a < 0:
					continue
				var east := _id(level, Vector2i(x2 + 1, y2))
				if east >= 0 and _passable(level, HouseData.vkey(x2 + 1, y2)):
					astar.connect_points(a, east)
				var south := _id(level, Vector2i(x2, y2 + 1))
				if south >= 0 and _passable(level, HouseData.hkey(x2, y2 + 1)):
					astar.connect_points(a, south)
	for level2 in house.levels():
		for st2: Dictionary in house.stairs(level2):
			var info := house.stair_tiles(st2, level2)
			var lo := _id(level2, info["approach"])
			var hi := _id(level2 + 1, info["arrival"])
			if lo >= 0 and hi >= 0:
				astar.connect_points(lo, hi)


func _passable(level: int, k: String) -> bool:
	if not house.walls(level).has(k):
		return true
	for op in house.openings_on_edge(level, k):
		var kind := str((op["o"] as Dictionary)["kind"])
		if kind in ["door", "doorway", "arch"] and float(op["to"]) - float(op["from"]) >= 0.25:
			return true
	return false


## Tiles from a to b as [level, Vector2i] pairs, or [] if there's no way through.
func find_path(level_a: int, a: Vector2i, level_b: int, b: Vector2i) -> Array:
	var ia := _id(level_a, a)
	var ib := _id(level_b, b)
	if ia < 0 or ib < 0:
		return []
	var ids := astar.get_id_path(ia, ib)
	var out: Array = []
	for i in ids:
		var p := astar.get_point_position(i)
		out.append(p)
	return out


func reachable(level_a: int, a: Vector2i, level_b: int, b: Vector2i) -> bool:
	return not find_path(level_a, a, level_b, b).is_empty()
