class_name HomeScores
extends RefCounted
## The seven home scores from docs/HOUSE_BUILDING.md, each 0 to 100, worked out from the house alone
## (and how many people live in it). Plain class: Buy mode previews a change by scoring a copy.
##
## Comfort: furniture quality, beds, a working kitchen, roomy rooms.
## Style:   colour harmony (data/palettes.json pairs), papers and trims, decor, verandah and garden.
## Warmth:  stove and fireplace coverage, walls, linings, roof, ceiling height.
## Light:   window area for each room's floor, lamps, morning sun in the kitchen.
## Space:   floor per resident and beds per sleeper.
## Privacy: bedrooms for the household, curtains, fences.
## Security: locks, latched windows, lamps, fences and gates, a telephone.

const NAMES: Array[String] = ["comfort", "style", "warmth", "light", "space", "privacy", "security"]
const KITCHEN_SET: Array[String] = ["wood_stove", "kitchen_sink", "icebox"]


static func compute(h: HouseData, residents: int = 2) -> Dictionary:
	var rooms := _rooms(h)
	var area := 0.0
	for r: Dictionary in rooms:
		area += float(r["area"])
	var items := _item_totals(h)
	var out := {
		"comfort": _comfort(h, rooms, items),
		"style": _style(h, rooms, items),
		"warmth": _warmth(h, rooms, area, items),
		"light": _light(h, rooms, items),
		"space": _space(h, area, residents),
		"privacy": _privacy(h, residents),
		"security": _security(h, items),
	}
	for k: String in out:
		out[k] = clampi(roundi(float(out[k])), 0, 100)
	return out


## What an edit would change: {score: difference} for the scores that move.
static func preview(h: HouseData, edit: Callable, residents: int = 2) -> Dictionary:
	var before := compute(h, residents)
	var copy := h.duplicate_house()
	var res: Dictionary = edit.call(copy)
	if not res.get("ok", false):
		return {}
	var after := compute(copy, residents)
	var out := {}
	for k in NAMES:
		if int(after[k]) != int(before[k]):
			out[k] = int(after[k]) - int(before[k])
	return out


## "+3 Comfort, -1 Space" for a preview.
static func describe(diff: Dictionary) -> String:
	var parts: Array[String] = []
	for k in NAMES:
		if diff.has(k):
			parts.append("%+d %s" % [int(diff[k]), k.capitalize()])
	return ", ".join(parts)


# --- Gathering -----------------------------------------------------------------------------------

## Every room with its storey and what's in it: [{level, room, area, items: [catalogue ids]}].
static func _rooms(h: HouseData) -> Array:
	var out: Array = []
	var index: Dictionary = {}
	for l in h.levels():
		for r in h.rooms(l):
			var e := {"level": l, "room": r, "area": float(r["area"]), "items": [], "name": h.room_name(r).to_lower()}
			out.append(e)
			for t: Vector2i in r["tiles"]:
				index["%d:%d,%d" % [l, t.x, t.y]] = e
	for o: Dictionary in h.objects:
		var id := Catalogue.id_of(o)
		var key := "%d:%d,%d" % [int(o.get("level", 0)), floori(float(o["x"])), floori(float(o["z"]))]
		if index.has(key) and id != "":
			((index[key] as Dictionary)["items"] as Array).append(id)
	return out


## Totals of each score the catalogue gives, plus counts by item id.
static func _item_totals(h: HouseData) -> Dictionary:
	var t := {"count": {}}
	for o: Dictionary in h.objects:
		var id := Catalogue.id_of(o)
		if id == "":
			continue
		(t["count"] as Dictionary)[id] = int((t["count"] as Dictionary).get(id, 0)) + 1
		var sc: Dictionary = Catalogue.item(id).get("scores", {})
		for k: String in sc:
			t[k] = float(t.get(k, 0.0)) + float(sc[k])
	return t


static func _has(items: Dictionary, id: String) -> bool:
	return int((items["count"] as Dictionary).get(id, 0)) > 0


# --- Scores --------------------------------------------------------------------------------------

static func _comfort(h: HouseData, rooms: Array, items: Dictionary) -> float:
	if rooms.is_empty():
		return 0.0
	var s := 15.0 + minf(float(items.get("comfort", 0.0)) * 1.2, 45.0)
	# A working kitchen: stove, sink, ice chest, a table and chairs.
	var kitchen := 0.0
	for id in KITCHEN_SET:
		if _has(items, id):
			kitchen += 4.0
	if _has(items, "laminex_table") or _has(items, "farmhouse_table"):
		kitchen += 4.0
	if _has(items, "kitchen_chair") or _has(items, "wooden_chair"):
		kitchen += 4.0
	s += kitchen
	# Somewhere to sleep, and somewhere to sit.
	if _beds(h) > 0:
		s += 10.0
	if _has(items, "settee") or _has(items, "armchair") or _has(items, "rocking_chair"):
		s += 5.0
	# Pokey rooms take the shine off.
	var small := 0
	for r: Dictionary in rooms:
		if float(r["area"]) < 6.0:
			small += 1
	return s - small * 4.0


static func _style(h: HouseData, rooms: Array, items: Dictionary) -> float:
	var s := 20.0 + minf(float(items.get("style", 0.0)) * 1.5, 25.0)
	var pairs: Array = MaterialLibrary.palettes().get("harmonious_pairs", [])
	var trim := str(h.exterior.get("trim", "white"))
	var paints: Dictionary = {}
	var papered := 0
	for r: Dictionary in rooms:
		var rr: Dictionary = r["room"]
		paints[h.room_paint(rr)] = true
		for f: Array in BuildOps.room_faces(h, int(r["level"]), rr):
			if str(BuildOps.pick_surface(h, int(r["level"]), f[0], f[1]).get("mat", "")) == "wallpaper":
				papered += 1
				break
	# Wall colours that go with the trim, and a house that isn't every colour at once.
	var matched := 0
	for p: String in paints:
		for pair: Array in pairs:
			if (pair[0] == p and pair[1] == trim) or (pair[1] == p and pair[0] == trim):
				matched += 1
				break
	s += minf(matched * 4.0, 12.0)
	s -= maxf(0.0, paints.size() - 4.0) * 3.0
	s += minf(papered * 3.0, 9.0)
	# The outside: verandah lace, a garden, a front fence.
	for v: Dictionary in h.verandahs:
		s += 4.0 if str(v.get("lace", "none")) != "none" else 2.0
	var plants := 0
	for it: Dictionary in h.garden:
		if str(GardenOps.item_def(str(it["kind"])).get("category", "")) == "plants":
			plants += 1
	s += minf(plants * 1.0, 10.0)
	if not h.fences.is_empty():
		s += 3.0
	return s


static func _warmth(h: HouseData, rooms: Array, area: float, items: Dictionary) -> float:
	if rooms.is_empty():
		return 0.0
	# Rooms with a stove or a fireplace, and the rooms next door get some of it.
	var heated := 0.0
	for r: Dictionary in rooms:
		var warm := false
		for id: String in r["items"]:
			if float(Catalogue.item(id).get("scores", {}).get("warmth", 0.0)) > 0.0:
				warm = true
		if _fireplace_in(h, r):
			warm = true
		if warm:
			heated += float(r["area"])
	var s := 15.0 + 45.0 * clampf(heated * 1.6 / maxf(area, 1.0), 0.0, 1.0)
	if not Roofs.pieces(h).is_empty():
		s += 20.0
	else:
		s -= 20.0
	# Brick keeps heat; tall ceilings lose it.
	var brick := 0
	var faces := BuildOps.exterior_faces(h)
	for f: Array in faces:
		if str(BuildOps.pick_surface(h, int(f[2]), f[0], f[1]).get("mat", "")) == "brick_red":
			brick += 1
	if not faces.is_empty():
		s += 10.0 * float(brick) / faces.size()
	s += 10.0 if h.storey_height(0) <= 2.7 else (4.0 if h.storey_height(0) <= 3.0 else 0.0)
	return s


static func _fireplace_in(h: HouseData, r: Dictionary) -> bool:
	var rr: Dictionary = r["room"]
	var b: Rect2 = Rect2(rr["bounds"]).grow(0.5)
	for c: Dictionary in h.chimneys:
		if int(c.get("level", 0)) != int(r["level"]):
			continue
		var cr := Rect2(float(c["x"]), float(c["z"]), float(c["w"]), float(c["d"]))
		var reach := b.grow(0.4) if bool(c.get("outside", false)) else b
		if reach.intersects(cr):
			return true
	for f: Dictionary in h.fixtures:
		if str(f.get("kind", "")) in ["stove", "fireplace"] and Rect2(rr["bounds"]).has_point(Vector2(float(f["x"]), float(f["z"]))):
			return true
	return false


static func _light(h: HouseData, rooms: Array, items: Dictionary) -> float:
	if rooms.is_empty():
		return 0.0
	var glass: Dictionary = {}
	var east_kitchen := false
	for l in h.levels():
		for o: Dictionary in h.openings(l):
			if str(o.get("kind", "")) != "window":
				continue
			var edges := HouseData.opening_edges(o)
			if edges.is_empty():
				continue
			var k: String = edges[0]
			for side: String in ["a", "b"]:
				var r := h.room_on_side(l, k, side)
				if r.is_empty():
					continue
				var key := "%d:%s" % [l, r["key"]]
				glass[key] = float(glass.get(key, 0.0)) + float(o["width"]) * float(o["height"])
				# A kitchen window on the east wall gets the morning sun.
				var other := h.room_on_side(l, k, "b" if side == "a" else "a")
				if other.is_empty() and h.room_name(r).to_lower().contains("kitchen") and k.ends_with(",W") and side == "a":
					east_kitchen = true
	var total := 0.0
	for r2: Dictionary in rooms:
		var key2 := "%d:%s" % [int(r2["level"]), (r2["room"] as Dictionary)["key"]]
		total += clampf(float(glass.get(key2, 0.0)) / (float(r2["area"]) * 0.1), 0.0, 1.0)
	var s := 10.0 + 60.0 * total / rooms.size()
	s += minf(float(items.get("light", 0.0)) * 1.5, 20.0)
	if east_kitchen:
		s += 10.0
	return s


static func _beds(h: HouseData) -> int:
	var n := 0
	for o: Dictionary in h.objects:
		n += int(Catalogue.item(Catalogue.id_of(o)).get("sleeps", 0))
	return n


static func _space(h: HouseData, area: float, residents: int) -> float:
	if area <= 0.0:
		return 0.0
	var per := area / maxf(1.0, residents)
	var s := 70.0 * clampf(per / 20.0, 0.0, 1.0)
	s += 30.0 * clampf(float(_beds(h)) / maxf(1.0, residents), 0.0, 1.0)
	return s


static func _privacy(h: HouseData, residents: int) -> float:
	var bedrooms := 0
	for l in h.levels():
		for r in h.rooms(l):
			var has_bed := false
			for o: Dictionary in h.objects:
				if int(o.get("level", 0)) == l and int(Catalogue.item(Catalogue.id_of(o)).get("sleeps", 0)) > 0:
					var t := Vector2i(floori(float(o["x"])), floori(float(o["z"])))
					if (r["tiles"] as Array).has(t):
						has_bed = true
			if has_bed or h.room_name(r).to_lower().contains("bed"):
				bedrooms += 1
	var need := ceili(residents / 2.0)
	var s := 20.0 + 45.0 * clampf(float(bedrooms) / maxf(1.0, need), 0.0, 1.0)
	var windows := 0
	var curtained := 0
	for l2 in h.levels():
		for o2: Dictionary in h.openings(l2):
			if str(o2.get("kind", "")) == "window":
				windows += 1
				if bool((o2.get("night", {}) as Dictionary).get("curtains", true)):
					curtained += 1
	if windows > 0:
		s += 20.0 * float(curtained) / windows
	if not h.fences.is_empty():
		s += 15.0
	return s


static func _security(h: HouseData, items: Dictionary) -> float:
	var s := 15.0
	var outer_doors := 0
	var locked := 0
	var windows := 0
	var latched := 0
	for l in h.levels():
		for o: Dictionary in h.openings(l):
			var edges := HouseData.opening_edges(o)
			if edges.is_empty():
				continue
			var outside := h.room_on_side(l, edges[0], "a").is_empty() or h.room_on_side(l, edges[0], "b").is_empty()
			if not outside:
				continue
			var night: Dictionary = o.get("night", {})
			if str(o.get("kind", "")) == "door":
				outer_doors += 1
				if bool(o.get("lock", false)) and bool(night.get("lock", false)):
					locked += 1
			elif str(o.get("kind", "")) == "window":
				windows += 1
				if bool(night.get("latch", false)):
					latched += 1
	if outer_doors > 0:
		s += 30.0 * float(locked) / outer_doors
	if windows > 0:
		s += 20.0 * float(latched) / windows
	var gates := 0
	for k: String in h.fences:
		if bool((h.fences[k] as Dictionary).get("gate", false)):
			gates += 1
	if not h.fences.is_empty():
		s += 10.0 + (5.0 if gates > 0 else 0.0)
	s += minf(float(items.get("security", 0.0)) * 2.0, 10.0)
	if float(items.get("light", 0.0)) > 0.0:
		s += 5.0
	for v: Dictionary in h.verandahs:
		if str(v.get("rail", "none")) != "none":
			s += 2.0
	return s
