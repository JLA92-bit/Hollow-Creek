class_name Roofs
extends RefCounted
## Roof pieces and their geometry: hip, gable, half-hip (jerkinhead), Dutch gable, skillion and
## flat, plus the auto-roof that turns a floor plan into pieces. Plain class with no scene
## dependencies, so the mesh builder, BuildOps and tests share one source of truth.
##
## A piece: {"id", "level", "rect": [x, z, w, d] (wall lines, metres), "shape", "axis": "x" | "z"
## (ridge direction), "pitch" (degrees), "overhang" (m), "material", "joins": [sides buried in
## another roof or against a wall, no overhang or trim], "ends": {side: shape} (optional per-end
## shape), "high": side (skillion and flat only)}. Sides are N (-z), S (+z), W (-x), E (+x).

const SHAPES: Array[String] = ["hip", "gable", "half_hip", "dutch", "skillion", "flat"]
const SHAPE_NAMES := {"hip": "Hip", "gable": "Gable", "half_hip": "Half-hip", "dutch": "Dutch gable",
	"skillion": "Skillion", "flat": "Flat"}
const MATERIALS: Array[String] = ["corrugated_iron", "roof_paint_red", "roof_paint_green", "corrugated_iron_old",
	"roof_terracotta", "roof_slate", "roof_shingles"]
## The roof plane crosses the wall line this far above the top of the wall (the top plate).
const PLATE := 0.08
const HALF_HIP_AT := 0.6
const DUTCH_AT := 0.5
const MIN_PITCH := 10.0
const MAX_PITCH := 45.0
const FLAT_PITCH := 3.0
const SIDES: Array[String] = ["N", "E", "S", "W"]


static func defaults() -> Dictionary:
	return {"shape": "hip", "pitch": 28.0, "overhang": 0.45, "material": "corrugated_iron"}


static func clamp_pitch(shape: String, pitch: float) -> float:
	if shape == "flat":
		return FLAT_PITCH
	return clampf(pitch, MIN_PITCH, MAX_PITCH)


## End profile from the eave up: [[from_fraction, "hip" | "gable"], ...].
static func end_profile(shape: String) -> Array:
	match shape:
		"gable":
			return [[0.0, "gable"]]
		"half_hip":
			return [[0.0, "gable"], [HALF_HIP_AT, "hip"]]
		"dutch":
			return [[0.0, "hip"], [DUTCH_AT, "gable"]]
		_:
			return [[0.0, "hip"]]


static func rect_of(p: Dictionary) -> Rect2:
	var r: Array = p["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func is_mono(p: Dictionary) -> bool:
	return str(p.get("shape", "hip")) in ["skillion", "flat"]


## The footprint including overhangs, for picking and plan drawing.
static func outer_rect(p: Dictionary) -> Rect2:
	var r := rect_of(p)
	var o := float(p.get("overhang", 0.45))
	var joins: Array = p.get("joins", [])
	var x0 := r.position.x - (0.0 if joins.has("W") else o)
	var x1 := r.end.x + (0.0 if joins.has("E") else o)
	var z0 := r.position.y - (0.0 if joins.has("N") else o)
	var z1 := r.end.y + (0.0 if joins.has("S") else o)
	return Rect2(x0, z0, x1 - x0, z1 - z0)


## Plan area in square metres (what the roofing costs by).
static func area(p: Dictionary) -> float:
	var r := outer_rect(p)
	return r.size.x * r.size.y / cos(deg_to_rad(clamp_pitch(str(p.get("shape", "hip")), float(p.get("pitch", 28.0)))))


static func cost(p: Dictionary) -> int:
	return ceili(area(p) * float(Pieces.cost(str(p.get("material", "corrugated_iron")))) * 0.5)


## Height where the roof plane crosses the wall line: floor of the storey, its tallest wall under
## the piece, and the plate.
static func eave_y(h: HouseData, p: Dictionary) -> float:
	var l := int(p.get("level", 0))
	var r := rect_of(p).grow(0.01)
	var top := 0.0
	for k: String in h.walls(l):
		var pts := HouseData.edge_points(k)
		var mid := Vector2(pts[0] + pts[1]) * 0.5
		if r.has_point(mid) and str((h.walls(l)[k] as Dictionary).get("kind", "full")) == "full":
			top = maxf(top, h.wall_h(l, k))
	if top <= 0.0:
		top = h.storey_height(l)
	return h.floor_y() + h.level_base(l) + top + PLATE


# --- Local frame ---------------------------------------------------------------------------------

## For the gabled family the ridge runs along u; w is across it. Ends are the sides at u0 and u1,
## slopes face the sides at w0 and w1.
static func _frame(p: Dictionary) -> Dictionary:
	var f := _frame_axis(p, str(p.get("axis", "x")))
	if not _fits(p, f):
		var other := _frame_axis(p, "z" if f["ax"] == "x" else "x")
		if _fits(p, other):
			return other
	return f


## Whether the hips at both ends fit along the ridge (otherwise the ridge turns the other way).
static func _fits(p: Dictionary, f: Dictionary) -> bool:
	var cv := _curves(p, f)
	var hw := (float(f["w1"]) - float(f["w0"])) * 0.5
	return _e_at(cv[0], hw) + _e_at(cv[1], hw) <= float(f["u1"]) - float(f["u0"]) + 0.001


static func _frame_axis(p: Dictionary, ax: String) -> Dictionary:
	var r := rect_of(p)
	if ax == "x":
		return {"ax": ax, "u0": r.position.x, "u1": r.end.x, "w0": r.position.y, "w1": r.end.y, "ends": ["W", "E"], "sides": ["N", "S"]}
	return {"ax": ax, "u0": r.position.y, "u1": r.end.y, "w0": r.position.x, "w1": r.end.x, "ends": ["N", "S"], "sides": ["W", "E"]}


static func _w(ax: String, u: float, y: float, w: float) -> Vector3:
	return Vector3(u, y, w) if ax == "x" else Vector3(w, y, u)


static func _wn(ax: String, nu: float, ny: float, nw: float) -> Vector3:
	return Vector3(nu, ny, nw).normalized() if ax == "x" else Vector3(nw, ny, nu).normalized()


## The end curve: [[d, e, kind of the segment above]] from the eave (d = -o) to the ridge (d = hw),
## where e is how far the end edge sits from the end wall line (negative = overhanging).
static func _end_curve(shape: String, o: float, o_end: float, hw: float) -> Array:
	var prof := end_profile(shape)
	var out: Array = []
	var d := -o
	var e := -o_end
	for i in prof.size():
		var kind: String = prof[i][1]
		var d_next := hw if i == prof.size() - 1 else maxf(float(prof[i + 1][0]) * hw, d)
		out.append([d, e, kind])
		if kind == "hip":
			e += d_next - d
		d = d_next
	out.append([hw, e, ""])
	return out


static func _e_at(curve: Array, d: float) -> float:
	for i in curve.size() - 1:
		var a: Array = curve[i]
		var b: Array = curve[i + 1]
		if d <= float(b[0]) + 0.000001:
			if str(a[2]) == "hip":
				return float(a[1]) + (d - float(a[0]))
			return float(a[1])
	return float((curve[curve.size() - 1] as Array)[1])


## Depth reachable at a distance u_rel in from the end wall line (inverse of the end curve).
static func _depth_at(curve: Array, u_rel: float) -> float:
	if u_rel < float((curve[0] as Array)[1]) - 0.000001:
		return NAN
	for i in curve.size() - 1:
		var a: Array = curve[i]
		var b: Array = curve[i + 1]
		if str(a[2]) == "hip" and u_rel < float(b[1]):
			return float(a[0]) + (u_rel - float(a[1]))
	return float((curve[curve.size() - 1] as Array)[0])


static func _end_shape(p: Dictionary, side: String) -> String:
	if (p.get("joins", []) as Array).has(side):
		return "gable"
	var ends: Dictionary = p.get("ends", {})
	return str(ends.get(side, p.get("shape", "hip")))


## The two end curves and overhangs for a gabled-family piece.
static func _curves(p: Dictionary, f: Dictionary) -> Array:
	var o := float(p.get("overhang", 0.45))
	var joins: Array = p.get("joins", [])
	var hw := (float(f["w1"]) - float(f["w0"])) * 0.5
	var out: Array = []
	for side: String in f["ends"]:
		var oe := 0.0 if joins.has(side) else o
		out.append(_end_curve(_end_shape(p, side), o, oe, hw))
	return out


# --- Height --------------------------------------------------------------------------------------

## Top of the roof at (x, z), or NAN outside the piece.
static func surface_y(p: Dictionary, ey: float, x: float, z: float) -> float:
	var shape := str(p.get("shape", "hip"))
	var tanp := tan(deg_to_rad(clamp_pitch(shape, float(p.get("pitch", 28.0)))))
	if not outer_rect(p).grow(0.001).has_point(Vector2(x, z)):
		return NAN
	if is_mono(p):
		var m := _mono_frame(p)
		var d := _mono_d(m, x, z)
		return ey + d * tanp
	var f := _frame(p)
	var u := x if f["ax"] == "x" else z
	var w := z if f["ax"] == "x" else x
	var hw := (float(f["w1"]) - float(f["w0"])) * 0.5
	var cv := _curves(p, f)
	var d_lo := _depth_at(cv[0], u - float(f["u0"]))
	var d_hi := _depth_at(cv[1], float(f["u1"]) - u)
	if is_nan(d_lo) or is_nan(d_hi):
		return NAN
	var d2 := minf(minf(w - float(f["w0"]), float(f["w1"]) - w), minf(minf(d_lo, d_hi), hw))
	return ey + d2 * tanp


## Highest point of the piece.
static func ridge_y(p: Dictionary, ey: float) -> float:
	var shape := str(p.get("shape", "hip"))
	var tanp := tan(deg_to_rad(clamp_pitch(shape, float(p.get("pitch", 28.0)))))
	var r := rect_of(p)
	if is_mono(p):
		var m := _mono_frame(p)
		return ey + (float(m["span"]) + float(m["o_high"])) * tanp
	var f := _frame(p)
	return ey + (float(f["w1"]) - float(f["w0"])) * 0.5 * tanp if r.size.x > 0.0 else ey


# --- Geometry ------------------------------------------------------------------------------------

## Everything the mesh builder draws for a piece:
## {"roof": [{pts, uv, n}], "gable": [{pts, n}], "fascia": [[a, b, gutter]], "barge": [[a, b]],
##  "capping": [[a, b]], "finials": [Vector3]}. Roof polygons are convex, wound any way; n says
## which way is out.
static func geometry(p: Dictionary, ey: float) -> Dictionary:
	if is_mono(p):
		return _mono_geometry(p, ey)
	var g := {"roof": [], "gable": [], "fascia": [], "barge": [], "capping": [], "finials": []}
	var shape := str(p.get("shape", "hip"))
	var pitch := deg_to_rad(clamp_pitch(shape, float(p.get("pitch", 28.0))))
	var tanp := tan(pitch)
	var secp := 1.0 / cos(pitch)
	var f := _frame(p)
	var ax: String = f["ax"]
	var u0 := float(f["u0"])
	var u1 := float(f["u1"])
	var w0 := float(f["w0"])
	var w1 := float(f["w1"])
	var hw := (w1 - w0) * 0.5
	var wc := (w0 + w1) * 0.5
	var o := float(p.get("overhang", 0.45))
	var joins: Array = p.get("joins", [])
	var cv := _curves(p, f)
	var lo: Array = cv[0]
	var hi: Array = cv[1]
	var y := func(d: float) -> float: return ey + d * tanp
	# Band breakpoints shared by both ends.
	var ds: Array[float] = []
	for c: Array in lo + hi:
		var dd := float(c[0])
		var dup := false
		for e2 in ds:
			if absf(e2 - dd) < 0.0001:
				dup = true
		if not dup:
			ds.append(dd)
	ds.sort()
	var ul := func(d: float) -> float: return u0 + _e_at(lo, d)
	var ur := func(d: float) -> float: return u1 - _e_at(hi, d)
	var span := func(d: float) -> Vector2:
		var a: float = ul.call(d)
		var b: float = ur.call(d)
		if a > b:
			var mid := (a + b) * 0.5
			return Vector2(mid, mid)
		return Vector2(a, b)
	# The two main slopes, one band at a time.
	for side in 2:
		var sgn := -1.0 if side == 0 else 1.0
		var n := _wn(ax, 0.0, 1.0, sgn * tanp)
		for i in ds.size() - 1:
			var da := ds[i]
			var db := ds[i + 1]
			var sa: Vector2 = span.call(da)
			var sb: Vector2 = span.call(db)
			var wa := (w0 + da) if side == 0 else (w1 - da)
			var wb := (w0 + db) if side == 0 else (w1 - db)
			var va := (hw - da) * secp
			var vb := (hw - db) * secp
			var uflip := 1.0 if side == 0 else -1.0
			g["roof"].append({"n": n, "pts": [_w(ax, sa.x, y.call(da), wa), _w(ax, sa.y, y.call(da), wa), _w(ax, sb.y, y.call(db), wb), _w(ax, sb.x, y.call(db), wb)],
				"uv": [Vector2(sa.x * uflip, va), Vector2(sa.y * uflip, va), Vector2(sb.y * uflip, vb), Vector2(sb.x * uflip, vb)]})
		var eave: Vector2 = span.call(-o)
		var we := (w0 - o) if side == 0 else (w1 + o)
		g["fascia"].append([_w(ax, eave.x, y.call(-o), we), _w(ax, eave.y, y.call(-o), we), true])
	# Ridge.
	var rs: Vector2 = span.call(hw)
	if rs.y - rs.x > 0.01:
		g["capping"].append([_w(ax, rs.x, y.call(hw), wc), _w(ax, rs.y, y.call(hw), wc)])
	# The two ends.
	for end in 2:
		var curve: Array = lo if end == 0 else hi
		var side_name: String = (f["ends"] as Array)[end]
		var joined := joins.has(side_name)
		var dir := -1.0 if end == 0 else 1.0
		var at := func(e: float) -> float: return (u0 + e) if end == 0 else (u1 - e)
		for i in curve.size() - 1:
			var a: Array = curve[i]
			var b: Array = curve[i + 1]
			var da := float(a[0])
			var db := float(b[0])
			if db - da < 0.0001:
				continue
			var ua: float = at.call(float(a[1]))
			var ub: float = at.call(float(b[1]))
			if str(a[2]) == "hip":
				var wa0 := w0 + da
				var wa1 := w1 - da
				var wb0 := minf(w0 + db, wc)
				var wb1 := maxf(w1 - db, wc)
				var n2 := _wn(ax, dir * tanp, 1.0, 0.0)
				var va2 := (hw - da) * secp
				var vb2 := (hw - db) * secp
				var wflip := -dir
				g["roof"].append({"n": n2, "pts": [_w(ax, ua, y.call(da), wa0), _w(ax, ua, y.call(da), wa1), _w(ax, ub, y.call(db), wb1), _w(ax, ub, y.call(db), wb0)],
					"uv": [Vector2(wa0 * wflip, va2), Vector2(wa1 * wflip, va2), Vector2(wb1 * wflip, vb2), Vector2(wb0 * wflip, vb2)]})
				g["capping"].append([_w(ax, ua, y.call(da), wa0), _w(ax, ub, y.call(db), wb0)])
				g["capping"].append([_w(ax, ua, y.call(da), wa1), _w(ax, ub, y.call(db), wb1)])
				if not joined:
					g["fascia"].append([_w(ax, ua, y.call(da), wa0), _w(ax, ua, y.call(da), wa1), i == 0])
			elif not joined:
				# Gable: barge boards along the slope edge, and the gable wall.
				g["barge"].append([_w(ax, ua, y.call(da), w0 + da), _w(ax, ua, y.call(db), minf(w0 + db, wc))])
				g["barge"].append([_w(ax, ua, y.call(da), w1 - da), _w(ax, ua, y.call(db), maxf(w1 - db, wc))])
				var gn := _wn(ax, dir, 0.0, 0.0)
				var top0 := w0 + db
				var top1 := w1 - db
				if i == 0:
					var uw: float = at.call(0.0)
					var ybot := ey - PLATE - 0.12
					var pts: Array = [_w(ax, uw, ybot, w0), _w(ax, uw, ybot, w1), _w(ax, uw, y.call(0.0), w1)]
					pts.append(_w(ax, uw, y.call(db), top1))
					if top1 - top0 > 0.001:
						pts.append(_w(ax, uw, y.call(db), top0))
					pts.append(_w(ax, uw, y.call(0.0), w0))
					g["gable"].append({"n": gn, "pts": pts})
				else:
					var pts2: Array = [_w(ax, ua, y.call(da), w0 + da), _w(ax, ua, y.call(da), w1 - da), _w(ax, ua, y.call(db), top1)]
					if top1 - top0 > 0.001:
						pts2.append(_w(ax, ua, y.call(db), top0))
					g["gable"].append({"n": gn, "pts": pts2})
				if db >= hw - 0.0001:
					g["finials"].append(_w(ax, ua, y.call(hw), wc))
	return g


# --- Skillion and flat ---------------------------------------------------------------------------

## Mono-pitch frame: d runs from the low wall line (0) to the high wall line (span); u along the
## low eave.
static func _mono_frame(p: Dictionary) -> Dictionary:
	var r := rect_of(p)
	var high := str(p.get("high", "N"))
	var o := float(p.get("overhang", 0.45))
	var joins: Array = p.get("joins", [])
	var low := {"N": "S", "S": "N", "E": "W", "W": "E"}[high] as String
	var along_z := high in ["N", "S"]
	var ends: Array = ["W", "E"] if along_z else ["N", "S"]
	var f := {"high": high, "low": low, "along_z": along_z, "ends": ends,
		"o_low": 0.0 if joins.has(low) else o, "o_high": 0.0 if joins.has(high) else o,
		"o0": 0.0 if joins.has(ends[0]) else o, "o1": 0.0 if joins.has(ends[1]) else o}
	if along_z:
		f["u0"] = r.position.x
		f["u1"] = r.end.x
		f["span"] = r.size.y
		f["base"] = r.end.y if high == "N" else r.position.y
		f["sgn"] = -1.0 if high == "N" else 1.0
	else:
		f["u0"] = r.position.y
		f["u1"] = r.end.y
		f["span"] = r.size.x
		f["base"] = r.end.x if high == "W" else r.position.x
		f["sgn"] = -1.0 if high == "W" else 1.0
	return f


static func _mono_d(f: Dictionary, x: float, z: float) -> float:
	var c := z if f["along_z"] else x
	return clampf((c - float(f["base"])) * float(f["sgn"]), -float(f["o_low"]), float(f["span"]) + float(f["o_high"]))


static func _mw(f: Dictionary, u: float, y: float, d: float) -> Vector3:
	var c := float(f["base"]) + float(f["sgn"]) * d
	return Vector3(u, y, c) if f["along_z"] else Vector3(c, y, u)


static func _mono_geometry(p: Dictionary, ey: float) -> Dictionary:
	var g := {"roof": [], "gable": [], "fascia": [], "barge": [], "capping": [], "finials": []}
	var shape := str(p.get("shape", "skillion"))
	var pitch := deg_to_rad(clamp_pitch(shape, float(p.get("pitch", 15.0))))
	var tanp := tan(pitch)
	var secp := 1.0 / cos(pitch)
	var f := _mono_frame(p)
	var u0 := float(f["u0"])
	var u1 := float(f["u1"])
	var span := float(f["span"])
	var sgn := float(f["sgn"])
	var dl := -float(f["o_low"])
	var dh := span + float(f["o_high"])
	var ua := u0 - float(f["o0"])
	var ub := u1 + float(f["o1"])
	var y := func(d: float) -> float: return ey + d * tanp
	var dn := Vector3(0, 0, sgn) if f["along_z"] else Vector3(sgn, 0, 0)
	var n := (Vector3.UP - dn * tanp).normalized()
	g["roof"].append({"n": n, "pts": [_mw(f, ua, y.call(dl), dl), _mw(f, ub, y.call(dl), dl), _mw(f, ub, y.call(dh), dh), _mw(f, ua, y.call(dh), dh)],
		"uv": [Vector2(ua, (dh - dl) * secp), Vector2(ub, (dh - dl) * secp), Vector2(ub, 0.0), Vector2(ua, 0.0)]})
	g["fascia"].append([_mw(f, ua, y.call(dl), dl), _mw(f, ub, y.call(dl), dl), true])
	var joins: Array = p.get("joins", [])
	if not joins.has(f["high"]):
		g["fascia"].append([_mw(f, ua, y.call(dh), dh), _mw(f, ub, y.call(dh), dh), false])
		var ybot := ey - PLATE - 0.12
		g["gable"].append({"n": dn, "pts": [_mw(f, u0, ybot, span), _mw(f, u1, ybot, span), _mw(f, u1, y.call(span), span), _mw(f, u0, y.call(span), span)]})
	var un := Vector3(1, 0, 0) if f["along_z"] else Vector3(0, 0, 1)
	for e in 2:
		if joins.has((f["ends"] as Array)[e]):
			continue
		var ue := ua if e == 0 else ub
		var uw := u0 if e == 0 else u1
		g["barge"].append([_mw(f, ue, y.call(dl), dl), _mw(f, ue, y.call(dh), dh)])
		var ybot2 := ey - PLATE - 0.12
		g["gable"].append({"n": un * (-1.0 if e == 0 else 1.0), "pts": [_mw(f, uw, ybot2, 0.0), _mw(f, uw, ybot2, span), _mw(f, uw, y.call(span), span), _mw(f, uw, y.call(0.0), 0.0)]})
	return g


# --- Auto-roof -----------------------------------------------------------------------------------

## Tiles on a storey that need roofing at that storey: covered by its rooms and not by the storey
## above.
static func roof_tiles(h: HouseData, level: int) -> Dictionary:
	var out: Dictionary = {}
	for r in h.rooms(level):
		if bool((r["props"] as Dictionary).get("sleepout", false)):
			continue
		for t: Vector2i in r["tiles"]:
			out[t] = true
	if h.has_storey(level + 1):
		for r2 in h.rooms(level + 1):
			for t2: Vector2i in r2["tiles"]:
				out.erase(t2)
	return out


## Splits a set of tiles into rectangles, biggest first.
static func rectangles(tiles: Dictionary) -> Array[Rect2i]:
	var left := tiles.duplicate()
	var out: Array[Rect2i] = []
	while not left.is_empty():
		var best := Rect2i()
		var best_a := 0
		var keys := left.keys()
		keys.sort()
		for t0: Vector2i in keys:
			# Grow right as far as possible for each height.
			var max_w := 0
			while left.has(t0 + Vector2i(max_w, 0)):
				max_w += 1
			var hgt := 0
			var w := max_w
			while w > 0:
				var row_w := 0
				while row_w < w and left.has(t0 + Vector2i(row_w, hgt)):
					row_w += 1
				if row_w == 0:
					break
				w = row_w
				hgt += 1
				var a := w * hgt
				# Prefer bigger areas, then squarer shapes, then the north-west.
				if a > best_a or (a == best_a and mini(w, hgt) > mini(best.size.x, best.size.y)):
					best_a = a
					best = Rect2i(t0, Vector2i(w, hgt))
		for x in range(best.position.x, best.end.x):
			for z in range(best.position.y, best.end.y):
				left.erase(Vector2i(x, z))
		out.append(best)
	return out


## Pieces for the whole house from roof settings {shape, pitch, overhang, material}.
static func auto_roof(h: HouseData, settings: Dictionary) -> Array:
	var s := defaults()
	s.merge(settings, true)
	var out: Array = []
	var n := 0
	for l in h.levels():
		if l < 0:
			continue
		var tiles := roof_tiles(h, l)
		if tiles.is_empty():
			continue
		var above: Dictionary = {}
		if h.has_storey(l + 1):
			for r2 in h.rooms(l + 1):
				for t2: Vector2i in r2["tiles"]:
					above[t2] = true
		var rects := rectangles(tiles)
		var placed: Array = []
		for rc in rects:
			n += 1
			var p := {"id": "auto%d" % n, "level": l, "shape": s["shape"], "pitch": float(s["pitch"]),
				"overhang": float(s["overhang"]), "material": s["material"], "joins": []}
			var r := Rect2(rc.position, rc.size)
			var long_x := rc.size.x >= rc.size.y
			p["axis"] = "x" if long_x else "z"
			# Sides touching the storey above sit against its wall.
			var against := _touching(rc, above)
			# Sides touching an earlier piece on this storey join into it.
			var host := {}
			for q: Dictionary in placed:
				var side := _shared_side(rc, q["_rc"])
				if side != "":
					host = {"side": side, "piece": q}
					break
			if str(s["shape"]) in ["skillion", "flat"]:
				p["high"] = against[0] if not against.is_empty() else ("N" if rc.size.x >= rc.size.y else "W")
				p["joins"] = against.duplicate()
				if not host.is_empty():
					(p["joins"] as Array).append(host["side"])
			elif not against.is_empty() and _is_long_side(rc, against[0]) and rc.size.y != rc.size.x:
				# A strip against a taller wall: a skillion leaning on it.
				p["shape"] = "skillion"
				p["pitch"] = minf(float(s["pitch"]), 18.0)
				p["high"] = against[0]
				p["joins"] = against.duplicate()
			else:
				if not host.is_empty():
					var side2: String = host["side"]
					var hq: Dictionary = host["piece"]
					p["axis"] = "z" if side2 in ["N", "S"] else "x"
					# Reach into the host as far as its ridge, so the two roofs meet in valleys.
					var hr := rect_of(hq)
					var reach := (hr.size.y if side2 in ["N", "S"] else hr.size.x) * 0.5
					if (rc.size.x if side2 in ["N", "S"] else rc.size.y) * 0.5 > reach:
						reach *= 2.0
					match side2:
						"N":
							r = Rect2(r.position.x, r.position.y - reach, r.size.x, r.size.y + reach)
						"S":
							r.size.y += reach
						"W":
							r = Rect2(r.position.x - reach, r.position.y, r.size.x + reach, r.size.y)
						"E":
							r.size.x += reach
					(p["joins"] as Array).append(side2)
				for a2: String in against:
					if not (p["joins"] as Array).has(a2):
						(p["joins"] as Array).append(a2)
			p["rect"] = [r.position.x, r.position.y, r.size.x, r.size.y]
			p["_rc"] = rc
			placed.append(p)
			out.append(p)
	for p2: Dictionary in out:
		p2.erase("_rc")
	return out


static func _is_long_side(rc: Rect2i, side: String) -> bool:
	return (side in ["N", "S"]) == (rc.size.x > rc.size.y)


## Sides of rc whose whole outside row is in tiles.
static func _touching(rc: Rect2i, tiles: Dictionary) -> Array:
	var out: Array = []
	if tiles.is_empty():
		return out
	for side in SIDES:
		var hits := 0
		var total := 0
		var cells: Array[Vector2i] = []
		match side:
			"N":
				for x in range(rc.position.x, rc.end.x):
					cells.append(Vector2i(x, rc.position.y - 1))
			"S":
				for x in range(rc.position.x, rc.end.x):
					cells.append(Vector2i(x, rc.end.y))
			"W":
				for z in range(rc.position.y, rc.end.y):
					cells.append(Vector2i(rc.position.x - 1, z))
			"E":
				for z in range(rc.position.y, rc.end.y):
					cells.append(Vector2i(rc.end.x, z))
		for c in cells:
			total += 1
			if tiles.has(c):
				hits += 1
		if hits * 2 >= total and hits > 0:
			out.append(side)
	return out


## The side of a that lies against b, with a's edge inside b's edge; "" if none.
static func _shared_side(a: Rect2i, b: Rect2i) -> String:
	if a.position.y == b.end.y and a.position.x >= b.position.x and a.end.x <= b.end.x:
		return "N"
	if a.end.y == b.position.y and a.position.x >= b.position.x and a.end.x <= b.end.x:
		return "S"
	if a.position.x == b.end.x and a.position.y >= b.position.y and a.end.y <= b.end.y:
		return "W"
	if a.end.x == b.position.x and a.position.y >= b.position.y and a.end.y <= b.end.y:
		return "E"
	return ""


# --- House-level helpers -------------------------------------------------------------------------

## The pieces a house shows: generated from the plan while the roof follows it, else stored.
static func pieces(h: HouseData) -> Array:
	if h.roof.is_empty():
		return []
	if bool(h.roof.get("follow", false)) or h.roof.has("type"):
		var s: Dictionary = h.roof.get("auto", {})
		if h.roof.has("type"):
			s = {"shape": h.roof["type"], "pitch": h.roof.get("pitch", 28.0), "overhang": h.roof.get("overhang", 0.45), "material": h.roof.get("material", "corrugated_iron")}
		return auto_roof(h, s)
	return h.roof.get("pieces", [])


## Highest roof surface over a rectangle (for chimney tops), or NAN with no roof there.
static func height_over(h: HouseData, area_r: Rect2) -> float:
	var best := NAN
	for p: Dictionary in pieces(h):
		var ey := eave_y(h, p)
		for i in 3:
			for j in 3:
				var x := area_r.position.x + area_r.size.x * i * 0.5
				var z := area_r.position.y + area_r.size.y * j * 0.5
				var yy := surface_y(p, ey, x, z)
				if not is_nan(yy) and (is_nan(best) or yy > best):
					best = yy
	return best


## The piece under a plan point (topmost), or {}.
static func piece_at(h: HouseData, x: float, z: float) -> Dictionary:
	var best: Dictionary = {}
	var best_y := -INF
	for p: Dictionary in pieces(h):
		var yy := surface_y(p, eave_y(h, p), x, z)
		if not is_nan(yy) and yy > best_y:
			best_y = yy
			best = p
	return best
