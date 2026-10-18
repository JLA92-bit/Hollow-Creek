extends Node
## Owns the live simulation (a plain Sim, scripts/sim/). Builds its town from the valley and the
## houses as they stand, keeps it in step with the Clock (one tick a game minute), and once a day
## tells it how every home is doing (scores and wishes), banking the rent and Town Trust it earns.

signal town_changed  ## somebody moved in, or the town was rebuilt
signal lights_changed(lit_rooms: Dictionary)  ## the rooms with lamps lit changed (room id -> true)
signal case_opened(inv: Investigation)  ## an incident alert: a case is open
signal case_closed(result: Dictionary)

const COTTAGE_ID := "lm_agnes_cottage"

var sim: Sim = Sim.new(1952)
var active := false
var tick_ms := 0.0  ## time the last batch of ticks took, for the debug panel
var investigation: Investigation = null  ## the open case, if any
var unlocked: Array[String] = []         ## things closed cases have unlocked (footpaths, street_lamps)
var _world: Node3D = null
var _lit_sig := ""
var _closed_cases: Array[String] = []


func _ready() -> void:
	EventBus.time_changed.connect(_on_time_changed)


## A fresh town for a new game.
func reset() -> void:
	sim = Sim.new(GameState.seed_value)
	active = false
	_world = null
	investigation = null
	unlocked.clear()
	_closed_cases.clear()


## Starts (or picks up, after loading) the town's life in this valley.
func start(world: Node3D) -> void:
	_world = world
	var town := _build_town()
	if sim.residents.is_empty():
		sim = Sim.new(GameState.seed_value)
		sim.setup(town, Sim.load_data(), {"h_doyle": COTTAGE_ID}, Clock.day, Clock.minute)
	else:
		sim.town = town
		sim.data = Sim.load_data()
	active = true
	_lit_sig = "?"
	review_homes()
	town_changed.emit()
	_check_lights()


func stop() -> void:
	active = false
	_world = null


## Rebuilds the walk graph and places after houses change (a house finished, a family moved in).
func rebuild_town() -> void:
	if not active:
		return
	sim.town = _build_town()
	town_changed.emit()


func _build_town() -> SimTown:
	var slice: MapSlice = _world.get("slice")
	var hs: Array = []
	for hv: HouseView in _world.get("houses"):
		var h := hv.shown
		if h.origin != hv.data.origin:
			h.origin = hv.data.origin
		hs.append(h)
	return SimTown.build(slice.grid, hs, slice.data["landmarks"], slice.creek_points)


func _on_time_changed(_day: int, _minute: int) -> void:
	if not active or sim.town == null:
		return
	var t0 := Time.get_ticks_usec()
	var rain: Node = _world.get("rain") if _world else null
	sim.raining = rain != null and float(rain.get("intensity")) > 0.3
	var target := Clock.day * 1440 + Clock.minute
	var n := 0
	var day_before := sim.day
	while sim.day * 1440 + sim.minute < target and n < 1440:
		sim.tick()
		n += 1
	if sim.day != day_before:
		review_homes()
	_check_lights()
	tick_ms = (Time.get_ticks_usec() - t0) / 1000.0


## Tells the world when the set of lit rooms changes, so the lamps drawn match the light grid.
func _check_lights() -> void:
	var lit := sim.light_now().lit_rooms if sim.town else {}
	var keys := lit.keys()
	keys.sort()
	var sig := ",".join(PackedStringArray(keys))
	if sig != _lit_sig:
		_lit_sig = sig
		lights_changed.emit(lit)


func lit_rooms() -> Dictionary:
	return sim.light_now().lit_rooms if active and sim.town else {}


# --- Homes ---------------------------------------------------------------------------------------

## The house as it stands now (the drawn one while it's being built), or null.
func house(id: String) -> HouseData:
	if _world == null:
		return null
	for hv: HouseView in _world.get("houses"):
		if hv.data.id == id:
			return hv.shown
	return null


func house_name(id: String) -> String:
	var h := house(id)
	if h == null:
		return id
	return h.name if h.name != "" else "Agnes Doyle's cottage" if id == COTTAGE_ID else id


## Which household lives in a house, or "".
func household_in(house_id: String) -> String:
	for hid: String in sim.households:
		if str(sim.households[hid].get("home", "")) == house_id:
			return hid
	return ""


## Finished houses with rooms and nobody living in them: where a family could go.
func vacant_houses() -> Array[String]:
	var out: Array[String] = []
	var ids := GameState.houses.keys()
	ids.sort()
	for id: String in ids:
		if GameState.construction.has(id) or household_in(id) != "":
			continue
		var h := house(id)
		if h != null and not h.rooms(0).is_empty():
			out.append(id)
	return out


## Households waiting for a home, in order.
func waiting() -> Array[String]:
	var out: Array[String] = []
	var ids := sim.households.keys()
	ids.sort()
	for hid: String in ids:
		if str(sim.households[hid].get("home", "")) == "":
			out.append(hid)
	return out


## What a household would make of a house, before they're offered it.
func preview_reaction(hid: String, house_id: String) -> Dictionary:
	var h := house(house_id)
	if h == null:
		return {}
	var brief: Dictionary = (sim.data["households"][hid] as Dictionary).get("brief", {})
	return HomeLife.reaction(brief, h, sim.members(hid).size())


## Moves a household into a house; returns their reaction.
func offer_home(hid: String, house_id: String) -> Dictionary:
	var reaction := preview_reaction(hid, house_id)
	if reaction.is_empty():
		return {}
	rebuild_town()
	sim.move_household(hid, house_id, reaction)
	var fam := "The %ss" % str(sim.households[hid]["name"])
	HomeLife.record(GameState.history, house_id, Clock.day, "%s moved in. %s" % [fam, str(HomeLife.VERDICTS[reaction["verdict"]]["say"])])
	review_homes()
	town_changed.emit()
	return reaction


## Scores and wishes for every lived-in home, then the rent and Town Trust banked.
func review_homes() -> void:
	if _world == null:
		return
	var by_id := {}
	for w: Dictionary in sim.data.get("wishes", []):
		by_id[str(w["id"])] = w
	var report := {}
	for hid: String in sim.households:
		var home := str(sim.households[hid].get("home", ""))
		var h := house(home)
		if home == "" or h == null:
			continue
		var met: Array = []
		for wid: String in sim.wishes:
			if str(sim.wishes[wid]["household"]) == hid and by_id.has(wid) and HomeLife.wish_met(by_id[wid], h):
				met.append(wid)
		met.sort()
		report[home] = {"score": HomeLife.average(HomeScores.compute(h, maxi(1, sim.members(hid).size()))), "wishes_met": met}
	sim.review_homes(report)
	if sim.collected != 0 and not GameState.is_sandbox():
		GameState.money += sim.collected
	sim.collected = 0
	if sim.trust_change != 0:
		GameState.town_trust = clampi(GameState.town_trust + sim.trust_change, 0, 100)
	sim.trust_change = 0


func living_count() -> int:
	var n := 0
	for rid: String in sim.residents:
		if sim.residents[rid]["status"] == "living":
			n += 1
	return n


func snapshot() -> Dictionary:
	return sim.snapshot()


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	sim = Sim.new(int(data.get("seed", GameState.seed_value)))
	sim.restore(data)


# --- Cases -----------------------------------------------------------------------------------------

## An incident alert. Time pauses on the first alert (docs/GAME_DESIGN.md "Investigation").
func open_case(path: String) -> Investigation:
	var data := Investigation.load_case(path)
	if data.is_empty():
		return null
	investigation = Investigation.new(data)
	Clock.set_speed(0)
	case_opened.emit(investigation)
	return investigation


## Banks the Town Trust the case has earned or lost since the last call, and unlocks what it opened.
func bank_case() -> int:
	if investigation == null:
		return 0
	var t := investigation.take_trust()
	GameState.town_trust = clampi(GameState.town_trust + t, 0, 100)
	for u: String in investigation.unlocked:
		if not unlocked.has(u):
			unlocked.append(u)
	if investigation.closed():
		var result := {"accused": investigation.accused, "resolution": investigation.resolution, "unlocked": investigation.unlocked.duplicate()}
		var closed_case := investigation
		investigation = null
		_closed_cases.append(str(closed_case.data.get("id", "")))
		case_closed.emit(result)
	return t


func is_unlocked(feature: String) -> bool:
	return unlocked.has(feature)


func case_done(id: String) -> bool:
	return _closed_cases.has(id)
