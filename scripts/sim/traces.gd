class_name Traces
extends RefCounted
## Bootprints (docs/BUILDING.md "Ground and traces"). As residents walk, each tile they cross may
## take a print of their boot size and sole, depending on the ground and whether it's wet: mud
## always, dirt clearly when wet and faintly when dry, grass faintly when wet (every other step),
## gravel, roads and paths never. Floors take muddy prints from anyone who came through mud in the
## last 30 m. Prints fade after 2 days or 6 hours of rain. Deterministic: no random numbers, a hash
## of who, where and when decides the faint steps.

const MAX_PER_TILE := 6
const FADE_TICKS := 2 * 1440
const RAIN_WASH := 6 * 60
const MUD_CARRY_M := 30
const WET_AFTER_RAIN := 6 * 60   ## ground stays wet this long after the rain stops
const DIRS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


## The stretch of route walked this minute, a metre at a time.
static func walk(sim: Sim, r: Dictionary, from_m: float, to_m: float) -> void:
	var route: Array = r["route"]
	var last := str(r.get("last_tile", ""))
	var d := maxf(0.0, from_m)
	while d <= to_m:
		var p := SimTown.along(route, d)
		if int(p[0]) == 0:
			var t := Vector2i(floori(float(p[1])), floori(float(p[2])))
			var key := "%d,%d" % [t.x, t.y]
			if key != last:
				var ahead := SimTown.along(route, d + 1.0)
				_step_on(sim, r, t, key, Vector2(float(ahead[1]) - float(p[1]), float(ahead[2]) - float(p[2])))
				last = key
		d += 1.0
	r["last_tile"] = last


static func ground_wet(sim: Sim) -> bool:
	return sim.raining or sim.ticks - sim.last_rain_tick < WET_AFTER_RAIN


static func _step_on(sim: Sim, r: Dictionary, t: Vector2i, key: String, heading: Vector2) -> void:
	var mud := int(r.get("mud_m", 99))
	if sim.town.sight.room_at(t) != "":
		if mud < MUD_CARRY_M:
			_print(sim, r, key, "clear", true, heading)
		r["mud_m"] = mini(mud + 1, 99)
		return
	var grid := sim.town.grid
	if grid == null or not grid.in_bounds(t.x, t.y):
		return
	var g := grid.get_ground(t.x, t.y)
	r["mud_m"] = 0 if g == Ground.Type.MUD else mini(mud + 1, 99)
	var clarity := Ground.print_clarity(g, ground_wet(sim) or grid.get_wet(t.x, t.y) > 0.5)
	if clarity <= 0.0:
		return
	if clarity < 1.0 and (hash("%s|%s|%d" % [r["id"], key, sim.ticks]) & 1) == 1:
		return
	_print(sim, r, key, "clear" if clarity >= 1.0 else "faint", false, heading)


static func _print(sim: Sim, r: Dictionary, key: String, clarity: String, muddy: bool, heading: Vector2) -> void:
	var boot: Dictionary = (sim.data["residents"] as Dictionary).get(r["id"], {}).get("boot", {})
	var dir := ""
	if heading.length() > 0.01:
		dir = DIRS[posmod(roundi(atan2(heading.x, -heading.y) / (PI / 4.0)), 8)]
	if not sim.traces.has(key):
		sim.traces[key] = []
	var list: Array = sim.traces[key]
	list.append({"who": r["id"], "size": str(boot.get("size", "?")), "sole": str(boot.get("sole", "?")), "day": sim.day, "minute": sim.minute,
		"tick": sim.ticks, "rain_at": sim.rain_minutes, "clarity": clarity, "muddy": muddy, "heading": dir})
	if list.size() > MAX_PER_TILE:
		list.remove_at(0)


## Hourly: prints older than 2 days, or rained on for 6 hours, are gone.
static func fade(sim: Sim) -> void:
	var keys := sim.traces.keys()
	for key: String in keys:
		var keep: Array = []
		for p: Dictionary in sim.traces[key]:
			if sim.ticks - int(p["tick"]) < FADE_TICKS and sim.rain_minutes - int(p["rain_at"]) < RAIN_WASH:
				keep.append(p)
		if keep.is_empty():
			sim.traces.erase(key)
		else:
			sim.traces[key] = keep


## Prints at a tile, newest last, as an investigator would read them (no names).
static func read(sim: Sim, t: Vector2i) -> Array:
	var out: Array = []
	for p: Dictionary in sim.traces.get("%d,%d" % [t.x, t.y], []):
		out.append({"size": p["size"], "sole": p["sole"], "clarity": p["clarity"], "muddy": p["muddy"], "heading": p["heading"], "day": p["day"], "minute": p["minute"]})
	return out
