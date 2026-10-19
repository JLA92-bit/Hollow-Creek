extends Node
## Owns the live simulation (a plain Sim, scripts/sim/). Builds its town from the valley and the
## houses as they stand, keeps it in step with the Clock (one tick a game minute), and once a day
## tells it how every home is doing (scores and wishes), banking the rent and Town Trust it earns.

signal town_changed  ## somebody moved in, or the town was rebuilt
signal lights_changed(lit_rooms: Dictionary)  ## the rooms with lamps lit changed (room id -> true)
signal case_opened(inv: Investigation)  ## an incident alert: a case is open
signal case_closed(result: Dictionary)
signal prologue_progressed(done: Array)  ## ids of the prologue steps just completed

const COTTAGE_ID := "lm_agnes_cottage"
const PROLOGUE_CREWS := 8  ## builders during the prologue, so it plays in under an hour at 4x

var sim: Sim = Sim.new(1952)
var active := false
var tick_ms := 0.0  ## time the last batch of ticks took, for the debug panel
var director: Director = Director.new(0)  ## plans incidents (scripts/crime/director.gd)
var director_enabled := false             ## off until the prologue case is done (M9) or a test turns it on
var prologue: Prologue = null            ## the guided opening, or null (sandbox, demos, after it's done)
var night: Dictionary = {}               ## CashTinNight state: the scripted week of Case 0
var story_ctx: Dictionary = {}           ## what the prologue last saw: road, store, houses, families
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
	director = Director.new(GameState.seed_value)
	director.last_incident_day = 0   # no incident in the first week
	director_enabled = false
	prologue = null
	night = {}
	story_ctx = {}
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
	refresh_story()


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
		if director_enabled:
			director.before_tick(sim)
		if prologue != null and not night.is_empty() and investigation == null and CashTinNight.step(sim, night) == "discovery":
			_open_cash_tin()
		sim.tick()
		n += 1
	if director_enabled and investigation == null:
		var alert := director.take_alert()
		if not alert.is_empty():
			open_case_data(alert)
	if sim.day != day_before:
		review_homes()
	if prologue != null and (sim.minute % 15 == 0 or sim.day != day_before):
		refresh_story()
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
	var d := sim.snapshot()
	d["director"] = director.snapshot()
	d["director_enabled"] = director_enabled
	d["prologue"] = prologue.snapshot() if prologue != null else {}
	d["night"] = night.duplicate(true)
	d["cases_done"] = _closed_cases.duplicate()
	d["unlocked"] = unlocked.duplicate()
	return d


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	sim = Sim.new(int(data.get("seed", GameState.seed_value)))
	sim.restore(data)
	director = Director.new(int(data.get("seed", GameState.seed_value)))
	director.restore(data.get("director", {}))
	director_enabled = bool(data.get("director_enabled", false))
	var ps: Dictionary = data.get("prologue", {})
	prologue = null
	if not ps.is_empty():
		prologue = Prologue.new()
		prologue.restore(ps)
	night = (data.get("night", {}) as Dictionary).duplicate(true)
	_closed_cases.assign(data.get("cases_done", []))
	unlocked.assign(data.get("unlocked", []))


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


## An incident alert from the director: a generated case (already checked solvable) opens.
func open_case_data(data: Dictionary) -> Investigation:
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
		if bool(closed_case.data.get("generated", false)):
			director.apply_outcome(sim, closed_case.data, result)
		case_closed.emit(result)
		refresh_story()
	return t


func is_unlocked(feature: String) -> bool:
	return unlocked.has(feature)


func case_done(id: String) -> bool:
	return _closed_cases.has(id)


# --- The prologue ---------------------------------------------------------------------------------

## Starts the guided opening (a new story game). The director stays off until The Cash Tin is solved.
func begin_prologue() -> void:
	prologue = Prologue.new()
	GameState.crews = PROLOGUE_CREWS   # the Department sends a work gang to get the town started
	night = {}
	director_enabled = false


## What the player has built, as the prologue needs to know it, and the steps that follow from it.
## Cheap enough to call when the town changes and every quarter hour.
func refresh_story() -> void:
	if prologue == null or _world == null:
		return
	var slice: MapSlice = _world.get("slice")
	var cfg: Dictionary = prologue.data
	var road: Dictionary = cfg["road"]
	var plot := Rect2i()
	for l: Dictionary in slice.data["landmarks"]:
		if str(l["id"]) == str(cfg["store_plot"]):
			var r: Array = l["rect"]
			plot = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	var store_id := ""
	var store_check := {"door": false, "window": false, "exchange": false}
	var finished_houses := 0
	for hv: HouseView in _world.get("houses"):
		var id := hv.data.id
		if id == COTTAGE_ID or GameState.construction.has(id) or hv.shown.rooms(0).is_empty():
			continue
		if store_id == "" and StoryChecks.on_plot(hv.shown, plot):
			store_id = id
			store_check = StoryChecks.store(hv.shown, slice.grid, slice.creek_points)
		elif StoryChecks.has_bed(hv.shown):
			finished_houses += 1
	var housed := 0
	for hid: String in sim.households:
		if hid != "h_doyle" and str(sim.households[hid].get("home", "")) != "":
			housed += 1
	story_ctx = {"road": StoryChecks.road_done(slice.grid, road["points"], int(road["width"])) >= float(road["needed"]), "store": store_check,
		"houses": finished_houses, "families": housed, "day": sim.day, "minute": sim.minute, "case_open": investigation != null or case_done("case_00_cash_tin"),
		"case_done": case_done("case_00_cash_tin")}
	if store_id != "" and bool(store_check["door"]) and bool(store_check["window"]) and bool(store_check["exchange"]):
		if night.is_empty():
			night = CashTinNight.new_state(store_id)
			# The Haywards come to run the store.
			if str(sim.households["h_hayward"].get("home", "")) == "":
				offer_home("h_hayward", store_id)
		else:
			night["store"] = store_id
	if not night.is_empty() and int(night.get("anchor", -1)) >= 0:
		story_ctx["dance_at"] = int(night["anchor"]) * 1440 + CashTinNight.DANCE_FROM
	var done := prologue.update(story_ctx)
	if done.has("families") and not night.is_empty() and int(night.get("anchor", -1)) < 0:
		# The week starts now: the dance is on the first Saturday that leaves time to live it.
		night["anchor"] = CashTinNight.saturday_after(sim.day)
		story_ctx["dance_at"] = int(night["anchor"]) * 1440 + CashTinNight.DANCE_FROM
	if not done.is_empty():
		prologue_progressed.emit(done)
	if prologue.finished:
		GameState.crews = 2
		director_enabled = true
		director.last_incident_day = sim.day
		prologue = null


func _open_cash_tin() -> void:
	var c := CashTinNight.case_for(sim, night)
	if c.is_empty():
		return
	Clock.set_speed(0)
	open_case_data(c)
	refresh_story()
