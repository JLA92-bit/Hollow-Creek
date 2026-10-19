class_name CashTinNight
extends RefCounted
## The scripted week of Case 0 (docs/CASE_00_CASH_TIN.md "What really happened"), enacted in the
## simulation so the town genuinely lives it: Thursday's refusal of credit, Saturday's welcome dance
## in the mill shed, Davey slipping out to the creek, Len walking the creek track to the back of the
## store and in through the unlatched window, Agnes seeing a man in a hat from her lit kitchen, the
## Haywards coming home to an open window, and Agnes's trunk call. The case itself is the authored
## data/cases/case_00_cash_tin.json, whose trace positions are fitted to the store the player built.
##
## A plain class over a state dictionary {fired: {id: true}, store: house id, runner: {...}} that the
## host keeps and saves. Call step() once a minute before Sim.tick().

const THURSDAY := 3
const SATURDAY := 5
const CASE_PATH := "res://data/cases/case_00_cash_tin.json"
const DANCERS: Array[String] = ["r_frank", "r_edna", "r_june", "r_len", "r_marge", "r_davey", "r_tomasz", "r_halina", "r_piotr"]
const HAYWARDS: Array[String] = ["r_frank", "r_edna", "r_june"]

## (day, minute) -> event id, in the order they happen.
const TIMELINE: Array = [
	[3, 16 * 60 + 40, "refusal"],
	[5, 19 * 60 + 30, "dance"],
	[5, 20 * 60 + 5, "agnes_up"],
	[5, 20 * 60 + 30, "davey_out"],
	[5, 20 * 60 + 50, "len_out"],
	[5, 22 * 60, "davey_home"],
	[5, 22 * 60 + 30, "haywards_home"],
	[5, 22 * 60 + 35, "discovery"],
	[5, 22 * 60 + 40, "agnes_rings"],
]


static func new_state(store_house: String) -> Dictionary:
	return {"fired": {}, "store": store_house, "runner": {}, "discovered": false}


## One minute of the script. Returns "discovery" on the minute the Haywards find the window open.
static func step(sim: Sim, st: Dictionary) -> String:
	var result := ""
	var now := sim.day * 1440 + sim.minute
	for e: Array in TIMELINE:
		var id := str(e[2])
		if bool((st["fired"] as Dictionary).get(id, false)):
			continue
		if now >= int(e[0]) * 1440 + int(e[1]):
			st["fired"][id] = true
			# A save loaded long after an event shouldn't replay it.
			if now - (int(e[0]) * 1440 + int(e[1])) > 60:
				continue
			if _fire(sim, st, id) and id == "discovery":
				result = "discovery"
	var run: Dictionary = st["runner"]
	if not run.is_empty():
		PlanRunner.step(sim, run)
		if str(run["state"]) == "done" and not bool(st.get("len_home", false)):
			st["len_home"] = true
			_send(sim, "r_len", _mill(sim), "dance", maxi(10, 23 * 60 - sim.minute))
			_remember(sim, st)
	return result


static func _fire(sim: Sim, st: Dictionary, id: String) -> bool:
	match id:
		"refusal":
			sim.add_grievance("r_len", "r_frank", "refused more credit, in front of the whole shop", 70.0)
		"dance":
			for rid: String in DANCERS:
				if sim.residents.has(rid) and sim.residents[rid]["status"] == "living":
					_send(sim, rid, _mill(sim), "dance", 23 * 60 - sim.minute)
			sim.log_event("r_frank", "The exchange closed for the welcome dance.")
		"agnes_up":
			var home: Dictionary = sim.town.homes.get(sim.home_of("r_agnes"), {})
			if not home.is_empty():
				sim.direct("r_agnes", home["living"], sim.home_of("r_agnes"), "sit_up", 200)
		"davey_out":
			var e := _entry(sim, st)
			if not e.is_empty():
				var spot := sim.town.walkable_near(Vector2i(int((e["out"] as Array)[0]) + 3, int((e["out"] as Array)[1]) + 6))
				if not spot.is_empty():
					sim.direct("r_davey", spot, "", "smoke", 85)
		"len_out":
			var plan := _len_plan(sim, st)
			if not plan.is_empty():
				st["runner"] = PlanRunner.start(sim, plan, sim.ticks)
		"davey_home":
			var h := CrimePlan.outside_house(sim, sim.home_of("r_davey"))
			if not h.is_empty():
				sim.direct("r_davey", h, "", "potter", 5)
		"haywards_home":
			for rid: String in HAYWARDS:
				var home: Dictionary = sim.town.homes.get(sim.home_of(rid), {})
				if not home.is_empty():
					sim.direct(rid, home["living"], sim.home_of(rid), "potter", 120)
		"discovery":
			st["discovered"] = true
			return true
		"agnes_rings":
			sim.records["exchange"].append({"day": sim.day, "minute": sim.minute, "caller": "r_agnes", "from": "the Doyle residence",
				"to": "Ballarat 2214 (trunk call, 6 minutes)", "operator": "r_edna"})
	return true


static func _send(sim: Sim, rid: String, at: Array, kind: String, minutes: int) -> void:
	if not at.is_empty() and sim.residents.has(rid):
		sim.direct(rid, at, "", kind, maxi(5, minutes))


static func _mill(sim: Sim) -> Array:
	var t: Array = sim.town.landmark_tiles.get("lm_mill", [])
	return t.duplicate() if not t.is_empty() else []


## The way in: the unlatched window furthest towards the creek (the back of the store).
static func _entry(sim: Sim, st: Dictionary) -> Dictionary:
	var best := {}
	for e: Dictionary in CrimePlan.entries(sim, str(st["store"])):
		if best.is_empty() or int((e["out"] as Array)[1]) > int((best["out"] as Array)[1]):
			best = e
	return best


static func _len_plan(sim: Sim, st: Dictionary) -> Dictionary:
	var e := _entry(sim, st)
	var loot := CrimePlan.loot_for(sim, str(st["store"]))
	var hide := CrimePlan.outside_house(sim, sim.home_of("r_len"))
	var mill := _mill(sim)
	if e.is_empty() or loot.is_empty() or hide.is_empty() or mill.is_empty():
		return {}
	var out_p := [0, float((e["out"] as Array)[0]) + 0.5, float((e["out"] as Array)[1]) + 0.5]
	var in_p := [0, float((e["in"] as Array)[0]) + 0.5, float((e["in"] as Array)[1]) + 0.5]
	var lurk := sim.town.walkable_near(Vector2i(int((e["out"] as Array)[0]) + 2, int((e["out"] as Array)[1]) + 4))
	var legs: Array[Dictionary] = [
		{"do": "walk", "at": lurk if not lurk.is_empty() else out_p, "house": "", "minutes": 10},
		{"do": "walk", "at": out_p, "house": "", "minutes": 1},
		{"do": "climb", "at": in_p, "house": str(st["store"])},
		{"do": "walk", "at": loot["at"], "house": str(st["store"]), "minutes": 5, "take": loot["loot"]},
		{"do": "walk", "at": in_p, "house": str(st["store"]), "minutes": 0},
		{"do": "climb", "at": out_p, "house": ""},
		{"do": "walk", "at": hide, "house": "", "minutes": 6, "drop": true},
	]
	return {"id": "case_00", "crime": "theft", "culprit": "r_len", "target": "r_frank", "motive": "money", "house": str(st["store"]), "loot": str(loot["loot"]),
		"loot_place": str(loot["place"]), "loot_at": loot["at"], "entry": e, "start": 0, "legs": legs, "careless": false, "decoy": {}}


## Required beat: Agnes, in her lit kitchen, saw a man in a hat behind the store. If the simulation
## didn't give her that memory (the light or the angle was wrong), she has it anyway.
static func _remember(sim: Sim, st: Dictionary) -> void:
	var agnes: Dictionary = sim.residents["r_agnes"]
	for m: Dictionary in agnes["memories"]:
		if str(m.get("subject", "")) == "r_len":
			return
	var e := _entry(sim, st)
	if e.is_empty():
		return
	var t := Vector2i(int((e["out"] as Array)[0]), int((e["out"] as Array)[1]))
	Memories.add(sim, agnes, {"kind": "saw_person", "subject": "r_len", "tile": [t.x, t.y], "place": "behind the store",
		"detail": "a man in a hat, walking like Len", "confidence": 0.6, "keep": true})


## The authored case, with its scene traces fitted to the store as built.
static func case_for(sim: Sim, st: Dictionary) -> Dictionary:
	var c := Investigation.load_case(CASE_PATH)
	var e := _entry(sim, st)
	var loot := CrimePlan.loot_for(sim, str(st["store"]))
	if c.is_empty() or e.is_empty() or loot.is_empty():
		return c
	var origin: Vector2i = sim.town.origins.get(str(st["store"]), Vector2i.ZERO)
	var out_t := Vector2i(int((e["out"] as Array)[0]), int((e["out"] as Array)[1]))
	var in_t := Vector2i(int((e["in"] as Array)[0]), int((e["in"] as Array)[1]))
	var loot_t := Vector2i(floori(float((loot["at"] as Array)[1])), floori(float((loot["at"] as Array)[2])))
	var where := {
		"t_window": out_t, "t_tin": loot_t, "t_prints_in": in_t + (loot_t - in_t) / 2,
		"t_prints_out": out_t + Vector2i(0, 2), "t_mud_track": out_t + Vector2i(1, 7)}
	for t: Dictionary in c["traces"]:
		if where.has(str(t["id"])):
			var w: Vector2i = where[str(t["id"])]
			t["pos"] = [w.x - origin.x, w.y - origin.y]
	(c["scene"] as Dictionary)["house"] = str(st["store"])
	return c
