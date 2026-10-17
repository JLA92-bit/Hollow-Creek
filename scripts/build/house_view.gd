class_name HouseView
extends Node3D
## A house in the world: meshes generated from HouseData per storey, furniture and lights.
## Walls are split into 8 x 8 m chunks; after an edit only the chunks whose walls or openings changed
## are rebuilt (a change to the room layout rebuilds that storey). Floor view hides storeys above the
## one being looked at; the cutaway lowers the walls of that storey facing the camera.

const WALLS_UP := "up"
const WALLS_CUTAWAY := "cutaway"
const WALLS_DOWN := "down"
const MODEL_PATH := "res://assets/models/%s/%s.gltf"

signal rebuilt(chunks: int)

var data: HouseData
var builder: HouseMeshBuilder
var walls_mode := WALLS_UP
var view_level := 99  ## show storeys up to this level (99 = all)
var show_roof := true
var ground_fn: Callable
var last_rebuild_chunks := 0

var _levels: Dictionary = {}  ## level -> {node, structure, chunks: {Vector2i: MeshInstance3D}}
var _roof: MeshInstance3D
var _garden: MeshInstance3D
var _furniture: Node3D
var _lights: Array[Dictionary] = []
var _slot_mats: Dictionary = {}
var _bounce: Array[Dictionary] = []
var _cam_forward := Vector3(0, 0, -1)
var _cut_signature := ""
var _room_signature: Dictionary = {}
var _lamp_level := 0.0
var _daylight := 1.0
var _lamp_budget := 8
var _lamp_shadows := false
var _t := 0.0


func setup(p_data: HouseData, p_ground_fn: Callable) -> void:
	data = p_data
	ground_fn = p_ground_fn
	builder = HouseMeshBuilder.new(data, ground_fn)
	_roof = MeshInstance3D.new()
	_roof.name = "Roof"
	add_child(_roof)
	_furniture = Node3D.new()
	_furniture.name = "Furniture"
	add_child(_furniture)
	rebuild_all()


## Replaces the data (undo, redo, loading) and rebuilds everything.
func set_data(p_data: HouseData) -> void:
	data = p_data
	builder = HouseMeshBuilder.new(data, ground_fn)
	rebuild_all()


## Swaps in new data and rebuilds only what differs from before (the old data's dict by default).
func replace_data(p_data: HouseData, before: Variant = null) -> void:
	var old_dict: Dictionary = before if before is Dictionary else data.to_dict()
	data = p_data
	builder.house = p_data
	refresh_after_edit(old_dict)


func rebuild_all() -> void:
	for l: int in _levels:
		(_levels[l]["node"] as Node3D).queue_free()
	_levels.clear()
	_cut_signature = _cut_sig()
	for l2 in data.levels():
		_build_level(l2)
	_build_roof()
	_build_garden()
	_place_objects()
	_make_lights()
	_apply_visibility()
	_snapshot_rooms()


func _level_entry(l: int) -> Dictionary:
	if not _levels.has(l):
		var node := Node3D.new()
		node.name = "Storey_%d" % l
		add_child(node)
		var st := MeshInstance3D.new()
		st.name = "Structure"
		node.add_child(st)
		_levels[l] = {"node": node, "structure": st, "chunks": {}}
	return _levels[l]


func _build_level(l: int) -> void:
	var entry := _level_entry(l)
	var kit := MeshKit.new()
	builder.build_structure(kit, l)
	(entry["structure"] as MeshInstance3D).mesh = kit.commit(builder.mats) if kit.has_geometry() else null
	var chunks: Dictionary = entry["chunks"]
	for c: Vector2i in chunks:
		(chunks[c] as MeshInstance3D).queue_free()
	chunks.clear()
	var wanted: Dictionary = {Vector2i.ZERO: true}
	for k: String in data.walls(l):
		wanted[HouseMeshBuilder.edge_chunk(k)] = true
	for c2: Vector2i in wanted:
		_build_chunk(l, c2)


func _build_chunk(l: int, c: Vector2i) -> void:
	var entry := _level_entry(l)
	var chunks: Dictionary = entry["chunks"]
	var kit := MeshKit.new()
	builder.build_walls(kit, l, func(k: String) -> bool: return _wall_is_cut(l, k), c)
	var mi: MeshInstance3D = chunks.get(c)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Walls_%d_%d" % [c.x, c.y]
		(entry["node"] as Node3D).add_child(mi)
		chunks[c] = mi
	mi.mesh = kit.commit(builder.mats) if kit.has_geometry() else null


func _build_garden() -> void:
	if _garden == null:
		_garden = MeshInstance3D.new()
		_garden.name = "Garden"
		add_child(_garden)
	var kit := MeshKit.new()
	GardenBuilder.new(builder).build(kit)
	_garden.mesh = kit.commit(builder.mats) if kit.has_geometry() else null


func _build_roof() -> void:
	var kit := MeshKit.new()
	builder.build_roof(kit)
	_roof.mesh = kit.commit(builder.mats) if kit.has_geometry() else null


## Rebuilds what an edit changed, given the house's state before the edit.
func refresh_after_edit(before: Dictionary) -> void:
	var old := HouseData.from_dict(before) if not before.is_empty() else HouseData.new()
	var count := 0
	for l in data.levels():
		if not old.has_storey(l) or _room_sig(data, l) != _room_sig(old, l) or _floors_changed(old, l):
			_build_level(l)
			count += (_levels[l]["chunks"] as Dictionary).size()
			if data.has_storey(l + 1):
				_build_level(l + 1)
			continue
		var dirty: Dictionary = {}
		var nw := data.walls(l)
		var ow := old.walls(l)
		for k: String in nw:
			if not ow.has(k) or JSON.stringify(nw[k]) != JSON.stringify(ow[k]):
				_mark(dirty, k)
		for k2: String in ow:
			if not nw.has(k2):
				_mark(dirty, k2)
		var no := _openings_by_id(data.openings(l))
		var oo := _openings_by_id(old.openings(l))
		for id: String in no:
			if not oo.has(id) or JSON.stringify(no[id]) != JSON.stringify(oo[id]):
				for ek in HouseData.opening_edges(no[id]):
					_mark(dirty, ek)
		for id2: String in oo:
			if not no.has(id2) or JSON.stringify(no[id2]) != JSON.stringify(oo[id2]):
				for ek2 in HouseData.opening_edges(oo[id2]):
					_mark(dirty, ek2)
		for c: Vector2i in dirty:
			_build_chunk(l, c)
		count += dirty.size()
		var outside_changed := not dirty.is_empty() or JSON.stringify(data.verandahs) != JSON.stringify(old.verandahs) \
			or JSON.stringify(data.exterior) != JSON.stringify(old.exterior) or JSON.stringify(data.terrain) != JSON.stringify(old.terrain) \
			or JSON.stringify(data.foundation) != JSON.stringify(old.foundation)
		if outside_changed or JSON.stringify(data.stairs(l)) != JSON.stringify(old.stairs(l)) or JSON.stringify(data.storey(l).get("columns", [])) != JSON.stringify(old.storey(l).get("columns", [])):
			var kit := MeshKit.new()
			builder.build_structure(kit, l)
			(_levels[l]["structure"] as MeshInstance3D).mesh = kit.commit(builder.mats) if kit.has_geometry() else null
			if data.has_storey(l + 1):
				_build_level(l + 1)
	for l2: int in _levels.keys():
		if not data.has_storey(l2):
			(_levels[l2]["node"] as Node3D).queue_free()
			_levels.erase(l2)
	_build_roof()
	if JSON.stringify([data.garden, data.fences, data.terrain]) != JSON.stringify([old.garden, old.fences, old.terrain]):
		_build_garden()
	if JSON.stringify(data.objects) != JSON.stringify(old.objects):
		_place_objects()
	_make_lights()
	_apply_visibility()
	_snapshot_rooms()
	last_rebuild_chunks = count
	rebuilt.emit(count)


func _mark(dirty: Dictionary, k: String) -> void:
	# The edge's chunk, plus neighbours, since corners look at the walls next door.
	for p in HouseData.edge_points(k):
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				dirty[HouseMeshBuilder.chunk_of(p + Vector2i(dx, dy))] = true


func _openings_by_id(arr: Array) -> Dictionary:
	var out := {}
	for o: Dictionary in arr:
		out[str(o["id"])] = o
	return out


func _floors_changed(old: HouseData, l: int) -> bool:
	return JSON.stringify(data.floors(l)) != JSON.stringify(old.floors(l))


static func _room_sig(h: HouseData, l: int) -> String:
	var parts: Array[String] = []
	for r in h.rooms(l):
		parts.append("%s:%.2f:%s" % [r["key"], float(r["area"]), h.room_paint(r)])
	return "|".join(parts)


func _snapshot_rooms() -> void:
	_room_signature.clear()
	for l in data.levels():
		_room_signature[l] = _room_sig(data, l)


# --- Views ---------------------------------------------------------------------------------------

## Sets walls up, cutaway or down. The camera direction decides which walls a cutaway lowers.
func set_view(mode: String, cam_forward: Vector3) -> void:
	walls_mode = mode
	_cam_forward = Vector3(cam_forward.x, 0, cam_forward.z).normalized()
	_apply_visibility()


## Shows storeys up to this level (floor view). 99 shows everything.
func set_view_level(l: int) -> void:
	view_level = l
	_apply_visibility()


func top_level() -> int:
	var levels := data.levels()
	return levels[levels.size() - 1] if not levels.is_empty() else 0


func active_level() -> int:
	return mini(view_level, top_level())


func _apply_visibility() -> void:
	for l: int in _levels:
		(_levels[l]["node"] as Node3D).visible = l <= view_level
	_roof.visible = show_roof and walls_mode == WALLS_UP and view_level >= top_level()
	for c in _furniture.get_children():
		var lvl := int(c.get_meta("level", 0))
		(c as Node3D).visible = lvl <= view_level
	# Rebuild walls only when the set of cut walls actually changes.
	var sig := _cut_sig()
	if sig != _cut_signature:
		_cut_signature = sig
		for l2: int in _levels:
			for c2: Vector2i in (_levels[l2]["chunks"] as Dictionary):
				_build_chunk(l2, c2)


func _cut_sig() -> String:
	var sig := "%s|%d|" % [walls_mode, active_level()]
	if walls_mode == WALLS_CUTAWAY:
		for k: String in data.walls(active_level()):
			sig += "1" if _wall_is_cut(active_level(), k) else "0"
	return sig


func _wall_is_cut(l: int, k: String) -> bool:
	if l != active_level():
		return false
	match walls_mode:
		WALLS_UP:
			return false
		WALLS_DOWN:
			return true
	var pts := HouseData.edge_points(k)
	var mid := (Vector2(pts[0]) + Vector2(pts[1])) * 0.5
	var out_a := data.room_on_side(l, k, "a").is_empty()
	var out_b := data.room_on_side(l, k, "b").is_empty()
	var na := HouseMeshBuilder._side_normal3(k)
	if out_a != out_b:
		var out := na if out_a else -na
		return out.dot(_cam_forward) < -0.2
	var b := data.bounds(l)
	var centre := Vector2(b.position) + Vector2(b.size) * 0.5
	var towards_camera := -Vector2(_cam_forward.x, _cam_forward.z)
	return (mid - centre).dot(towards_camera) > 0.6


# --- Furniture -----------------------------------------------------------------------------------

func _place_objects() -> void:
	for c in _furniture.get_children():
		c.queue_free()
	var placed: Dictionary = {}
	var deferred: Array[Dictionary] = []
	for o in data.objects:
		if o.has("item"):
			# Buy mode objects carry their own height above the floor.
			var nb := _instance(o)
			if nb != null:
				nb.position = Vector3(float(o["x"]), builder.level_y(int(o.get("level", 0))) + float(o.get("y", 0.0)), float(o["z"]))
				nb.set_meta("object_id", str(o.get("id", "")))
			continue
		if o.has("on"):
			deferred.append(o)
			continue
		var n := _instance(o)
		if n == null:
			continue
		var lvl := int(o.get("level", 0))
		var base_y := builder.level_y(lvl) if not o.get("outside", false) else float(ground_fn.call(float(o["x"]), float(o["z"])))
		n.position = Vector3(float(o["x"]), base_y + float(o.get("y", 0.0)), float(o["z"]))
		var model := str(o["model"])
		if not placed.has(model):
			placed[model] = []
		(placed[model] as Array).append(n)
	for o2 in deferred:
		var n2 := _instance(o2)
		if n2 == null:
			continue
		var lvl2 := int(o2.get("level", 0))
		var fy := builder.level_y(lvl2)
		var on := str(o2["on"])
		var top := fy + 0.8
		if on == "table":
			for f in data.fixtures:
				if f["kind"] == "tablecloth":
					top = fy + float(f["h"]) + 0.003
		elif on == "stove":
			top = fy + 0.82
		elif placed.has(on):
			var best: Node3D = null
			var p := Vector2(float(o2["x"]), float(o2["z"]))
			for cand: Node3D in placed[on]:
				if best == null or Vector2(cand.position.x, cand.position.z).distance_to(p) < Vector2(best.position.x, best.position.z).distance_to(p):
					best = cand
			if best:
				top = _top_of(best)
		n2.position = Vector3(float(o2["x"]), top, float(o2["z"]))


func _instance(o: Dictionary) -> Node3D:
	var model := str(o["model"])
	var path := Catalogue.model_path(model)
	if not ResourceLoader.exists(path):
		push_warning("Missing model: %s" % path)
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.name = model
	n.rotation_degrees.y = float(o.get("rot", 0.0))
	n.set_meta("level", int(o.get("level", 0)))
	if o.has("scale"):
		var s: Array = o["scale"]
		n.scale = Vector3(float(s[0]), float(s[1]), float(s[2]))
	_furniture.add_child(n)
	if o.has("item"):
		_apply_slots(n, o)
	return n


## The Design tool's choices: each slot's surfaces get a library material in a colour, or the model's
## own material tinted.
func _apply_slots(n: Node3D, o: Dictionary) -> void:
	var it := Catalogue.item(Catalogue.id_of(o))
	var slots: Dictionary = it.get("slots", {})
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var slot := m.resource_name if m else ""
			if not slots.has(slot):
				continue
			var v := Catalogue.slot_value(o, slot)
			var colour := Color(str(v.get("colour", "#FFFFFF")))
			var key := "%s|%s|%s|%s" % [o.get("model", ""), slot, v.get("mat", ""), colour.to_html(false)]
			if not _slot_mats.has(key):
				var mat: Material
				if str(v.get("mat", "")) == "" and m is StandardMaterial3D:
					var dup := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.albedo_color = dup.albedo_color * colour
					mat = dup
				elif str(v.get("mat", "")) != "":
					mat = MaterialLibrary.get_material(str(v["mat"]), colour)
				else:
					mat = m
				_slot_mats[key] = mat
			mi.set_surface_override_material(i, _slot_mats[key])


## Top of a placed object, from its meshes' bounding boxes (works before it's in the tree).
func _top_of(n: Node3D) -> float:
	var top := -INF
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		var xf := Transform3D()
		var node: Node = vi
		while node != null and node != _furniture:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var box := xf * vi.get_aabb()
		top = maxf(top, box.end.y)
	return top if top > -INF else 0.8


# --- Lights --------------------------------------------------------------------------------------

func _make_lights() -> void:
	for l in _lights:
		(l["light"] as Node).queue_free()
		(l["flame"] as Node).queue_free()
	for b in _bounce:
		(b["light"] as Node).queue_free()
	_lights.clear()
	_bounce.clear()
	for l2 in data.lights:
		var kind := str(l2["kind"])
		var lvl := int(l2.get("level", 0))
		var fy := builder.level_y(lvl)
		var light := OmniLight3D.new()
		light.position = Vector3(float(l2["x"]), fy + float(l2["y"]) + (0.36 if kind == "kerosene" else 0.0), float(l2["z"]))
		light.light_color = Color(1.0, 0.62, 0.34) if kind == "kerosene" else Color(1.0, 0.47, 0.22)
		light.omni_range = 6.5 if kind == "kerosene" else 4.5
		light.omni_attenuation = 1.3
		light.shadow_bias = 0.08
		light.light_specular = 0.3
		light.visible = false
		add_child(light)
		var flame := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.012 if kind == "kerosene" else 0.16
		sphere.height = 0.04 if kind == "kerosene" else 0.12
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1.0, 0.75, 0.4)
		fm.emission_enabled = true
		fm.emission = Color(1.0, 0.6, 0.25)
		fm.emission_energy_multiplier = 4.0
		sphere.material = fm
		flame.mesh = sphere
		flame.position = light.position + (Vector3.ZERO if kind == "kerosene" else Vector3(0, -0.15, 0))
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.visible = false
		add_child(flame)
		var room := data.room_at_tile(lvl, Vector2i(floori(float(l2["x"])), floori(float(l2["z"]))))
		_lights.append({"light": light, "room": "%d:%s" % [lvl, str(room.get("key", "none"))], "kind": kind,
			"base": 1.5 if kind == "kerosene" else 1.8, "flame": flame, "level": lvl})
	# Lamps, candles and lights from the catalogue, with their own brightness and colour temperature.
	for o in data.objects:
		var ld := Catalogue.light_of(o)
		if ld.is_empty():
			continue
		var lvl3 := int(o.get("level", 0))
		var at: Array = ld.get("at", [0, 0.5, 0])
		var base := Vector3(float(o["x"]), builder.level_y(lvl3) + float(o.get("y", 0.0)), float(o["z"]))
		var lamp := OmniLight3D.new()
		lamp.position = base + Basis(Vector3.UP, deg_to_rad(float(o.get("rot", 0.0)))) * Vector3(float(at[0]), float(at[1]), float(at[2]))
		lamp.light_color = Catalogue.kelvin_colour(float(ld.get("kelvin", 2700)))
		lamp.omni_range = float(ld.get("range", 4.5))
		lamp.omni_attenuation = 1.3
		lamp.shadow_bias = 0.08
		lamp.light_specular = 0.3
		lamp.visible = false
		add_child(lamp)
		var glow := MeshInstance3D.new()
		var bulb := SphereMesh.new()
		var lk := str(ld.get("kind", "electric"))
		bulb.radius = 0.04 if lk == "electric" else 0.012
		bulb.height = bulb.radius * (2.0 if lk == "electric" else 3.0)
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_color = lamp.light_color
		gm.emission_enabled = true
		gm.emission = lamp.light_color
		gm.emission_energy_multiplier = 4.0
		bulb.material = gm
		glow.mesh = bulb
		glow.position = lamp.position
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = false
		add_child(glow)
		var room3 := data.room_at_tile(lvl3, Vector2i(floori(float(o["x"])), floori(float(o["z"]))))
		_lights.append({"light": lamp, "room": "%d:%s" % [lvl3, str(room3.get("key", "none"))], "kind": "kerosene" if lk != "electric" else "electric",
			"base": 1.6 * float(ld.get("energy", 1.0)), "flame": glow, "level": lvl3})
	# One soft fill light per room, tinted by its walls and floor (fake bounce light).
	for lvl2 in data.levels():
		for r in data.rooms(lvl2):
			var rb: Rect2i = r["bounds"]
			var b2 := OmniLight3D.new()
			b2.position = Vector3(rb.get_center().x, builder.level_y(lvl2) + 1.7, rb.get_center().y)
			b2.omni_range = maxf(rb.size.x, rb.size.y) * 0.95 + 0.8
			b2.omni_attenuation = 0.7
			b2.light_specular = 0.0
			var t: Vector2i = (r["full_tiles"] as Array)[0] if not (r["full_tiles"] as Array).is_empty() else (r["tiles"] as Array)[0]
			var f: Dictionary = data.floors(lvl2).get(HouseData.tile_key(t.x, t.y), {"m": "floor_boards"})
			var fm2 := str(f["m"]) if f["m"] is String else str((f["m"] as Array)[0])
			var colour := HouseMeshBuilder._paint(data.room_paint(r)).lerp(MaterialLibrary.get_material(fm2).albedo_color, 0.35)
			b2.light_color = colour
			add_child(b2)
			_bounce.append({"light": b2, "room": "%d:%s" % [lvl2, r["key"]], "colour": colour, "level": lvl2})
	set_lighting(_lamp_level, _daylight, _lamp_budget, _lamp_shadows)


## level: 0 lamps off to 1 all lit. daylight: 0 night to 1 noon. budget: real lights allowed.
func set_lighting(level: float, daylight: float, budget: int, lamp_shadows: bool) -> void:
	_lamp_level = level
	_daylight = daylight
	_lamp_budget = budget
	_lamp_shadows = lamp_shadows
	var lit_rooms: Dictionary = {}
	var used := 0
	for l in _lights:
		var on := level > 0.4 and int(l["level"]) <= view_level
		var light: OmniLight3D = l["light"]
		light.visible = on and used < budget
		light.shadow_enabled = lamp_shadows and l["kind"] == "kerosene"
		(l["flame"] as MeshInstance3D).visible = on
		if light.visible:
			used += 1
		if on:
			lit_rooms[l["room"]] = true
	for room_key: String in builder.glass_materials:
		var g: StandardMaterial3D = builder.glass_materials[room_key]
		g.emission_energy_multiplier = 1.6 * level if lit_rooms.has(room_key) else 0.0
	for b in _bounce:
		var bl: OmniLight3D = b["light"]
		var lamp := 0.35 * level if lit_rooms.has(b["room"]) else 0.0
		bl.light_energy = 0.32 * daylight + lamp
		bl.light_color = (b["colour"] as Color).lerp(Color(1.0, 0.7, 0.45), clampf(lamp * 2.0, 0.0, 0.7))
		bl.visible = bl.light_energy > 0.01 and int(b["level"]) <= view_level


func _process(delta: float) -> void:
	_t += delta
	if _lamp_level <= 0.4:
		return
	for i in _lights.size():
		var l: Dictionary = _lights[i]
		var f := 1.0 + 0.04 * sin(_t * 11.0 + i * 2.1) + 0.03 * sin(_t * 23.0 + i) if l["kind"] != "electric" else 1.0
		if l["kind"] == "fire":
			f = 1.0 + 0.12 * sin(_t * 7.0 + i) + 0.08 * sin(_t * 17.3)
		(l["light"] as OmniLight3D).light_energy = float(l["base"]) * _lamp_level * f
