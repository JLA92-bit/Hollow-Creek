class_name LightGrid
extends RefCounted
## The logical light for one minute (docs/BUILDING.md "Light"), 0 to 1 per tile, for sightlines and
## the crime director. By day everything outdoors is lit. At night the base is 0.1, or 0.2 under a
## bright moon on a clear night; a room's lamps are lit while somebody is awake in it, and light
## spills 3 m out through its windows (1.5 m through drawn curtains); verandah lamps light 4 m.
## The renderer lights the same rooms (HouseView.set_lit_rooms), so a tile that looks lit is 0.4+.

const NIGHT := 0.1
const MOON := 0.2
const ROOM_DAY := 0.7
const ROOM_LIT := 0.8
const ROOM_DARK := 0.05
const SPILL_M := 3.0
const CURTAIN_SPILL_M := 1.5
const FULL_MOON_DAY := 6     ## Sunday 8 June 1952 in the game's calendar (day 0 is Monday 2 June)
const LUNATION := 29.53
const LAMPS_BELOW := 4.0     ## sun elevation (degrees) under which lamps are lit

var night := false
var outdoor := 1.0
var lit_rooms: Dictionary = {}  ## room id -> true
var spill: Dictionary = {}      ## "x,y" -> light from windows and outdoor lamps (outdoor tiles)
var sight: SightMap

static var _sun: Array = []


## Sun elevation in degrees at a minute of the day, from data/time_of_day.json.
static func sun_elevation(minute: float) -> float:
	if _sun.is_empty():
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/time_of_day.json"))
		for k: Dictionary in d["keys"]:
			_sun.append([float(k["m"]), float(k["sun_el"])])
	for i in range(1, _sun.size()):
		var a: Array = _sun[i - 1]
		var b: Array = _sun[i]
		if minute <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (minute - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1.0))
	return float(_sun[_sun.size() - 1][1])


## Within four days of the full moon.
static func bright_moon(day: int) -> bool:
	var phase := fposmod(float(day - FULL_MOON_DAY), LUNATION)
	return phase < 4.0 or phase > LUNATION - 4.0


## The light for a minute. occupied: room ids with somebody awake in them.
static func compute(p_sight: SightMap, day: int, minute: int, raining: bool, occupied: Dictionary) -> LightGrid:
	var g := LightGrid.new()
	g.sight = p_sight
	var el := sun_elevation(minute)
	g.night = el < -2.0
	g.outdoor = 1.0 if not g.night else (MOON if bright_moon(day) and not raining else NIGHT)
	if el >= LAMPS_BELOW:
		return g
	# From dusk, lamps are lit in rooms where somebody's up.
	var ids := occupied.keys()
	ids.sort()
	for rid: String in ids:
		if not p_sight.rooms.has(rid) or int(p_sight.rooms[rid]["lamps"]) <= 0:
			continue
		g.lit_rooms[rid] = true
		if not g.night:
			continue
		for w: Dictionary in p_sight.rooms[rid]["windows"]:
			var reach := CURTAIN_SPILL_M if p_sight.curtains.has(str(w["edge"])) else SPILL_M
			g._glow(Vector2(w["out"]) + Vector2(0.5, 0.5), reach)
	if g.night:
		for l: Dictionary in p_sight.outdoor_lamps:
			g._glow(l["at"], float(l["radius"]))
	return g


## Light falling off from 0.7 at the source to 0.4 at the edge of its reach, on outdoor tiles.
func _glow(at: Vector2, reach: float) -> void:
	var r := ceili(reach)
	for y in range(floori(at.y) - r, floori(at.y) + r + 1):
		for x in range(floori(at.x) - r, floori(at.x) + r + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(at)
			if d > reach + 0.01:
				continue
			var key := "%d,%d" % [x, y]
			if sight.room_of.has(key):
				continue
			var v := snappedf(0.4 + 0.3 * (1.0 - d / maxf(reach, 0.01)), 0.01)
			if v > float(spill.get(key, 0.0)):
				spill[key] = v


func at(t: Vector2i) -> float:
	var rid := sight.room_at(t) if sight else ""
	if rid != "":
		if lit_rooms.has(rid):
			return ROOM_LIT
		return ROOM_DAY if not night else ROOM_DARK
	return maxf(outdoor, float(spill.get("%d,%d" % [t.x, t.y], 0.0)))
