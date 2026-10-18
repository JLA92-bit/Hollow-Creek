class_name CaseBuilder
extends RefCounted
## Turns a plan that has run in the simulation into an investigation case, in the same data format
## as data/cases/case_00_cash_tin.json (docs/CRIME_DIRECTOR.md "The evidence graph"). Everything in
## it comes from what really happened: the prints the culprit left, the things dropped, what each
## resident actually remembers (told honestly, left out or lied about by Statements) and what the
## victim knows. Each resident gets a `proof` table saying what would prove opportunity, means,
## motive and a broken lie against them, which is what solvability checks and what the accusation
## uses. Deterministic.

const WINDOW := 120
const MOTIVE_TEXT := {"money": "refused credit and in debt", "grievance": "an old grudge", "cover_up": "something to hide"}


static func build(sim: Sim, plan: Dictionary, st: Dictionary) -> Dictionary:
	var culprit := str(plan["culprit"])
	var victim := str(plan["target"])
	var house := str(plan["house"])
	var origin: Vector2i = sim.town.origins.get(house, Vector2i.ZERO)
	var now_abs := sim.day * 1440 + sim.minute
	var crime_abs := now_abs - (sim.ticks - int(st["crime_tick"]))
	var crime_day := crime_abs / 1440
	var crime_min := crime_abs % 1440
	var decoy: Dictionary = plan.get("decoy", {})
	var touches: Array = [str(decoy["secret"])] if not decoy.is_empty() and str((st["decoy"] as Dictionary).get("state", "")) == "done" else []
	var decoy_rid := str(decoy["rid"]) if not touches.is_empty() else ""
	var incident := {"culprit": culprit, "victim": victim, "day": crime_day, "minute": crime_min, "touches": touches, "window": WINDOW, "decoy": decoy_rid,
		"cover": {"place": "at home", "minute": crime_min}}
	var c := {"id": "gen:%s" % str(plan["id"]), "title": _title(plan), "victim": victim, "culprit": culprit, "generated": true, "plan": str(plan["id"]),
		"deadline_days": 4, "scene": {"id": "sc_%s" % house, "name": str(sim.town.sight.house_names.get(house, house)), "house": house},
		"traces": [], "records": [], "people": {}, "facts": {}, "households": {}, "deductions": [], "proof": {}, "resolutions": _resolutions(plan)}
	var cfg: Dictionary = Motives.config()
	var traces: Array = c["traces"]
	var facts: Dictionary = c["facts"]
	var deductions: Array = c["deductions"]

	# --- Scene traces -----------------------------------------------------------------------------
	var entry: Dictionary = plan["entry"]
	var in_t := Vector2i(int((entry["in"] as Array)[0]), int((entry["in"] as Array)[1]))
	var out_t := Vector2i(int((entry["out"] as Array)[0]), int((entry["out"] as Array)[1]))
	var room := str(sim.town.sight.rooms.get(sim.town.sight.room_at(in_t), {}).get("name", "back"))
	traces.append({"id": "t_entry", "area": "store", "pos": _rel(out_t, origin), "label": "The %s window left unlatched" % room, "prompt": "Tap the window",
		"minutes": 30, "text": "The %s window is pushed open. It was never latched." % room})
	var loot_t := Vector2i(floori(float((plan["loot_at"] as Array)[1])), floori(float((plan["loot_at"] as Array)[2])))
	traces.append({"id": "t_missing", "area": "store", "pos": _rel(loot_t, origin), "label": "%s gone from %s" % [str(plan["loot"]).capitalize(), str(plan["loot_place"])],
		"prompt": "Tap %s" % str(plan["loot_place"]), "minutes": 30, "text": "%s is gone from %s." % [str(plan["loot"]).capitalize(), str(plan["loot_place"])]})
	var since := int(st["start_tick"]) - 30
	var crime_boot: Dictionary = (sim.data["residents"] as Dictionary)[culprit].get("boot", {})
	var seen_prints := _prints(sim, since)
	var mine: Array = []
	var others: Dictionary = {}
	for key: String in seen_prints:
		for p: Dictionary in seen_prints[key]:
			if str(p["who"]) == culprit:
				mine.append({"key": key, "p": p})
			elif _near(key, out_t, 14.0):
				if not others.has(str(p["who"])):
					others[str(p["who"])] = {"key": key, "p": p}
	var prints_known := false
	if not mine.is_empty():
		mine.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _dist(str(a["key"]), out_t) < _dist(str(b["key"]), out_t))
		var inside := false
		for m: Dictionary in mine:
			if sim.town.sight.room_at(_tile(str(m["key"]))) != "" and str(sim.town.sight.rooms[sim.town.sight.room_at(_tile(str(m["key"])))]["house"]) == house:
				inside = true
		var best: Dictionary = mine[0]
		var label := "Size %s, %s" % [crime_boot.get("size", "?"), crime_boot.get("sole", "?")]
		traces.append({"id": "t_prints", "area": "store", "pos": _rel(_tile(str(best["key"])), origin), "label": "Bootprints %s" % ("on the floor" if inside else "outside"),
			"prompt": "Look at the ground", "minutes": 30, "text": "Prints in the %s, %s. A work boot. Measure it?" % ["mud" if bool((best["p"] as Dictionary)["muddy"]) else "dirt", str((best["p"] as Dictionary)["clarity"])],
			"measure": {"fact": "t_prints_measured", "label": label, "text": "%s." % label}})
		prints_known = true
	var other_i := 0
	var other_ids := others.keys()
	other_ids.sort()
	for oid: String in other_ids:
		if other_i >= 2:
			break
		var o: Dictionary = others[oid]
		var ob: Dictionary = (sim.data["residents"] as Dictionary)[oid].get("boot", {})
		var lab := "Size %s, %s" % [ob.get("size", "?"), ob.get("sole", "?")]
		other_i += 1
		traces.append({"id": "t_prints_other_%d" % other_i, "area": "outside", "pos": _rel(_tile(str(o["key"])), origin), "label": "Other prints nearby",
			"prompt": "Search around outside", "minutes": 45, "text": "A different set of prints, going somewhere else. Measure them?",
			"measure": {"fact": "t_prints_other_%d_measured" % other_i, "label": lab, "text": "%s." % lab}, "made_by": oid})
	var item_drop: Dictionary = {}          # the culprit's, if any
	var decoy_drop: Dictionary = {}         # the decoy's, if any
	for d: Dictionary in sim.dropped:
		if int(d["tick"]) >= since:
			if str(d["owner"]) == culprit:
				item_drop = d
			elif decoy_rid != "" and str(d["owner"]) == decoy_rid:
				decoy_drop = d
	var item_facts: Dictionary = {}         # owner -> trace id
	for pair: Array in [[item_drop, "t_item", "store"], [decoy_drop, "t_item_decoy", "outside"]]:
		var drop: Dictionary = pair[0]
		if drop.is_empty():
			continue
		var dt := Vector2i(int((drop["tile"] as Array)[0]), int((drop["tile"] as Array)[1]))
		item_facts[str(drop["owner"])] = str(pair[1])
		traces.append({"id": str(pair[1]), "area": str(pair[2]), "pos": _rel(dt, origin), "label": "A %s on the ground" % str(drop["item"]), "prompt": "Look around the ground",
			"minutes": 30, "text": "A %s, left lying there. It's somebody's." % str(drop["item"])})

	# --- Statements ---------------------------------------------------------------------------------
	var ids := sim.residents.keys()
	ids.sort()
	var living: Array[String] = []
	for rid: String in ids:
		if sim.residents[rid]["status"] == "living":
			living.append(rid)
	var statements: Dictionary = {}
	for rid: String in living:
		statements[rid] = Statements.build(sim, rid, incident)
	# The informative honest statements, by who they're about.
	var sightings: Dictionary = {}   # subject -> [statement]
	for rid: String in living:
		for s: Dictionary in statements[rid]:
			if str(s["stance"]) == "honest" and str(s.get("subject", "")) != "" and str(s["kind"]) == "saw_person" and float(s.get("confidence", 1.0)) >= 0.5:
				if not sightings.has(str(s["subject"])):
					sightings[str(s["subject"])] = []
				(sightings[str(s["subject"])] as Array).append(s)

	# --- People -------------------------------------------------------------------------------------
	var people: Dictionary = c["people"]
	var grievances := _grievances_on(sim, victim)
	var ledger := _ledger(sim, plan)
	if not ledger.is_empty():
		(c["records"] as Array).append(ledger)
	for rid: String in living:
		(c["households"] as Dictionary)[rid] = str(sim.residents[rid]["household"])
		var role := "victim" if rid == victim else ("suspect" if rid == culprit or (not decoy.is_empty() and rid == str(decoy["rid"])) else "witness")
		var person := {"role": role, "pressure": role == "suspect" or _lies(statements[rid]), "note": _note(sim, rid), "statements": []}
		var list: Array = person["statements"]
		var lie_n := 0
		for s: Dictionary in statements[rid]:
			if str(s["stance"]) == "lie":
				lie_n += 1
		if rid == victim:
			var first := {"id": "st_%s_v1" % rid, "text": "I locked up and went to bed. In the morning %s was gone from %s, and a window was open." % [plan["loot"], plan["loot_place"]],
				"press": {"text": "Who'd do it? I can think of a few." if ledger.is_empty() else "Who'd do it? I can think of a few. Here, have a look at the ledger.",
					"gives": [str(ledger["id"])] if not ledger.is_empty() else []}}
			list.append(first)
			for g: Dictionary in grievances:
				var sid := "st_%s_gr_%s" % [rid, g["owner"]]
				list.append({"id": sid, "text": "I'd had words with %s: %s." % [_name(sim, str(g["owner"])), str(g["reason"])], "gives": [sid],
					"press": {"text": "That's all there was to it.", "gives": []}})
				facts[sid] = {"short": "%s: words with %s" % [_first(sim, rid), _first(sim, str(g["owner"]))], "label": "%s had words with %s: %s" % [_name(sim, rid), _name(sim, str(g["owner"])), g["reason"]]}
		for s: Dictionary in statements[rid]:
			if rid == victim:
				continue
			var entry_s := {"id": str(s["id"]), "text": str(s["text"])}
			if str(s["stance"]) == "lie":
				entry_s["contradicted_by"] = _contradictions(s, rid, sightings, item_facts, lie_n)
				entry_s["_truth"] = str(s["truth"])
			else:
				if str(s.get("subject", "")) != "" and str(s["kind"]) == "saw_person" and float(s.get("confidence", 1.0)) >= 0.5:
					entry_s["gives"] = [str(s["id"])]
					facts[str(s["id"])] = {"short": "%s saw %s" % [_first(sim, rid), _first(sim, str(s["subject"]))], "label": "%s: %s" % [_first(sim, rid), str(s["text"])]}
				entry_s["press"] = {"text": "That's all I can tell you.", "gives": []}
			list.append(entry_s)
		# Lies: when broken, the truth comes out and becomes a fact.
		for k in list.size():
			var es: Dictionary = list[k]
			if es.has("contradicted_by"):
				var src: Dictionary = {}
				for s: Dictionary in statements[rid]:
					if str(s["id"]) == str(es["id"]):
						src = s
				var truth_id := "%s_true" % str(es["id"])
				var informative := str(src.get("subject", "")) != "" and str(src.get("subject", "")) != rid and str(src["stance"]) == "lie"
				for cb: Dictionary in es["contradicted_by"]:
					cb["result"] = "All right. %s" % str(es["_truth"]) if informative else "All right. I went out for a bit. I never took it."
					cb["gives"] = [truth_id] if informative else []
				if informative:
					facts[truth_id] = {"short": "%s admits seeing %s" % [_first(sim, rid), _first(sim, str(src["subject"]))], "label": "%s admits: %s" % [_first(sim, rid), str(es["_truth"])]}
					(sightings.get(str(src["subject"]), []) as Array).append({"id": truth_id, "minute": int(src["minute"]), "subject": str(src["subject"])})
					if not sightings.has(str(src["subject"])):
						sightings[str(src["subject"])] = [{"id": truth_id, "minute": int(src["minute"]), "subject": str(src["subject"])}]
				es.erase("_truth")
		if list.is_empty():
			list.append({"id": "st_%s_none" % rid, "text": "I was asleep. I didn't see or hear anything.", "press": {"text": "Sorry, dear. Nothing.", "gives": []}})
		if rid == culprit:
			person["confession"] = {"text": "I needed the money. I was going to put it back.", "gives": ["confession_%s" % rid]}
			facts["confession_%s" % rid] = {"short": "%s's confession" % _first(sim, rid), "label": "%s confessed" % _name(sim, rid)}
		people[rid] = person
	# Re-point contradictions at facts that exist: sightings made by the person themselves don't count.
	for rid: String in living:
		for es: Dictionary in (people[rid]["statements"] as Array):
			if es.has("contradicted_by"):
				var keep: Array = []
				for cb: Dictionary in es["contradicted_by"]:
					if not str(cb["fact"]).begins_with("st_%s_" % rid):
						keep.append(cb)
				es["contradicted_by"] = keep

	# --- Records, warrant -----------------------------------------------------------------------------
	var home := sim.home_of(culprit)
	c["warrant"] = {"target": str(sim.residents[culprit]["household"]), "trust_cost": 5, "label": "the %s house" % _last(sim, culprit),
		"finds": [{"id": "t_loot", "label": "%s hidden outside the %s house" % [str(plan["loot"]).capitalize(), _last(sim, culprit)],
			"text": "%s, hidden away outside the %s house." % [str(plan["loot"]).capitalize(), _last(sim, culprit)]}]}
	c["_home"] = home

	# --- Deductions and proof ---------------------------------------------------------------------------
	var all_names: Array = []
	for rid: String in living:
		all_names.append(_name(sim, rid))
	deductions.append({"id": "d_entry", "sentence": "The thief came in through the [entry].", "slots": [{"key": "entry", "options": ["front door", "%s window" % room, "side gate", "roof"]}],
		"proven_by": ["t_entry"], "answer": {"entry": "%s window" % room}})
	if prints_known:
		var sizes: Array = []
		var soles: Array = []
		for rid: String in living:
			var b: Dictionary = (sim.data["residents"] as Dictionary)[rid].get("boot", {})
			if not sizes.has(str(b.get("size", ""))):
				sizes.append(str(b.get("size", "")))
			if not soles.has(str(b.get("sole", ""))):
				soles.append(str(b.get("sole", "")))
		sizes.sort()
		soles.sort()
		deductions.append({"id": "d_size", "sentence": "The bootprints belong to someone with size [size] [sole] boots.",
			"slots": [{"key": "size", "options": sizes}, {"key": "sole", "options": soles}], "proven_by": ["t_prints_measured"],
			"answer": {"size": str(crime_boot.get("size", "")), "sole": str(crime_boot.get("sole", ""))}})
	for owner: String in item_facts:
		var did := "d_item" if owner == culprit else "d_item_decoy"
		var dd: Dictionary = item_drop if owner == culprit else decoy_drop
		deductions.append({"id": did, "sentence": "The [item] on the ground belongs to [person].", "slots": [{"key": "item", "options": _all_items(sim)}, {"key": "person", "options": all_names}],
			"proven_by": [str(item_facts[owner])], "answer": {"item": str(dd["item"]), "person": _name(sim, owner)}})
	var times := _times(crime_min)
	for subj: String in sightings:
		var srcs: Array = sightings[subj]
		var groups: Array = []
		var answers: Array = []
		for s: Dictionary in srcs:
			groups.append([str(s["id"])])
			answers.append(_bucket(int(s["minute"])))
		deductions.append({"id": "d_saw_%s" % subj, "sentence": "[person] was near the %s at about [time]." % _short_place(c), "slots": [{"key": "person", "options": all_names}, {"key": "time", "options": times}],
			"proven_by_any": groups, "answer": {"person": _name(sim, subj), "time": answers}})
	var motive_ids: Dictionary = {}
	var m_text := MOTIVE_TEXT
	for rid: String in living:
		var groups: Array = []
		for g: Dictionary in grievances:
			if str(g["owner"]) == rid:
				groups.append(["st_%s_gr_%s" % [victim, rid]])
		var m_answer := "an old grudge"
		if not ledger.is_empty() and str(ledger["household"]) == str(sim.residents[rid]["household"]):
			groups.append([str(ledger["id"])])
			m_answer = str(m_text["money"])
		if groups.is_empty():
			continue
		motive_ids[rid] = "d_motive_%s" % rid
		deductions.append({"id": "d_motive_%s" % rid, "sentence": "%s had reason: [motive]." % _name(sim, rid), "slots": [{"key": "motive", "options": m_text.values()}],
			"proven_by_any": groups, "answer": {"motive": m_answer}})
	# What would convict each resident.
	var proof: Dictionary = c["proof"]
	for rid: String in living:
		var opp: Array = []
		if sightings.has(rid):
			opp.append("d_saw_%s" % rid)
		if item_facts.has(rid):
			opp.append("d_item" if rid == culprit else "d_item_decoy")
		var means_rules: Array = []
		if rid == culprit:
			means_rules.append({"any_fact": ["t_loot"]})
		var b2: Dictionary = (sim.data["residents"] as Dictionary)[rid].get("boot", {})
		if prints_known and str(b2.get("size", "")) == str(crime_boot.get("size", "")) and str(b2.get("sole", "")) == str(crime_boot.get("sole", "")):
			means_rules.append({"all_deduction": ["d_size"]})
		proof[rid] = {"opportunity": {"any_deduction": opp}, "means": {"or": means_rules}, "motive": {"any_deduction": [motive_ids[rid]] if motive_ids.has(rid) else []},
			"lie": {"broken_by": rid}}
	c["accusation"] = {"culprit": culprit, "opportunity": proof[culprit]["opportunity"], "means": proof[culprit]["means"], "motive": proof[culprit]["motive"], "lie": proof[culprit]["lie"]}
	c["crime_minute"] = crime_min
	c["crime_day"] = crime_day
	c["tip"] = "Residents have started latching their windows."
	return c


# --- Helpers ----------------------------------------------------------------------------------------

static func _title(plan: Dictionary) -> String:
	return "The Missing %s" % str(plan["loot"]).trim_prefix("the ").capitalize()


static func _resolutions(plan: Dictionary) -> Array:
	var weeks: int = int((Motives.config()[str(plan["crime"])] as Dictionary).get("charge_weeks", 4))
	return [{"id": "charge", "label": "Charge", "text": "Sent to the district court for %d weeks. The family's income drops." % weeks, "trust": 10,
			"grievances": [], "unlocks": []},
		{"id": "restitution", "label": "Restitution", "text": "Repays from wages and does a month of community work.", "trust": 6, "grievances": [], "unlocks": []}]


static func _rel(t: Vector2i, origin: Vector2i) -> Array:
	return [t.x - origin.x, t.y - origin.y]


static func _tile(key: String) -> Vector2i:
	var p := key.split(",")
	return Vector2i(int(p[0]), int(p[1]))


static func _dist(key: String, t: Vector2i) -> float:
	return Vector2(_tile(key)).distance_to(Vector2(t))


static func _near(key: String, t: Vector2i, r: float) -> bool:
	return _dist(key, t) <= r


## Prints made since a tick, tile key -> [print].
static func _prints(sim: Sim, since: int) -> Dictionary:
	var out: Dictionary = {}
	for key: String in sim.traces:
		for p: Dictionary in sim.traces[key]:
			if int(p["tick"]) >= since:
				if not out.has(key):
					out[key] = []
				(out[key] as Array).append(p)
	return out


static func _grievances_on(sim: Sim, victim: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in sim.grievances:
		if str(g["target"]) == victim and float(g["weight"]) >= 20.0 and sim.residents.has(str(g["owner"])):
			out.append(g)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["owner"]) < str(b["owner"]))
	return out


## The store's credit ledger, when the motive is money and the victim keeps one: who owes what.
static func _ledger(sim: Sim, plan: Dictionary) -> Dictionary:
	if str(plan["motive"]) != "money":
		return {}
	var culprit := str(plan["culprit"])
	var owed := 0.0
	for sid: String in sim.secrets:
		var s: Dictionary = sim.secrets[sid]
		if str(s["owner"]) == culprit and str(s["kind"]) == "debt":
			owed += 5.0 + float(s["exposure_risk"])
	if owed <= 0.0:
		owed = 8.0
	var hid := str(sim.residents[culprit]["household"])
	return {"id": "rec_ledger", "name": "Credit ledger", "short": "%s owes" % _last(sim, culprit), "via": str(plan["target"]), "minutes": 30, "household": hid,
		"text": "%s, %s. Owes £%d. Credit STOPPED." % [_last(sim, culprit).to_upper(), _first(sim, culprit).substr(0, 1), int(owed)]}


static func _lies(list: Array) -> bool:
	for s: Dictionary in list:
		if str(s["stance"]) == "lie":
			return true
	return false


## What breaks a lie: the honest sightings of the same subject by other people, and the dropped item
## if it's the culprit's. Each takes composure so that breaking every lie someone tells leaves them at 0.
static func _contradictions(s: Dictionary, rid: String, sightings: Dictionary, item_facts: Dictionary, lie_n: int) -> Array:
	var subject := str(s.get("subject", ""))
	var out: Array = []
	var per := int(ceil(100.0 / float(maxi(1, lie_n))))
	if subject != "" and sightings.has(subject):
		for o: Dictionary in sightings[subject]:
			if not str(o["id"]).begins_with("st_%s_" % rid):
				out.append({"fact": str(o["id"]), "composure": per})
	if item_facts.has(rid) and subject == rid:
		out.append({"fact": str(item_facts[rid]), "composure": per})
	return out


static func _note(sim: Sim, rid: String) -> String:
	var r: Dictionary = sim.residents[rid]
	var job := str((sim.data["jobs"] as Dictionary).get(str(r["job"]), {}).get("name", "Resident"))
	return "%s, %d." % [job, int(r["age"])]


static func _first(sim: Sim, rid: String) -> String:
	return str(sim.residents[rid]["first"])


static func _last(sim: Sim, rid: String) -> String:
	return str(sim.residents[rid]["last"])


static func _name(sim: Sim, rid: String) -> String:
	return "%s %s" % [_first(sim, rid), _last(sim, rid)]


static func _all_items(sim: Sim) -> Array:
	var out: Array = []
	for rid: String in sim.residents:
		for it: Variant in (sim.data["residents"] as Dictionary)[rid].get("items", []):
			if not out.has(str(it)):
				out.append(str(it))
	out.sort()
	return out


static func _short_place(c: Dictionary) -> String:
	return str((c["scene"] as Dictionary)["name"]).trim_prefix("the ")


## A quarter-hour label for a minute of the day: sightings are matched to the nearest.
static func _bucket(minute: int) -> String:
	return TimeText.label(int(round(float(minute) / 15.0)) * 15 % 1440)


static func _times(crime_min: int) -> Array:
	var out: Array = []
	var start := int(round(float(crime_min - 150) / 15.0)) * 15
	for i in 21:
		out.append(TimeText.label(posmod(start + i * 15, 1440)))
	return out
