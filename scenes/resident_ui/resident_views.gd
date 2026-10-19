class_name ResidentViews
extends Node3D
## The residents in the valley: one figure each (ResidentLook on a placeholder mannequin, or their
## own MPFB model), walking smoothly along their sim routes between ticks, sitting, sleeping, and
## standing about. A view of the Sim, never a source of truth.

const STRIDE_M_PER_S := 1.4  ## how fast the walk animation moves at speed_scale 1
const PICK_RADIUS := 0.45

var houses: Array = []  ## the world's HouseViews, for floor heights
var height_fn: Callable  ## (x, z) -> ground height
var lod := 0
var selected := ""
var _views: Dictionary = {}  ## rid -> {node, player, anim, facing}
var _floors: Dictionary = {}  ## "level:x,z" -> floor height (world), for every house tile
var _tag: Label3D


func _ready() -> void:
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0012
	_tag.font = load("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf") as Font
	_tag.font_size = 22
	_tag.outline_size = 10
	_tag.modulate = Color("#00294D")
	_tag.outline_modulate = Color.WHITE
	_tag.visible = false
	add_child(_tag)
	SimHost.town_changed.connect(refresh_floors)
	refresh_floors()
	# The residents' own bodies come in the characters pack; until it lands they stand in as mannequins.
	if not ContentPacks.is_loaded("characters"):
		ContentPacks.pack_loaded.connect(func(n: String) -> void: set_lod(lod, true) if n == "characters" else null)
		ContentPacks.request("characters")


## Floor heights of every house tile, so people stand on floors indoors and the ground outside.
func refresh_floors() -> void:
	_floors.clear()
	for hv: HouseView in houses:
		var h := hv.shown
		for l in h.levels():
			var y := hv.position.y + h.floor_y() + h.level_base(l)
			for r: Dictionary in h.rooms(l):
				for t: Vector2i in r["tiles"]:
					_floors["%d:%d,%d" % [l, t.x + h.origin.x, t.y + h.origin.y]] = y


func set_lod(level: int, force: bool = false) -> void:
	if level == lod and not force:
		return
	lod = level
	for rid: String in _views:
		(_views[rid]["node"] as Node).queue_free()
	_views.clear()


func _make(rid: String) -> Dictionary:
	var sim := SimHost.sim
	var d: Dictionary = (sim.data["residents"] as Dictionary).get(rid, {})
	var look := ResidentLook.for_resident(rid, d)
	if not ResourceLoader.exists("res://assets/characters/%s.glb" % look["model"]):
		look["model"] = "mannequin_f" if str(d.get("sex", "m")) == "f" else "mannequin_m"   # the pack hasn't arrived yet
	var path := "res://assets/characters/%s.glb" % look["model"]
	if lod > 0 and ResourceLoader.exists("res://assets/characters/%s_lod1.glb" % look["model"]):
		path = "res://assets/characters/%s_lod1.glb" % look["model"]
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.name = rid
	add_child(n)
	ResidentLook.apply(n, look)
	var player := CharacterAnims.attach(n)
	var v := {"node": n, "player": player, "anim": "", "facing": 0.0}
	_views[rid] = v
	return v


func _play(v: Dictionary, anim: String, speed: float = 1.0) -> void:
	var p := v["player"] as AnimationPlayer
	if p == null:
		return
	p.speed_scale = speed
	if v["anim"] != anim and p.has_animation(anim):
		p.play(anim, 0.2)
		v["anim"] = anim


## Height of a [level, x, z] sim position in the world.
func height_at(pos: Array) -> float:
	var key := "%d:%d,%d" % [int(pos[0]), floori(float(pos[1])), floori(float(pos[2]))]
	if _floors.has(key):
		return float(_floors[key])
	return float(height_fn.call(float(pos[1]), float(pos[2]))) if height_fn.is_valid() else 0.0


func _process(_delta: float) -> void:
	if not SimHost.active:
		return
	var sim := SimHost.sim
	var frac := clampf(Clock.minute_f() - float(Clock.minute), 0.0, 1.0) if Clock.speed > 0 else 0.0
	var walk_speed := SimTown.WALK_M_PER_MIN * Clock.BASE_MINUTES_PER_SECOND * maxf(1.0, float(Clock.speed)) / 60.0
	for rid: String in sim.residents:
		var r: Dictionary = sim.residents[rid]
		var living: bool = r["status"] == "living" and not (r["pos"] as Array).is_empty()
		if not living:
			if _views.has(rid):
				(_views[rid]["node"] as Node3D).visible = false
			continue
		var v: Dictionary = _views[rid] if _views.has(rid) else _make(rid)
		var n := v["node"] as Node3D
		n.visible = true
		var route: Array = r["route"]
		var kind := str((r["action"] as Dictionary).get("kind", "idle"))
		var pos: Array = r["pos"]
		n.rotation.x = 0.0
		if not route.is_empty():
			var walked := (float(sim.ticks - int(r["walk_start"])) + frac) * SimTown.WALK_M_PER_MIN
			pos = SimTown.along(route, minf(walked, SimTown.route_length(route)))
			var ahead := SimTown.along(route, walked + 0.8)
			var dir := Vector2(float(ahead[1]) - float(pos[1]), float(ahead[2]) - float(pos[2]))
			if dir.length() > 0.05:
				v["facing"] = atan2(dir.x, dir.y)
			_play(v, CharacterAnims.pick(kind, true, "stand", int(r["age"])), clampf(walk_speed / STRIDE_M_PER_S, 0.6, 3.5))
		var pose := "walk"
		if route.is_empty():
			# At the place: lying on the bed, sitting on the seat, or standing at the front of the thing.
			var pl := sim.town.place(str((r["action"] as Dictionary).get("place", ""))) if sim.town else {}
			pose = str(pl.get("pose", "stand"))
			if pl.has("stand"):
				pos = pl["stand"]
				v["facing"] = float(pl["face"])
			if kind != "sleep" and pose == "lie":
				pose = "sit"
			_play(v, CharacterAnims.pick(kind, false, pose, int(r["age"])), 0.0 if pose == "lie" else 1.0)
		var y := height_at(pos)
		n.position = Vector3(float(pos[1]), y, float(pos[2]))
		n.rotation.y = float(v["facing"])
		if pose == "lie":
			n.position.y += 0.5
			n.rotation.x = -PI * 0.5
	if selected != "" and _views.has(selected) and (_views[selected]["node"] as Node3D).visible:
		var sn := _views[selected]["node"] as Node3D
		_tag.text = str(sim.residents[selected]["first"])
		_tag.position = sn.position + Vector3(0, 2.05 * sn.scale.y if sn.rotation.x == 0.0 else 1.0, 0)
		_tag.visible = true
	else:
		_tag.visible = false


## The resident nearest a screen ray, or "".
func pick(from: Vector3, dir: Vector3) -> String:
	var best := ""
	var best_d := PICK_RADIUS
	var ids := _views.keys()
	ids.sort()
	for rid: String in ids:
		var n := _views[rid]["node"] as Node3D
		if not n.visible:
			continue
		# A short upright capsule through the body.
		for h in [0.5, 1.0, 1.5]:
			var p := n.position + Vector3(0, h * n.scale.y, 0)
			var t := (p - from).dot(dir)
			if t <= 0.0:
				continue
			var d := (from + dir * t).distance_to(p)
			if d < best_d:
				best_d = d
				best = rid
	return best


## Where a resident is in the world (for the camera), or the origin if they're away.
func position_of(rid: String) -> Vector3:
	if _views.has(rid):
		return (_views[rid]["node"] as Node3D).position
	return Vector3.ZERO
