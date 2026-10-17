extends GutTest
## docs/SIMULATION.md "Memories": a scripted night produces the expected memory with the right
## confidence; walls hide things; noises wake light sleepers; memories fade and are forgotten;
## gossips pass things on at 0.6; incidents mark whoever is near; the cap holds.

static var _town: SimTown


func _sim() -> Sim:
	if _town == null:
		var slice := MapSlice.load_default()
		var hs: Array = DemoTown.houses()
		for l: Dictionary in slice.data["landmarks"]:
			if l["kind"] == "house":
				var a := HouseData.load_file(str(l["house"]))
				var o: Array = l["origin"]
				a.origin = Vector2i(int(o[0]), int(o[1]))
				hs.append(a)
		_town = SimTown.build(slice.grid, hs, slice.data["landmarks"], slice.creek_points)
	var s := Sim.new(1952)
	s.setup(_town, Sim.load_data(), DemoTown.homes(), 1, 23 * 60 + 30)
	return s


## Puts somebody at a tile, standing about (awake) or in bed.
func _put(s: Sim, rid: String, t: Vector2i, kind: String = "idle") -> void:
	var r: Dictionary = s.residents[rid]
	r["pos"] = [0, t.x + 0.5, t.y + 0.5]
	r["route"] = []
	r["action"] = {"kind": kind, "place": ""}
	r["memories"] = []


## A lamp-lit room of Agnes's with a bare window: the tile just inside and the way out.
func _agnes_window(s: Sim) -> Dictionary:
	var sight := s.town.sight
	var ids := sight.rooms.keys()
	ids.sort()
	for rid: String in ids:
		var room: Dictionary = sight.rooms[rid]
		if room["house"] != "lm_agnes_cottage" or int(room["lamps"]) == 0:
			continue
		for w: Dictionary in room["windows"]:
			if sight.curtains.has(str(w["edge"])):
				continue
			var out: Vector2i = w["out"]
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if sight.room_at(out + d) == rid:
					return {"room": rid, "inside": out + d, "out": out, "dir": -d}
	return {}


func _park_everyone(s: Sim) -> void:
	# Everyone else in bed at home, out of the way.
	for rid: String in s.residents:
		var r: Dictionary = s.residents[rid]
		var bed: Array = s.town.homes[s.home_of(rid)]["living"]
		r["pos"] = bed.duplicate()
		r["route"] = []
		r["action"] = {"kind": "sleep", "place": ""}
		r["memories"] = []


func test_scripted_night_memory() -> void:
	var s := _sim()
	_park_everyone(s)
	var w := _agnes_window(s)
	assert_false(w.is_empty(), "Agnes has a lamp-lit room with a bare window")
	# 11:30 pm: Agnes is up in her lit room; Frank goes past outside with a cash tin, 3 m off,
	# between her cottage and the store.
	_put(s, "r_agnes", w["inside"], "sit")
	var frank_at: Vector2i = w["out"] + (w["dir"] as Vector2i) * 2
	assert_eq(s.town.sight.room_at(frank_at), "", "Frank is outdoors")
	_put(s, "r_frank", frank_at)
	s.residents["r_frank"]["carrying"] = "a cash tin"
	Memories.observe(s)
	var mem: Array = s.residents["r_agnes"]["memories"]
	assert_eq(mem.size(), 1, "Agnes saw something")
	var m: Dictionary = mem[0] if not mem.is_empty() else {}
	assert_eq(m.get("kind"), "saw_person")
	assert_eq(m.get("subject"), "r_frank")
	assert_eq(m.get("detail"), "carrying a cash tin")
	assert_eq(m.get("source"), "firsthand")
	assert_eq([int(m.get("day", -1)), int(m.get("minute", -1))], [1, 23 * 60 + 30])
	# Confidence by the rules in docs/BUILDING.md: 0.9 less 0.4 x distance over the 9 m night range,
	# times the light (0.6 to 1), plus 0.2 for Observant, less 0.1 for elderly at night.
	var light := s.light_now()
	assert_true(light.lit_rooms.has(w["room"]), "her lamp is lit while she's up")
	var lux := light.at(frank_at)
	assert_gte(lux, SightMap.LIT, "Frank stands in her window light")
	var d := Vector2(w["inside"]).distance_to(Vector2(frank_at))
	var expected := (0.9 - 0.4 * d / SightMap.NIGHT_LIT_RANGE) * lerpf(0.6, 1.0, lux) + 0.2 - 0.1
	gut.p("Agnes: %s (expected %.3f at %.1f m, light %.2f)" % [m, expected, d, lux])
	assert_almost_eq(float(m.get("confidence", 0.0)), expected, 0.011)
	assert_string_contains(str(m.get("place", "")), "outside", "where Frank was")
	# Frank's household asleep saw nothing; nor did Frank see himself.
	assert_true((s.residents["r_edna"]["memories"] as Array).is_empty())
	# Again a minute later: one memory an hour of the same thing is enough.
	Memories.observe(s)
	assert_eq((s.residents["r_agnes"]["memories"] as Array).size(), 1)


func test_dark_and_walls_hide_things() -> void:
	var s := _sim()
	_park_everyone(s)
	var w := _agnes_window(s)
	# Out in the mill yard in the dark, 5 m apart: too dark to see. (By day, plain as anything.)
	_put(s, "r_agnes", Vector2i(30, 15))
	_put(s, "r_frank", Vector2i(35, 15))
	s.residents["r_frank"]["carrying"] = "a cash tin"
	s._light = null
	Memories.observe(s)
	assert_true((s.residents["r_agnes"]["memories"] as Array).is_empty(), "5 m in the dark is too far")
	s.minute = 12 * 60
	s._light = null
	Memories.observe(s)
	assert_eq((s.residents["r_agnes"]["memories"] as Array).size(), 1, "seen at noon")
	s.minute = 23 * 60 + 30
	s.residents["r_agnes"]["memories"] = []
	# Asleep in her lit room: nothing.
	_put(s, "r_agnes", w["inside"], "sleep")
	_put(s, "r_frank", (w["out"] as Vector2i) + (w["dir"] as Vector2i) * 2)
	s.residents["r_frank"]["carrying"] = "a cash tin"
	s._light = null
	Memories.observe(s)
	assert_true((s.residents["r_agnes"]["memories"] as Array).is_empty(), "asleep")


func test_noises_wake_light_sleepers() -> void:
	var s := _sim()
	_park_everyone(s)
	var w := _agnes_window(s)
	var at: Vector2i = (w["out"] as Vector2i) + (w["dir"] as Vector2i) * 4
	_put(s, "r_agnes", w["inside"], "sleep")
	_put(s, "r_davey", at + Vector2i(0, 12))
	_put(s, "r_len", at + Vector2i(9, 0), "sleep")
	var heard := Memories.noise(s, at, "glass breaking")
	assert_true(heard.has("r_agnes"), "asleep 4 m away, woken")
	assert_true(heard.has("r_davey"), "awake 12 m away")
	assert_false(heard.has("r_len"), "asleep 9 m away sleeps on")
	assert_eq(s.residents["r_agnes"]["action"]["kind"], "idle", "Agnes is up")
	assert_eq(s.residents["r_agnes"]["memories"][0]["kind"], "heard_noise")
	assert_eq(s.residents["r_agnes"]["memories"][0]["detail"], "glass breaking")


func test_memories_fade() -> void:
	var s := _sim()
	var r: Dictionary = s.residents["r_halina"]
	r["memories"] = []
	Memories.add(s, r, {"kind": "saw_person", "subject": "r_len", "detail": "out late", "confidence": 0.3})
	Memories.add(s, r, {"kind": "saw_person", "subject": "r_len", "detail": "near the store", "confidence": 0.3, "keep": true})
	Memories.decay(s)
	Memories.decay(s)
	assert_eq((r["memories"] as Array).size(), 2, "0.2 is still remembered")
	assert_almost_eq(float(r["memories"][0]["confidence"]), 0.2, 0.002)
	Memories.decay(s)
	assert_eq((r["memories"] as Array).size(), 1, "forgotten below 0.2, except what's held for a case")
	assert_true(bool(r["memories"][0]["keep"]))


func test_gossip_passes_things_on() -> void:
	var s := _sim()
	var marge: Dictionary = s.residents["r_marge"]
	var agnes: Dictionary = s.residents["r_agnes"]
	marge["memories"] = []
	agnes["memories"] = []
	Memories.add(s, marge, {"kind": "saw_person", "subject": "r_len", "detail": "out late", "place": "near the mill", "confidence": 0.8})
	Memories.gossip(s, marge, agnes)
	assert_eq((agnes["memories"] as Array).size(), 1)
	var m: Dictionary = agnes["memories"][0]
	assert_eq(m["kind"], "was_told")
	assert_eq(m["source"], "rumour")
	assert_eq(m["from"], "r_marge")
	assert_almost_eq(float(m["confidence"]), 0.48, 0.002, "x 0.6")
	assert_eq(m["detail"], "out late")
	Memories.add(s, marge, {"kind": "saw_person", "subject": "r_piotr", "detail": "out late", "confidence": 0.8})
	Memories.gossip(s, marge, agnes)
	assert_eq((agnes["memories"] as Array).size(), 1, "once a day is plenty")
	s.day += 1
	Memories.gossip(s, marge, agnes)
	assert_eq((agnes["memories"] as Array).size(), 2, "the next day, the next thing")
	Memories.gossip(s, agnes, marge)
	assert_eq((marge["memories"] as Array).size(), 2, "nobody's told what they told")


func test_incident_and_cap() -> void:
	var s := _sim()
	_park_everyone(s)
	s.minute = 14 * 60
	var w := _agnes_window(s)
	var spot: Vector2i = (w["out"] as Vector2i) + (w["dir"] as Vector2i) * 2
	s.add_incident("i_test", spot, 30, "the back fence")
	_put(s, "r_agnes", w["inside"], "sit")
	_put(s, "r_june", spot + Vector2i(0, 1))
	s._light = null
	Memories.observe(s)
	var june := ""
	for m: Dictionary in s.residents["r_agnes"]["memories"]:
		if m["subject"] == "r_june":
			june = str(m["detail"])
	assert_eq(june, "near the back fence", "by day, June near the incident is notable")
	s.run_ticks(31)
	s.residents["r_agnes"]["memories"] = []
	Memories.observe(s)
	assert_true((s.residents["r_agnes"]["memories"] as Array).filter(func(m: Dictionary) -> bool: return str(m["detail"]).contains("back fence")).is_empty(), "not after it's over")
	var r: Dictionary = s.residents["r_tomasz"]
	r["memories"] = []
	Memories.add(s, r, {"kind": "saw_object", "detail": "a crowbar", "confidence": 0.9, "keep": true})
	for i in Memories.CAP + 5:
		Memories.add(s, r, {"kind": "saw_person", "subject": "r_len", "detail": "x%d" % i, "confidence": 0.9})
	assert_eq((r["memories"] as Array).size(), Memories.CAP)
	assert_eq(r["memories"][0]["detail"], "a crowbar", "kept for the case")


func test_a_week_of_memories() -> void:
	var s := _sim()
	s.run_ticks(7 * 1440)
	var kinds := {}
	var most := 0
	for rid: String in s.residents:
		var mem: Array = s.residents[rid]["memories"]
		most = maxi(most, mem.size())
		for m: Dictionary in mem:
			kinds[m["kind"]] = int(kinds.get(m["kind"], 0)) + 1
	gut.p("A week of memories by kind: %s, most for one resident %d" % [kinds, most])
	assert_gt(int(kinds.get("saw_person", 0)), 0, "visits and late nights are noticed")
	assert_lte(most, Memories.CAP)
