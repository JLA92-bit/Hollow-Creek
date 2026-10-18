class_name Solvability
extends RefCounted
## Is a generated case fair? (docs/CRIME_DIRECTOR.md "The evidence graph and solvability".) The solver
## bot plays it with only discoverable facts. A case is solvable when:
##   1. the culprit can be shown to meet all four requirements;
##   2. nobody else can;
##   3. there are between MIN_FACTS and MAX_FACTS discoverable facts.
## It is interesting when at least one other resident meets two or three requirements (a red herring).

const MIN_FACTS := 5
const MAX_FACTS := 24


## Returns {solvable, interesting, reasons: [String], facts, herrings: {pid: score}, culprit_score}.
static func analyse(case_data: Dictionary) -> Dictionary:
	var inv := Investigation.new(case_data)
	SolverBot.play(inv, false)
	var culprit := inv.culprit()
	var reasons: Array[String] = []
	var herrings: Dictionary = {}
	if not inv.complete(culprit):
		reasons.append("the culprit can't be shown to meet all four requirements: %s" % str(inv.requirements(culprit)))
	for pid: String in (case_data["people"] as Dictionary):
		if pid == culprit:
			continue
		if inv.complete(pid):
			reasons.append("%s can be convicted too" % pid)
		var n := SolverBot.score(inv, pid)
		if n >= 2:
			herrings[pid] = n
	var facts := _count_facts(inv)
	if facts < MIN_FACTS:
		reasons.append("only %d discoverable facts" % facts)
	if facts > MAX_FACTS:
		reasons.append("%d discoverable facts is too many" % facts)
	return {"solvable": reasons.is_empty(), "interesting": not herrings.is_empty(), "reasons": reasons, "facts": facts, "herrings": herrings,
		"culprit_score": SolverBot.score(inv, culprit)}


## Facts worth counting: traces, records, measurements, informative statements and what lies reveal.
static func _count_facts(inv: Investigation) -> int:
	var n := 0
	for f: String in inv.facts:
		if f.begins_with("confession_"):
			continue
		n += 1
	return n
