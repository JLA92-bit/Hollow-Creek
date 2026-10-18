class_name CrimePlan
extends RefCounted
## Step 2 of the crime director (docs/CRIME_DIRECTOR.md "Generating plans"): concrete plans for a
## candidate, varied by when the crime happens, how the culprit gets in and which way they walk.
## A plan is a plain dictionary so it can be saved, compared and run on a snapshot:
##   {id, crime, culprit, target, motive, house, loot, loot_place, loot_at, entry: {kind, edge, out, in},
##    start (minutes after the planning time), route: "direct" | "left" | "right", via: [level, x, z] or [],
##    hide: [level, x, z], hide_house, cover: {place, minute}, legs: [...]}
## Legs are what the culprit actually does, in order; PlanRunner executes them.

const STARTS: Array[int] = [150, 240, 330]   ## 23:30, 1:00 and 2:30 for a plan made at 21:00
const ROUTES: Array[String] = ["direct", "left", "right"]
const SIDE_M := 9.0


## Ways into a house: windows nobody has latched, and the front door if it isn't locked.
static func entries(sim: Sim, house: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sight := sim.town.sight
	var ids := sight.rooms.keys()
	ids.sort()
	for rid: String in ids:
		var room: Dictionary = sight.rooms[rid]
		if str(room["house"]) != house:
			continue
		for w: Dictionary in room["windows"]:
			if bool(w.get("latched", false)) or windows_latched(sim, str(w["edge"])):
				continue
			var o: Vector2i = w["out"]
			var i: Vector2i = w.get("in", o)
			out.append({"kind": "window", "edge": str(w["edge"]), "out": [o.x, o.y], "in": [i.x, i.y]})
	return out


## After a crime, windows get latched for a while: half of them, picked by a hash of the edge.
static func windows_latched(sim: Sim, edge: String) -> bool:
	return sim.day < sim.latch_until_day and (hash(edge) & 1) == 1


## Where the loot is and what it is: the shop counter for a store, else the living area.
static func loot_for(sim: Sim, house: String) -> Dictionary:
	var cfg: Dictionary = Motives.config()["theft"]
	for p: Dictionary in sim.town.places:
		if str(p["house"]) == house and str(p["kind"]) == "shop":
			return {"loot": cfg["loot"]["shop"], "place": cfg["loot_place"]["shop"], "at": (p["at"] as Array).duplicate()}
	var home: Dictionary = sim.town.homes.get(house, {})
	var living: Array = home.get("living", [])
	if living.is_empty():
		return {}
	return {"loot": cfg["loot"]["living"], "place": cfg["loot_place"]["living"], "at": living.duplicate()}


## A spot just outside a house (a few steps off its south wall), for hiding things.
static func outside_house(sim: Sim, house: String) -> Array:
	var sight := sim.town.sight
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for rid: String in sight.rooms:
		var room: Dictionary = sight.rooms[rid]
		if str(room["house"]) != house:
			continue
		for t: Vector2i in room["tiles"]:
			lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
			hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	if hi.x < lo.x:
		return []
	for dy in range(2, 8):
		var p := sim.town.walkable_near(Vector2i((lo.x + hi.x) / 2, hi.y + dy))
		if not p.is_empty() and sight.room_at(Vector2i(floori(float(p[1])), floori(float(p[2])))) == "":
			return p
	return []


## A waypoint to one side of the straight line between two tiles, for the other routes.
static func waypoint(sim: Sim, a: Array, b: Array, side: float) -> Array:
	var pa := Vector2(float(a[1]), float(a[2]))
	var pb := Vector2(float(b[1]), float(b[2]))
	var mid := (pa + pb) * 0.5
	var dir := (pb - pa).normalized()
	var perp := Vector2(-dir.y, dir.x) * side * SIDE_M
	return sim.town.walkable_near(Vector2i(floori(mid.x + perp.x), floori(mid.y + perp.y)))


## All the plans worth trying for one candidate (up to `max_plans`), in a fixed order.
static func generate(sim: Sim, cand: Dictionary, max_plans: int = 12, salt: int = 0) -> Array[Dictionary]:
	var culprit := str(cand["culprit"])
	var target := str(cand["target"])
	var house := sim.home_of(target)
	var out: Array[Dictionary] = []
	if house == "" or not sim.town.homes.has(house):
		return out
	var loot := loot_for(sim, house)
	if loot.is_empty():
		return out
	var home := sim.home_of(culprit)
	var door := outside_house(sim, home)
	if door.is_empty():
		return out
	var from: Array = sim.residents[culprit]["pos"]
	var ents := entries(sim, house)
	var n := 0
	for start: int in STARTS:
		for route: String in ROUTES:
			for e: Dictionary in ents:
				var via: Array = []
				if route != "direct":
					via = waypoint(sim, from, [0, float((e["out"] as Array)[0]) + 0.5, float((e["out"] as Array)[1]) + 0.5], -1.0 if route == "left" else 1.0)
				var plan := {"id": "%s>%s:%d:%s:%s" % [culprit, target, start, route, str(e["edge"])], "crime": str(cand["crime"]), "culprit": culprit,
					"target": target, "motive": str(cand["motive"]), "house": house, "loot": str(loot["loot"]), "loot_place": str(loot["place"]),
					"loot_at": loot["at"], "entry": e, "start": start, "route": route, "via": via, "hide": door.duplicate(), "hide_house": "",
					"cover": {"place": "at home", "minute": 0}}
				plan["careless"] = (absi(hash(str(plan["id"]))) % 3) == 0
				plan["legs"] = legs_for(sim, plan)
				plan["decoy"] = decoy_for(sim, plan)
				out.append(plan)
				n += 1
	# Spread the choice across start times and routes rather than taking the first dozen.
	var picked: Array[Dictionary] = []
	var rng := SimRng.new(sim.seed_value * 31 + sim.day * 7 + 11 + salt * 1013)
	rng.shuffle(out)
	for p: Dictionary in out:
		if picked.size() >= max_plans:
			break
		picked.append(p)
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	return picked


## Somebody with a secret to keep who's out that night and near the scene, in three plans out of
## four. {} when there's no one suitable. {rid, secret, start, legs}.
static func decoy_for(sim: Sim, plan: Dictionary) -> Dictionary:
	if (absi(hash(str(plan["id"]) + "decoy")) % 4) == 0:
		return {}
	var skip := {str(plan["culprit"]): true, str(plan["target"]): true}
	var ids := sim.residents.keys()
	ids.sort()
	var options: Array[Dictionary] = []
	for rid: String in ids:
		if skip.has(rid) or sim.residents[rid]["status"] != "living":
			continue
		for sid: String in sim.secrets:
			var sec: Dictionary = sim.secrets[sid]
			if str(sec["owner"]) == rid and sec.has("night_out"):
				options.append({"rid": rid, "secret": sid, "minutes": int((sec["night_out"] as Dictionary)["minutes"])})
	if options.is_empty():
		return {}
	var pick: Dictionary = options[absi(hash(str(plan["id"]))) % options.size()]
	var e: Dictionary = plan["entry"]
	var out_p := [0, float((e["out"] as Array)[0]) + 0.5, float((e["out"] as Array)[1]) + 0.5]
	var spot := sim.town.walkable_near(Vector2i(floori(float(out_p[1])) + 3, floori(float(out_p[2])) + 3))
	if spot.is_empty():
		return {}
	var home := sim.home_of(str(pick["rid"]))
	var legs: Array[Dictionary] = [{"do": "walk", "at": spot, "house": "", "minutes": int(pick["minutes"]), "leave_item": true}]
	var back := outside_house(sim, home)
	if not back.is_empty():
		legs.append({"do": "walk", "at": back, "house": "", "minutes": 0})
	return {"rid": pick["rid"], "secret": pick["secret"], "start": int(plan["start"]) - 20, "legs": legs}


## What the culprit does, step by step. `at` is a position [level, x, z]; `house` is "" outdoors.
static func legs_for(_sim: Sim, plan: Dictionary) -> Array[Dictionary]:
	var e: Dictionary = plan["entry"]
	var out_p := [0, float((e["out"] as Array)[0]) + 0.5, float((e["out"] as Array)[1]) + 0.5]
	var in_p := [0, float((e["in"] as Array)[0]) + 0.5, float((e["in"] as Array)[1]) + 0.5]
	var legs: Array[Dictionary] = []
	if not (plan["via"] as Array).is_empty():
		legs.append({"do": "walk", "at": plan["via"], "house": "", "minutes": 0})
	legs.append({"do": "walk", "at": out_p, "house": "", "minutes": 1})
	legs.append({"do": "climb", "at": in_p, "house": plan["house"]})
	legs.append({"do": "walk", "at": plan["loot_at"], "house": plan["house"], "minutes": 3, "take": plan["loot"]})
	legs.append({"do": "walk", "at": in_p, "house": plan["house"], "minutes": 0})
	legs.append({"do": "climb", "at": out_p, "house": ""})
	legs.append({"do": "walk", "at": plan["hide"], "house": "", "minutes": 4, "drop": true})
	return legs
