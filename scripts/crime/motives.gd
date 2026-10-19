class_name Motives
extends RefCounted
## Step 1 of the crime director (docs/CRIME_DIRECTOR.md "Finding motives"): how much pressure each
## resident is under towards each kind of crime, and which of those are over the line.
## A candidate is {culprit, target, motive, crime, pressure}. Plain and deterministic.

const DEBT_BASE := 30.0
const DEBT_PER_RISK := 2.0
const MONEY_LOW := 20.0
const MONEY_PER_POUND := 3.0


static func config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/crime_types.json")) as Dictionary


## Money worry, 0 to 100: debts they're hiding, and a household that's running short.
static func money_worry(sim: Sim, rid: String) -> float:
	var w := 0.0
	for sid: String in sim.secrets:
		var s: Dictionary = sim.secrets[sid]
		if str(s["owner"]) == rid and str(s["kind"]) == "debt":
			w += DEBT_BASE + DEBT_PER_RISK * float(s["exposure_risk"])
	var h: Dictionary = sim.households.get(str(sim.residents[rid]["household"]), {})
	if h.has("money"):
		w += maxf(0.0, MONEY_LOW - float(h["money"])) * MONEY_PER_POUND
	return clampf(w * (2.0 if sim.has_trait(rid, "greedy") else 1.0), 0.0, 100.0)


## Grievance pressure towards one target.
static func grievance(sim: Sim, rid: String, target: String) -> float:
	var w := 0.0
	for g: Dictionary in sim.grievances:
		if str(g["owner"]) == rid and str(g["target"]) == target:
			w += float(g["weight"])
	if sim.has_trait(rid, "hot_headed"):
		w *= 1.5
	if sim.has_trait(rid, "proud"):
		w *= 1.3
	return clampf(w, 0.0, 100.0)


## Secrets that could come out, as pressure to cover them up.
static func cover_up(sim: Sim, rid: String) -> float:
	var w := 0.0
	for sid: String in sim.secrets:
		var s: Dictionary = sim.secrets[sid]
		if str(s["owner"]) == rid:
			w = maxf(w, float(s["exposure_risk"]))
	return clampf(w * (1.3 if sim.has_trait(rid, "secretive") else 1.0), 0.0, 100.0)


## How much a well-lit, watched street takes off the pressure to rob somebody (docs/GAME_DESIGN.md
## "Prevention is part of play"): 6 for each lamp within 12 m of their home, up to 24.
static func safety(sim: Sim, target: String) -> float:
	var home := sim.home_of(target)
	if home == "" or sim.town == null or sim.town.sight == null:
		return 0.0
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for rid: String in sim.town.sight.rooms:
		var room: Dictionary = sim.town.sight.rooms[rid]
		if str(room["house"]) != home:
			continue
		for t: Vector2i in room["tiles"]:
			lo = Vector2(minf(lo.x, t.x), minf(lo.y, t.y))
			hi = Vector2(maxf(hi.x, t.x), maxf(hi.y, t.y))
	if hi.x < lo.x:
		return 0.0
	var centre := (lo + hi) * 0.5
	var n := 0
	for l: Dictionary in sim.town.sight.outdoor_lamps:
		if bool(l.get("street", false)) and (l["at"] as Vector2).distance_to(centre) <= 12.0:
			n += 1
	return minf(24.0, 6.0 * float(n))


## Everyone's candidates for a crime type, strongest first. `minor` or `major` picks the threshold.
## Honest residents only commit crimes at pressure 90 or more.
static func candidates(sim: Sim, crime: String, severity: String = "minor") -> Array[Dictionary]:
	var cfg := config()
	var threshold := float(cfg["thresholds"][severity])
	var out: Array[Dictionary] = []
	var ids := sim.residents.keys()
	ids.sort()
	var living: Array[String] = []
	for rid: String in ids:
		if sim.residents[rid]["status"] == "living":
			living.append(rid)
	for rid: String in living:
		var money := money_worry(sim, rid)
		var cover := cover_up(sim, rid)
		for target: String in living:
			if target == rid or str(sim.residents[target]["household"]) == str(sim.residents[rid]["household"]):
				continue
			var best_motive := ""
			var best := 0.0
			var g := grievance(sim, rid, target)
			if g > best:
				best_motive = "grievance"
				best = g
			# Money pressure points at somebody who has money: a shopkeeper, or a greedy neighbour.
			var rich := _has_cash(sim, target)
			if rich and money > best:
				best_motive = "money"
				best = money
			if rich and g > 0.0 and cover > best:
				best_motive = "cover_up"
				best = cover
			var need := float(cfg["honest_veto"]) if sim.has_trait(rid, "honest") else threshold
			best -= safety(sim, target)
			if best >= need:
				out.append({"culprit": rid, "target": target, "motive": best_motive, "crime": crime, "pressure": best})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["pressure"]) != float(b["pressure"]):
			return float(a["pressure"]) > float(b["pressure"])
		return str(a["culprit"]) + str(a["target"]) < str(b["culprit"]) + str(b["target"]))
	return out


static func _has_cash(sim: Sim, rid: String) -> bool:
	var job := str((sim.residents[rid] as Dictionary)["job"])
	return job in ["shopkeeper", "shop_assistant"] or sim.has_trait(rid, "greedy")
