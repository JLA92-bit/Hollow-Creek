class_name Sim
extends RefCounted
## The resident simulation (docs/SIMULATION.md). Plain class, no scene dependencies, deterministic:
## one tick is one game minute, residents are visited in id order, and every random choice comes
## from the one SimRng. snapshot() and restore() round-trip exactly.
##
## Residents have needs (hunger, energy, social, fun: 100 is satisfied) that fall over time. When
## idle they pick an action by utility, from the top three with weighted randomness; work, sleep
## and the like override needs on schedule. They walk real routes through the town graph
## (SimTown), chat with whoever is near, and build or lose friendship, romance and respect.

const NEEDS: Array[String] = ["hunger", "energy", "social", "fun"]
## Decay per minute (docs/SIMULATION.md lists per hour: hunger 6, energy 4, social 5, fun 4).
const DECAY := {"hunger": 0.1, "energy": 0.0667, "social": 0.0833, "fun": 0.0667}
const SLEEP_RECOVERY := 0.2
const CHAT_RANGE := 4.0
const PLAYER := "player"           ## grievances against the Administrator use this as the target
const WISH_PATIENCE := 28          ## days before an ignored wish turns into a grievance
const SAME_PLACE := 1.6


## Keeps simulation numbers on a binary grid (multiples of 1/1024), so snapshots written as JSON read
## back bit for bit and a restored town carries on exactly as the original would have.
static func q(x: float) -> float:
	return roundf(x * 1024.0) / 1024.0

var rng: SimRng
var ticks: int = 0
var seed_value: int = 0
var day: int = 0
var minute: int = 0
var town: SimTown
var data: Dictionary = {}          ## data/residents.json
var residents: Dictionary = {}     ## id -> resident state
var households: Dictionary = {}    ## id -> {name, home, money, weekly}
var relationships: Dictionary = {} ## "a>b" -> {friendship, romance, respect}
var grievances: Array = []         ## {owner, target, reason, weight, day}
var secrets: Dictionary = {}
var home_scores: Dictionary = {}   ## house id -> average home score (0 to 100), for mood
var events: Array = []             ## recent notable things, newest last: {day, minute, who, text}
var wishes: Dictionary = {}        ## id -> {owner, household, text, since (day, or -1 while homeless), met (day or -1), nagged}
var incidents: Array = []          ## {id, tile: [x, y], from, to (ticks), label}: anyone near during the window is notable
var next_memory: int = 0
var raining := false               ## set by the host from the weather
var rain_minutes: int = 0          ## minutes of rain so far (bootprints wash out after 6 hours of it)
var last_rain_tick: int = -100000
var traces: Dictionary = {}        ## "x,y" -> bootprints (Traces)
var records: Dictionary = {"time_cards": [], "ledger": [], "exchange": []}  ## the town's paperwork
var _light: LightGrid
var _light_tick := -1
var dropped: Array = []            ## things dropped where they shouldn't be: {item, owner, tile: [x, y], day, minute, tick}
var latch_until_day: int = -1      ## after a crime the town latches its windows until this day (docs/CRIME_DIRECTOR.md "Consequences")
var collected: int = 0             ## rent paid to the town and not yet banked by the host
var trust_change: int = 0          ## Town Trust earned or lost and not yet banked by the host


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	rng = SimRng.new(p_seed)


static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/residents.json")) as Dictionary


## Sets up the town and its people. homes: household id -> house id for households living here;
## households without a home stay away (not simulated) until they move in.
func setup(p_town: SimTown, p_data: Dictionary, homes: Dictionary, start_day: int = 0, start_minute: int = 360) -> void:
	town = p_town
	data = p_data
	day = start_day
	minute = start_minute
	var hh: Dictionary = data["households"]
	var hkeys := hh.keys()
	hkeys.sort()
	for hid: String in hkeys:
		var h: Dictionary = (hh[hid] as Dictionary).duplicate(true)
		h["home"] = str(homes.get(hid, ""))
		households[hid] = h
	var rs: Dictionary = data["residents"]
	var rkeys := rs.keys()
	rkeys.sort()
	for rid: String in rkeys:
		var d: Dictionary = rs[rid]
		var r := {"id": rid, "first": d["first"], "last": d["last"], "age": int(d["age"]), "sex": d["sex"], "household": d["household"],
			"job": d["job"], "traits": (d["traits"] as Array).duplicate(), "needs": {}, "mood": 70.0, "pos": [], "house": "",
			"action": {"kind": "idle"}, "route": [], "walk_start": 0, "status": "away", "memories": []}
		for n in NEEDS:
			r["needs"][n] = q(60.0 + rng.randf_range(0.0, 30.0))
		residents[rid] = r
		move_in(rid)
	for rel: Dictionary in data.get("relationships", []):
		var k := "%s>%s" % [rel["a"], rel["b"]]
		relationships[k] = {"friendship": float(rel.get("friendship", 0)), "romance": float(rel.get("romance", 0)), "respect": float(rel.get("respect", 0))}
	for g: Dictionary in data.get("grievances", []):
		grievances.append(g.duplicate())
	secrets = (data.get("secrets", {}) as Dictionary).duplicate(true)
	for w: Dictionary in data.get("wishes", []):
		var owner := str(w["owner"])
		if not residents.has(owner):
			continue
		var hid := str(residents[owner]["household"])
		wishes[str(w["id"])] = {"owner": owner, "household": hid, "text": str(w["text"]),
			"since": day if str(households[hid].get("home", "")) != "" else -1, "met": -1, "nagged": false}


## Puts a resident at home if their household has one; otherwise they're away.
func move_in(rid: String) -> void:
	var r: Dictionary = residents[rid]
	var home := str((households[r["household"]] as Dictionary).get("home", ""))
	if home == "" or not town.homes.has(home):
		r["status"] = "away"
		return
	r["status"] = "living"
	var spot: Array = (town.homes[home] as Dictionary).get("living", [])
	if spot.is_empty():
		r["status"] = "away"
		return
	r["pos"] = spot.duplicate()
	r["house"] = home
	r["action"] = {"kind": "idle"}


func home_of(rid: String) -> String:
	return str((households[(residents[rid] as Dictionary)["household"]] as Dictionary).get("home", ""))


func has_trait(rid: String, t: String) -> bool:
	return ((residents[rid] as Dictionary)["traits"] as Array).has(t)


func rel(a: String, b: String) -> Dictionary:
	var k := "%s>%s" % [a, b]
	if not relationships.has(k):
		relationships[k] = {"friendship": 0.0, "romance": 0.0, "respect": 0.0}
	return relationships[k]


## The label the UI shows for how a feels about b.
func rel_label(a: String, b: String) -> String:
	var r := rel(a, b)
	if float(r["romance"]) >= 50.0:
		return "Sweethearts"
	var f := float(r["friendship"])
	if f >= 60.0:
		return "Close friend"
	if f >= 30.0:
		return "Friend"
	if f <= -60.0:
		return "Enemy"
	if f <= -30.0:
		return "Wary"
	return "Neutral"


func log_event(who: String, text: String) -> void:
	# The same news twice in a day is still the same news.
	for i in range(events.size() - 1, maxi(-1, events.size() - 30), -1):
		var e: Dictionary = events[i]
		if int(e["day"]) != day:
			break
		if str(e["who"]) == who and str(e["text"]) == text:
			return
	events.append({"day": day, "minute": minute, "who": who, "text": text})
	if events.size() > 200:
		events.pop_front()


# --- Tick ----------------------------------------------------------------------------------------

func tick() -> void:
	ticks += 1
	minute += 1
	if minute >= 1440:
		minute = 0
		day += 1
		_new_day()
	if town == null:
		return
	var ids := residents.keys()
	ids.sort()
	for rid: String in ids:
		var r: Dictionary = residents[rid]
		if r["status"] != "living":
			continue
		_decay(r)
		_step(r)
	_socialise(ids)
	if raining:
		rain_minutes += 1
		last_rain_tick = ticks
	if minute % 60 == 0:
		Traces.fade(self)
	if town.sight != null:
		Memories.observe(self)


func run_ticks(n: int) -> void:
	for i in n:
		tick()


func _decay(r: Dictionary) -> void:
	var needs: Dictionary = r["needs"]
	var asleep: bool = str((r["action"] as Dictionary).get("kind", "")) == "sleep" and (r["route"] as Array).is_empty()
	for n in NEEDS:
		var d := float(DECAY[n])
		if n == "social":
			if (r["traits"] as Array).has("lonely"):
				d *= 1.5
			if (r["traits"] as Array).has("shy"):
				d *= 0.7
		if n == "energy" and asleep:
			needs[n] = q(minf(100.0, float(needs[n]) + SLEEP_RECOVERY))
			continue
		if asleep and n != "hunger":
			continue
		needs[n] = q(maxf(0.0, float(needs[n]) - d * (0.5 if asleep else 1.0)))
	var avg := 0.0
	for n2 in NEEDS:
		avg += float(needs[n2])
	avg /= NEEDS.size()
	var home_s := float(home_scores.get(home_of(r["id"]), 60.0))
	var boost := 20.0 if int(r.get("boost_until", -1)) > day else 0.0
	r["mood"] = q(lerpf(float(r["mood"]), minf(100.0, avg * 0.75 + home_s * 0.25 + boost), 0.02))


## One minute of a resident: walk on, carry on with the action, or choose the next thing to do.
func _step(r: Dictionary) -> void:
	var act: Dictionary = r["action"]
	if not r["route"].is_empty():
		var walked := float(ticks - int(r["walk_start"])) * SimTown.WALK_M_PER_MIN
		var length := SimTown.route_length(r["route"])
		if town.grid != null:
			Traces.walk(self, r, walked - SimTown.WALK_M_PER_MIN, minf(walked, length))
		if walked >= length:
			r["pos"] = (r["route"][r["route"].size() - 1] as Array).duplicate()
			r["route"] = []
			act["until"] = ticks + int(act.get("minutes", 30))
		else:
			r["pos"] = SimTown.along(r["route"], walked)
			return
	var kind := str(act.get("kind", "idle"))
	if kind != "idle":
		if kind == "work" and str(act.get("place", "")) == "lm_mill" and not act.get("clocked", false):
			act["clocked"] = true
			_record("time_cards", {"rid": r["id"], "day": day, "in": minute, "out": -1})
		_satisfy(r, act)
		if ticks < int(act.get("until", 0)) and not _interrupted(r, act):
			return
		_finished(r, act)
		act["kind"] = "idle"
	_choose(r)


func _satisfy(r: Dictionary, act: Dictionary) -> void:
	var needs0: Dictionary = r["needs"]
	if str(act["kind"]) == "work":
		# Crib at midday, and the people you deal with at work.
		if minute >= 12 * 60 and minute < 12 * 60 + 30:
			needs0["hunger"] = q(minf(100.0, float(needs0["hunger"]) + 1.5))
		needs0["social"] = q(minf(100.0, float(needs0["social"]) + 0.05))
	var adv: Dictionary = act.get("advert", {})
	var mins := maxf(1.0, float(act.get("minutes", 30)))
	for n: String in adv:
		if n == "energy" and str(act["kind"]) == "sleep":
			continue
		var needs: Dictionary = r["needs"]
		needs[n] = q(minf(100.0, float(needs[n]) + float(adv[n]) / mins))


## Paperwork when something's done: a mill hand clocks off; a shopper's purchases go in the
## store's ledger, and now and then they ring somebody from the store's telephone.
func _finished(r: Dictionary, act: Dictionary) -> void:
	var kind := str(act["kind"])
	if kind == "work" and act.get("clocked", false):
		var cards: Array = records["time_cards"]
		for i in range(cards.size() - 1, -1, -1):
			if cards[i]["rid"] == r["id"] and int(cards[i]["out"]) < 0:
				cards[i]["out"] = minute
				break
	elif kind == "shop" and str(town.place(str(act.get("place", ""))).get("house", "")) != home_of(str(r["id"])):
		var h := absi(hash("%s|%d" % [r["id"], ticks]))
		var goods := ["tea and sugar", "flour and lard", "a tin of Bushells", "kerosene", "tobacco", "a pound of butter", "matches and soap", "a bag of oats"]
		_record("ledger", {"day": day, "minute": minute, "rid": r["id"], "household": r["household"], "goods": goods[h % goods.size()], "pence": 12 + (h >> 3) % 96})
		if h % 4 == 0 and _operator() != "":
			_record("exchange", {"day": day, "minute": minute, "caller": r["id"], "from": "the store", "to": _ring_whom(r), "operator": _operator()})


## Who somebody rings: their best friend outside the house, or a trunk call to Benalla.
func _ring_whom(r: Dictionary) -> String:
	var best := ""
	var best_f := 30.0
	var keys := relationships.keys()
	keys.sort()
	for k: String in keys:
		if not k.begins_with(str(r["id"]) + ">"):
			continue
		var other := k.substr(str(r["id"]).length() + 1)
		if not residents.has(other) or residents[other]["household"] == r["household"]:
			continue
		var f := float(relationships[k]["friendship"])
		if f > best_f:
			best_f = f
			best = other
	if best == "":
		return "Benalla (trunk call)"
	return "%s %s" % [residents[best]["first"], residents[best]["last"]]


func _operator() -> String:
	var ids := residents.keys()
	ids.sort()
	for rid: String in ids:
		var act: Dictionary = residents[rid]["action"]
		if str(act.get("kind", "")) == "work" and str(act.get("place", "")).ends_with("exchange") and (residents[rid]["route"] as Array).is_empty():
			return rid
	return ""


func _record(book: String, entry: Dictionary) -> void:
	var list: Array = records[book]
	list.append(entry)
	if list.size() > 500:
		list.remove_at(0)


## Work and sleep end on the clock; other things stop when something urgent comes up.
func _interrupted(r: Dictionary, act: Dictionary) -> bool:
	if act.get("hold", false):
		return false  # scripted (a demo, or the crime director): runs its full time
	var kind := str(act["kind"])
	if kind == "sleep":
		return minute == _wake(r)
	if kind == "work":
		return false
	return _should_sleep(r) or _work_now(r) and kind != "work"


# --- Choosing ------------------------------------------------------------------------------------

func _bed_time(r: Dictionary) -> int:
	if (r["traits"] as Array).has("night_owl"):
		return 0
	if (r["traits"] as Array).has("early_riser"):
		return 21 * 60
	return 22 * 60


func _wake(r: Dictionary) -> int:
	if (r["traits"] as Array).has("night_owl"):
		return 7 * 60 + 30
	if (r["traits"] as Array).has("early_riser"):
		return 5 * 60
	return 6 * 60 + 30


func _should_sleep(r: Dictionary) -> bool:
	var bed := _bed_time(r)
	var wake := _wake(r)
	if bed == 0:
		return minute < wake
	return minute >= bed or minute < wake


func _job(r: Dictionary) -> Dictionary:
	return (data["jobs"] as Dictionary).get(str(r["job"]), {})


func _work_now(r: Dictionary) -> bool:
	var j := _job(r)
	if j.is_empty() or (j.get("days", []) as Array).is_empty():
		return false
	var today := posmod(day, 7)
	var works := false
	for d: Variant in j["days"]:
		if int(d) == today:
			works = true
	if not works:
		return false
	return minute >= int(j["start"]) - 20 and minute < int(j["end"])


func _work_place(r: Dictionary) -> Dictionary:
	var j := _job(r)
	var where := str(j.get("place", ""))
	if where == "home":
		var living: Array = (town.homes.get(home_of(r["id"]), {}) as Dictionary).get("living", [])
		return {"id": "home", "at": living, "house": home_of(r["id"])} if not living.is_empty() else {}
	if where.begins_with("lm_"):
		return town.place(where)
	for p in town.places:
		if str(p.get("work", "")) == where:
			return p
	return {}


func _choose(r: Dictionary) -> void:
	var rid: String = r["id"]
	if _should_sleep(r):
		var beds: Array = (town.homes.get(home_of(rid), {}) as Dictionary).get("beds", [])
		var bed: Dictionary = town.place(beds[0]) if not beds.is_empty() else {}
		if bed.is_empty():
			var living: Array = (town.homes.get(home_of(rid), {}) as Dictionary).get("living", r["pos"])
			bed = {"id": "floor", "at": living, "house": home_of(rid)}
		_go(r, {"kind": "sleep", "place": bed["id"], "minutes": _minutes_until(_wake(r))}, bed["at"], str(bed.get("house", "")))
		return
	if _work_now(r):
		var wp := _work_place(r)
		if not wp.is_empty():
			var j := _job(r)
			_go(r, {"kind": "work", "place": wp["id"], "minutes": maxi(10, int(j["end"]) - minute)}, wp["at"], str(wp.get("house", "")))
			return
	# Utility: what the places on offer would do for this resident's needs, nearer is better.
	var cands: Array = []
	var home := home_of(rid)
	for p in town.places:
		var kind := str(p["kind"])
		if kind in ["bed", "work", "exchange"]:
			continue
		if str(p.get("house", "")) != "" and str(p["house"]) != home and kind != "shop":
			continue
		if kind == "fish" and not (has_trait(rid, "night_owl") or has_trait(rid, "early_riser") or minute >= 15 * 60):
			continue
		var s := _score(r, p["advert"])
		if s <= 0.0:
			continue
		if kind == "shop" and float((households[r["household"]] as Dictionary).get("money", 0)) <= 0.0:
			continue
		var dist := Vector2(float(p["at"][1]), float(p["at"][2])).distance_to(Vector2(float(r["pos"][1]), float(r["pos"][2])))
		cands.append({"score": s / (1.0 + dist / 60.0), "kind": kind, "place": p})
	# Visiting a friend who's at home.
	var social_need := 100.0 - float(r["needs"]["social"])
	if social_need > 25.0 and minute >= 8 * 60 and minute < 20 * 60:
		var others := residents.keys()
		others.sort()
		for oid: String in others:
			if oid == rid or (residents[oid] as Dictionary)["status"] != "living":
				continue
			var f := float(rel(rid, oid)["friendship"])
			var oh := home_of(oid)
			if f < 30.0 or oh == home or str((residents[oid] as Dictionary)["house"]) != oh:
				continue
			var m := 1.0
			if has_trait(rid, "kind"):
				m *= 1.2
			if has_trait(rid, "gossip") or has_trait(rid, "nosy"):
				m *= 1.3
			if has_trait(rid, "shy"):
				m *= 0.5
			var living: Array = (town.homes.get(oh, {}) as Dictionary).get("living", [])
			if living.is_empty():
				continue
			var dist2 := Vector2(float(living[1]), float(living[2])).distance_to(Vector2(float(r["pos"][1]), float(r["pos"][2])))
			cands.append({"score": social_need / 100.0 * 40.0 * m * (f / 60.0) / (1.0 + dist2 / 60.0), "kind": "visit",
				"place": {"id": "visit:" + oid, "at": living, "house": oh, "advert": {"social": 40.0}, "minutes": 60}, "friend": oid})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and str(a["place"]["id"]) < str(b["place"]["id"])))
	if cands.is_empty() or float(cands[0]["score"]) < 3.0:
		# Pottering about at home.
		var living2: Array = (town.homes.get(home, {}) as Dictionary).get("living", r["pos"])
		_go(r, {"kind": "potter", "place": "home", "minutes": 20 + rng.randi_range(0, 25)}, living2, home)
		return
	var top: Array = cands.slice(0, 3)
	var weights: Array[float] = []
	for c in top:
		weights.append(float(c["score"]))
	var pick: Dictionary = top[maxi(0, rng.weighted_index(weights))]
	var pl: Dictionary = pick["place"]
	var act := {"kind": pick["kind"], "place": pl["id"], "minutes": int(pl.get("minutes", 30)), "advert": pl["advert"]}
	if pick.has("friend"):
		act["friend"] = pick["friend"]
		log_event(rid, "%s went to visit %s." % [r["first"], (residents[pick["friend"]] as Dictionary)["first"]])
	if str(pick["kind"]) == "shop":
		var hh: Dictionary = households[r["household"]]
		hh["money"] = float(hh["money"]) - 1.0
	_go(r, act, pl["at"], str(pl.get("house", "")))


func _score(r: Dictionary, advert: Dictionary) -> float:
	var s := 0.0
	for n: String in advert:
		var deficit := 100.0 - float((r["needs"] as Dictionary).get(n, 100.0))
		var m := 1.0
		if n == "social" and (r["traits"] as Array).has("lonely"):
			m = 1.5
		s += deficit / 100.0 * float(advert[n]) * m
	return s


func _minutes_until(target: int) -> int:
	return posmod(target - minute, 1440)


## Sets off for a place: a route through the town, then the action once there.
func _go(r: Dictionary, act: Dictionary, at: Array, house: String) -> void:
	if at.is_empty():
		act["until"] = ticks + 15
		r["action"] = act
		return
	var route := town.route(r["pos"], at, str(r["house"]), house)
	r["action"] = act
	r["house"] = house
	if route.size() <= 1:
		r["pos"] = at.duplicate() if route.is_empty() else (route[0] as Array).duplicate()
		r["route"] = []
		act["until"] = ticks + int(act.get("minutes", 30))
		return
	r["route"] = route
	r["walk_start"] = ticks


# --- People together -----------------------------------------------------------------------------

## Residents near each other chat: social rises, friendship grows (faster for the Kind), sweethearts
## grow fonder. Only people on the same storey and within a few metres, awake and not walking.
func _socialise(ids: Array) -> void:
	var here: Array = []
	for rid: String in ids:
		var r: Dictionary = residents[rid]
		if r["status"] != "living" or not r["route"].is_empty() or str(r["action"].get("kind", "")) == "sleep" or r["pos"].is_empty():
			continue
		here.append(r)
	for i in here.size():
		var a: Dictionary = here[i]
		for j in range(i + 1, here.size()):
			var b: Dictionary = here[j]
			if int(a["pos"][0]) != int(b["pos"][0]):
				continue
			if Vector2(float(a["pos"][1]), float(a["pos"][2])).distance_to(Vector2(float(b["pos"][1]), float(b["pos"][2]))) > CHAT_RANGE:
				continue
			_chat(a, b)
			_chat(b, a)


func _chat(a: Dictionary, b: Dictionary) -> void:
	var needs: Dictionary = a["needs"]
	needs["social"] = q(minf(100.0, float(needs["social"]) + 0.25))
	var r := rel(a["id"], b["id"])
	var gain := 0.02 * (1.5 if (a["traits"] as Array).has("kind") else 1.0)
	if _grievance_weight(a["id"], b["id"]) > 20.0:
		gain = -0.01
	r["friendship"] = q(clampf(float(r["friendship"]) + gain, -100.0, 100.0))
	if float(r["romance"]) >= 30.0:
		r["romance"] = q(clampf(float(r["romance"]) + 0.01, 0.0, 100.0))
	if (a["traits"] as Array).has("gossip"):
		Memories.gossip(self, a, b)


func _grievance_weight(owner: String, target: String) -> float:
	var w := 0.0
	for g: Dictionary in grievances:
		if str(g["owner"]) == owner and str(g["target"]) == target:
			w += float(g["weight"])
	return w


func add_grievance(owner: String, target: String, reason: String, weight: float) -> void:
	grievances.append({"owner": owner, "target": target, "reason": reason, "weight": clampf(weight, 0.0, 100.0), "day": day})
	var who := "the Administrator" if target == PLAYER else str((residents[target] as Dictionary)["first"])
	log_event(owner, "%s has a grievance against %s: %s." % [(residents[owner] as Dictionary)["first"], who, reason])


## Midnight: grievances fade (2 a day), wages and household costs on Mondays.
func _new_day() -> void:
	var keep: Array = []
	for g: Dictionary in grievances:
		g["weight"] = float(g["weight"]) - (4.0 if g.get("amends", false) else 2.0)
		if float(g["weight"]) > 0.0:
			keep.append(g)
	grievances = keep
	Memories.decay(self)
	if posmod(day, 7) == 0:
		weekly_economy()


## Wages in, rent and groceries out, for every household living here.
func weekly_economy() -> void:
	var hids := households.keys()
	hids.sort()
	for hid: String in hids:
		var h: Dictionary = households[hid]
		if str(h.get("home", "")) == "":
			continue
		var income := float(h.get("weekly", 0))
		var members := 0
		for rid: String in residents:
			var r: Dictionary = residents[rid]
			if str(r["household"]) == hid and r["status"] == "living":
				members += 1
				income += float(_job(r).get("wage", 0))
		var rent_w := int(h.get("rent", 0))
		collected += rent_w
		h["money"] = q(float(h["money"]) + income - 3.0 - members * 1.5 - rent_w)
		h["last_week"] = {"income": income, "costs": 3.0 + members * 1.5 + rent_w, "rent": rent_w}


## Sends somebody somewhere to do something for a while, whatever the hour (scripted events and,
## later, the crime director). The action isn't cut short by bedtime or work.
func direct(rid: String, at: Array, house: String, kind: String, minutes: int, carrying: String = "") -> void:
	var r: Dictionary = residents[rid]
	r["carrying"] = carrying
	_go(r, {"kind": kind, "place": "", "minutes": minutes, "hold": true}, at, house)


# --- Light and incidents ----------------------------------------------------------------------

## The logical light this minute: rooms with their lamps lit where somebody's awake in them.
func light_now() -> LightGrid:
	if _light != null and _light_tick == ticks:
		return _light
	var occupied := {}
	var ids := residents.keys()
	ids.sort()
	for rid: String in ids:
		var r: Dictionary = residents[rid]
		if r["status"] != "living" or (r["pos"] as Array).is_empty() or int(r["pos"][0]) != 0 or not Memories.state(r)["awake"]:
			continue
		var room := town.sight.room_at(Memories.tile_of(r))
		if room != "":
			occupied[room] = true
	_light = LightGrid.compute(town.sight, day, minute, raining, occupied)
	_light_tick = ticks
	return _light


## Something happening at a place for a while (the crime director's doing, or a scripted event):
## anyone seen within 9 m of it in that time is remembered as being there.
func add_incident(id: String, tile: Vector2i, minutes: int, label: String) -> void:
	incidents.append({"id": id, "tile": [tile.x, tile.y], "from": ticks, "to": ticks + minutes, "label": label})


# --- Homes -----------------------------------------------------------------------------------------

## Who lives in a household (living here now).
func members(hid: String) -> Array[String]:
	var out: Array[String] = []
	var ids := residents.keys()
	ids.sort()
	for rid: String in ids:
		if str(residents[rid]["household"]) == hid:
			out.append(rid)
	return out


## A household moves into a house, with how they took it (HomeLife.reaction): mood, rent, the log.
func move_household(hid: String, house: String, reaction: Dictionary) -> void:
	var h: Dictionary = households[hid]
	h["home"] = house
	h["rent"] = int(reaction.get("rent", 0))
	var verdict := str(reaction.get("verdict", "content"))
	var v: Dictionary = HomeLife.VERDICTS.get(verdict, HomeLife.VERDICTS["content"])
	var ids := members(hid)
	for rid in ids:
		var r: Dictionary = residents[rid]
		move_in(rid)
		r["mood"] = q(clampf(float(r["mood"]) + float(v["mood"]), 0.0, 100.0))
	for wid: String in wishes:
		var w: Dictionary = wishes[wid]
		if str(w["household"]) == hid and int(w["since"]) < 0:
			w["since"] = day
	if not ids.is_empty():
		log_event(ids[0], "The %ss moved in. %s" % [h["name"], v["say"]])
		if verdict == "disappointed":
			var cons: Array = reaction.get("cons", [])
			add_grievance(ids[0], PLAYER, str(cons[0]).to_lower() if not cons.is_empty() else "the house", 15.0)
	if reaction.has("scores"):
		home_scores[house] = q(HomeLife.average(reaction["scores"]))


## The host's daily look at each home: {house: {score (average), wishes_met: [wish ids]}}.
## Met wishes lift the owner's mood for a week and earn Town Trust; ignored ones turn sour.
func review_homes(report: Dictionary) -> void:
	var hkeys := report.keys()
	hkeys.sort()
	for house: String in hkeys:
		home_scores[house] = q(float((report[house] as Dictionary).get("score", 60.0)))
	var wkeys := wishes.keys()
	wkeys.sort()
	for wid: String in wkeys:
		var w: Dictionary = wishes[wid]
		var home := str(households[w["household"]].get("home", ""))
		if home == "" or int(w["met"]) >= 0 or int(w["since"]) < 0:
			continue
		var met: Array = (report.get(home, {}) as Dictionary).get("wishes_met", [])
		var owner: Dictionary = residents[w["owner"]]
		if met.has(wid):
			w["met"] = day
			owner["boost_until"] = day + 7
			trust_change += 1
			log_event(str(w["owner"]), "%s's wish came true: %s." % [owner["first"], str(w["text"]).to_lower()])
		elif not w["nagged"] and day - int(w["since"]) >= WISH_PATIENCE:
			w["nagged"] = true
			add_grievance(str(w["owner"]), PLAYER, "still waiting for %s" % str(w["text"]).to_lower(), 10.0)


# --- Snapshot ------------------------------------------------------------------------------------

func snapshot() -> Dictionary:
	return {"seed": seed_value, "ticks": ticks, "rng": rng.snapshot(), "day": day, "minute": minute,
		"residents": residents.duplicate(true), "households": households.duplicate(true), "relationships": relationships.duplicate(true),
		"grievances": grievances.duplicate(true), "secrets": secrets.duplicate(true), "events": events.duplicate(true), "home_scores": home_scores.duplicate(),
		"wishes": wishes.duplicate(true), "collected": collected, "trust_change": trust_change,
		"incidents": incidents.duplicate(true), "next_memory": next_memory, "raining": raining, "rain_minutes": rain_minutes,
		"last_rain_tick": last_rain_tick, "latch_until_day": latch_until_day, "dropped": dropped.duplicate(true), "traces": traces.duplicate(true), "records": records.duplicate(true)}


func restore(d: Dictionary) -> void:
	seed_value = int(d.get("seed", 0))
	ticks = int(d.get("ticks", 0))
	rng.restore(d.get("rng", {}))
	day = int(d.get("day", 0))
	minute = int(d.get("minute", 0))
	residents = (d.get("residents", {}) as Dictionary).duplicate(true)
	households = (d.get("households", {}) as Dictionary).duplicate(true)
	relationships = (d.get("relationships", {}) as Dictionary).duplicate(true)
	grievances = (d.get("grievances", []) as Array).duplicate(true)
	secrets = (d.get("secrets", {}) as Dictionary).duplicate(true)
	events = (d.get("events", []) as Array).duplicate(true)
	home_scores = (d.get("home_scores", {}) as Dictionary).duplicate()
	wishes = (d.get("wishes", {}) as Dictionary).duplicate(true)
	collected = int(d.get("collected", 0))
	trust_change = int(d.get("trust_change", 0))
	incidents = (d.get("incidents", []) as Array).duplicate(true)
	next_memory = int(d.get("next_memory", 0))
	raining = bool(d.get("raining", false))
	rain_minutes = int(d.get("rain_minutes", 0))
	last_rain_tick = int(d.get("last_rain_tick", -100000))
	latch_until_day = int(d.get("latch_until_day", -1))
	dropped = (d.get("dropped", []) as Array).duplicate(true)
	traces = (d.get("traces", {}) as Dictionary).duplicate(true)
	records = (d.get("records", {"time_cards": [], "ledger": [], "exchange": []}) as Dictionary).duplicate(true)
	_light = null
