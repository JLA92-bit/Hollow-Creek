class_name SolverBot
extends RefCounted
## Plays an investigation the way an honest player would, using only the Investigation rules and
## what has been discovered so far (docs/CRIME_DIRECTOR.md "Testing"): search everywhere, measure,
## interview everyone, press, present whatever contradicts a statement, link every deduction that its
## evidence supports, then search the house of whoever the evidence points at and accuse them.
## Used by the director to check a case is solvable and by the soak test and CI.

const DAY := 6


## Gather everything that can be gathered, to a fixpoint. Returns the number of passes.
static func gather(inv: Investigation) -> int:
	var passes := 0
	var before := -1
	while passes < 12:
		var sig := _signature(inv)
		if sig == before:
			break
		before = sig
		passes += 1
		for t: Dictionary in inv.traces():
			inv.search(str(t["id"]))
			if t.has("measure"):
				inv.measure(str(t["id"]))
		for pid: String in (inv.data["people"] as Dictionary):
			_question(inv, pid)
		_link_all(inv)
	return passes


static func _signature(inv: Investigation) -> int:
	return inv.facts.size() * 1000 + inv.proven.size() * 10 + inv.broken.size()


static func _question(inv: Investigation, pid: String) -> void:
	inv.interview(pid, DAY)
	for i in 8:
		var pressed := false
		if bool((inv.press(pid, DAY) as Dictionary).get("ok", false)):
			pressed = true
		var progressed := false
		for f: String in inv.presentable():
			if not inv.contradicts(pid, f).is_empty():
				inv.present(pid, f, DAY)
				progressed = true
				break
		if not pressed and not progressed:
			break


static func _link_all(inv: Investigation) -> void:
	for d: Dictionary in inv.deductions():
		var id := str(d["id"])
		if inv.proven.has(id) or not inv.supported(id):
			continue
		var answers := {}
		for k: String in (d.get("answer", {}) as Dictionary):
			var v: Variant = d["answer"][k]
			answers[k] = str((v as Array)[0]) if v is Array else str(v)
		# A listed answer may be one of several acceptable ones; any works.
		inv.link(id, answers)


## How much of the case there is against somebody, 0 to 4.
static func score(inv: Investigation, pid: String) -> int:
	var r := inv.requirements(pid)
	var n := 0
	for k: String in r:
		if bool(r[k]):
			n += 1
	return n


## Who the evidence points at: the most requirements met, ties broken by id.
static func top_suspect(inv: Investigation) -> String:
	var best := ""
	var best_n := -1
	var ids := (inv.data["people"] as Dictionary).keys()
	ids.sort()
	for pid: String in ids:
		var n := score(inv, pid)
		if n > best_n:
			best_n = n
			best = pid
	return best


## Play to the end. `accuse` false stops before accusing, to inspect what the evidence supports.
static func play(inv: Investigation, accuse: bool = true) -> Dictionary:
	gather(inv)
	var suspect := top_suspect(inv)
	# Search the house of whoever we're leaning towards, once, if we haven't the means yet.
	if suspect != "" and not bool(inv.requirements(suspect)["means"]) and not inv.warrant_used and inv.household_of(suspect) != "":
		inv.request_warrant(inv.household_of(suspect))
		gather(inv)
		suspect = top_suspect(inv)
	var result := {"suspect": suspect, "score": score(inv, suspect) if suspect != "" else 0, "facts": inv.facts.size(), "accused": ""}
	if accuse and suspect != "":
		var a := inv.accuse(suspect)
		result["accused"] = suspect
		result["right"] = bool(a["right"])
		result["complete"] = bool(a["complete"])
		if bool(a["right"]) and bool(a["complete"]):
			inv.resolve("restitution")
	return result
