class_name BuildOps
extends RefCounted
## Edits on HouseData: the same functions back the build tools, the tests and scripted builds.
## Every op returns {ok: bool, msg: String, cost: int} and leaves the house unchanged when it fails.

const FACE_EMPTY := {}


static func ok(cost: int = 0, extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true, "msg": "", "cost": cost}
	d.merge(extra)
	return d


static func fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg, "cost": 0}


static func _new_wall(kind: String, h: float) -> Dictionary:
	return {"kind": kind, "h": h, "f": {"a": {}, "b": {}}}


# --- Rooms ---------------------------------------------------------------------------------------

## Draws a rectangular room: walls round the outside, floor inside. Existing walls are kept.
## opts: floor (material), paint (paint name), name, height (wall height), wall (cladding piece id).
static func add_room(h: HouseData, level: int, rect: Rect2i, opts: Dictionary = {}) -> Dictionary:
	if rect.size.x < 1 or rect.size.y < 1:
		return fail("A room needs to be at least 1 m by 1 m.")
	if rect.size.x > 30 or rect.size.y > 30:
		return fail("That's bigger than the builders can manage in one go (30 m).")
	var s := h.storey(level)
	if s.is_empty():
		return fail("There's no %s yet." % HouseData.storey_name(level).to_lower())
	if level > 0 and not _supported(h, level, rect):
		return fail("Upper rooms need floor or walls underneath.")
	var tiles: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			tiles.append(Vector2i(x, y))
	var res := _enclose(h, level, tiles, opts)
	_label(h, level, rect.position, opts)
	h.touch()
	return res


## Adds a rectangle to an existing room (L-shapes and extensions): walls between them come down.
static func extend_room(h: HouseData, level: int, rect: Rect2i, opts: Dictionary = {}) -> Dictionary:
	var target := {}
	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			var r := h.room_at_tile(level, Vector2i(x, y))
			if not r.is_empty():
				target = r
				break
		if not target.is_empty():
			break
	if target.is_empty():
		return add_room(h, level, rect, opts)
	var union: Dictionary = {}
	for t: Vector2i in target["tiles"]:
		union[HouseData.tile_key(t.x, t.y)] = t
	for y2 in range(rect.position.y, rect.end.y):
		for x2 in range(rect.position.x, rect.end.x):
			union[HouseData.tile_key(x2, y2)] = Vector2i(x2, y2)
	var tiles: Array[Vector2i] = []
	for v: Vector2i in union.values():
		tiles.append(v)
	var paint := h.room_paint(target)
	var o := opts.duplicate()
	if not o.has("paint"):
		o["paint"] = paint
	var floor_tile: Vector2i = (target["full_tiles"] as Array)[0] if not (target["full_tiles"] as Array).is_empty() else (target["tiles"] as Array)[0]
	var fl: Dictionary = h.floors(level).get(HouseData.tile_key(floor_tile.x, floor_tile.y), {})
	if not o.has("floor") and fl.has("m") and fl["m"] is String:
		o["floor"] = fl["m"]
	var res := _enclose(h, level, tiles, o, true)
	h.touch()
	return res


## Walls round a set of tiles. With remove_inner, walls between two of the tiles are taken down.
static func _enclose(h: HouseData, level: int, tiles: Array[Vector2i], opts: Dictionary, remove_inner: bool = false) -> Dictionary:
	var s := h.storey(level)
	var walls: Dictionary = s["walls"]
	var floors: Dictionary = s["floors"]
	var inside: Dictionary = {}
	for t in tiles:
		inside[HouseData.tile_key(t.x, t.y)] = true
	var height := float(opts.get("height", s["height"]))
	var paint := str(opts.get("paint", "cream"))
	var cost := 0
	var wall_cost := Pieces.cost(str(opts.get("wall", "wall_weatherboard")))
	for t in tiles:
		var edges := [[HouseData.hkey(t.x, t.y), Vector2i(t.x, t.y - 1), "b"], [HouseData.hkey(t.x, t.y + 1), Vector2i(t.x, t.y + 1), "a"],
			[HouseData.vkey(t.x, t.y), Vector2i(t.x - 1, t.y), "b"], [HouseData.vkey(t.x + 1, t.y), Vector2i(t.x + 1, t.y), "a"]]
		for e: Array in edges:
			var other: Vector2i = e[1]
			var k: String = e[0]
			if inside.has(HouseData.tile_key(other.x, other.y)):
				if remove_inner and walls.has(k):
					_remove_wall_and_openings(h, level, k)
				continue
			if not walls.has(k):
				walls[k] = _new_wall("full", height)
				cost += wall_cost
			else:
				(walls[k] as Dictionary)["kind"] = "full"
			((walls[k] as Dictionary)["f"] as Dictionary)[e[2]] = {"mat": "plaster", "paint": paint}
		var tk := HouseData.tile_key(t.x, t.y)
		if not floors.has(tk):
			var fm := str(opts.get("floor", "floor_boards"))
			floors[tk] = {"m": fm, "rot": 0}
			cost += Pieces.cost(fm)
	return ok(cost)


static func _label(h: HouseData, level: int, at: Vector2i, opts: Dictionary) -> void:
	var labels: Dictionary = h.storey(level)["labels"]
	labels[HouseData.tile_key(at.x, at.y)] = {"name": str(opts.get("name", "Room")), "paint": str(opts.get("paint", "cream")),
		"needs_window": bool(opts.get("needs_window", true))}


static func _supported(h: HouseData, level: int, rect: Rect2i) -> bool:
	var below := h.storey(level - 1)
	if below.is_empty():
		return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if (below["floors"] as Dictionary).has(HouseData.tile_key(x, y)) or not h.room_at_tile(level - 1, Vector2i(x, y)).is_empty():
				return true
	return false


## Renames or repaints the room containing a tile.
static func set_room_props(h: HouseData, level: int, tile: Vector2i, props: Dictionary) -> Dictionary:
	var r := h.room_at_tile(level, tile)
	if r.is_empty():
		return fail("There's no room there.")
	var labels: Dictionary = h.storey(level)["labels"]
	var anchor := str(r["anchor"]) if str(r["anchor"]) != "" else str(r["key"])
	var cur: Dictionary = labels.get(anchor, {"name": "Room", "paint": "cream", "needs_window": true})
	cur.merge(props, true)
	labels[anchor] = cur
	if props.has("paint"):
		for k in h.room_walls(level, r):
			for side: String in ["a", "b"]:
				var rs := h.room_on_side(level, k, side)
				if not rs.is_empty() and rs["key"] == r["key"]:
					((h.walls(level)[k] as Dictionary)["f"] as Dictionary)[side] = {"mat": "plaster", "paint": str(props["paint"])}
	h.touch()
	return ok()


## Sets the wall height for every wall round a room (2.4, 2.7, 3.0 or 3.3 m).
static func set_room_height(h: HouseData, level: int, tile: Vector2i, height: float) -> Dictionary:
	var r := h.room_at_tile(level, tile)
	if r.is_empty():
		return fail("There's no room there.")
	if height < 2.1 or height > 4.0:
		return fail("Walls can be 2.1 to 4 m high.")
	var edges := h.room_walls(level, r)
	for o: Dictionary in h.openings(level):
		var on_room := false
		for ek in HouseData.opening_edges(o):
			on_room = on_room or edges.has(ek)
		var top := (float(o.get("sill", 0.0)) if o["kind"] == "window" else 0.0) + float(o["height"]) + (0.42 if o.get("fanlight", false) else 0.0)
		if on_room and top > height - 0.05:
			return fail("A window or door is too tall for %.1f m walls." % height)
	for k in edges:
		var w: Dictionary = h.walls(level)[k]
		if str(w.get("kind", "full")) == "full":
			w["h"] = height
	h.touch()
	return ok()


# --- Walls ---------------------------------------------------------------------------------------

## Draws a wall from corner a to corner b: straight along a grid line, or at 45 degrees.
## kind: full, half (1.0 m) or low (0.6 m).
static func add_wall(h: HouseData, level: int, a: Vector2i, b: Vector2i, kind: String = "full") -> Dictionary:
	var d := b - a
	if d == Vector2i.ZERO:
		return fail("Drag to draw a wall.")
	var straight := d.x == 0 or d.y == 0
	var diagonal := absi(d.x) == absi(d.y)
	if not straight and not diagonal:
		return fail("Walls run along the grid or at 45 degrees.")
	var s := h.storey(level)
	if s.is_empty():
		return fail("There's no %s yet." % HouseData.storey_name(level).to_lower())
	var steps := maxi(absi(d.x), absi(d.y))
	var step := Vector2i(signi(d.x), signi(d.y))
	var walls: Dictionary = s["walls"]
	var cost := 0
	var piece := "wall_half" if kind != "full" else "wall_weatherboard"
	for i in steps:
		var k := HouseData.edge_from_points(a + step * i, a + step * (i + 1))
		if not walls.has(k):
			walls[k] = _new_wall(kind, float(s["height"]))
			cost += Pieces.cost(piece)
		else:
			(walls[k] as Dictionary)["kind"] = kind
	h.touch()
	return ok(cost)


static func _remove_wall_and_openings(h: HouseData, level: int, k: String) -> void:
	var s := h.storey(level)
	(s["walls"] as Dictionary).erase(k)
	var keep: Array = []
	for o: Dictionary in s["openings"]:
		if not HouseData.opening_edges(o).has(k):
			keep.append(o)
	s["openings"] = keep


## Removes walls (and anything sitting in them) between corners a and b.
static func remove_walls(h: HouseData, level: int, a: Vector2i, b: Vector2i) -> Dictionary:
	var d := b - a
	if d == Vector2i.ZERO or not (d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y)):
		return fail("Drag along a wall to remove it.")
	var steps := maxi(absi(d.x), absi(d.y))
	var step := Vector2i(signi(d.x), signi(d.y))
	var removed := 0
	for i in steps:
		var k := HouseData.edge_from_points(a + step * i, a + step * (i + 1))
		if h.walls(level).has(k):
			_remove_wall_and_openings(h, level, k)
			removed += 1
	if removed == 0:
		return fail("There's no wall there.")
	h.touch()
	return ok(-removed)


## Paints one face of a wall ("a" or "b" side).
static func paint_face(h: HouseData, level: int, k: String, side: String, face: Dictionary) -> Dictionary:
	if not h.walls(level).has(k):
		return fail("There's no wall there.")
	(((h.walls(level)[k] as Dictionary)["f"]) as Dictionary)[side] = face.duplicate()
	return ok(1)


# --- Push and pull -------------------------------------------------------------------------------

## The straight run of walls through edge k, stopping where other walls meet it.
static func wall_run(h: HouseData, level: int, k: String) -> Array[String]:
	var out: Array[String] = [k]
	if HouseData.is_diagonal(k) or not h.walls(level).has(k):
		return out
	var horizontal := k.ends_with(",N")
	var e := HouseData.parse_edge(k)
	var x: int = e["x"]
	var y: int = e["y"]
	for dirn: int in [-1, 1]:
		var i := 0
		while true:
			# The corner between the current edge and the next one along.
			var cur := (x + i) if horizontal else (y + i)
			var corner := Vector2i(cur + (1 if dirn > 0 else 0), y) if horizontal else Vector2i(x, cur + (1 if dirn > 0 else 0))
			if _has_side_walls(h, level, corner, horizontal):
				break
			var nk := HouseData.hkey(x + i + dirn, y) if horizontal else HouseData.vkey(x, y + i + dirn)
			if not h.walls(level).has(nk):
				break
			out.append(nk)
			i += dirn
	out.sort()
	return out


## Whether any wall leaves a corner across the run's direction (perpendicular or diagonal).
static func _has_side_walls(h: HouseData, level: int, c: Vector2i, horizontal: bool) -> bool:
	var wd := h.walls(level)
	var perp: Array[String]
	if horizontal:
		perp = [HouseData.vkey(c.x, c.y - 1), HouseData.vkey(c.x, c.y)]
	else:
		perp = [HouseData.hkey(c.x - 1, c.y), HouseData.hkey(c.x, c.y)]
	for k in perp:
		if wd.has(k):
			return true
	for dd: Vector2i in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		if wd.has(HouseData.edge_from_points(c, c + dd)):
			return true
	return false


## Moves a straight run of walls by delta tiles across itself. Side walls stretch or shrink to follow,
## floors grow or shrink with the room, and doors, windows and wall faces travel with the wall.
static func push_pull(h: HouseData, level: int, k: String, delta: int) -> Dictionary:
	if delta == 0:
		return ok()
	if HouseData.is_diagonal(k):
		return fail("Diagonal walls can't be pushed or pulled yet.")
	if not h.walls(level).has(k):
		return fail("There's no wall there.")
	var s := h.storey(level)
	var wd: Dictionary = s["walls"]
	var floors: Dictionary = s["floors"]
	var run := wall_run(h, level, k)
	var horizontal := k.ends_with(",N")
	var first := HouseData.parse_edge(run[0])
	var last := HouseData.parse_edge(run[run.size() - 1])
	var line: int = first["y"] if horizontal else first["x"]
	var s0: int = first["x"] if horizontal else first["y"]
	var s1: int = (last["x"] if horizontal else last["y"]) + 1
	var new_line := line + delta
	# Which sides are rooms before the move (a = north or west, b = south or east).
	var room_a := not h.room_on_side(level, run[0], "a").is_empty()
	var room_b := not h.room_on_side(level, run[0], "b").is_empty()
	# Don't push through another wall or collapse the room onto its far side.
	for i in range(s0, s1):
		for step in range(1, absi(delta) + 1):
			var l := line + signi(delta) * step
			var kk := HouseData.hkey(i, l) if horizontal else HouseData.vkey(l, i)
			if wd.has(kk):
				return fail("There's another wall in the way.")
	# Lift the run (with its faces) and put it down on the new line.
	var lifted: Dictionary = {}
	for rk in run:
		lifted[rk] = wd[rk]
		wd.erase(rk)
	for rk2: String in lifted:
		var e := HouseData.parse_edge(rk2)
		var nk := HouseData.hkey(int(e["x"]), new_line) if horizontal else HouseData.vkey(new_line, int(e["y"]))
		wd[nk] = lifted[rk2]
	# Side walls at each end of the run follow it.
	var lo := mini(line, new_line)
	var hi := maxi(line, new_line)
	for end_pos: int in [s0, s1]:
		var behind := _side_wall_key(end_pos, line, -signi(delta), horizontal)
		var ahead := _side_wall_key(end_pos, line, signi(delta), horizontal)
		var template: Dictionary = {}
		if wd.has(behind):
			template = wd[behind]
		for l2 in range(lo, hi):
			var sk := HouseData.vkey(end_pos, l2) if horizontal else HouseData.hkey(l2, end_pos)
			if wd.has(ahead) and wd.has(sk):
				wd.erase(sk)
			elif not template.is_empty() and not wd.has(sk):
				wd[sk] = (template as Dictionary).duplicate(true)
	# Openings in the run travel with it.
	for o: Dictionary in s["openings"]:
		var axis := "x" if horizontal else "z"
		if o["axis"] != axis:
			continue
		var oline := int(o["z"]) if horizontal else int(o["x"])
		var ostart := float(o["x"]) if horizontal else float(o["z"])
		if oline == line and ostart >= s0 - 0.001 and ostart + float(o["width"]) <= s1 + 0.001:
			if horizontal:
				o["z"] = new_line
			else:
				o["x"] = new_line
	# Floors: the room behind the wall grows into the new strip; the strip ahead loses its floor if it
	# was outside.
	var grows_side_a := delta > 0  # moving south or east enlarges the room on side a
	var growing_room := room_a if grows_side_a else room_b
	var shrinking_room := room_b if grows_side_a else room_a
	for i2 in range(s0, s1):
		for l3 in range(lo, hi):
			var t := Vector2i(i2, l3) if horizontal else Vector2i(l3, i2)
			var tk := HouseData.tile_key(t.x, t.y)
			if growing_room and not floors.has(tk):
				var src := Vector2i(i2, line - 1) if horizontal else Vector2i(line - 1, i2)
				if not grows_side_a:
					src = Vector2i(i2, line) if horizontal else Vector2i(line, i2)
				var sf: Dictionary = floors.get(HouseData.tile_key(src.x, src.y), {"m": "floor_boards", "rot": 0})
				floors[tk] = sf.duplicate(true)
			elif not growing_room and not shrinking_room:
				pass
			elif not growing_room and floors.has(tk):
				floors.erase(tk)
	# Furniture standing against the wall moves with it.
	for obj: Dictionary in h.objects:
		if int(obj.get("level", 0)) != level or obj.get("outside", false):
			continue
		var ox := float(obj["x"])
		var oz := float(obj["z"])
		var dist := (oz - line) if horizontal else (ox - line)
		var along := ox if horizontal else oz
		if absf(dist) < 0.75 and along >= s0 and along <= s1 and signf(dist) != signf(float(delta)):
			if horizontal:
				obj["z"] = oz + delta
			else:
				obj["x"] = ox + delta
	h.touch()
	return ok(Pieces.cost("wall_weatherboard") * absi(delta) * 2)


static func _side_wall_key(pos: int, line: int, dirn: int, horizontal: bool) -> String:
	# The side wall leaving the run's end corner towards dirn.
	var l := line if dirn > 0 else line - 1
	return HouseData.vkey(pos, l) if horizontal else HouseData.hkey(l, pos)


# --- Moving and rotating rooms -------------------------------------------------------------------

## Picks up the room containing tile and puts it down offset by tiles, turned by quarter_turns
## (clockwise, seen from above). Shared walls stay for the neighbour. Fails if it would overlap a room.
static func move_room(h: HouseData, level: int, tile: Vector2i, offset: Vector2i, quarter_turns: int = 0) -> Dictionary:
	var r := h.room_at_tile(level, tile)
	if r.is_empty():
		return fail("There's no room there.")
	var turns := posmod(quarter_turns, 4)
	if offset == Vector2i.ZERO and turns == 0:
		return ok()
	var s := h.storey(level)
	var wd: Dictionary = s["walls"]
	var floors: Dictionary = s["floors"]
	var rb: Rect2i = r["bounds"]
	var o := Vector2(rb.position)
	var size := Vector2(rb.size)
	var pivot_new := o + Vector2(offset)
	# Rotate clockwise within the room's box, which swaps its width and height each quarter turn.
	var xf_point := func(p: Vector2) -> Vector2:
		var u := p - o
		var w := size.x
		var hh := size.y
		for i in turns:
			u = Vector2(hh - u.y, u.x)
			var tmp := w
			w = hh
			hh = tmp
		return pivot_new + u
	var xf_tile := func(t: Vector2i) -> Vector2i:
		var c: Vector2 = xf_point.call(Vector2(t) + Vector2(0.5, 0.5))
		return Vector2i(floori(c.x), floori(c.y))
	# Target tiles must be free of other rooms.
	var own: Dictionary = {}
	for t: Vector2i in r["tiles"]:
		own[HouseData.tile_key(t.x, t.y)] = true
	for t2: Vector2i in r["tiles"]:
		var nt: Vector2i = xf_tile.call(t2)
		var other := h.room_at_tile(level, nt)
		if not other.is_empty() and other["key"] != r["key"]:
			return fail("It would overlap the %s." % h.room_name(other).to_lower())
	var room_edges := h.room_walls(level, r)
	var moved_walls: Dictionary = {}
	for k in room_edges:
		var pts := HouseData.edge_points(k)
		var a2: Vector2 = xf_point.call(Vector2(pts[0]))
		var b2: Vector2 = xf_point.call(Vector2(pts[1]))
		var nk := HouseData.edge_from_points(Vector2i(roundi(a2.x), roundi(a2.y)), Vector2i(roundi(b2.x), roundi(b2.y)))
		var w: Dictionary = (wd[k] as Dictionary).duplicate(true)
		w["f"] = _rotate_faces(k, nk, w["f"], turns)
		moved_walls[nk] = w
		var ra := h.room_on_side(level, k, "a")
		var rbb := h.room_on_side(level, k, "b")
		var shared: bool = (not ra.is_empty() and ra["key"] != r["key"]) or (not rbb.is_empty() and rbb["key"] != r["key"])
		if not shared:
			wd.erase(k)
	# Openings on the room's walls (not shared ones) move too.
	var keep: Array = []
	var moved_openings: Array = []
	for op: Dictionary in s["openings"]:
		var on_room := false
		var shared_o := false
		for ek in HouseData.opening_edges(op):
			if room_edges.has(ek):
				on_room = true
				var ra2 := h.room_on_side(level, ek, "a")
				var rb2 := h.room_on_side(level, ek, "b")
				shared_o = shared_o or (not ra2.is_empty() and ra2["key"] != r["key"]) or (not rb2.is_empty() and rb2["key"] != r["key"])
		if on_room and not shared_o:
			moved_openings.append(_transform_opening(op, xf_point))
		else:
			keep.append(op)
	s["openings"] = keep
	for nk2: String in moved_walls:
		wd[nk2] = moved_walls[nk2]
	(s["openings"] as Array).append_array(moved_openings)
	# Floors and labels.
	var new_floors: Dictionary = {}
	for t3: Vector2i in r["tiles"]:
		var tk := HouseData.tile_key(t3.x, t3.y)
		if floors.has(tk):
			var f: Dictionary = (floors[tk] as Dictionary).duplicate(true)
			if f.get("m") is Array:
				var qm: Array = f["m"]
				var rot_q: Array = qm.duplicate()
				for i in 4:
					rot_q[(i + turns) % 4] = qm[i]
				f["m"] = rot_q
			if turns % 2 == 1:
				f["rot"] = (int(f.get("rot", 0)) + 90) % 180
			var nt2: Vector2i = xf_tile.call(t3)
			new_floors[HouseData.tile_key(nt2.x, nt2.y)] = f
			floors.erase(tk)
	floors.merge(new_floors, true)
	var labels: Dictionary = s["labels"]
	if str(r["anchor"]) != "":
		var props: Dictionary = labels[r["anchor"]]
		labels.erase(r["anchor"])
		var na: Vector2i = xf_tile.call(HouseData.parse_tile(r["anchor"]))
		labels[HouseData.tile_key(na.x, na.y)] = props
	# Furniture inside goes along for the ride.
	for obj: Dictionary in h.objects:
		if int(obj.get("level", 0)) != level:
			continue
		var ot := Vector2i(floori(float(obj["x"])), floori(float(obj["z"])))
		if own.has(HouseData.tile_key(ot.x, ot.y)):
			var np: Vector2 = xf_point.call(Vector2(float(obj["x"]), float(obj["z"])))
			obj["x"] = np.x
			obj["z"] = np.y
			obj["rot"] = float(obj.get("rot", 0.0)) - 90.0 * turns
	h.touch()
	return ok(Pieces.cost("move_room"))


## Works out which side of the new edge each old face now faces.
static func _rotate_faces(old_k: String, new_k: String, faces: Dictionary, turns: int) -> Dictionary:
	var old_a := _side_normal(old_k)
	var v := old_a
	for i in turns:
		v = Vector2(-v.y, v.x)
	var new_a := _side_normal(new_k)
	if v.dot(new_a) > 0.0:
		return {"a": (faces.get("a", {}) as Dictionary).duplicate(), "b": (faces.get("b", {}) as Dictionary).duplicate()}
	return {"a": (faces.get("b", {}) as Dictionary).duplicate(), "b": (faces.get("a", {}) as Dictionary).duplicate()}


## A vector pointing out of side a of an edge.
static func _side_normal(k: String) -> Vector2:
	if k.ends_with(",N"):
		return Vector2(0, -1)
	if k.ends_with(",W"):
		return Vector2(-1, 0)
	if k.ends_with(",D"):
		return Vector2(1, -1).normalized()
	return Vector2(-1, -1).normalized()


static func _transform_opening(op: Dictionary, xf_point: Callable) -> Dictionary:
	var o := op.duplicate(true)
	var a: Vector2
	var b: Vector2
	if o["axis"] == "x":
		a = Vector2(float(o["x"]), float(o["z"]))
		b = a + Vector2(float(o["width"]), 0)
	else:
		a = Vector2(float(o["x"]), float(o["z"]))
		b = a + Vector2(0, float(o["width"]))
	var na: Vector2 = xf_point.call(a)
	var nb: Vector2 = xf_point.call(b)
	if is_equal_approx(na.y, nb.y):
		o["axis"] = "x"
		o["x"] = minf(na.x, nb.x)
		o["z"] = roundi(na.y)
	else:
		o["axis"] = "z"
		o["x"] = roundi(na.x)
		o["z"] = minf(na.y, nb.y)
	return o


# --- Doors, windows and arches ---------------------------------------------------------------------

## Places an opening. It must sit on walls along its whole width, fit under the wall height, and not
## overlap another opening (windows may stack above each other on tall walls).
static func place_opening(h: HouseData, level: int, op: Dictionary) -> Dictionary:
	var o := op.duplicate(true)
	if not o.has("id"):
		o["id"] = h.new_id("o")
	var s := h.storey(level)
	if s.is_empty():
		return fail("There's no storey there.")
	var kind := str(o["kind"])
	var bottom := float(o.get("sill", 0.0)) if kind == "window" else 0.0
	var top := bottom + float(o["height"]) + (0.42 if o.get("fanlight", false) else 0.0)
	for k in HouseData.opening_edges(o):
		var w := h.wall(level, k)
		if w.is_empty():
			return fail("Doors and windows go in walls.")
		if str(w.get("kind", "full")) != "full":
			return fail("Half and low walls can't hold a %s." % kind)
		if top > h.wall_h(level, k) - 0.05:
			return fail("That's too tall for this wall.")
	var start := float(o["x"]) if o["axis"] == "x" else float(o["z"])
	var end := start + float(o["width"])
	var line := int(o["z"]) if o["axis"] == "x" else int(o["x"])
	for other: Dictionary in s["openings"]:
		if other["id"] == o["id"] or other["axis"] != o["axis"]:
			continue
		var ol := int(other["z"]) if o["axis"] == "x" else int(other["x"])
		if ol != line:
			continue
		var os := float(other["x"]) if o["axis"] == "x" else float(other["z"])
		var oe := os + float(other["width"])
		if end <= os + 0.001 or start >= oe - 0.001:
			continue
		var ob := float(other.get("sill", 0.0)) if other["kind"] == "window" else 0.0
		var ot := ob + float(other["height"]) + (0.42 if other.get("fanlight", false) else 0.0)
		if top <= ob + 0.05 or bottom >= ot - 0.05:
			continue  # stacked windows
		return fail("That overlaps another %s." % other["kind"])
	var keep: Array = []
	for other2: Dictionary in s["openings"]:
		if other2["id"] != o["id"]:
			keep.append(other2)
	keep.append(o)
	s["openings"] = keep
	h.touch()
	return ok(Pieces.cost(str(o.get("style", kind))), {"id": o["id"]})


static func remove_opening(h: HouseData, oid: String) -> Dictionary:
	for s in h.storeys:
		var keep: Array = []
		var found := false
		for o: Dictionary in s["openings"]:
			if o["id"] == oid:
				found = true
			else:
				keep.append(o)
		if found:
			s["openings"] = keep
			h.touch()
			return ok()
	return fail("Nothing to remove.")


## Changes an opening's settings (position, sill, swing, lock, keys, night behaviour) with validation.
static func update_opening(h: HouseData, oid: String, changes: Dictionary) -> Dictionary:
	var o := h.opening_by_id(oid)
	if o.is_empty():
		return fail("Nothing selected.")
	var level := h.opening_level(oid)
	var updated := o.duplicate(true)
	updated.merge(changes, true)
	var res := place_opening(h, level, updated)
	return res


# --- Floors --------------------------------------------------------------------------------------

## Paints floor tiles. quarters picks triangles (0 N, 1 E, 2 S, 3 W); all four paints the whole tile.
static func paint_floor(h: HouseData, level: int, tiles: Array[Vector2i], mat: String, quarters: Array = [0, 1, 2, 3], rot: int = -1) -> Dictionary:
	var floors: Dictionary = h.storey(level)["floors"]
	var cost := 0
	for t in tiles:
		var tk := HouseData.tile_key(t.x, t.y)
		var f: Dictionary = floors.get(tk, {"m": mat, "rot": 0})
		if quarters.size() == 4:
			f["m"] = mat
		else:
			var qm: Array = f["m"] if f["m"] is Array else [f["m"], f["m"], f["m"], f["m"]]
			for q: int in quarters:
				qm[q] = mat
			f["m"] = qm
			if qm[0] == qm[1] and qm[1] == qm[2] and qm[2] == qm[3]:
				f["m"] = qm[0]
		if rot >= 0:
			f["rot"] = rot
		floors[tk] = f
		cost += Pieces.cost(mat)
	h.touch()
	return ok(cost)


static func remove_floor(h: HouseData, level: int, tiles: Array[Vector2i]) -> Dictionary:
	var floors: Dictionary = h.storey(level)["floors"]
	for t in tiles:
		floors.erase(HouseData.tile_key(t.x, t.y))
	h.touch()
	return ok()


# --- Storeys and stairs --------------------------------------------------------------------------

## Adds a storey above the top one (up to 3) or a cellar below the ground floor.
static func add_storey(h: HouseData, level: int, height: float = 2.7) -> Dictionary:
	if level < HouseData.MIN_LEVEL or level > HouseData.MAX_LEVEL:
		return fail("Houses go up to three storeys and a cellar.")
	if h.has_storey(level):
		return ok()
	if level > 0 and not h.has_storey(level - 1):
		return fail("Build the storey below first.")
	h.storeys.append(HouseData.new_storey(level, height))
	h.storeys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	h.touch()
	return ok()


## Places a staircase on a storey, rising to the one above. It must stand on floor inside the house,
## have a clear run with no walls across it, and arrive on a floor upstairs.
static func add_stairs(h: HouseData, level: int, st: Dictionary) -> Dictionary:
	var stair := st.duplicate(true)
	if not stair.has("id"):
		stair["id"] = h.new_id("st")
	var above := h.storey(level + 1)
	if above.is_empty():
		return fail("Add a storey above first.")
	var info := h.stair_tiles(stair, level)
	var floors: Dictionary = h.floors(level)
	var lower: Array = info["lower"]
	for t: Vector2i in lower:
		if not floors.has(HouseData.tile_key(t.x, t.y)):
			return fail("Stairs need floor to stand on.")
		for other: Dictionary in h.stairs(level):
			if (h.stair_tiles(other, level)["lower"] as Array).has(t):
				return fail("That's on top of another staircase.")
	var path: Array = info["path"]
	for i in path.size() - 1:
		if _edge_between_blocked(h, level, path[i], path[i + 1]):
			return fail("There's a wall across the stairs.")
	var arr: Vector2i = info["arrival"]
	if not (above["floors"] as Dictionary).has(HouseData.tile_key(arr.x, arr.y)):
		return fail("The top of the stairs needs a floor to step onto.")
	if (h.stairwell_tiles(level + 1) as Dictionary).has(HouseData.tile_key(arr.x, arr.y)):
		return fail("The top of the stairs would land in another stairwell.")
	(h.storey(level)["stairs"] as Array).append(stair)
	h.touch()
	return ok(Pieces.cost("stairs_" + str(stair.get("kind", "straight"))), {"id": stair["id"]})


static func _edge_between_blocked(h: HouseData, level: int, a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	var k := ""
	if d == Vector2i(1, 0):
		k = HouseData.vkey(b.x, b.y)
	elif d == Vector2i(-1, 0):
		k = HouseData.vkey(a.x, a.y)
	elif d == Vector2i(0, 1):
		k = HouseData.hkey(b.x, b.y)
	elif d == Vector2i(0, -1):
		k = HouseData.hkey(a.x, a.y)
	return k != "" and h.walls(level).has(k)


static func remove_stairs(h: HouseData, sid: String) -> Dictionary:
	for s in h.storeys:
		var keep: Array = []
		var found := false
		for st: Dictionary in s["stairs"]:
			if st["id"] == sid:
				found = true
			else:
				keep.append(st)
		if found:
			s["stairs"] = keep
			h.touch()
			return ok()
	return fail("Nothing to remove.")


# --- Columns, foundations ------------------------------------------------------------------------

static func add_column(h: HouseData, level: int, corner: Vector2i, kind: String = "timber_post") -> Dictionary:
	var cols: Array = h.storey(level)["columns"]
	for c: Dictionary in cols:
		if int(c["x"]) == corner.x and int(c["y"]) == corner.y:
			return fail("There's already a post there.")
	cols.append({"x": corner.x, "y": corner.y, "kind": kind})
	return ok(Pieces.cost(kind))


static func remove_column(h: HouseData, level: int, corner: Vector2i) -> Dictionary:
	var keep: Array = []
	var found := false
	for c: Dictionary in h.storey(level)["columns"]:
		if int(c["x"]) == corner.x and int(c["y"]) == corner.y:
			found = true
		else:
			keep.append(c)
	h.storey(level)["columns"] = keep
	return ok() if found else fail("There's no post there.")


static func set_foundation(h: HouseData, type: String, height: float) -> Dictionary:
	if type == "stumps" and (height < 0.3 or height > 1.8):
		return fail("Stumps can be 0.3 to 1.8 m high.")
	h.foundation = {"type": type, "height": height if type == "stumps" else (0.15 if type == "slab" else height)}
	return ok()


## Demolishes a room: its own walls (not ones shared with a neighbour), its openings and its floor.
static func remove_room(h: HouseData, level: int, tile: Vector2i) -> Dictionary:
	var r := h.room_at_tile(level, tile)
	if r.is_empty():
		return fail("There's no room there.")
	var s := h.storey(level)
	var removed := 0
	for k in h.room_walls(level, r):
		var ra := h.room_on_side(level, k, "a")
		var rb := h.room_on_side(level, k, "b")
		var shared: bool = (not ra.is_empty() and ra["key"] != r["key"]) or (not rb.is_empty() and rb["key"] != r["key"])
		if not shared:
			_remove_wall_and_openings(h, level, k)
			removed += 1
	for t: Vector2i in r["tiles"]:
		(s["floors"] as Dictionary).erase(HouseData.tile_key(t.x, t.y))
		(s["labels"] as Dictionary).erase(HouseData.tile_key(t.x, t.y))
	h.touch()
	return ok(-removed)


# --- Surfaces (M3) ---------------------------------------------------------------------------------

## Faces [edge key, side] of the walls round a room that face into it.
static func room_faces(h: HouseData, level: int, r: Dictionary) -> Array:
	var out: Array = []
	for k in h.room_walls(level, r):
		for side: String in ["a", "b"]:
			var rs := h.room_on_side(level, k, side)
			if not rs.is_empty() and rs["key"] == r["key"]:
				out.append([k, side])
	return out


## Every outside face on a storey (all levels with level = 99).
static func exterior_faces(h: HouseData, level: int = 99) -> Array:
	var out: Array = []
	for l in h.levels():
		if level != 99 and l != level:
			continue
		for k: String in h.walls(l):
			for side: String in ["a", "b"]:
				if h.room_on_side(l, k, side).is_empty() and not h.room_on_side(l, k, "b" if side == "a" else "a").is_empty():
					out.append([k, side, l])
	return out


## Every inside face in the house, all storeys.
static func interior_faces(h: HouseData) -> Array:
	var out: Array = []
	for l in h.levels():
		for k: String in h.walls(l):
			for side: String in ["a", "b"]:
				if not h.room_on_side(l, k, side).is_empty():
					out.append([k, side, l])
	return out


## Applies a surface to faces ([edge, side] or [edge, side, level]). With part = "dado" it sets only
## the lower wall (panelling or tiles to surface.h metres); otherwise it replaces the finish and keeps
## any dado. Surfaces: {mat, paint} or {mat: "wallpaper", pattern, colourway}.
static func paint_faces(h: HouseData, level: int, faces: Array, surface: Dictionary, part: String = "finish") -> Dictionary:
	if faces.is_empty():
		return fail("Point at a wall to paint it.")
	var n := 0
	for f: Array in faces:
		var lv: int = f[2] if f.size() > 2 else level
		var k: String = f[0]
		if not h.walls(lv).has(k):
			continue
		var fd: Dictionary = (h.walls(lv)[k] as Dictionary)["f"]
		var cur: Dictionary = (fd.get(f[1], {}) as Dictionary).duplicate(true)
		if part == "dado":
			if surface.is_empty():
				cur.erase("dado")
			else:
				cur["dado"] = surface.duplicate(true)
			if not cur.has("mat"):
				cur["mat"] = "plaster"
				var r := h.room_on_side(lv, k, f[1])
				cur["paint"] = h.room_paint(r) if not r.is_empty() else "cream"
		else:
			var keep_dado: Variant = cur.get("dado")
			cur = surface.duplicate(true)
			if keep_dado != null:
				cur["dado"] = keep_dado
		fd[f[1]] = cur
		n += 1
	if n == 0:
		return fail("There's no wall there.")
	return ok(ceili(n * 0.5))


## The surface on a face, for the eyedropper.
static func pick_surface(h: HouseData, level: int, k: String, side: String) -> Dictionary:
	if not h.walls(level).has(k):
		return {}
	var fd: Dictionary = (((h.walls(level)[k] as Dictionary)["f"] as Dictionary).get(side, {}) as Dictionary).duplicate(true)
	if fd.has("mat"):
		return fd
	var r := h.room_on_side(level, k, side)
	if r.is_empty():
		return {"mat": str(h.exterior.get("cladding", "weatherboard")), "paint": str(h.exterior.get("paint", "cream"))}
	return {"mat": "plaster", "paint": h.room_paint(r)}


## The quality tier for building work: rough, standard or fine.
static func set_quality(h: HouseData, tier: String) -> Dictionary:
	if not Construction.TIERS.has(tier):
		return fail("Unknown quality.")
	h.quality = tier
	return ok()


## Sets the house's trim colour (fascias, sashes, posts) and door colour.
static func set_exterior(h: HouseData, changes: Dictionary) -> Dictionary:
	h.exterior.merge(changes, true)
	return ok(2)


# --- Roofs and chimneys --------------------------------------------------------------------------

static func _roof_total(h: HouseData) -> int:
	var t := 0
	for p: Dictionary in Roofs.pieces(h):
		t += Roofs.cost(p)
	return t


## Roofs the whole house from its plan. The roof keeps following the plan until a piece is changed
## by hand.
static func auto_roof(h: HouseData, settings: Dictionary) -> Dictionary:
	if h.rooms(0).is_empty() and h.levels().all(func(l: int) -> bool: return h.rooms(l).is_empty()):
		return fail("Build some rooms first; the roof follows the plan.")
	var before := _roof_total(h)
	var s := Roofs.defaults()
	s.merge(settings, true)
	s["pitch"] = Roofs.clamp_pitch(str(s["shape"]), float(s["pitch"]))
	h.roof = {"follow": true, "auto": s}
	h.touch()
	return ok(maxi(0, _roof_total(h) - before))


## Turns a roof that follows the plan into explicit pieces, so they can be edited one by one.
static func _materialise_roof(h: HouseData) -> void:
	if h.roof.is_empty():
		h.roof = {"follow": false, "auto": Roofs.defaults(), "pieces": []}
		return
	if bool(h.roof.get("follow", false)) or h.roof.has("type"):
		var pcs := Roofs.pieces(h)
		var auto_s: Dictionary = h.roof.get("auto", Roofs.defaults())
		if h.roof.has("type"):
			auto_s = {"shape": h.roof["type"], "pitch": h.roof.get("pitch", 28.0), "overhang": h.roof.get("overhang", 0.45), "material": h.roof.get("material", "corrugated_iron")}
		for p: Dictionary in pcs:
			p["id"] = h.new_id("roof")
		h.roof = {"follow": false, "auto": auto_s, "pieces": pcs}


## Adds a hand-drawn roof piece over a rectangle (wall lines, metres).
static func add_roof_piece(h: HouseData, level: int, rect: Rect2, opts: Dictionary = {}) -> Dictionary:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return fail("A roof needs to be at least 1 m by 1 m.")
	if not h.has_storey(level):
		return fail("There's no storey there to roof.")
	_materialise_roof(h)
	var p := Roofs.defaults()
	p.merge(h.roof.get("auto", {}), true)
	p.merge(opts, true)
	p["id"] = h.new_id("roof")
	p["level"] = level
	p["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if not p.has("axis"):
		p["axis"] = "x" if rect.size.x >= rect.size.y else "z"
	if Roofs.is_mono(p) and not p.has("high"):
		p["high"] = "N" if rect.size.x >= rect.size.y else "W"
	if not p.has("joins"):
		p["joins"] = []
	p["pitch"] = Roofs.clamp_pitch(str(p["shape"]), float(p["pitch"]))
	(h.roof["pieces"] as Array).append(p)
	h.touch()
	return ok(Roofs.cost(p), {"id": p["id"]})


static func roof_piece(h: HouseData, id: String) -> Dictionary:
	for p: Dictionary in h.roof.get("pieces", []):
		if str(p.get("id", "")) == id:
			return p
	return {}


## Changes a piece: shape, pitch, overhang, material, axis, high side, rect or per-end shapes.
## Pieces made by the auto-roof are first copied out so the roof stops following the plan.
static func update_roof_piece(h: HouseData, id: String, changes: Dictionary) -> Dictionary:
	var auto_index := -1
	if bool(h.roof.get("follow", false)) or h.roof.has("type"):
		var pcs := Roofs.pieces(h)
		for i in pcs.size():
			if str(pcs[i].get("id", "")) == id:
				auto_index = i
		_materialise_roof(h)
		if auto_index >= 0:
			id = str((h.roof["pieces"] as Array)[auto_index]["id"])
	var p := roof_piece(h, id)
	if p.is_empty():
		return fail("That roof piece has gone.")
	var before := Roofs.cost(p)
	var c := changes.duplicate(true)
	if c.has("rect"):
		var r: Array = c["rect"]
		if float(r[2]) < 1.0 or float(r[3]) < 1.0:
			return fail("A roof needs to be at least 1 m by 1 m.")
	if c.has("overhang"):
		c["overhang"] = clampf(float(c["overhang"]), 0.0, 1.2)
	p.merge(c, true)
	if Roofs.is_mono(p) and not p.has("high"):
		p["high"] = "N"
	p["pitch"] = Roofs.clamp_pitch(str(p["shape"]), float(p.get("pitch", 28.0)))
	h.touch()
	return ok(maxi(0, Roofs.cost(p) - before), {"id": id})


static func remove_roof_piece(h: HouseData, id: String) -> Dictionary:
	var auto_index := -1
	if bool(h.roof.get("follow", false)) or h.roof.has("type"):
		var pcs := Roofs.pieces(h)
		for i in pcs.size():
			if str(pcs[i].get("id", "")) == id:
				auto_index = i
		_materialise_roof(h)
		if auto_index >= 0:
			id = str((h.roof["pieces"] as Array)[auto_index]["id"])
	var arr: Array = h.roof.get("pieces", [])
	for i2 in arr.size():
		if str(arr[i2].get("id", "")) == id:
			arr.remove_at(i2)
			h.touch()
			return ok()
	return fail("That roof piece has gone.")


static func remove_roof(h: HouseData) -> Dictionary:
	if h.roof.is_empty():
		return fail("There's no roof to take off.")
	h.roof = {}
	h.touch()
	return ok()


## A brick chimney on a wall: straddling it when the wall is inside, built against the outside face
## when it's an outside wall. The stack clears the roof by 0.6 m wherever the roof is.
static func add_chimney(h: HouseData, level: int, k: String) -> Dictionary:
	if not h.walls(level).has(k) or HouseData.is_diagonal(k):
		return fail("Chimneys go on a straight wall.")
	var pts := HouseData.edge_points(k)
	var mid := Vector2(pts[0] + pts[1]) * 0.5
	var along_x := pts[0].y == pts[1].y
	for c: Dictionary in h.chimneys:
		if Vector2(float(c["x"]) + float(c["w"]) * 0.5, float(c["z"]) + float(c["d"]) * 0.5).distance_to(mid) < 1.0:
			return fail("There's already a chimney there.")
	var outside := ""
	for side: String in ["a", "b"]:
		if h.room_on_side(level, k, side).is_empty():
			outside = side
	var w := 1.2
	var d := 0.6
	var c2 := {"level": level, "edge": k, "w": w if along_x else d, "d": d if along_x else w}
	var off := 0.0
	if outside != "":
		# Side a is north (horizontal walls) or west (vertical walls).
		off = (-1.0 if outside == "a" else 1.0) * (d * 0.5 + 0.06)
		c2["outside"] = true
	if along_x:
		c2["x"] = mid.x - w * 0.5
		c2["z"] = mid.y + off - d * 0.5
	else:
		c2["x"] = mid.x + off - d * 0.5
		c2["z"] = mid.y - w * 0.5
	h.chimneys.append(c2)
	h.touch()
	return ok(Pieces.cost("chimney"))


static func remove_chimney(h: HouseData, index: int) -> Dictionary:
	if index < 0 or index >= h.chimneys.size():
		return fail("There's no chimney there.")
	h.chimneys.remove_at(index)
	h.touch()
	return ok()


## Index of the chimney nearest a plan point (within 1 m), or -1.
static func chimney_at(h: HouseData, x: float, z: float) -> int:
	for i in h.chimneys.size():
		var c: Dictionary = h.chimneys[i]
		var r := Rect2(float(c["x"]), float(c["z"]), float(c["w"]), float(c["d"])).grow(0.4)
		if r.has_point(Vector2(x, z)):
			return i
	return -1


# --- Verandahs and sleep-outs --------------------------------------------------------------------
# A verandah: {"id", "level", "side": N|E|S|W (which way it faces), "line" (the wall line it runs
# along), "from", "to" (along that line), "depth" (out from the wall face), "shape": bullnose |
# skillion | gable, "material", "post": timber_post | turned_post | cast_iron, "lace": none | lace |
# fretwork, "rail": none | timber | lace, "lattice": bool, "steps": [[from, to]], "post_h",
# "sleepout": {"from", "to", "kind"}}.

const VERANDAH_SHAPES: Array[String] = ["bullnose", "skillion", "gable"]
const VERANDAH_DEFAULTS := {"depth": 2.1, "shape": "bullnose", "material": "corrugated_iron", "post": "timber_post",
	"lace": "none", "rail": "none", "lattice": false, "steps": [], "post_h": 2.1}


## The straight outside run of wall through edge k, and the way it faces:
## {side, line, from, to} or {} when k isn't an outside wall.
static func outside_run(h: HouseData, level: int, k: String) -> Dictionary:
	if HouseData.is_diagonal(k) or not h.walls(level).has(k):
		return {}
	var out_side := ""
	for sd: String in ["a", "b"]:
		if h.room_on_side(level, k, sd).is_empty() and not h.room_on_side(level, k, "b" if sd == "a" else "a").is_empty():
			out_side = sd
	if out_side == "":
		return {}
	var horizontal := k.ends_with(",N")
	var e := HouseData.parse_edge(k)
	var line: int = e["y"] if horizontal else e["x"]
	var at: int = e["x"] if horizontal else e["y"]
	var lo := at
	var hi := at + 1
	var outside := func(i: int) -> bool:
		var kk := HouseData.hkey(i, line) if horizontal else HouseData.vkey(line, i)
		return h.walls(level).has(kk) and h.room_on_side(level, kk, out_side).is_empty() and not h.room_on_side(level, kk, "b" if out_side == "a" else "a").is_empty()
	while outside.call(lo - 1):
		lo -= 1
	while outside.call(hi):
		hi += 1
	var side := ("N" if out_side == "a" else "S") if horizontal else ("W" if out_side == "a" else "E")
	return {"side": side, "line": float(line), "from": float(lo), "to": float(hi)}


static func verandah_by_id(h: HouseData, id: String) -> Dictionary:
	for v: Dictionary in h.verandahs:
		if str(v.get("id", "")) == id:
			return v
	return {}


static func _verandah_cost(v: Dictionary) -> int:
	var length := float(v["to"]) - float(v["from"])
	var c := ceili(length * float(v["depth"]) * float(Pieces.cost("verandah")))
	if str(v.get("lace", "none")) != "none":
		c += ceili(length * Pieces.cost("lace"))
	if str(v.get("rail", "none")) != "none":
		c += ceili(length * Pieces.cost("verandah_rail"))
	return c


static func _verandah_check(h: HouseData, v: Dictionary) -> String:
	if float(v["to"]) - float(v["from"]) < 1.0:
		return "A verandah needs to be at least 1 m long."
	if float(v["depth"]) < 1.2 or float(v["depth"]) > 3.6:
		return "Verandahs are 1.2 to 3.6 m deep."
	for o: Dictionary in h.verandahs:
		if o.get("id", "") == v.get("id", "") or str(o["side"]) != str(v["side"]):
			continue
		if not is_equal_approx(float(o.get("line", -999.0)), float(v["line"])):
			continue
		if float(v["from"]) < float(o["to"]) - 0.01 and float(v["to"]) > float(o["from"]) + 0.01:
			return "There's already a verandah there."
	return ""


## Adds a verandah along an outside wall line.
static func add_verandah(h: HouseData, level: int, side: String, line: float, from: float, to: float, opts: Dictionary = {}) -> Dictionary:
	var v := VERANDAH_DEFAULTS.duplicate(true)
	v.merge(opts.duplicate(true), true)
	v["id"] = h.new_id("v")
	v["level"] = level
	v["side"] = side
	v["line"] = line
	v["from"] = minf(from, to)
	v["to"] = maxf(from, to)
	var msg := _verandah_check(h, v)
	if msg != "":
		return fail(msg)
	h.verandahs.append(v)
	h.touch()
	return ok(_verandah_cost(v), {"id": v["id"]})


static func update_verandah(h: HouseData, id: String, changes: Dictionary) -> Dictionary:
	var v := verandah_by_id(h, id)
	if v.is_empty():
		return fail("That verandah has gone.")
	var before := _verandah_cost(v)
	var trial := v.duplicate(true)
	trial.merge(changes.duplicate(true), true)
	if trial.has("sleepout") and changes.has("depth"):
		return fail("Take the sleep-out off before changing the depth.")
	var msg := _verandah_check(h, trial)
	if msg != "":
		return fail(msg)
	v.merge(changes.duplicate(true), true)
	h.touch()
	return ok(maxi(0, _verandah_cost(v) - before))


static func remove_verandah(h: HouseData, id: String) -> Dictionary:
	for i in h.verandahs.size():
		if str(h.verandahs[i].get("id", "")) == id:
			if h.verandahs[i].has("sleepout"):
				_remove_sleepout_room(h, h.verandahs[i])
			h.verandahs.remove_at(i)
			h.touch()
			return ok()
	return fail("That verandah has gone.")


## Adds or removes a flight of steps centred at u along the verandah's outer edge.
static func toggle_steps(h: HouseData, id: String, u: float) -> Dictionary:
	var v := verandah_by_id(h, id)
	if v.is_empty():
		return fail("That verandah has gone.")
	var steps: Array = (v.get("steps", []) as Array).duplicate(true)
	for i in steps.size():
		if u >= float(steps[i][0]) - 0.1 and u <= float(steps[i][1]) + 0.1:
			steps.remove_at(i)
			v["steps"] = steps
			h.touch()
			return ok()
	var a := clampf(snappedf(u - 0.8, 0.25), float(v["from"]), float(v["to"]) - 1.0)
	var so: Dictionary = v.get("sleepout", {})
	if not so.is_empty() and a + 1.6 > float(so["from"]) and a < float(so["to"]):
		return fail("Steps can't go up into the sleep-out.")
	steps.append([a, minf(a + 1.6, float(v["to"]))])
	v["steps"] = steps
	h.touch()
	return ok(Pieces.cost("verandah_steps"))


## The rooms' tile rectangle for a sleep-out on part of a verandah.
static func sleepout_rect(v: Dictionary, from: float, to: float) -> Rect2i:
	var d := floori(float(v["depth"]) + 0.01)
	var line := roundi(float(v["line"]))
	var a := roundi(from)
	var b := roundi(to)
	match str(v["side"]):
		"N":
			return Rect2i(a, line - d, b - a, d)
		"S":
			return Rect2i(a, line, b - a, d)
		"W":
			return Rect2i(line - d, a, d, b - a)
	return Rect2i(line, a, d, b - a)


## Encloses part of a verandah as a sleep-out: a real room (so residents can sleep there) with
## weatherboard to sill height and louvres or casements above, under the verandah roof.
static func enclose_sleepout(h: HouseData, id: String, from: float, to: float, kind: String = "louvre") -> Dictionary:
	var v := verandah_by_id(h, id)
	if v.is_empty():
		return fail("That verandah has gone.")
	if v.has("sleepout"):
		return fail("This verandah already has a sleep-out.")
	if float(v["depth"]) < 2.0:
		return fail("A sleep-out needs a verandah at least 2 m deep.")
	var a := maxf(float(v["from"]), roundf(minf(from, to)))
	var b := minf(float(v["to"]), roundf(maxf(from, to)))
	if b - a < 2.0:
		return fail("A sleep-out needs at least 2 m of verandah.")
	for st: Array in v.get("steps", []):
		if float(st[0]) < b and float(st[1]) > a:
			return fail("Move the steps off that stretch first.")
	var lv := int(v.get("level", 0))
	if h.storey_height(lv) < 2.7:
		return fail("The house walls are too low to fit a sleep-out under the verandah.")
	var rect := sleepout_rect(v, a, b)
	var res := add_room(h, lv, rect, {"name": "Sleep-out", "paint": "cream", "floor": "decking", "height": 2.4})
	if not res["ok"]:
		return res
	set_room_props(h, lv, rect.position, {"sleepout": true})
	# Louvres (or casements) along the outer wall, about one per 1.2 m.
	var outer := {"N": rect.position.y, "S": rect.end.y, "W": rect.position.x, "E": rect.end.x}[str(v["side"])] as int
	var horizontal := str(v["side"]) in ["N", "S"]
	var n := maxi(1, floori((b - a) / 1.2))
	var piece := Pieces.get_piece(kind)
	var w := float(piece.get("width", 0.9))
	var cost := int(res["cost"])
	for i in n:
		var at := a + (b - a) * (i + 0.5) / n - w * 0.5
		var o := {"kind": "window", "style": kind, "width": w, "height": float(piece.get("height", 1.2)), "sill": 1.0,
			"axis": "x" if horizontal else "z", "x": at if horizontal else float(outer), "z": float(outer) if horizontal else at,
			"night": {"latch": false, "curtains": false, "lock": false}}
		var r2 := place_opening(h, lv, o)
		if r2["ok"]:
			cost += int(r2["cost"])
	v["sleepout"] = {"from": a, "to": b, "kind": kind}
	v["post_h"] = maxf(float(v.get("post_h", 2.1)), 2.45)
	# A bullnose can't clear sleep-out walls under the eaves; sleep-outs sit under a skillion.
	if str(v.get("shape", "bullnose")) == "bullnose":
		v["shape"] = "skillion"
	h.touch()
	return ok(cost + Pieces.cost("sleepout"))


static func _remove_sleepout_room(h: HouseData, v: Dictionary) -> void:
	var so: Dictionary = v["sleepout"]
	var rect := sleepout_rect(v, float(so["from"]), float(so["to"]))
	var lv := int(v.get("level", 0))
	if not h.room_at_tile(lv, rect.position).is_empty():
		remove_room(h, lv, rect.position)


## Opens a sleep-out back up into verandah.
static func remove_sleepout(h: HouseData, id: String) -> Dictionary:
	var v := verandah_by_id(h, id)
	if v.is_empty() or not v.has("sleepout"):
		return fail("There's no sleep-out there.")
	_remove_sleepout_room(h, v)
	v.erase("sleepout")
	h.touch()
	return ok()


## The verandah whose deck covers a plan point, or {}.
static func verandah_at(h: HouseData, x: float, z: float) -> Dictionary:
	for v: Dictionary in h.verandahs:
		if verandah_rect(h, v).grow(0.15).has_point(Vector2(x, z)):
			return v
	return {}


## A verandah's deck rectangle in plan (from the wall face out).
static func verandah_rect(h: HouseData, v: Dictionary) -> Rect2:
	var t := HouseData.WALL_THICKNESS * 0.5
	var depth := float(v["depth"])
	var a := float(v.get("from", 0.0))
	var b := float(v.get("to", 0.0))
	var line := float(v["line"]) if v.has("line") else _legacy_line(h, v)
	match str(v["side"]):
		"N":
			return Rect2(a, line - t - depth, b - a, depth)
		"S":
			return Rect2(a, line + t, b - a, depth)
		"W":
			return Rect2(line - t - depth, a, depth, b - a)
	return Rect2(line + t, a, depth, b - a)


## M1 verandahs had no line: they ran along the footprint's edge.
static func _legacy_line(h: HouseData, v: Dictionary) -> float:
	var fp := h.footprint()
	match str(v["side"]):
		"N":
			return fp.position.y
		"S":
			return fp.end.y
		"W":
			return fp.position.x
	return fp.end.x
