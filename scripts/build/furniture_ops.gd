class_name FurnitureOps
extends RefCounted
## Buy mode edits on a house's objects (docs/HOUSE_BUILDING.md): placing catalogue items on floors,
## against walls, from ceilings and on surfaces (stacking), moving and turning them alone or as a
## group, raising and lowering wall items, and the Design tool's per-slot materials and colours.
## Like BuildOps, each op mutates the HouseData and returns {ok, msg, cost}.
##
## A placed object: {id, item, model, level, x, z, y (height of its base above the floor), rot
## (degrees), slots: {slot: {mat, colour}}, on (id of what it stands on), light: {energy, kelvin}}.

const WALL_GAP := 0.005


static func object_by_id(h: HouseData, id: String) -> Dictionary:
	for o: Dictionary in h.objects:
		if str(o.get("id", "")) == id:
			return o
	return {}


## Footprint in plan: the item's size turned by its rotation (axis-aligned bounds).
static func rect_of(o: Dictionary) -> Rect2:
	var it := Catalogue.item(Catalogue.id_of(o))
	var sz: Array = it.get("size", [0.5, 0.5])
	var w := float(sz[0])
	var d := float(sz[1])
	var a := deg_to_rad(float(o.get("rot", 0.0)))
	var c := absf(cos(a))
	var s := absf(sin(a))
	var ew := w * c + d * s
	var ed := w * s + d * c
	var centre := Vector2(float(o["x"]), float(o["z"]))
	if str(it.get("place", "floor")) == "wall":
		# Wall items' origin is at their back; their footprint sits in front of it.
		var fwd := Vector2(sin(a), cos(a))
		centre += fwd * d * 0.5
	return Rect2(centre - Vector2(ew, ed) * 0.5, Vector2(ew, ed))


## Height of an object's top surface above the floor, if things can stand on it, else -1.
static func surface_top(o: Dictionary) -> float:
	var it := Catalogue.item(Catalogue.id_of(o))
	if not it.has("surface"):
		return -1.0
	return float(o.get("y", 0.0)) + float(it["surface"])


static func _inside_room(h: HouseData, level: int, r: Rect2) -> bool:
	var room := h.room_at_tile(level, Vector2i(floori(r.get_center().x), floori(r.get_center().y)))
	if room.is_empty():
		return false
	var tiles: Dictionary = {}
	for t: Vector2i in room["tiles"]:
		tiles[t] = true
	var g := r.grow(-0.02)
	for p: Vector2 in [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]:
		if not tiles.has(Vector2i(floori(p.x), floori(p.y))):
			return false
	return true


## The thing a surface item would stand on at p: the highest surface whose top contains p.
static func host_at(h: HouseData, level: int, p: Vector2, skip_id: String = "") -> Dictionary:
	var best: Dictionary = {}
	var best_top := -1.0
	for o: Dictionary in h.objects:
		if int(o.get("level", 0)) != level or str(o.get("id", "")) == skip_id:
			continue
		var top := surface_top(o)
		if top >= 0.0 and rect_of(o).has_point(p) and top > best_top:
			best_top = top
			best = o
	return best


## Snaps a wall item to the nearest wall face within reach: {x, z, rot} or {}.
static func wall_spot(h: HouseData, level: int, p: Vector2, reach: float = 0.6) -> Dictionary:
	var best: Dictionary = {}
	var best_d := reach
	for k: String in h.walls(level):
		if HouseData.is_diagonal(k):
			continue
		var pts := HouseData.edge_points(k)
		var q := Geometry2D.get_closest_point_to_segment(p, Vector2(pts[0]), Vector2(pts[1]))
		var dd := p.distance_to(q)
		if dd >= best_d:
			continue
		var horizontal := k.ends_with(",N")
		# The face on the pointer's side, if a room is there.
		var side := ("a" if p.y < q.y else "b") if horizontal else ("a" if p.x < q.x else "b")
		if h.room_on_side(level, k, side).is_empty():
			continue
		var t := HouseData.WALL_THICKNESS * 0.5 + WALL_GAP
		var spot := {}
		if horizontal:
			spot = {"x": p.x, "z": q.y + (t if side == "b" else -t), "rot": 0.0 if side == "b" else 180.0}
		else:
			spot = {"x": q.x + (t if side == "b" else -t), "z": p.y, "rot": 90.0 if side == "b" else -90.0}
		best = spot
		best_d = dd
	return best


## Checks an object where it is (not counting skip ids). Returns "" or the reason it can't go there.
static func check(h: HouseData, o: Dictionary, skip: Array = []) -> String:
	var it := Catalogue.item(Catalogue.id_of(o))
	if it.is_empty():
		return "That's not in the catalogue."
	var level := int(o.get("level", 0))
	var r := rect_of(o)
	var place := str(it.get("place", "floor"))
	if not _inside_room(h, level, r):
		return "That needs to go inside a room."
	if place == "wall" or place == "ceiling":
		return ""
	if o.has("on"):
		var host := object_by_id(h, str(o["on"]))
		if host.is_empty() or not rect_of(host).grow(0.05).encloses(r.grow(-maxf(0.0, minf(r.size.x, r.size.y) * 0.3))):
			return "It won't sit on that."
		return ""
	for other: Dictionary in h.objects:
		var oid := str(other.get("id", ""))
		if oid == str(o.get("id", "")) or skip.has(oid) or int(other.get("level", 0)) != level or other.has("on"):
			continue
		var oit := Catalogue.item(Catalogue.id_of(other))
		if str(oit.get("place", "floor")) != "floor":
			continue
		if rect_of(other).grow(-0.02).intersects(r.grow(-0.02)):
			return "Something's in the way."
	return ""


## Places a catalogue item centred at pos on a storey. Floor items stand on the floor; surface items
## stand on whatever surface is under them (or the floor); wall items hang on the nearest wall at
## their usual height; ceiling items hang from the ceiling.
static func place(h: HouseData, level: int, item_id: String, pos: Vector2, rot: float = 0.0, opts: Dictionary = {}) -> Dictionary:
	var it := Catalogue.item(item_id)
	if it.is_empty():
		return BuildOps.fail("That's not in the catalogue.")
	var o := {"item": item_id, "model": it["model"], "level": level, "x": pos.x, "z": pos.y, "y": float(it.get("y", 0.0)), "rot": rot, "slots": {}}
	var place_kind := str(it.get("place", "floor"))
	match place_kind:
		"wall":
			var spot := wall_spot(h, level, pos)
			if spot.is_empty():
				return BuildOps.fail("Hang it on an inside wall.")
			o.merge(spot, true)
			o["y"] = float(opts.get("y", it.get("y", 1.4)))
		"ceiling":
			var room := h.room_at_tile(level, Vector2i(floori(pos.x), floori(pos.y)))
			if room.is_empty():
				return BuildOps.fail("Hang it from a ceiling inside a room.")
			var k0: Array = h.room_walls(level, room)
			o["y"] = h.wall_h(level, k0[0]) if not k0.is_empty() else h.storey_height(level)
		_:
			# Surface items stand on whatever is under them; anything can be stacked on purpose.
			var host := host_at(h, level, pos)
			if not host.is_empty() and (place_kind == "surface" or bool(opts.get("stack", false))):
				o["on"] = host["id"]
				o["y"] = surface_top(host)
	var msg := check(h, o)
	if msg != "":
		return BuildOps.fail(msg)
	o["id"] = h.new_id("f")
	h.objects.append(o)
	h.touch()
	return BuildOps.ok(int(it.get("price", 1)), {"id": o["id"]})


## Moves, turns or raises an object (changes may hold x, z, y, rot). Things standing on it move too.
static func update(h: HouseData, id: String, changes: Dictionary) -> Dictionary:
	var o := object_by_id(h, id)
	if o.is_empty():
		return BuildOps.fail("That's gone.")
	var it := Catalogue.item(Catalogue.id_of(o))
	var trial := o.duplicate(true)
	trial.merge(changes, true)
	if str(it.get("place", "floor")) == "wall" and (changes.has("x") or changes.has("z")):
		var spot := wall_spot(h, int(o.get("level", 0)), Vector2(float(trial["x"]), float(trial["z"])))
		if spot.is_empty():
			return BuildOps.fail("Hang it on an inside wall.")
		trial.merge(spot, true)
	if changes.has("y") and str(it.get("place", "floor")) == "wall":
		trial["y"] = clampf(float(changes["y"]), 0.2, h.storey_height(int(o.get("level", 0))) - 0.2)
	var riders := _riders(h, id)
	var msg := check(h, trial, riders)
	if msg != "":
		return BuildOps.fail(msg)
	var dx := float(trial["x"]) - float(o["x"])
	var dz := float(trial["z"]) - float(o["z"])
	var dy := float(trial.get("y", 0.0)) - float(o.get("y", 0.0))
	o.merge(trial, true)
	for rid in riders:
		var r := object_by_id(h, rid)
		r["x"] = float(r["x"]) + dx
		r["z"] = float(r["z"]) + dz
		r["y"] = float(r.get("y", 0.0)) + dy
	h.touch()
	return BuildOps.ok()


## Everything standing on an object, and on those, and so on.
static func _riders(h: HouseData, id: String) -> Array:
	var out: Array = []
	var frontier: Array = [id]
	while not frontier.is_empty():
		var cur: String = frontier.pop_back()
		for o: Dictionary in h.objects:
			if str(o.get("on", "")) == cur and not out.has(str(o["id"])):
				out.append(str(o["id"]))
				frontier.append(str(o["id"]))
	return out


## Removes an object and anything standing on it.
static func remove(h: HouseData, id: String) -> Dictionary:
	if object_by_id(h, id).is_empty():
		return BuildOps.fail("That's gone.")
	var gone: Array = [id] + _riders(h, id)
	var keep: Array[Dictionary] = []
	for o: Dictionary in h.objects:
		if not gone.has(str(o.get("id", ""))):
			keep.append(o)
	h.objects = keep
	h.touch()
	return BuildOps.ok()


## Moves several objects together by an offset, turning the group about its centre (90 degree steps).
static func move_group(h: HouseData, ids: Array, offset: Vector2, turns: int = 0) -> Dictionary:
	var objs: Array[Dictionary] = []
	for id: String in ids:
		var o := object_by_id(h, id)
		if not o.is_empty():
			objs.append(o)
	if objs.is_empty():
		return BuildOps.fail("Nothing selected.")
	var all_ids: Array = ids.duplicate()
	for id2: String in ids:
		for rid in _riders(h, id2):
			if not all_ids.has(rid):
				all_ids.append(rid)
	var centre := Vector2.ZERO
	for o in objs:
		centre += Vector2(float(o["x"]), float(o["z"]))
	centre /= objs.size()
	var before := h.to_dict()
	var a := turns * PI * 0.5
	for id3: String in all_ids:
		var o2 := object_by_id(h, id3)
		var p := Vector2(float(o2["x"]), float(o2["z"])) - centre
		p = p.rotated(-a) + centre + offset
		o2["x"] = snappedf(p.x, 0.001)
		o2["z"] = snappedf(p.y, 0.001)
		o2["rot"] = fposmod(float(o2.get("rot", 0.0)) + turns * 90.0 + 180.0, 360.0) - 180.0
	for id4: String in all_ids:
		var msg := check(h, object_by_id(h, id4), all_ids)
		if msg != "":
			var restored := HouseData.from_dict(before)
			h.objects = restored.objects
			h.touch()
			return BuildOps.fail(msg)
	h.touch()
	return BuildOps.ok()


## The Design tool: a library material and colour for one slot ({mat, colour}; mat "" keeps the
## model's own texture, tinted).
static func set_slot(h: HouseData, id: String, slot: String, value: Dictionary) -> Dictionary:
	var o := object_by_id(h, id)
	if o.is_empty():
		return BuildOps.fail("That's gone.")
	var it := Catalogue.item(Catalogue.id_of(o))
	if not (it.get("slots", {}) as Dictionary).has(slot):
		return BuildOps.fail("That has no %s to change." % slot)
	if not o.has("slots"):
		o["slots"] = {}
	var cur := Catalogue.slot_value(o, slot)
	cur.merge(value, true)
	(o["slots"] as Dictionary)[slot] = cur
	h.touch()
	return BuildOps.ok(1)


## Applies a saved style (slot -> {mat, colour}) to an object: slots it doesn't have are skipped.
static func apply_style(h: HouseData, id: String, style: Dictionary) -> Dictionary:
	var o := object_by_id(h, id)
	if o.is_empty():
		return BuildOps.fail("That's gone.")
	var it := Catalogue.item(Catalogue.id_of(o))
	var n := 0
	for slot: String in style:
		if (it.get("slots", {}) as Dictionary).has(slot):
			set_slot(h, id, slot, style[slot])
			n += 1
	if n == 0:
		return BuildOps.fail("That style doesn't fit this piece.")
	return BuildOps.ok(n)


## A lamp's brightness (0.2 to 2) and colour temperature (1500 to 6500 K).
static func set_light(h: HouseData, id: String, energy: float, kelvin: float) -> Dictionary:
	var o := object_by_id(h, id)
	if o.is_empty() or Catalogue.light_of(o).is_empty():
		return BuildOps.fail("That doesn't give light.")
	o["light"] = {"energy": clampf(energy, 0.2, 2.0), "kelvin": clampf(kelvin, 1500.0, 6500.0)}
	h.touch()
	return BuildOps.ok()


## The object under a plan point on a storey (things on top first, then the smallest).
static func object_at(h: HouseData, level: int, p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_key := Vector2(-INF, INF)
	for o: Dictionary in h.objects:
		if int(o.get("level", 0)) != level or not o.has("id"):
			continue
		var r := rect_of(o).grow(0.08)
		if not r.has_point(p):
			continue
		var key := Vector2(float(o.get("y", 0.0)), r.get_area())
		if key.x > best_key.x or (is_equal_approx(key.x, best_key.x) and key.y < best_key.y):
			best_key = key
			best = o
	return best
