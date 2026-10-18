class_name Statements
extends RefCounted
## What a resident tells the Constable, built from what they actually remember (docs/SIMULATION.md
## "Statements in interviews"). Each memory inside the case window is told honestly, left out, or
## lied about, depending on who it concerns and who the resident is. Lies are specific and checkable
## and keep a link to the true memory, so contradictions can be found. Deterministic: wording is
## picked by a hash of the resident and memory, never the global RNG.
##
## incident: {culprit, victim, day, minute, touches: [secret ids the truth would expose],
##   cover: {place, minute} (the culprit's false alibi), window: minutes either side (default 180)}
## Statement: {id, owner, stance (honest | omit | lie), kind, text, memory_id, truth, why}

const WINDOW := 180
const LOYAL_FRIENDSHIP := 60.0
const AFRAID_GRIEVANCE := 30.0
const AFRAID_FRIENDSHIP := -30.0
const TEMPLATES := "res://data/dialogue/statements.json"

static var _templates: Dictionary = {}


static func templates() -> Dictionary:
	if _templates.is_empty():
		_templates = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATES)) as Dictionary
	return _templates


## Whether `rid` will tell the truth about `subject` (the culprit, or somebody tied to the incident).
## Returns {stance: honest | omit | lie, why}.
static func decide(sim: Sim, rid: String, incident: Dictionary) -> Dictionary:
	var culprit := str(incident.get("culprit", ""))
	if rid == culprit:
		return {"stance": "lie", "why": "protecting themselves"}
	# A secret the truth would expose.
	for sid: Variant in incident.get("touches", []):
		var s: Dictionary = sim.secrets.get(str(sid), {})
		if str(s.get("owner", "")) == rid:
			return {"stance": "lie", "why": "protecting a secret"}
	if culprit == "" or not sim.residents.has(culprit):
		return {"stance": "honest", "why": ""}
	# Family, or a close friend of the culprit's family if loyal.
	var home := str(sim.residents[culprit]["household"])
	if str(sim.residents[rid]["household"]) == home:
		return {"stance": "lie", "why": "protecting family"}
	if sim.has_trait(rid, "loyal"):
		for other: String in sim.members(home):
			if float(sim.rel(rid, other)["friendship"]) >= LOYAL_FRIENDSHIP:
				return {"stance": "lie", "why": "protecting a friend"}
	# Afraid of the culprit.
	var scared := sim.has_trait(culprit, "hot_headed") and float(sim.rel(rid, culprit)["friendship"]) < AFRAID_FRIENDSHIP
	for g: Dictionary in sim.grievances:
		if str(g["owner"]) == culprit and str(g["target"]) == rid and float(g["weight"]) >= AFRAID_GRIEVANCE:
			scared = true
	if scared:
		return {"stance": "omit", "why": "afraid of the culprit"}
	return {"stance": "honest", "why": ""}


## Everything `rid` will say, in the order it happened.
static func build(sim: Sim, rid: String, incident: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var decision := decide(sim, rid, incident)
	var stance := str(decision["stance"])
	var culprit := str(incident.get("culprit", ""))
	var at := int(incident["day"]) * 1440 + int(incident["minute"])
	var win := int(incident.get("window", WINDOW))
	var mems: Array = (sim.residents[rid]["memories"] as Array).duplicate()
	mems.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["day"]) * 1440 + int(a["minute"]) < int(b["day"]) * 1440 + int(b["minute"]))
	var n := 0
	for m: Dictionary in mems:
		if absi(int(m["day"]) * 1440 + int(m["minute"]) - at) > win:
			continue
		var about_culprit := str(m.get("subject", "")) == culprit and culprit != "" and rid != culprit
		var truth := _tell(sim, m, rid)
		n += 1
		var st := {"id": "st_%s_%d" % [rid, n], "owner": rid, "stance": "honest", "kind": str(m["kind"]), "text": truth, "memory_id": str(m["id"]),
			"truth": truth, "why": "", "subject": str(m.get("subject", "")), "minute": int(m["minute"]), "day": int(m["day"]),
			"confidence": float(m.get("confidence", 1.0)), "tile": m.get("tile", [])}
		if about_culprit and stance == "lie":
			st["stance"] = "lie"
			st["why"] = str(decision["why"])
			st["kind"] = "denial"
			st["text"] = _pick(templates()["lie"]["denial"], rid, str(m["id"]))
		elif about_culprit and stance == "omit":
			st["stance"] = "omit"
			st["why"] = str(decision["why"])
			st["kind"] = "omit"
			st["text"] = _pick(templates()["omit"], rid, str(m["id"]))
		out.append(st)
	# The culprit (or anyone with something to hide) gives a false whereabouts.
	var cover: Dictionary = incident.get("cover", {})
	if rid == culprit and not cover.is_empty():
		var time_text := TimeText.label(int(cover.get("minute", incident["minute"])))
		var text := _pick(templates()["lie"]["false_location"], rid, "cover").format({"place": cover.get("place", "at home"), "time": time_text})
		out.append({"id": "st_%s_cover" % rid, "owner": rid, "stance": "lie", "kind": "false_location", "text": text, "memory_id": "",
			"truth": "was away from %s" % cover.get("place", "home"), "why": "protecting themselves", "subject": rid, "minute": int(incident["minute"]),
			"day": int(incident["day"]), "confidence": 1.0, "tile": []})
	return out


## A memory in the resident's own words.
static func _tell(sim: Sim, m: Dictionary, rid: String) -> String:
	var kind := str(m["kind"])
	var t: Dictionary = templates()["honest"]
	var key := kind if t.has(kind) else "saw_object"
	var who := "somebody"
	if str(m.get("subject", "")) != "" and sim.residents.has(m["subject"]):
		who = "%s %s" % [sim.residents[m["subject"]]["first"], sim.residents[m["subject"]]["last"]]
	return _pick(t[key], rid, str(m["id"])).format({"who": who, "detail": m["detail"], "place": m["place"], "time": TimeText.label(int(m["minute"]))})


static func _pick(options: Array, rid: String, salt: String) -> String:
	return str(options[absi(hash("%s|%s" % [rid, salt])) % options.size()])


## What disproves a lie: other residents' honest firsthand memories of the same person inside the
## window. Returns [{fact: "mem:<owner>:<id>", owner, memory_id}]. A case's records (time cards, the
## exchange log) and physical traces are added by the caller.
static func contradictions(sim: Sim, statement: Dictionary, incident: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if str(statement["stance"]) != "lie":
		return out
	var owner := str(statement["owner"])
	var culprit := str(incident.get("culprit", ""))
	var at := int(incident["day"]) * 1440 + int(incident["minute"])
	var win := int(incident.get("window", WINDOW))
	var ids := sim.residents.keys()
	ids.sort()
	for other: String in ids:
		if other == owner or other == culprit:
			continue
		if str(Statements.decide(sim, other, incident)["stance"]) != "honest":
			continue
		for m: Dictionary in sim.residents[other]["memories"]:
			if str(m.get("subject", "")) == culprit and str(m.get("source", "firsthand")) == "firsthand" \
					and absi(int(m["day"]) * 1440 + int(m["minute"]) - at) <= win:
				out.append({"fact": "mem:%s:%s" % [other, m["id"]], "owner": other, "memory_id": str(m["id"])})
	return out
