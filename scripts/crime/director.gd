class_name Director
extends RefCounted
## The crime director (docs/CRIME_DIRECTOR.md): turns tension in the simulation into incidents that
## are real, fair and interesting. A plain class: the host calls it from the clock.
##
##   morning(sim)    06:00  decides whether something is brewing (budget, motives over the line)
##   nightfall(sim)  21:00  re-plans with tonight's town: tries up to 12 plans on snapshots, keeps the
##                          best solvable one and starts it for real (or lets the night pass quietly)
##   before_tick(sim) every minute, before Sim.tick(): feeds the culprit's legs to the live sim
##   after the run, the case is built from what really happened and waits for the victim to find out
##
## Never ships an unsolvable case: every candidate case is played by the solver bot first.

const SOLVABLE_PLANS := 12
const SECOND_ROUND := 12
const MORNING := 6 * 60
const NIGHTFALL := 21 * 60
const DISCOVERY := 6 * 60 + 30
const RELIEF := 10.0          ## pressure taken off a culprit when no plan could be made fair

var last_incident_day: int = -100
var gap_days: int = 7                    ## drama budget: days to wait after an incident (7 to 10)
var brewing: Array[Dictionary] = []      ## candidates found this morning
var authored: Dictionary = {}            ## {day, culprit, target, motive, crime, fix: {start, careless}} for a scripted case
var run: Dictionary = {}                 ## the live runner state, {} when nothing is under way
var pending_case: Dictionary = {}        ## the case built from the live run, waiting for discovery
var open_case: Dictionary = {}           ## the case the player is working on
var returns: Dictionary = {}             ## resident id -> day they come back from court
var relief: Dictionary = {}              ## culprit id -> pressure taken off
var history: Array[Dictionary] = []      ## incidents shipped: {day, culprit, target, plan, facts, herrings}
var followed: Array[String] = []         ## residents the player has followed recently (drama)
var stats := {"planning_days": 0, "plans_tried": 0, "plans_unsolvable": 0, "shipped": 0, "cancelled": 0, "ms": 0.0, "night_ms": 0.0,
	"facts": 0, "with_herring": 0, "morning_ms": 0.0, "morning_n": 0}
var rng: SimRng
var last_plan: Dictionary = {}


func _init(p_seed: int = 0) -> void:
	rng = SimRng.new(p_seed * 977 + 5)


# --- The day ---------------------------------------------------------------------------------------

## Call every in-game minute, before Sim.tick().
func before_tick(sim: Sim) -> void:
	if not run.is_empty():
		PlanRunner.step(sim, run)
		if PlanRunner.finished(run, sim):
			_run_finished(sim)
	if not pending_case.is_empty() and open_case.is_empty():
		var victim := str(pending_case["victim"])
		if sim.minute >= DISCOVERY and sim.minute < NIGHTFALL and Memories.state(sim.residents[victim])["awake"]:
			open_case = pending_case
			pending_case = {}
	if sim.minute == MORNING:
		morning(sim)
	elif sim.minute == NIGHTFALL:
		nightfall(sim)


## Pops the case waiting to be opened (the alert), or {}.
func take_alert() -> Dictionary:
	if open_case.is_empty() or bool(open_case.get("_alerted", false)):
		return {}
	open_case["_alerted"] = true
	return open_case


func morning(sim: Sim) -> void:
	var t0 := Time.get_ticks_usec()
	for rid: String in returns.keys():
		if sim.day >= int(returns[rid]):
			returns.erase(rid)
			sim.move_in(rid)
	brewing.clear()
	if run.is_empty() and pending_case.is_empty() and open_case.is_empty() and _budget_allows(sim):
		for cand: Dictionary in Motives.candidates(sim, "theft", "minor"):
			if float(cand["pressure"]) - float(relief.get(str(cand["culprit"]), 0.0)) >= float((Motives.config()["thresholds"] as Dictionary)["minor"]):
				brewing.append(cand)
		if not authored.is_empty() and int(authored["day"]) == sim.day:
			brewing = [authored.duplicate()]
	stats["morning_ms"] = float(stats["morning_ms"]) + float(Time.get_ticks_usec() - t0) / 1000.0
	stats["morning_n"] = int(stats["morning_n"]) + 1


func _budget_allows(sim: Sim) -> bool:
	return sim.day - last_incident_day >= gap_days


## Re-plan at the start of the night with the town as it is now, and start the best plan.
func nightfall(sim: Sim) -> void:
	if brewing.is_empty() or not run.is_empty() or not open_case.is_empty() or not pending_case.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	stats["planning_days"] = int(stats["planning_days"]) + 1
	var best := _best_plan(sim, brewing)
	stats["night_ms"] = float(stats["night_ms"]) + float(Time.get_ticks_usec() - t0) / 1000.0
	if best.is_empty():
		stats["cancelled"] = int(stats["cancelled"]) + 1
		for cand: Dictionary in brewing.slice(0, 1):
			relief[str(cand["culprit"])] = float(relief.get(str(cand["culprit"]), 0.0)) + RELIEF
		brewing.clear()
		return
	last_plan = best["plan"]
	run = PlanRunner.start(sim, best["plan"], sim.ticks)
	last_incident_day = sim.day
	gap_days = int(Motives.config()["drama"]["min_gap_days"]) + rng.randi_range(0, int(Motives.config()["drama"]["max_gap_days"]) - int(Motives.config()["drama"]["min_gap_days"]))
	history.append({"day": sim.day, "culprit": str(best["plan"]["culprit"]), "target": str(best["plan"]["target"]), "plan": str(best["plan"]["id"]),
		"facts": int(best["analysis"]["facts"]), "herrings": (best["analysis"]["herrings"] as Dictionary).size()})
	brewing.clear()


## Try plans on snapshots, keep solvable ones, pick the best. {} if none can be made fair.
func _best_plan(sim: Sim, cands: Array[Dictionary]) -> Dictionary:
	var best := {}
	for round_i in 2:
		var plans: Array[Dictionary] = []
		for cand: Dictionary in cands.slice(0, 3):
			plans.append_array(CrimePlan.generate(sim, cand, (SOLVABLE_PLANS if round_i == 0 else SECOND_ROUND) / mini(3, cands.size()), round_i))
		if not authored.is_empty() and authored.has("fix"):
			plans = plans.filter(func(p: Dictionary) -> bool: return _fits(p, authored["fix"]))
		for tried: Dictionary in _try(sim, plans):
			stats["plans_tried"] = int(stats["plans_tried"]) + 1
			if not bool((tried["analysis"] as Dictionary)["solvable"]):
				stats["plans_unsolvable"] = int(stats["plans_unsolvable"]) + 1
				continue
			tried["score"] = _score(tried)
			if best.is_empty() or float(tried["score"]) > float(best["score"]):
				best = tried
		if not best.is_empty():
			break
	return best


static func _fits(plan: Dictionary, fix: Dictionary) -> bool:
	for k: String in fix:
		if plan.get(k) != fix[k]:
			return false
	return true


## Run each plan on a snapshot, sharing the quiet hours before it starts, and build and analyse its case.
func _try(sim: Sim, plans: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if plans.is_empty():
		return out
	var live := sim.snapshot()
	var night_tick := sim.ticks
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["start"]) < int(b["start"]) if int(a["start"]) != int(b["start"]) else str(a["id"]) < str(b["id"]))
	var prefix_at := -1
	var prefix: Dictionary = {}
	for plan: Dictionary in plans:
		var want := int(plan["start"]) - 25
		if want != prefix_at:
			# Advance the shared prefix (everyone just living the night) to just before this plan begins.
			if prefix_at < 0:
				sim.restore(live)
			else:
				sim.restore(prefix)
			var from := 0 if prefix_at < 0 else prefix_at
			sim.run_ticks(maxi(0, want - from))
			prefix = sim.snapshot()
			prefix_at = want
		else:
			sim.restore(prefix)
		var st := PlanRunner.run(sim, plan, night_tick)
		if str(st["state"]) != "done":
			continue
		var case_data := CaseBuilder.build(sim, plan, st)
		out.append({"plan": plan, "case": case_data, "analysis": Solvability.analyse(case_data)})
	sim.restore(live)
	return out


## Interest (red herrings), variety, drama; a little for more facts. Higher is better.
func _score(t: Dictionary) -> float:
	var plan: Dictionary = t["plan"]
	var a: Dictionary = t["analysis"]
	var score := 0.0
	for pid: String in a["herrings"]:
		score += 2.0 if int(a["herrings"][pid]) == 2 else 3.0
	score += 1.0 if bool(a["interesting"]) else 0.0
	var recent := history.slice(maxi(0, history.size() - 3))
	var same := false
	for h: Dictionary in recent:
		same = same or (str(h["culprit"]) == str(plan["culprit"]) and str(h["target"]) == str(plan["target"]))
	score += 0.0 if same else 1.0
	if followed.has(str(plan["culprit"])) or followed.has(str(plan["target"])):
		score += 1.0
	score += minf(float(a["facts"]), 12.0) * 0.05
	return score


func _run_finished(sim: Sim) -> void:
	var st := run
	run = {}
	if str(st["state"]) != "done":
		stats["cancelled"] = int(stats["cancelled"]) + 1
		return
	var plan: Dictionary = st["plan"]
	var case_data := CaseBuilder.build(sim, plan, st)
	var analysis := Solvability.analyse(case_data)
	if not bool(analysis["solvable"]):
		# The town changed under the plan (a lamp, a latch): don't ship an unfair case.
		stats["cancelled"] = int(stats["cancelled"]) + 1
		return
	stats["shipped"] = int(stats["shipped"]) + 1
	stats["facts"] = int(stats["facts"]) + int(analysis["facts"])
	if bool(analysis["interesting"]):
		stats["with_herring"] = int(stats["with_herring"]) + 1
	case_data["analysis"] = {"facts": analysis["facts"], "herrings": analysis["herrings"]}
	pending_case = case_data


# --- Consequences ---------------------------------------------------------------------------------

## After the accusation (docs/CRIME_DIRECTOR.md "Consequences"). `result` is {accused, outcome, resolution}.
func apply_outcome(sim: Sim, case_data: Dictionary, result: Dictionary) -> void:
	var culprit := str(case_data.get("culprit", ""))
	var accused := str(result.get("accused", ""))
	var right := accused == culprit
	var res := str(result.get("resolution", ""))
	if right and res == "charge":
		var weeks := int((Motives.config()["theft"] as Dictionary).get("charge_weeks", 4))
		sim.residents[culprit]["status"] = "away"
		returns[culprit] = sim.day + weeks * 7
		for rid: String in sim.members(str(sim.residents[culprit]["household"])):
			if rid != culprit:
				sim.add_grievance(rid, Sim.PLAYER, "took %s away" % sim.residents[culprit]["first"], 25.0)
	elif right and res == "restitution":
		for g: Dictionary in sim.grievances:
			if str(g["owner"]) == culprit and str(g["target"]) == str(case_data.get("victim", "")):
				g["weight"] = 0.0
		sim.add_grievance(str(case_data.get("victim", "")), Sim.PLAYER, "went easy on a thief", 30.0)
	elif not right and accused != "":
		sim.add_grievance(accused, Sim.PLAYER, "falsely accused", 60.0)
		relief[culprit] = float(relief.get(culprit, 0.0)) + 30.0   # the real culprit's pressure eases
	# The town latches its windows for a fortnight.
	sim.latch_until_day = sim.day + 14
	open_case = {}


# --- Save -------------------------------------------------------------------------------------------

func snapshot() -> Dictionary:
	return {"last_incident_day": last_incident_day, "gap_days": gap_days, "brewing": brewing.duplicate(true), "authored": authored.duplicate(true),
		"run": run.duplicate(true), "pending_case": pending_case.duplicate(true), "open_case": open_case.duplicate(true), "returns": returns.duplicate(),
		"relief": relief.duplicate(), "history": history.duplicate(true), "followed": followed.duplicate(), "stats": stats.duplicate(), "rng": rng.snapshot()}


func restore(d: Dictionary) -> void:
	last_incident_day = int(d.get("last_incident_day", -100))
	gap_days = int(d.get("gap_days", 7))
	brewing.assign(d.get("brewing", []))
	authored = (d.get("authored", {}) as Dictionary).duplicate(true)
	run = (d.get("run", {}) as Dictionary).duplicate(true)
	pending_case = (d.get("pending_case", {}) as Dictionary).duplicate(true)
	open_case = (d.get("open_case", {}) as Dictionary).duplicate(true)
	returns = (d.get("returns", {}) as Dictionary).duplicate()
	relief = (d.get("relief", {}) as Dictionary).duplicate()
	history.assign(d.get("history", []))
	followed.assign(d.get("followed", []))
	stats = (d.get("stats", stats) as Dictionary).duplicate()
	rng.restore(d.get("rng", {}))
