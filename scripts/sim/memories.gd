class_name Memories
extends RefCounted
## What residents see, hear and are told (docs/SIMULATION.md "Memories"). Run by the Sim each
## minute, deterministically. Only notable things are remembered: somebody in a house that isn't
## theirs, out late, carrying something, or near an incident while it happens; lights on at odd
## hours; noises. Memories fade 0.05 a day and go below 0.2; gossips pass them on at 0.6 confidence.
##
## Memory: {id, day, minute, kind (saw_person | heard_noise | saw_light | saw_object | was_told),
##   subject, tile: [x, y], place, detail, confidence, source (firsthand | rumour), from, about, keep}

const RANGE := 18.0
const NOISE_AWAKE := 15.0
const NOISE_ASLEEP := 6.0
const INCIDENT_RANGE := 9.0
const LIGHT_RANGE := 15.0
const DECAY := 0.05
const FORGET := 0.2
const CAP := 200
const RUMOUR := 0.6
const LATE_FROM := 22 * 60
const LATE_TO := 5 * 60
const ODD_LIGHT_FROM := 23 * 60
const PUBLIC: Array[String] = ["shop", "store", "exchange", "hotel", "bar", "church", "hall"]
const LANDMARK_NAMES := {"lm_mill": "the mill", "lm_siding": "the siding", "plot_store": "the store", "lm_old_town": "the old town"}


## "high", "medium" or "low".
static func confidence_word(c: float) -> String:
	return "high" if c >= 0.7 else "medium" if c >= 0.45 else "low"


## A memory in words, as the resident would put it: "Saw Frank Hayward carrying a cash tin, outside
## the General store."
static func describe(sim: Sim, m: Dictionary) -> String:
	var who := ""
	if str(m.get("subject", "")) != "" and sim.residents.has(m["subject"]):
		var s: Dictionary = sim.residents[m["subject"]]
		who = "%s %s" % [s["first"], s["last"]]
	var place := str(m.get("place", ""))
	var kind := str(m.get("told_kind", m["kind"])) if m["kind"] == "was_told" else str(m["kind"])
	var text := ""
	match kind:
		"saw_person":
			text = "Saw %s %s, %s." % [who if who != "" else "somebody", m["detail"], place]
		"saw_light":
			text = "Saw %s." % m["detail"]
		"heard_noise":
			text = "Heard %s, %s." % [m["detail"], place]
		_:
			text = "Saw %s, %s." % [m["detail"], place]
	if m["kind"] == "was_told":
		var from: Dictionary = sim.residents.get(m.get("from", ""), {})
		text = "%s says she %s" % [from.get("first", "Somebody"), text.substr(0, 1).to_lower() + text.substr(1)] if str(from.get("sex", "m")) == "f" else "%s says he %s" % [from.get("first", "Somebody"), text.substr(0, 1).to_lower() + text.substr(1)]
	return text


static func tile_of(r: Dictionary) -> Vector2i:
	var p: Array = r["pos"]
	return Vector2i(floori(float(p[1])), floori(float(p[2])))


static func late(minute: int, from: int = LATE_FROM) -> bool:
	return minute >= from or minute < LATE_TO


## How an observer is placed to notice things: awake, busy with something absorbing, traits.
static func state(r: Dictionary) -> Dictionary:
	var act: Dictionary = r["action"]
	var kind := str(act.get("kind", ""))
	var walking := not (r["route"] as Array).is_empty()
	var traits: Array = r["traits"]
	return {"awake": walking or kind != "sleep", "focused": not walking and (kind == "cook" or (kind == "work" and str(act.get("place", "")).ends_with("exchange"))),
		"observant": traits.has("observant"), "elderly": int(r["age"]) >= 65, "drunk": bool(r.get("drunk", false))}


## Words for where a tile is: "the Pikes' cottage, kitchen", "near the mill", "outside the store".
static func place_label(sim: Sim, t: Vector2i) -> String:
	var sight := sim.town.sight
	var rid := sight.room_at(t)
	if rid != "":
		var room: Dictionary = sight.rooms[rid]
		var hn := str(sight.house_names.get(room["house"], ""))
		return "%s, %s" % [hn if hn != "" else "a house", room["name"]]
	var best := ""
	var best_d := 20.0
	var lids := sim.town.landmark_tiles.keys()
	lids.sort()
	for lid: String in lids:
		var at: Array = sim.town.landmark_tiles[lid]
		var d := Vector2(t).distance_to(Vector2(float(at[1]), float(at[2])))
		if d < best_d and LANDMARK_NAMES.has(lid):
			best_d = d
			best = "near %s" % LANDMARK_NAMES[lid]
	var hids := sim.town.homes.keys()
	hids.sort()
	for hid: String in hids:
		var door: Array = (sim.town.homes[hid] as Dictionary).get("living", [])
		if door.is_empty():
			continue
		var d2 := Vector2(t).distance_to(Vector2(float(door[1]), float(door[2])))
		if d2 < minf(best_d, 12.0):
			best_d = d2
			var hn2 := str(sim.town.sight.house_names.get(hid, ""))
			best = "outside %s" % (hn2 if hn2 != "" else "a house")
	return best if best != "" else "out on the flat"


## Why somebody would stick in a witness's mind this minute, or "".
static func notable(sim: Sim, r: Dictionary) -> String:
	var t := tile_of(r)
	for inc: Dictionary in sim.incidents:
		if sim.ticks >= int(inc["from"]) and sim.ticks <= int(inc["to"]) and Vector2(t).distance_to(Vector2(float(inc["tile"][0]), float(inc["tile"][1]))) <= INCIDENT_RANGE:
			return "near %s" % inc["label"]
	if str(r.get("carrying", "")) != "":
		return "carrying %s" % r["carrying"]
	var sight := sim.town.sight
	var rid := sight.room_at(t)
	if rid != "":
		var room: Dictionary = sight.rooms[rid]
		var house := str(room["house"])
		if house != sim.home_of(str(r["id"])) and not _public(str(room["name"])):
			var hn := str(sight.house_names.get(house, "somebody's house"))
			return ("visiting at %s" if str((r["action"] as Dictionary).get("kind", "")) == "visit" else "inside %s") % hn
		return ""
	if late(sim.minute) and state(r)["awake"]:
		return "out late"
	return ""


static func _public(room_name: String) -> bool:
	for p: String in PUBLIC:
		if room_name.contains(p):
			return true
	return false


## Each minute: everyone who's notable is checked against everyone awake nearby (an 18 m spatial
## hash), and the ones who can see them remember it. Lights on at odd hours too.
static func observe(sim: Sim) -> void:
	var ids := sim.residents.keys()
	ids.sort()
	var here: Array[String] = []
	var marks := {}
	for rid: String in ids:
		var r: Dictionary = sim.residents[rid]
		if r["status"] != "living" or (r["pos"] as Array).is_empty() or int(r["pos"][0]) != 0:
			continue
		here.append(rid)
		var why := notable(sim, r)
		if why != "":
			marks[rid] = why
	if here.is_empty():
		return
	var light: LightGrid = null
	if not marks.is_empty():
		light = sim.light_now()
		var cells := {}
		for rid in here:
			var t := tile_of(sim.residents[rid])
			var ck := Vector2i(floori(t.x / RANGE), floori(t.y / RANGE))
			if not cells.has(ck):
				cells[ck] = []
			(cells[ck] as Array).append(rid)
		for tid: String in marks:
			var target: Dictionary = sim.residents[tid]
			var tt := tile_of(target)
			var c := Vector2i(floori(tt.x / RANGE), floori(tt.y / RANGE))
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					for oid: String in cells.get(c + Vector2i(dx, dy), []):
						if oid == tid:
							continue
						var o: Dictionary = sim.residents[oid]
						var ot := tile_of(o)
						if Vector2(ot).distance_to(Vector2(tt)) > RANGE:
							continue
						var seen := sim.town.sight.look(ot, tt, state(o), light)
						if seen["seen"]:
							_saw(sim, o, "saw_person", tid, tt, str(marks[tid]), float(seen["confidence"]))
	if late(sim.minute, ODD_LIGHT_FROM):
		if light == null:
			light = sim.light_now()
		_odd_lights(sim, here, light)


## A light still on in somebody else's house in the small hours, seen through its window.
static func _odd_lights(sim: Sim, here: Array[String], light: LightGrid) -> void:
	if light.lit_rooms.is_empty():
		return
	var sight := sim.town.sight
	var rooms := light.lit_rooms.keys()
	rooms.sort()
	for oid in here:
		var o: Dictionary = sim.residents[oid]
		var st := state(o)
		if not st["awake"]:
			continue
		var ot := tile_of(o)
		for rid: String in rooms:
			var room: Dictionary = sight.rooms[rid]
			if str(room["house"]) == sim.home_of(oid) or sight.room_at(ot) == rid:
				continue
			for w: Dictionary in room["windows"]:
				var out: Vector2i = w["out"]
				var d := Vector2(ot).distance_to(Vector2(out))
				if d > LIGHT_RANGE or sight.curtains.has(str(w["edge"])):
					continue
				if sight.blocker(ot, out, false) == "":
					var hn := str(sight.house_names.get(room["house"], "a house"))
					_saw(sim, o, "saw_light", "", out, "a lamp still lit at %s" % hn, snappedf(0.9 - 0.3 * d / LIGHT_RANGE, 0.01))
					break


static func _saw(sim: Sim, o: Dictionary, kind: String, subject: String, t: Vector2i, detail: String, confidence: float) -> void:
	var mem: Array = o["memories"]
	# Once an hour is enough for the same thing.
	for i in range(mem.size() - 1, -1, -1):
		var m: Dictionary = mem[i]
		if (sim.day - int(m["day"])) * 1440 + sim.minute - int(m["minute"]) > 60:
			break
		if str(m["subject"]) == subject and str(m["detail"]) == detail and str(m["source"]) == "firsthand":
			return
	add(sim, o, {"kind": kind, "subject": subject, "tile": [t.x, t.y], "place": place_label(sim, t), "detail": detail, "confidence": confidence, "source": "firsthand"})


## Stores a memory (with an id, day and minute unless given), keeping the newest 200 that aren't
## held for an open case.
static func add(sim: Sim, o: Dictionary, m: Dictionary) -> void:
	sim.next_memory += 1
	var full := {"id": "m%d" % sim.next_memory, "day": sim.day, "minute": sim.minute, "subject": "", "detail": "", "place": "", "tile": [],
		"source": "firsthand", "confidence": 0.5}
	full.merge(m, true)
	full["confidence"] = Sim.q(clampf(float(full["confidence"]), 0.0, 1.0))
	var mem: Array = o["memories"]
	mem.append(full)
	if mem.size() > CAP:
		for i in mem.size():
			if not bool((mem[i] as Dictionary).get("keep", false)):
				mem.remove_at(i)
				break


## A noise (a smashed window, shouting, a dog): heard by anyone awake within 15 m, or asleep within
## 6 m, who wakes up.
static func noise(sim: Sim, t: Vector2i, detail: String) -> Array[String]:
	var heard: Array[String] = []
	var ids := sim.residents.keys()
	ids.sort()
	for rid: String in ids:
		var r: Dictionary = sim.residents[rid]
		if r["status"] != "living" or (r["pos"] as Array).is_empty():
			continue
		var d := Vector2(tile_of(r)).distance_to(Vector2(t))
		var awake: bool = state(r)["awake"]
		if (awake and d <= NOISE_AWAKE) or (not awake and d <= NOISE_ASLEEP):
			var c := 0.9 - 0.4 * d / NOISE_AWAKE if awake else 0.6
			add(sim, r, {"kind": "heard_noise", "tile": [t.x, t.y], "place": place_label(sim, t), "detail": detail, "confidence": c})
			heard.append(rid)
			if not awake:
				r["action"] = {"kind": "idle", "woken": true}
				sim.log_event(rid, "%s was woken by %s." % [r["first"], detail])
	return heard


## Midnight: everything fades a little; faint memories are forgotten unless held for a case.
static func decay(sim: Sim) -> void:
	for rid: String in sim.residents:
		var mem: Array = sim.residents[rid]["memories"]
		var keep: Array = []
		for m: Dictionary in mem:
			if bool(m.get("keep", false)):
				keep.append(m)
				continue
			m["confidence"] = Sim.q(float(m["confidence"]) - DECAY)
			if float(m["confidence"]) >= FORGET:
				keep.append(m)
		sim.residents[rid]["memories"] = keep


## A gossip passing on the newest thing they saw that the listener hasn't heard, once a day a pair.
static func gossip(sim: Sim, a: Dictionary, b: Dictionary) -> void:
	var told: Array = b["memories"]
	for m: Dictionary in told:
		if str(m.get("from", "")) == str(a["id"]) and int(m.get("heard_day", -1)) == sim.day:
			return
	var known := {}
	for m2: Dictionary in told:
		known[str(m2.get("about", m2["id"]))] = true
	var mem: Array = a["memories"]
	for i in range(mem.size() - 1, -1, -1):
		var m3: Dictionary = mem[i]
		if str(m3["source"]) != "firsthand" or float(m3["confidence"]) < 0.4 or known.has(str(m3["id"])) or str(m3["subject"]) == str(b["id"]):
			continue
		var r := m3.duplicate(true)
		r.erase("id")
		r.erase("keep")
		r["kind"] = "was_told"
		r["told_kind"] = m3["kind"]
		r["source"] = "rumour"
		r["from"] = a["id"]
		r["about"] = m3["id"]
		r["heard_day"] = sim.day
		r["heard_minute"] = sim.minute
		r["confidence"] = float(m3["confidence"]) * RUMOUR
		add(sim, b, r)
		return
