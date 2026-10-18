class_name Investigation
extends RefCounted
## One open case, from the first alert to the outcome (docs/GAME_DESIGN.md "Investigation"). A plain
## class: no scenes, no randomness, so it runs headlessly and snapshots exactly. All content comes
## from the case's data file (data/cases/*.json); nothing here knows about any particular case.
##
## Facts are strings: a trace id, a record id, a statement id someone has given, or a measurement.
## Everything the player can learn is a fact, and deductions, interviews and the accusation only
## ever ask "is this fact known?".

const PRESSURE_WRONG := 20
const PRESSURE_REFUSE := 100
const TRUST_WRONG_WARRANT := 5
const TRUST_RIGHT_COMPLETE := 10
const TRUST_RIGHT_INCOMPLETE := 3
const TRUST_WRONG_PERSON := -15
const TRUST_UNSOLVED := -8

var data: Dictionary
var facts: Dictionary = {}            ## fact id -> true
var found: Array[String] = []         ## traces found, in order (the numbered markers)
var records: Array[String] = []       ## records gathered, in order
var minutes_spent: int = 0            ## in-game minutes the player has spent on the case
var people: Dictionary = {}           ## person id -> interview state
var proven: Dictionary = {}           ## deduction id -> true
var warrant_used: bool = false
var warrant_target: String = ""
var broken: Dictionary = {}           ## person id -> true once one of their lies is broken
var accused: String = ""
var outcome: Dictionary = {}          ## set by accuse()
var resolution: String = ""
var trust_change: int = 0             ## Town Trust earned or lost and not yet banked by the host
var unlocked: Array[String] = []      ## things the case closing unlocks (footpaths, street_lamps)
var log: Array[String] = []           ## what the player did, for the case file


func _init(p_data: Dictionary = {}) -> void:
	data = p_data
	for pid: String in (data.get("people", {}) as Dictionary):
		var p: Dictionary = data["people"][pid]
		people[pid] = {"index": 0, "composure": 100, "pressure": 0, "pressed": [], "shown": [], "refuses_day": -1,
			"confessed": false, "met": false, "last": ""}


static func load_case(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func title() -> String:
	return str(data.get("title", ""))


func knows(fact: String) -> bool:
	return facts.has(fact)


func _learn(ids: Array) -> Array[String]:
	var fresh: Array[String] = []
	for id: Variant in ids:
		if not facts.has(str(id)):
			facts[str(id)] = true
			fresh.append(str(id))
	return fresh


func _spend(minutes: int) -> void:
	minutes_spent += minutes


# --- Scene ------------------------------------------------------------------------------------------

func traces() -> Array:
	return data.get("traces", [])


func trace(id: String) -> Dictionary:
	for t: Dictionary in traces():
		if str(t["id"]) == id:
			return t
	for t: Dictionary in (data.get("warrant", {}) as Dictionary).get("finds", []):
		if str(t["id"]) == id:
			return t
	return {}


## Search for a trace by tapping where it is. Returns {ok, text, number}. A trace already found
## costs nothing; the player just reads it again.
func search(id: String) -> Dictionary:
	var t := trace(id)
	if t.is_empty() or not (traces() as Array).has(t):
		return {"ok": false, "text": ""}
	if found.has(id):
		return {"ok": true, "text": str(t["text"]), "number": found.find(id) + 1, "again": true}
	_spend(int(t.get("minutes", 30)))
	found.append(id)
	_learn([id])
	log.append("Found: %s" % t["label"])
	return {"ok": true, "text": str(t["text"]), "number": found.size(), "again": false}


## Measure a found trace (bootprints). Returns {ok, text, fact}.
func measure(id: String) -> Dictionary:
	var t := trace(id)
	if not found.has(id) or not t.has("measure"):
		return {"ok": false, "text": ""}
	var m: Dictionary = t["measure"]
	if knows(str(m["fact"])):
		return {"ok": true, "text": str(m["text"]), "fact": str(m["fact"]), "again": true}
	_spend(15)
	_learn([m["fact"]])
	log.append("Measured: %s" % m["label"])
	return {"ok": true, "text": str(m["text"]), "fact": str(m["fact"]), "again": false}


func traces_found() -> int:
	var n := 0
	for t: Dictionary in traces():
		if found.has(str(t["id"])):
			n += 1
	return n


## Where the case ends up if it isn't solved: the number of traces and records on the board.
func evidence() -> Array[String]:
	var out: Array[String] = []
	out.append_array(found)
	out.append_array(records)
	return out


## Short label for anything in the case file: "Muddy bootprints" or "Exchange log".
func label_of(fact: String) -> String:
	var known: Dictionary = (data.get("facts", {}) as Dictionary).get(fact, {})
	if known.has("label"):
		return str(known["label"])
	var t := trace(fact)
	if not t.is_empty():
		return str(t["label"])
	for r: Dictionary in data.get("records", []):
		if str(r["id"]) == fact:
			return str(r["name"])
	for pid: String in (data.get("people", {}) as Dictionary):
		for s: Dictionary in data["people"][pid]["statements"]:
			if str(s["id"]) == fact:
				return str(s["text"])
	for tr: Dictionary in traces():
		if tr.has("measure") and str(tr["measure"]["fact"]) == fact:
			return str(tr["measure"]["label"])
	return fact


## A chip-sized name for a fact, if the case gives it one.
func short_of(fact: String) -> String:
	return str(((data.get("facts", {}) as Dictionary).get(fact, {}) as Dictionary).get("short", ""))


# --- Records ----------------------------------------------------------------------------------------

func record(id: String) -> Dictionary:
	for r: Dictionary in data.get("records", []):
		if str(r["id"]) == id:
			return r
	return {}


## Records come from people ("Ask Frank"), so they are given up in interviews. This is also how the
## records screen lists what has been seen.
func gather(id: String) -> bool:
	var r := record(id)
	if r.is_empty() or records.has(id):
		return false
	_spend(int(r.get("minutes", 30)))
	records.append(id)
	_learn([id])
	log.append("Records: %s" % r["name"])
	return true


# --- Interviews -------------------------------------------------------------------------------------

func person(pid: String) -> Dictionary:
	return (data.get("people", {}) as Dictionary).get(pid, {})


func statements(pid: String) -> Array:
	return person(pid).get("statements", [])


## The statement the person is currently standing behind, or {} once they have none left.
func current_statement(pid: String) -> Dictionary:
	var st := statements(pid)
	var i: int = int(people[pid]["index"])
	return st[i] if i < st.size() else {}


func has_pressure(pid: String) -> bool:
	return bool(person(pid).get("pressure", false))


func can_talk(pid: String, day: int) -> bool:
	return people.has(pid) and int(people[pid]["refuses_day"]) < day


## First conversation with someone: they give their opening statement and anything it hands over.
## Returns {ok, text, gives}.
func interview(pid: String, day: int) -> Dictionary:
	if not people.has(pid):
		return {"ok": false, "text": ""}
	if not can_talk(pid, day):
		return {"ok": false, "text": "Won't talk to you until tomorrow.", "refused": true}
	var ps: Dictionary = people[pid]
	var st := current_statement(pid)
	var gives: Array[String] = []
	if not bool(ps["met"]):
		ps["met"] = true
		_spend(30)
		log.append("Interviewed %s" % pid)
		if not st.is_empty():
			gives = _give_statement(pid, st)
	return {"ok": true, "text": str(st.get("text", "")), "gives": gives}


func _give_statement(pid: String, st: Dictionary) -> Array[String]:
	var shown: Array = people[pid]["shown"]
	if shown.has(str(st["id"])):
		return []
	shown.append(str(st["id"]))
	var gives: Array[String] = _learn(st.get("gives", []))
	for g: String in gives:
		if not records.has(g) and not record(g).is_empty():
			gather(g)
	return gives


## Press the current statement: the person says a little more. Once per statement.
## Returns {ok, text, gives}.
func press(pid: String, day: int) -> Dictionary:
	if not people.has(pid) or not can_talk(pid, day):
		return {"ok": false, "text": ""}
	var st := current_statement(pid)
	var pressed: Array = people[pid]["pressed"]
	if st.is_empty() or not st.has("press") or pressed.has(str(st["id"])):
		return {"ok": false, "text": "They've nothing more to add.", "gives": []}
	pressed.append(str(st["id"]))
	_spend(15)
	var pr: Dictionary = st["press"]
	var gives: Array[String] = _learn(pr.get("gives", []))
	for g: String in gives:
		if not records.has(g) and not record(g).is_empty():
			gather(g)
	people[pid]["last"] = str(pr["text"])
	# A statement nobody can contradict gives way to the next one once it has been pressed.
	if (st.get("contradicted_by", []) as Array).is_empty():
		var ps: Dictionary = people[pid]
		ps["index"] = int(ps["index"]) + 1
		var nxt := current_statement(pid)
		if not nxt.is_empty():
			gives.append_array(_give_statement(pid, nxt))
	return {"ok": true, "text": str(pr["text"]), "gives": gives}


## Is this fact something the player can present against the current statement?
func contradicts(pid: String, fact: String) -> Dictionary:
	var st := current_statement(pid)
	for c: Dictionary in st.get("contradicted_by", []):
		if str(c["fact"]) == fact:
			return c
	return {}


## Present a fact (trace, record or statement) to a person. Returns
## {ok, hit, text, composure, pressure, gives, confessed, refused}.
func present(pid: String, fact: String, day: int) -> Dictionary:
	if not people.has(pid) or not knows(fact) or not can_talk(pid, day):
		return {"ok": false, "hit": false, "text": ""}
	var ps: Dictionary = people[pid]
	var hit := contradicts(pid, fact)
	_spend(10)
	if hit.is_empty():
		if has_pressure(pid):
			ps["pressure"] = mini(PRESSURE_REFUSE, int(ps["pressure"]) + PRESSURE_WRONG)
		var refused := int(ps["pressure"]) >= PRESSURE_REFUSE
		if refused:
			ps["refuses_day"] = day
			ps["pressure"] = 0
		var txt := "That doesn't prove a thing." if not refused else "I'm not saying another word. Not today."
		ps["last"] = txt
		return {"ok": true, "hit": false, "text": txt, "composure": int(ps["composure"]), "pressure": int(ps["pressure"]),
			"gives": [], "confessed": false, "refused": refused}
	ps["composure"] = maxi(0, int(ps["composure"]) - int(hit["composure"]))
	broken[pid] = true
	var gives: Array[String] = _learn(hit.get("gives", []))
	var text := str(hit.get("result", ""))
	ps["index"] = int(ps["index"]) + 1
	var confessed := false
	var conf: Dictionary = person(pid).get("confession", {})
	if int(ps["composure"]) == 0 and not conf.is_empty() and not bool(ps["confessed"]):
		ps["confessed"] = true
		confessed = true
		text = (text + " " if text != "" else "") + str(conf["text"])
		gives.append_array(_learn(conf.get("gives", [])))
	var nxt := current_statement(pid)
	if not nxt.is_empty() and not confessed:
		gives.append_array(_give_statement(pid, nxt))
	ps["last"] = text
	log.append("Broke a lie: %s" % pid)
	return {"ok": true, "hit": true, "text": text, "composure": int(ps["composure"]), "pressure": int(ps["pressure"]),
		"gives": gives, "confessed": confessed, "refused": false}


## Everything the player holds that they could present: traces found, measurements, records and
## statements given by other people.
func presentable() -> Array[String]:
	var out: Array[String] = []
	for k: String in facts:
		out.append(k)
	out.sort()
	return out


# --- Warrants ---------------------------------------------------------------------------------------

## Search a household's property. Wrong searches cost Town Trust and sour that household.
## Returns {ok, right, text, found}.
func request_warrant(household: String) -> Dictionary:
	if warrant_used and warrant_target == household:
		return {"ok": false, "right": false, "text": "Already searched."}
	var w: Dictionary = data.get("warrant", {})
	_spend(60)
	warrant_used = true
	warrant_target = household
	if household != str(w.get("target", "")):
		trust_change -= TRUST_WRONG_WARRANT
		log.append("Wrong search: %s" % household)
		return {"ok": true, "right": false, "text": "Nothing. The family is not pleased.", "found": [], "household": household}
	var out: Array[String] = []
	var texts: Array[String] = []
	for t: Dictionary in w.get("finds", []):
		out.append_array(_learn([t["id"]]))
		found.append(str(t["id"]))
		texts.append(str(t["text"]))
	log.append("Searched %s" % w.get("label", household))
	return {"ok": true, "right": true, "text": " ".join(texts), "found": out, "household": household}


# --- Deductions -------------------------------------------------------------------------------------

func deductions() -> Array:
	return data.get("deductions", [])


func deduction(id: String) -> Dictionary:
	for d: Dictionary in deductions():
		if str(d["id"]) == id:
			return d
	return {}


## Has the player found what a deduction needs to be provable?
func supported(id: String) -> bool:
	var d := deduction(id)
	if d.is_empty():
		return false
	if d.has("proven_by_any"):
		for group: Array in d["proven_by_any"]:
			if _all_known(group):
				return true
		return false
	return _all_known(d.get("proven_by", []))


func _all_known(ids: Array) -> bool:
	for f: Variant in ids:
		if not knows(str(f)):
			return false
	return true


## Try to fill in a deduction's blanks. Returns {ok, proven, reason}. Wrong answers prove nothing
## and don't cost anything: the board is for thinking.
func link(id: String, answers: Dictionary) -> Dictionary:
	var d := deduction(id)
	if d.is_empty():
		return {"ok": false, "proven": false, "reason": "unknown"}
	if proven.has(id):
		return {"ok": true, "proven": true, "reason": "already"}
	if not supported(id):
		return {"ok": true, "proven": false, "reason": "no evidence"}
	var want: Dictionary = d.get("answer", {})
	for k: String in want:
		# An answer may list several acceptable values (the same sighting told at slightly different times).
		var ok: bool = (want[k] as Array).has(str(answers.get(k, ""))) if want[k] is Array else str(answers.get(k, "")) == str(want[k])
		if not ok:
			return {"ok": true, "proven": false, "reason": "wrong"}
	proven[id] = true
	log.append("Proved: %s" % d["sentence"])
	return {"ok": true, "proven": true, "reason": ""}


# --- Accusation -------------------------------------------------------------------------------------

## What proves the four requirements against somebody: a case can list a table for each resident
## (`proof`), which is how generated cases say who the evidence points at. The authored Cash Tin only
## has the culprit's rules, under `accusation`; everybody else can't be convicted.
func proof_for(pid: String) -> Dictionary:
	var table: Dictionary = data.get("proof", {})
	if table.has(pid):
		return table[pid]
	var a: Dictionary = data.get("accusation", {})
	if pid == str(a.get("culprit", "")):
		return a
	return {"opportunity": {"any_fact": []}, "means": {"any_fact": []}, "motive": {"any_fact": []}, "lie": {"broken_by": ""}}


## The household a resident belongs to (generated cases list them), for warrants.
func household_of(pid: String) -> String:
	return str((data.get("households", {}) as Dictionary).get(pid, ""))


func culprit() -> String:
	return str((data.get("accusation", {}) as Dictionary).get("culprit", data.get("culprit", "")))


## The four requirements against `pid` (the culprit if none is given): {opportunity, means, motive, lie}.
func requirements(pid: String = "") -> Dictionary:
	var who := pid if pid != "" else culprit()
	var a := proof_for(who)
	var out := {}
	for k: String in ["opportunity", "means", "motive"]:
		out[k] = _meets(a.get(k, {}))
	out["lie"] = bool(broken.get(str((a.get("lie", {}) as Dictionary).get("broken_by", "")), false)) if str((a.get("lie", {}) as Dictionary).get("broken_by", "")) != "" else false
	return out


func _meets(rule: Dictionary) -> bool:
	if rule.has("or"):
		for sub: Dictionary in rule["or"]:
			if _meets(sub):
				return true
		return false
	var any_ok := false
	var has_any := rule.has("any_deduction") or rule.has("any_fact")
	for d: Variant in rule.get("any_deduction", []):
		any_ok = any_ok or proven.has(str(d))
	for f: Variant in rule.get("any_fact", []):
		any_ok = any_ok or knows(str(f))
	for d: Variant in rule.get("all_deduction", []):
		if not proven.has(str(d)):
			return false
	return any_ok if has_any else true


func complete(pid: String = "") -> bool:
	var r := requirements(pid)
	return bool(r["opportunity"]) and bool(r["means"]) and bool(r["motive"]) and bool(r["lie"])


## Accuse someone. Returns {ok, right, complete, trust, text, requirements}.
func accuse(pid: String) -> Dictionary:
	if accused != "":
		return {"ok": false}
	accused = pid
	var right := pid == culprit()
	var done := complete(pid)
	var trust := TRUST_WRONG_PERSON
	var text := "Wrong person. The accused family is furious, and the real culprit breathes easier."
	if right and done:
		trust = TRUST_RIGHT_COMPLETE
		text = "The case holds together. Charge or restitution?"
	elif right:
		trust = TRUST_RIGHT_INCOMPLETE
		text = "It's the right person, but the case has holes. The magistrate may throw it out."
	outcome = {"right": right, "complete": done, "trust": trust, "text": text, "requirements": requirements(pid)}
	trust_change += trust if not (right and done) else 0
	log.append("Accused %s" % pid)
	return {"ok": true, "right": right, "complete": done, "trust": trust, "text": text, "requirements": requirements(pid)}


func resolutions() -> Array:
	return data.get("resolutions", [])


## After a right, complete accusation the player chooses how it ends. Returns the resolution's
## {trust, grievances, unlocks, text}, or {} if it isn't available.
func resolve(id: String) -> Dictionary:
	if accused == "" or resolution != "" or not bool(outcome.get("right", false)) or not bool(outcome.get("complete", false)):
		return {}
	for r: Dictionary in resolutions():
		if str(r["id"]) == id:
			resolution = id
			trust_change += int(r["trust"])
			for u: Variant in r.get("unlocks", []):
				unlocked.append(str(u))
			log.append("Resolved: %s" % r["label"])
			return r
	return {}


func closed() -> bool:
	if accused == "":
		return false
	if bool(outcome.get("right", false)) and bool(outcome.get("complete", false)):
		return resolution != ""
	return true


## Banks and clears the Town Trust waiting for the host.
func take_trust() -> int:
	var t := trust_change
	trust_change = 0
	return t


# --- Snapshot -----------------------------------------------------------------------------------------

func snapshot() -> Dictionary:
	return {"facts": facts.duplicate(), "found": found.duplicate(), "records": records.duplicate(), "minutes_spent": minutes_spent,
		"people": people.duplicate(true), "proven": proven.duplicate(), "warrant_used": warrant_used, "warrant_target": warrant_target,
		"broken": broken.duplicate(), "accused": accused, "outcome": outcome.duplicate(true), "resolution": resolution,
		"trust_change": trust_change, "unlocked": unlocked.duplicate(), "log": log.duplicate()}


func restore(d: Dictionary) -> void:
	facts = (d["facts"] as Dictionary).duplicate()
	found.assign(d["found"])
	records.assign(d["records"])
	minutes_spent = int(d["minutes_spent"])
	people = (d["people"] as Dictionary).duplicate(true)
	proven = (d["proven"] as Dictionary).duplicate()
	warrant_used = bool(d["warrant_used"])
	warrant_target = str(d["warrant_target"])
	broken = (d["broken"] as Dictionary).duplicate()
	accused = str(d["accused"])
	outcome = (d["outcome"] as Dictionary).duplicate(true)
	resolution = str(d["resolution"])
	trust_change = int(d["trust_change"])
	unlocked.assign(d["unlocked"])
	log.assign(d["log"])
