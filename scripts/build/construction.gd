class_name Construction
extends RefCounted
## Story-mode building (docs/HOUSE_BUILDING.md): what the player designs is the plan; the house as
## it stands is the "built" state. The difference between the two is the project. Crews work through
## it in stages, and the house is drawn as it stands at the current stage: blueprints while the
## materials are on their way to the siding, then stumps, floor frames, floors, wall frames, roof
## frame, roofing, cladding and lining, joinery and paint. Plain class: the world advances it with
## the clock and asks it what to draw.
##
## Work is in units: one crew does 5 units a day, which is 5 m of wall or 5 square metres of floor
## (docs/GAME_DESIGN.md). Rain slows the outdoor stages; quality tiers trade speed for finish.

const STAGES: Array[String] = ["demolition", "stumps", "floor_frame", "floors", "wall_frames", "roof_frame", "roofing",
	"cladding", "joinery", "paint"]
const STAGE_NAMES := {"demolition": "Demolition", "stumps": "Stumps", "floor_frame": "Floor frame", "floors": "Floors",
	"wall_frames": "Wall frames", "roof_frame": "Roof frame", "roofing": "Roofing", "cladding": "Cladding and lining",
	"joinery": "Doors and windows", "paint": "Paint and garden"}
const OUTDOOR: Array[String] = ["stumps", "floor_frame", "wall_frames", "roof_frame", "roofing", "cladding"]
const UNITS_PER_CREW_DAY := 5.0
const WORK_START := 8 * 60
const WORK_END := 16 * 60
const TIERS := {"rough": {"name": "Rough", "speed": 1.25, "cost": 0.8, "style": -6},
	"standard": {"name": "Standard", "speed": 1.0, "cost": 1.0, "style": 0},
	"fine": {"name": "Fine", "speed": 0.75, "cost": 1.3, "style": 6}}
const RAW_INSIDE := "#E3DDD0"
const RAW_OUTSIDE := "#CDBFA4"
const STAGE_INDEX := {"demolition": 0, "stumps": 1, "floor_frame": 2, "floors": 3, "wall_frames": 4, "roof_frame": 5,
	"roofing": 6, "cladding": 7, "joinery": 8, "paint": 9}


# --- Work ----------------------------------------------------------------------------------------

## Units of work in each stage to turn before into after.
static func work(before: HouseData, after: HouseData) -> Array[float]:
	var w: Array[float] = []
	w.resize(STAGES.size())
	w.fill(0.0)
	var levels: Dictionary = {}
	for l in before.levels() + after.levels():
		levels[l] = true
	for l: int in levels:
		var bw := before.walls(l)
		var aw := after.walls(l)
		for k: String in aw:
			if not bw.has(k):
				w[4] += 0.5
				w[7] += 0.5
				w[9] += 0.1
			elif JSON.stringify((aw[k] as Dictionary).get("f", {})) != JSON.stringify((bw[k] as Dictionary).get("f", {})):
				w[9] += 0.15
		for k2: String in bw:
			if not aw.has(k2):
				w[0] += 0.3
		var bf := before.floors(l)
		var af := after.floors(l)
		for tk: String in af:
			if not bf.has(tk):
				w[1] += 0.2 if l == 0 else 0.0
				w[2] += 0.4
				w[3] += 0.4
			elif JSON.stringify(af[tk]) != JSON.stringify(bf[tk]):
				w[3] += 0.3
		for tk2: String in bf:
			if not af.has(tk2):
				w[0] += 0.2
		var bo := _by_id(before.openings(l))
		var ao := _by_id(after.openings(l))
		for id: String in ao:
			if not bo.has(id):
				w[8] += 1.0
			elif JSON.stringify(ao[id]) != JSON.stringify(bo[id]):
				w[8] += 0.4
		for id2: String in bo:
			if not ao.has(id2):
				w[0] += 0.4
		if JSON.stringify(after.stairs(l)) != JSON.stringify(before.stairs(l)):
			w[8] += 6.0
	if _roof_changed(before, after):
		var area := 0.0
		for p: Dictionary in Roofs.pieces(after):
			area += Roofs.area(p)
		w[5] += area * 0.12
		w[6] += area * 0.12
	var bv := _by_id(before.verandahs)
	for v: Dictionary in after.verandahs:
		if not bv.has(str(v.get("id", ""))) or JSON.stringify(v) != JSON.stringify(bv[str(v.get("id", ""))]):
			var a := (float(v["to"]) - float(v["from"])) * float(v["depth"])
			w[1] += a * 0.1
			w[3] += a * 0.2
			w[6] += a * 0.2
	if after.chimneys.size() > before.chimneys.size():
		w[6] += 4.0 * (after.chimneys.size() - before.chimneys.size())
	var fences := 0
	for k3: String in after.fences:
		if not before.fences.has(k3) or JSON.stringify(after.fences[k3]) != JSON.stringify(before.fences[k3]):
			fences += 1
	w[8] += fences * 0.3
	if JSON.stringify(after.garden) != JSON.stringify(before.garden):
		w[9] += maxf(1.0, (after.garden.size() - before.garden.size()) * 0.5)
	if JSON.stringify([after.ground, after.terrain]) != JSON.stringify([before.ground, before.terrain]):
		w[9] += 1.0 + absf(after.ground.size() - before.ground.size()) * 0.05 + absf(after.terrain.size() - before.terrain.size()) * 0.05
	if JSON.stringify(after.exterior) != JSON.stringify(before.exterior):
		w[9] += 1.0
	return w


static func total(w: Array[float]) -> float:
	var t := 0.0
	for x in w:
		t += x
	return t


## The stage reached after done units: {index, name, fraction} (index STAGES.size() when finished).
static func stage_at(w: Array[float], done: float) -> Dictionary:
	var acc := 0.0
	for i in w.size():
		if w[i] <= 0.0:
			continue
		if done < acc + w[i] - 0.0001:
			return {"index": i, "name": STAGES[i], "fraction": (done - acc) / w[i]}
		acc += w[i]
	return {"index": STAGES.size(), "name": "done", "fraction": 1.0}


## Units the crews get through in an hour of work.
static func hourly_rate(crews: int, tier: String, raining: bool, stage: String) -> float:
	var r := crews * UNITS_PER_CREW_DAY / ((WORK_END - WORK_START) / 60.0)
	r *= float((TIERS.get(tier, TIERS["standard"]) as Dictionary)["speed"])
	if raining and stage in OUTDOOR:
		r *= 0.3
	return r


## Working days left, roughly, at a crew count (ignoring rain).
static func days_left(w: Array[float], done: float, crews: int, tier: String) -> float:
	var rate := crews * UNITS_PER_CREW_DAY * float((TIERS.get(tier, TIERS["standard"]) as Dictionary)["speed"])
	return maxf(0.0, total(w) - done) / maxf(rate, 0.01)


# --- What to draw --------------------------------------------------------------------------------

## The house as it stands: after, with each change not yet built shown as blueprint, frame, raw or
## not there yet. stage is the current stage index (-1 while the materials are on their way).
## delivered: whether the furniture has arrived.
static func display(before: HouseData, after: HouseData, stage: int, delivered: bool) -> HouseData:
	var d := after.duplicate_house()
	if stage >= STAGES.size():
		return d
	var new_tiles: Dictionary = {}
	for l in d.levels():
		var bw := before.walls(l)
		var dw := d.walls(l)
		for k: String in dw:
			var wall: Dictionary = dw[k]
			if not bw.has(k):
				if stage < 4:
					wall["stage"] = "blueprint"
				elif stage < 7:
					wall["stage"] = "frame"
				elif stage < 9:
					_raw_faces(wall)
			elif stage < 9:
				wall["f"] = ((bw[k] as Dictionary).get("f", {}) as Dictionary).duplicate(true)
		if stage <= 0:
			for k2: String in bw:
				if not dw.has(k2):
					dw[k2] = (bw[k2] as Dictionary).duplicate(true)
		var bf := before.floors(l)
		var df := d.floors(l)
		for tk: String in df:
			var fl: Dictionary = df[tk]
			if not bf.has(tk):
				new_tiles[tk + ":%d" % l] = true
				if stage < 1:
					fl["stage"] = "blueprint"
				elif stage < 2:
					fl["stage"] = "stumps"
				elif stage < 3:
					fl["stage"] = "frame"
			elif stage < 3:
				df[tk] = (bf[tk] as Dictionary).duplicate(true)
		if stage <= 0:
			for tk2: String in bf:
				if not df.has(tk2):
					df[tk2] = (bf[tk2] as Dictionary).duplicate(true)
		if stage < 8:
			var bo := _by_id(before.openings(l))
			var keep: Array = []
			for o: Dictionary in d.openings(l):
				var id := str(o.get("id", ""))
				if bo.has(id):
					keep.append((bo[id] as Dictionary).duplicate(true))
			if stage <= 0:
				for id2: String in bo:
					if not _by_id(keep).has(id2):
						keep.append((bo[id2] as Dictionary).duplicate(true))
			d.storey(l)["openings"] = keep
			if JSON.stringify(after.stairs(l)) != JSON.stringify(before.stairs(l)):
				d.storey(l)["stairs"] = before.stairs(l).duplicate(true) if before.has_storey(l) else []
	if _roof_changed(before, after):
		if stage < 5:
			d.roof = before.roof.duplicate(true)
		elif stage < 6:
			d.roof = after.roof.duplicate(true)
			d.roof["stage"] = "frame"
	if stage < 6:
		var bv := _by_id(before.verandahs)
		var vs: Array[Dictionary] = []
		for v: Dictionary in d.verandahs:
			if bv.has(str(v.get("id", ""))):
				vs.append((bv[str(v.get("id", ""))] as Dictionary).duplicate(true))
		d.verandahs = vs
		d.chimneys = before.chimneys.duplicate(true)
	if stage < 9:
		d.garden = before.garden.duplicate(true)
		d.ground = before.ground.duplicate(true)
		d.terrain = before.terrain.duplicate(true)
		d.exterior = before.exterior.duplicate(true)
		if stage < 8:
			d.fences = before.fences.duplicate(true)
	if not delivered:
		d.objects = before.objects.duplicate(true)
	d.stage = {"index": stage, "new_tiles": new_tiles}
	d.touch()
	return d


static func _raw_faces(wall: Dictionary) -> void:
	var f: Dictionary = wall.get("f", {})
	for side: String in ["a", "b"]:
		var cur: Dictionary = f.get(side, {})
		var mat := str(cur.get("mat", ""))
		if mat == "" or mat == "wallpaper":
			mat = "plaster" if mat == "wallpaper" else ""
		if mat == "":
			f[side] = {"mat": "weatherboard", "paint": RAW_OUTSIDE}
		else:
			f[side] = {"mat": mat, "paint": RAW_INSIDE if mat in ["plaster", "wall_tiles", "vj_panelling"] else RAW_OUTSIDE}
	wall["f"] = f


static func _roof_changed(before: HouseData, after: HouseData) -> bool:
	return JSON.stringify(Roofs.pieces(before)) != JSON.stringify(Roofs.pieces(after)) or JSON.stringify(before.roof) != JSON.stringify(after.roof)


static func _by_id(arr: Array) -> Dictionary:
	var out := {}
	for o: Dictionary in arr:
		out[str(o.get("id", ""))] = o
	return out


# --- Projects ------------------------------------------------------------------------------------
# A project: {built: HouseData dict, done: units, ordered_day, ordered_minute, tier}. Materials ordered
# arrive at the siding the next morning; nothing starts before then.

static func new_project(built: Dictionary, day: int, minute: int, tier: String = "standard") -> Dictionary:
	return {"built": built, "done": 0.0, "ordered_day": day, "ordered_minute": minute, "tier": tier}


static func delivered(project: Dictionary, day: int, minute: int) -> bool:
	return day > int(project["ordered_day"]) and (day > int(project["ordered_day"]) + 1 or minute >= 7 * 60)


## One minute of the clock on a project, given its work list. Returns the stage to draw: -1 while
## the materials are on their way, STAGES.size() once it's finished.
static func tick(project: Dictionary, w: Array[float], day: int, minute: int, crews: int, raining: bool) -> int:
	if not delivered(project, day, minute):
		return -1
	var st := stage_at(w, float(project["done"]))
	var idx := int(st["index"])
	if idx >= STAGES.size():
		return idx
	if minute >= WORK_START and minute < WORK_END and posmod(day, 7) != 6:
		project["done"] = float(project["done"]) + hourly_rate(crews, str(project.get("tier", "standard")), raining, str(st["name"])) / 60.0
	return int(stage_at(w, float(project["done"]))["index"])


## Advances a project by some minutes of the clock. Returns true when the stage changed.
static func advance(project: Dictionary, plan: HouseData, from_day: int, from_minute: int, minutes: int, crews: int, raining: bool) -> bool:
	var before := HouseData.from_dict(project["built"])
	var w := work(before, plan)
	var start_stage := int(stage_at(w, float(project["done"]))["index"])
	var day := from_day
	var minute := from_minute
	for i in minutes:
		minute += 1
		if minute >= 24 * 60:
			minute = 0
			day += 1
		if minute < WORK_START or minute >= WORK_END or posmod(day, 7) == 6 or not delivered(project, day, minute):
			continue
		var st := stage_at(w, float(project["done"]))
		if int(st["index"]) >= STAGES.size():
			break
		project["done"] = float(project["done"]) + hourly_rate(crews, str(project.get("tier", "standard")), raining, str(st["name"])) / 60.0
	return int(stage_at(w, float(project["done"]))["index"]) != start_stage
