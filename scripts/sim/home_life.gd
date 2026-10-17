class_name HomeLife
extends RefCounted
## How households get on with their homes (docs/HOUSE_BUILDING.md, "Wishes, briefs and life changes"):
## wishes checked against the house as built, move-in reactions to a family's brief, weekly rent and
## each home's history card. Plain class: reads a HouseData, never changes it.

## Mood change and how the family puts it, for each move-in verdict.
const VERDICTS := {
	"delighted": {"mood": 15.0, "say": "They're delighted with it."},
	"content": {"mood": 5.0, "say": "They're content enough."},
	"disappointed": {"mood": -15.0, "say": "They're disappointed."},
}


## Rooms with the catalogue items standing in them: [{level, room, area, items: [ids], name}].
static func rooms(h: HouseData) -> Array:
	return HomeScores._rooms(h)


## Weekly rent in whole pounds, from the average home score: £1 for a bare hut, up to £4.
static func rent(scores: Dictionary) -> int:
	return 1 + roundi(average(scores) / 35.0)


static func average(scores: Dictionary) -> float:
	if scores.is_empty():
		return 0.0
	var t := 0.0
	for k: String in scores:
		t += float(scores[k])
	return t / scores.size()


## Is this wish (data/residents.json "wishes") met by the house as it stands?
static func wish_met(w: Dictionary, h: HouseData) -> bool:
	var needs: Dictionary = w.get("needs", {})
	if needs.has("room_with") or needs.has("room_with_all") or needs.has("heated") or needs.has("east_window"):
		var found := false
		for r: Dictionary in rooms(h):
			if needs.has("room_with") and not _has_any(r["items"], needs["room_with"]):
				continue
			if needs.has("room_with_all") and not _has_all(r["items"], needs["room_with_all"]):
				continue
			if bool(needs.get("east_window", false)) and not east_window(h, r):
				continue
			if bool(needs.get("heated", false)) and not heated(h, r):
				continue
			found = true
			break
		if not found:
			return false
	if bool(needs.get("sleepout_with_bed", false)) and not _sleepout_bed(h):
		return false
	if needs.has("garden"):
		var any := false
		for g: Dictionary in h.garden:
			if (needs["garden"] as Array).has(str(g["kind"])):
				any = true
		if not any:
			return false
	if needs.has("garden_area"):
		var want: Dictionary = needs["garden_area"]
		for kind: String in want:
			var area := 0.0
			for g: Dictionary in h.garden:
				if str(g["kind"]) == kind:
					area += GardenOps.item_rect(g).get_area()
			if area + 0.001 < float(want[kind]):
				return false
	if needs.has("items"):
		var have := {}
		for o: Dictionary in h.objects:
			have[Catalogue.id_of(o)] = true
		for id: String in needs["items"]:
			if not have.has(id):
				return false
	return true


## An item id matches a wanted key by its id or its catalogue function ("surfaces", "beds"...).
static func _matches(id: String, key: String) -> bool:
	return id == key or str(Catalogue.item(id).get("function", "")) == key


static func _has_any(items: Array, keys: Array) -> bool:
	for id: String in items:
		for k: String in keys:
			if _matches(id, k):
				return true
	return false


static func _has_all(items: Array, keys: Array) -> bool:
	for k: String in keys:
		if not _has_any(items, [k]):
			return false
	return true


## A window on the room's east wall, with nothing built on the other side (the morning sun).
static func east_window(h: HouseData, r: Dictionary) -> bool:
	var l := int(r["level"])
	for o: Dictionary in h.openings(l):
		if str(o.get("kind", "")) != "window":
			continue
		for k: String in HouseData.opening_edges(o):
			if k.ends_with(",W") and h.room_on_side(l, k, "a").get("key", "") == (r["room"] as Dictionary)["key"] and h.room_on_side(l, k, "b").is_empty():
				return true
	return false


## A stove or anything else that warms, or a fireplace on one of its walls.
static func heated(h: HouseData, r: Dictionary) -> bool:
	for id: String in r["items"]:
		if int((Catalogue.item(id).get("scores", {}) as Dictionary).get("warmth", 0)) > 0:
			return true
	return HomeScores._fireplace_in(h, r)


## A sleep-out (BuildOps.enclose_sleepout makes it a room) with a bed in it.
static func _sleepout_bed(h: HouseData) -> bool:
	for r: Dictionary in rooms(h):
		if ((r["room"] as Dictionary).get("props", {}) as Dictionary).get("sleepout", false) and _has_any(r["items"], ["beds"]):
			return true
	return false


## Rooms with a bed in them, or named as bedrooms.
static func bedrooms(h: HouseData) -> int:
	var n := 0
	for r: Dictionary in rooms(h):
		if str(r["name"]).contains("bed") or _has_any(r["items"], ["beds"]):
			n += 1
	return n


## Has the house a room of this kind ("kitchen", "living", "bathroom"), by name or by what's in it?
static func has_room(h: HouseData, kind: String) -> bool:
	var marks := {"kitchen": ["wood_stove", "kitchen_sink"], "living": ["settee", "armchair", "wireless_set"], "bathroom": ["clawfoot_bath", "washstand"]}
	for r: Dictionary in rooms(h):
		if str(r["name"]).contains(kind) or _has_any(r["items"], marks.get(kind, [])):
			return true
	return false


## How a family takes a home against its brief: {verdict, pros, cons, scores, rent}.
## Brief: {text, bedrooms, rooms: [kinds], rent: most they can pay a week, wants: [garden kinds or item ids]}.
static func reaction(brief: Dictionary, h: HouseData, members: int) -> Dictionary:
	var scores := HomeScores.compute(h, members)
	var avg := average(scores)
	var pros: Array[String] = []
	var cons: Array[String] = []
	var need := int(brief.get("bedrooms", 1))
	var beds := bedrooms(h)
	if beds >= need:
		pros.append("%d bedroom%s, as we asked" % [beds, "" if beds == 1 else "s"])
	else:
		cons.append("Only %d bedroom%s; we asked for %d" % [beds, "" if beds == 1 else "s", need])
	if HomeScores._beds(h) < members:
		cons.append("Not enough beds to go round")
	for kind: String in brief.get("rooms", []):
		if not has_room(h, kind):
			cons.append("No %s" % kind)
	for want: String in brief.get("wants", []):
		var got := false
		for g: Dictionary in h.garden:
			got = got or str(g["kind"]) == want
		for o: Dictionary in h.objects:
			got = got or Catalogue.id_of(o) == want
		if got:
			pros.append("A %s, just what we wanted" % _item_name(want).to_lower())
	var r := rent(scores)
	if brief.has("rent") and r > int(brief["rent"]):
		cons.append("Dearer than we can manage (£%d a week)" % r)
	if avg >= 70.0:
		pros.append("A lovely home")
	elif avg < 40.0:
		cons.append("It feels bare and comfortless")
	var verdict := "disappointed"
	if cons.is_empty() and avg >= 55.0:
		verdict = "delighted"
	elif cons.size() <= 1:
		verdict = "content"
	return {"verdict": verdict, "pros": pros, "cons": cons, "scores": scores, "rent": r}


static func _item_name(id: String) -> String:
	var g := GardenOps.item_def(id)
	if not g.is_empty():
		return str(g.get("name", id))
	return str(Catalogue.item(id).get("name", id))


## Adds a line to a home's history card: history is {house id: [{day, text}]}.
static func record(history: Dictionary, house: String, day: int, text: String) -> void:
	if not history.has(house):
		history[house] = []
	(history[house] as Array).append({"day": day, "text": text})
