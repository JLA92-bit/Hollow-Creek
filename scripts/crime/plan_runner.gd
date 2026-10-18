class_name PlanRunner
extends RefCounted
## Runs a CrimePlan inside the simulation (docs/CRIME_DIRECTOR.md "Simulating each plan"). The
## culprit's legs are fed to Sim.direct() one at a time, so everything that follows is real: prints
## on the ground, residents who happen to be awake and look out, noises, the incident marker. A plan
## may also send a decoy (somebody with a secret) out the same night. The same runner drives both the
## trial on a snapshot and the live night, so they match.
##
## State is a plain dictionary so a save in the middle of a night keeps it. It is the culprit's actor
## state, plus "decoy" (another actor state, or {}):
##   {plan, rid, legs, state: wait | go | done | failed, start_tick, leg, arrived, wait_until, carrying,
##    crime_tick, done_tick, why, decoy}

const TAIL_MINUTES := 30        ## keep running this long after the culprit is home, so witnesses and prints settle
const MAX_MINUTES := 240        ## a plan that hasn't finished by now has failed
const HOLD := 600               ## directed actions never end on their own; the runner moves on


static func start(_sim: Sim, plan: Dictionary, begin_tick: int) -> Dictionary:
	var st := _actor(str(plan["culprit"]), plan["legs"], begin_tick + int(plan["start"]))
	st["plan"] = plan
	var dec: Dictionary = plan.get("decoy", {})
	st["decoy"] = _actor(str(dec["rid"]), dec["legs"], begin_tick + int(dec["start"])) if not dec.is_empty() else {}
	return st


static func _actor(rid: String, legs: Array, start_tick: int) -> Dictionary:
	return {"rid": rid, "legs": legs, "state": "wait", "start_tick": start_tick, "leg": -1, "arrived": false, "wait_until": 0,
		"carrying": "", "crime_tick": -1, "done_tick": -1, "why": ""}


static func finished(st: Dictionary, sim: Sim) -> bool:
	var main_done: bool = str(st["state"]) == "failed" or (str(st["state"]) == "done" and sim.ticks >= int(st["done_tick"]) + TAIL_MINUTES)
	var dec: Dictionary = st["decoy"]
	var dec_done: bool = dec.is_empty() or str(dec["state"]) in ["done", "failed"]
	return main_done and dec_done


## Called once a minute, before Sim.tick().
static func step(sim: Sim, st: Dictionary) -> void:
	_step_actor(sim, st, st["plan"], true)
	if not (st["decoy"] as Dictionary).is_empty():
		_step_actor(sim, st["decoy"], st["plan"], false)


## Run the whole plan on a sim from its current tick (used on a snapshot). Returns the final state.
static func run(sim: Sim, plan: Dictionary) -> Dictionary:
	var st := start(sim, plan, sim.ticks)
	while not finished(st, sim) and sim.ticks - int(st["start_tick"]) < MAX_MINUTES + 120:
		step(sim, st)
		sim.tick()
	return st


static func _step_actor(sim: Sim, a: Dictionary, plan: Dictionary, is_main: bool) -> void:
	var r: Dictionary = sim.residents[str(a["rid"])]
	match str(a["state"]):
		"wait":
			if sim.ticks >= int(a["start_tick"]):
				a["state"] = "go"
				_issue(sim, a, r, 0)
		"go":
			if sim.ticks - int(a["start_tick"]) > MAX_MINUTES:
				_fail(a, "took too long")
				return
			if not (r["route"] as Array).is_empty():
				return
			var legs: Array = a["legs"]
			var leg: Dictionary = legs[int(a["leg"])]
			if not bool(a["arrived"]):
				if not _near(r, leg["at"]):
					_fail(a, "no way there")
					return
				a["arrived"] = true
				a["wait_until"] = sim.ticks + int(leg.get("minutes", 0))
				_arrive(sim, a, r, leg, plan, is_main)
			if sim.ticks < int(a["wait_until"]):
				return
			if int(a["leg"]) + 1 >= legs.size():
				a["state"] = "done"
				a["done_tick"] = sim.ticks
				r["action"] = {"kind": "idle"}
				r["carrying"] = ""
				return
			_issue(sim, a, r, int(a["leg"]) + 1)


static func _issue(sim: Sim, a: Dictionary, r: Dictionary, i: int) -> void:
	var legs: Array = a["legs"]
	a["leg"] = i
	a["arrived"] = false
	var leg: Dictionary = legs[i]
	if str(leg["do"]) == "climb":
		r["pos"] = (leg["at"] as Array).duplicate()
		r["house"] = str(leg["house"])
		r["route"] = []
		r["action"] = {"kind": "sneak", "place": "", "minutes": HOLD, "hold": true, "until": sim.ticks + HOLD}
		return
	sim.direct(str(r["id"]), leg["at"], str(leg["house"]), "sneak", HOLD, str(a["carrying"]))


## What happens on arrival: taking the loot (and perhaps being careless), hiding it.
static func _arrive(sim: Sim, a: Dictionary, r: Dictionary, leg: Dictionary, plan: Dictionary, is_main: bool) -> void:
	if not is_main:
		return
	if leg.has("take"):
		a["carrying"] = str(leg["take"])
		r["carrying"] = a["carrying"]
		a["crime_tick"] = sim.ticks
		var t := Memories.tile_of(r)
		sim.add_incident("crime:%s" % str(plan["id"]), t, 8, "the theft")
		if bool(plan.get("careless", false)):
			var items: Array = (sim.data["residents"] as Dictionary)[str(r["id"])].get("items", [])
			if not items.is_empty():
				sim.dropped.append({"item": str(items[0]), "owner": str(r["id"]), "tile": [t.x, t.y], "day": sim.day, "minute": sim.minute, "tick": sim.ticks})
			Memories.noise(sim, t, "something knocked over in the %s" % str(plan.get("loot_place", "store")).trim_prefix("the "))
	if bool(leg.get("drop", false)):
		a["carrying"] = ""
		r["carrying"] = ""


static func _near(r: Dictionary, at: Array) -> bool:
	var p: Array = r["pos"]
	return Vector2(float(p[1]), float(p[2])).distance_to(Vector2(float(at[1]), float(at[2]))) < 2.0


static func _fail(a: Dictionary, why: String) -> void:
	a["state"] = "failed"
	a["why"] = why
