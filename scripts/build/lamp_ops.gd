class_name LampOps
extends RefCounted
## Street lamps (docs/BUILDING.md "Lights"): a pole and shade the player puts along the town's
## roads. Each lights the ground around it from dusk to dawn, which makes sightings of whoever passes
## more likely and crimes in its glow less tempting (see Motives.safety). Plain functions over the
## list of lamp positions [[x, y], ...] kept in GameState.lamps.

const COST := 15
const REFUND := 8
const REACH := 6.0         ## metres of light on the ground
const MIN_SPACING := 3.0
const MAX_LAMPS := 80


static func snap(p: Vector2) -> Vector2:
	return Vector2(snappedf(p.x, 0.5), snappedf(p.y, 0.5))


static func index_near(lamps: Array, at: Vector2, within: float = 1.2) -> int:
	var best := -1
	var best_d := within
	for i in lamps.size():
		var d := Vector2(float(lamps[i][0]), float(lamps[i][1])).distance_to(at)
		if d <= best_d:
			best_d = d
			best = i
	return best


## Puts a lamp at a point. `blocked` says whether the spot can't take one (water, inside a house).
## Returns {ok, msg, cost}.
static func place(lamps: Array, at: Vector2, blocked: Callable = Callable()) -> Dictionary:
	var p := snap(at)
	if lamps.size() >= MAX_LAMPS:
		return {"ok": false, "msg": "That's a lamp for every few steps already.", "cost": 0}
	if blocked.is_valid() and bool(blocked.call(p)):
		return {"ok": false, "msg": "A lamp can't go there.", "cost": 0}
	if index_near(lamps, p, MIN_SPACING) >= 0:
		return {"ok": false, "msg": "Too close to another lamp.", "cost": 0}
	lamps.append([p.x, p.y])
	return {"ok": true, "msg": "Lamp up.", "cost": COST}


## Takes down the lamp nearest a point. Returns the refund, or -1 if there was none.
static func remove_at(lamps: Array, at: Vector2) -> int:
	var i := index_near(lamps, snap(at), 1.5)
	if i < 0:
		return -1
	lamps.remove_at(i)
	return REFUND


## How many lamps light the ground within `radius` of a point.
static func lamps_within(lamps: Array, at: Vector2, radius: float) -> int:
	var n := 0
	for l: Variant in lamps:
		if Vector2(float((l as Array)[0]), float((l as Array)[1])).distance_to(at) <= radius:
			n += 1
	return n
