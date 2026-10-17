class_name BuildMode
extends Node
## Build mode: turns pointer, keyboard and touch input into BuildOps edits on the town's houses, with
## live previews (blueprint ghosts, snapping guides, dimension and cost labels), unlimited undo and
## redo, sounds, money and autosave. The world owns the houses; this node owns the tools.

signal changed
signal message(text: String, kind: String)

const TOOLS: Array[String] = ["room", "wall", "select", "door", "window", "arch", "floor", "paint", "roof", "verandah", "stairs", "post", "terrain", "garden", "fence", "demolish"]
const GARDEN_TOOLS: Array[String] = ["terrain", "garden", "fence"]
const HINTS := {
	"room": "Drag to draw a room. Hold Shift (or tap Add to room) to extend the room you start in.",
	"wall": "Drag along the grid to draw a wall. Drag at 45 degrees for a diagonal.",
	"select": "Drag a wall to push or pull it. Drag inside a room to move it, and turn it with , and .",
	"door": "Point at a wall and click to place a door. Hold Alt for free placement.",
	"window": "Point at a wall and click to place a window. Arrow keys nudge and raise a selected window.",
	"arch": "Point at a wall and click to open an archway.",
	"floor": "Drag over tiles to lay floor. Quarter mode paints triangles.",
	"paint": "Click a wall to paint that side. Shift paints the whole room, Ctrl the whole house. I picks up a finish.",
	"roof": "Click the house to roof it. Draw adds a piece; Change lets you drag a roof's pitch or its edges. Chimney goes on a wall.",
	"verandah": "Click an outside wall for a verandah along it, or drag along the wall for part of it. Steps and Sleep-out work on a verandah.",
	"terrain": "Click or drag to shape the ground round a house. Paint lays lawn, paths, gravel or garden beds.",
	"garden": "Click to plant or place it. , and . turn it. Demolish takes things away.",
	"fence": "Drag along the grid to run a fence. Gate turns a metre of fence into a gate.",
	"stairs": "Click to place stairs. Turn them with , and . (they rise the way the arrow points).",
	"post": "Click a grid corner to stand a post.",
	"demolish": "Click a door, window, post or stairs to remove it. Drag along walls, or click a room to clear it.",
}

var world: Node3D
var rig: CameraRig
var sfx: Sfx
var active := false
var tool := "room"
var level := 0
var undo := UndoStack.new()
var options: Dictionary = {
	"wall_kind": "full", "floor": "floor_boards", "floor_mode": "tile", "floor_rot": 0,
	"door_style": "four_panel", "window_style": "double_hung", "arch_style": "arch",
	"stairs_kind": "straight", "stairs_dir": "N", "post_kind": "timber_post",
	"room_paint": "cream", "room_height": 2.7, "room_floor": "floor_boards", "room_name": "Room",
	"extend": false, "free": false, "latch_night": false, "curtains_dusk": true, "lock_night": false,
	"paint_kind": "paint", "paint_colour": "cream", "wallpaper": "floral", "colourway": "cream_rose",
	"cladding": "weatherboard", "lining": "wall_tiles", "paint_part": "finish", "dado_h": 1.0,
	"paint_scope": "face", "eyedropper": false,
	"v_mode": "add", "v_depth": 2.1, "v_shape": "bullnose", "v_post": "timber_post", "v_lace": "none", "v_rail": "none",
	"v_lattice": false, "v_material": "corrugated_iron", "v_colour": "cream",
	"terrain_op": "raise", "terrain_radius": 2.5, "ground": "footpath",
	"garden_cat": "plants", "garden_kind": "rose", "garden_rot": 0.0, "fence_type": "picket", "fence_mode": "build",
	"roof_mode": "auto", "roof_shape": "hip", "roof_pitch": 28.0, "roof_overhang": 0.45, "roof_material": "corrugated_iron",
}
var house: HouseView = null  ## the house being edited
var selection: Dictionary = {}  ## {type: run|room|opening|stairs, ...}
var touch_mode := false  ## last input came from a touchscreen: placements wait for a confirm

var _drag: Dictionary = {}
var _pending: Dictionary = {}
var _preview: MeshInstance3D
var _label: Label3D
var _blueprint: StandardMaterial3D
var _bad: StandardMaterial3D
var _touches: Dictionary = {}
var _hover_world := Vector3.ZERO
var _house_counter := 1
var _walls_before := ""
## A design waiting to be placed (from the library or a share code), and its name.
var placing: HouseData = null
var placing_name := ""


func _ready() -> void:
	_blueprint = StandardMaterial3D.new()
	_blueprint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blueprint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blueprint.albedo_color = Color(0.294, 0.788, 0.961, 0.42)
	_blueprint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blueprint.no_depth_test = false
	_blueprint.render_priority = 10
	_bad = _blueprint.duplicate() as StandardMaterial3D
	_bad.albedo_color = Color(0.949, 0.408, 0.224, 0.45)
	_preview = MeshInstance3D.new()
	_preview.name = "BuildPreview"
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0011
	_label.font = load("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf") as Font
	_label.font_size = 30
	_label.modulate = Color("#00294D")
	_label.outline_modulate = Color.WHITE
	_label.outline_size = 10
	_label.render_priority = 20
	_label.visible = false
	add_child(_label)
	sfx = Sfx.new()
	add_child(sfx)
	for h in world.get("houses") as Array:
		_house_counter += 1


# --- Mode and tool switching -----------------------------------------------------------------------

func enter() -> void:
	active = true
	tool = "room"
	level = 0
	if house == null:
		var hs: Array = world.get("houses")
		for hv: HouseView in hs:
			if not hv.data.locked:
				house = hv
				break
	_apply_view()
	_say(HINTS[tool], "hint")
	changed.emit()


func exit() -> void:
	active = false
	_cancel()
	selection.clear()
	for hv: HouseView in world.get("houses") as Array:
		hv.set_view_level(99)
	changed.emit()


func set_tool(t: String) -> void:
	_cancel()
	if t == "roof" and tool != "roof":
		_walls_before = str(world.get("walls_mode"))
		world.call("set_walls_mode", HouseView.WALLS_UP)
		if house != null:
			level = house.data.levels()[-1]
			_apply_view()
	elif t != "roof" and tool == "roof" and _walls_before != "":
		world.call("set_walls_mode", _walls_before)
		_walls_before = ""
	tool = t
	selection.clear()
	sfx.play("click")
	_say(HINTS.get(t, ""), "hint")
	changed.emit()


func set_option(key: String, value: Variant) -> void:
	options[key] = value
	if tool == "verandah" and key.begins_with("v_") and key != "v_mode" and selection.get("type", "") == "verandah":
		var vid := str(selection["id"])
		var vk := key.substr(2)
		_commit("Change verandah", func(h: HouseData) -> Dictionary: return BuildOps.update_verandah(h, vid, {vk: value}))
		changed.emit()
		return
	if tool == "roof" and key.begins_with("roof_") and key != "roof_mode":
		if selection.get("type", "") == "roof":
			var map := {"roof_shape": "shape", "roof_pitch": "pitch", "roof_overhang": "overhang", "roof_material": "material"}
			set_roof_prop(map[key], value)
			return
		if options["roof_mode"] == "auto" and house != null and bool(house.data.roof.get("follow", false)):
			roof_house()
	if selection.get("type", "") == "opening" and key in ["latch_night", "curtains_dusk", "lock_night"]:
		var night_key: String = {"latch_night": "latch", "curtains_dusk": "curtains", "lock_night": "lock"}[key]
		var o := house.data.opening_by_id(str(selection["id"]))
		var night: Dictionary = (o.get("night", {}) as Dictionary).duplicate()
		night[night_key] = value
		_commit("Change %s" % o["kind"], func(h: HouseData) -> Dictionary: return BuildOps.update_opening(h, str(selection["id"]), {"night": night}))
	changed.emit()


func set_level(l: int) -> void:
	if house == null:
		level = clampi(l, 0, 0)
	else:
		level = clampi(l, house.data.levels()[0], house.data.levels()[-1])
	sfx.play("storey")
	_apply_view()
	changed.emit()


func _apply_view() -> void:
	for hv: HouseView in world.get("houses") as Array:
		hv.set_view_level(level if hv == house else 99)


func add_storey(up: bool) -> void:
	if house == null:
		_say("Draw a room first.", "warn")
		return
	var levels := house.data.levels()
	var target: int = levels[-1] + 1 if up else levels[0] - 1
	var res := _commit("Add %s" % HouseData.storey_name(target).to_lower(), func(h: HouseData) -> Dictionary: return BuildOps.add_storey(h, target, 2.7))
	if res:
		set_level(target)


# --- Coordinates -------------------------------------------------------------------------------------

## The world point under the pointer, on the floor plane of the storey being edited (or the ground).
func pick(screen: Vector2) -> Vector3:
	var cam := rig.camera
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var plane_y := 0.0
	if house != null and tool not in GARDEN_TOOLS:
		plane_y = house.position.y + house.builder.level_y(level)
	else:
		var grid: WorldGrid = world.get("slice").grid
		plane_y = grid.height_at(rig.focus.x, rig.focus.z)
		for i in 3:
			if absf(dir.y) < 0.001:
				break
			var t := (plane_y - origin.y) / dir.y
			var p := origin + dir * t
			plane_y = grid.height_at(p.x, p.z)
	if absf(dir.y) < 0.001:
		return origin
	return origin + dir * ((plane_y - origin.y) / dir.y)


## World position to the edited house's local tile space (continuous).
func to_local_2d(p: Vector3, hv: HouseView = house) -> Vector2:
	if hv == null:
		return Vector2(p.x, p.z)
	return Vector2(p.x - hv.position.x, p.z - hv.position.z)


func _house_at(p: Vector3) -> HouseView:
	for hv: HouseView in world.get("houses") as Array:
		if tool in GARDEN_TOOLS and hv.data.locked:
			continue
		var b := hv.data.bounds().grow(GardenOps.LOT_MARGIN if tool in GARDEN_TOOLS else 2)
		var lp := to_local_2d(p, hv)
		if Rect2(b).has_point(lp):
			return hv
	return null


# --- Input -------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey:
		_key(event as InputEventKey)
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		touch_mode = true
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() > 1:
			_cancel()
			return
		if st.pressed:
			_press(st.position, false, false)
		else:
			_release(st.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if _touches.size() == 1:
			_move((event as InputEventScreenDrag).position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			touch_mode = false
			if mb.pressed:
				_press(mb.position, mb.shift_pressed, mb.alt_pressed)
			else:
				_release(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not _drag.is_empty():
			_cancel()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		touch_mode = false
		_move(mm.position, mm.alt_pressed)


func _key(k: InputEventKey) -> void:
	if not k.pressed or k.echo and k.keycode not in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		return
	if k.ctrl_pressed and k.keycode == KEY_Z:
		do_redo() if k.shift_pressed else do_undo()
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		do_redo()
	elif k.keycode == KEY_ESCAPE:
		if placing != null:
			cancel_placing()
		elif not _drag.is_empty() or not _pending.is_empty():
			_cancel()
		else:
			selection.clear()
			changed.emit()
	elif k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE:
		delete_selection()
	elif k.keycode == KEY_COMMA or k.keycode == KEY_PERIOD:
		_rotate(1 if k.keycode == KEY_PERIOD else -1)
	elif k.shift_pressed and k.keycode == KEY_PAGEUP:
		set_level(level + 1)
	elif k.shift_pressed and k.keycode == KEY_PAGEDOWN:
		set_level(level - 1)
	elif k.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		_nudge(k.keycode)
	else:
		if k.keycode == KEY_I and tool == "paint":
			set_option("eyedropper", not bool(options["eyedropper"]))
			get_viewport().set_input_as_handled()
			return
		var keys := {KEY_R: "room", KEY_W: "", KEY_T: "wall", KEY_V: "select", KEY_D: "door", KEY_N: "window", KEY_F: "floor", KEY_P: "paint", KEY_O: "roof", KEY_E: "verandah", KEY_G: "stairs", KEY_X: "demolish"}
		if keys.has(k.keycode) and str(keys[k.keycode]) != "" and not k.ctrl_pressed:
			set_tool(str(keys[k.keycode]))
			return
		return
	get_viewport().set_input_as_handled()


func _press(screen: Vector2, shift: bool, alt: bool) -> void:
	if not _pending.is_empty():
		_cancel()
	if placing != null:
		_drag = {"start": pick(screen), "screen": screen, "shift": false, "alt": false, "moved": false, "ctrl": false}
		return
	var p := pick(screen)
	var target := _house_at(p)
	if target != null and target.data.locked:
		_say("%s is a heritage building and can't be changed." % target.data.name, "warn")
		sfx.play("error")
		return
	if target == null and tool == "room":
		# Drawing away from every house starts a new one.
		if house != null:
			house = null
			level = 0
			_apply_view()
			changed.emit()
	elif target != null and target != house:
		house = target
		level = clampi(level, house.data.levels()[0], house.data.levels()[-1])
		_apply_view()
		changed.emit()
	_drag = {"start": p, "screen": screen, "shift": shift or options["extend"], "alt": alt or options["free"], "moved": false,
		"ctrl": Input.is_key_pressed(KEY_CTRL)}
	match tool:
		"select":
			_select_press(p)
		"door", "window", "arch":
			_drag["opening"] = _opening_at_pointer(p, alt or options["free"])
		"roof":
			_roof_press(screen)
		"verandah":
			_verandah_press(p)
		_:
			pass
	_move(screen, alt)


func _move(screen: Vector2, alt: bool = false) -> void:
	var p := pick(screen)
	_hover_world = p
	if not _drag.is_empty() and (screen - (_drag["screen"] as Vector2)).length() > 6.0:
		_drag["moved"] = true
	if not _drag.is_empty():
		_drag["last_screen"] = screen
	if placing != null:
		_place_preview(p)
		return
	match tool:
		"room":
			_room_preview(p)
		"wall":
			_wall_preview(p)
		"select":
			_select_move(p)
		"door", "window", "arch":
			_opening_preview(p, alt or options["free"])
		"floor":
			_floor_preview(p)
		"paint":
			_paint_preview(p)
		"roof":
			_roof_preview(screen, p)
		"verandah":
			_verandah_preview(p)
		"terrain":
			_terrain_preview(p)
		"garden":
			_garden_preview(p)
		"fence":
			_fence_preview(p)
		"stairs":
			_stairs_preview(p)
		"post":
			_post_preview(p)
		"demolish":
			_demolish_preview(p)


func _release(screen: Vector2) -> void:
	if _drag.is_empty():
		return
	_drag["last_screen"] = screen
	var p := pick(screen)
	var action := _action_for(p)
	if action.is_empty():
		_clear_preview()
		_drag.clear()
		return
	if touch_mode and action.get("confirm", false):
		# Phones: show the plan and wait for the Build button.
		_pending = action
		_drag.clear()
		_say("%s · tap Build to confirm" % action["label"], "confirm")
		changed.emit()
		return
	_run_action(action)
	_drag.clear()


func confirm_pending() -> void:
	if _pending.is_empty():
		return
	var a := _pending
	_pending = {}
	_run_action(a)


func has_pending() -> bool:
	return not _pending.is_empty()


func pending_label() -> String:
	return str(_pending.get("label", ""))


func _cancel() -> void:
	if _drag.has("original") and house != null:
		house.replace_data(HouseData.from_dict(_drag["original"]))
	_drag.clear()
	_pending.clear()
	_clear_preview()
	changed.emit()


func _run_action(a: Dictionary) -> void:
	if a.has("live"):
		_finish_live(a)
	else:
		_commit(str(a["label"]), a["fn"], bool(a.get("new_house", false)), a.get("origin", Vector2i.ZERO))
	_clear_preview()


# --- Committing edits ----------------------------------------------------------------------------

## Runs an op on the edited house (or a new one), records undo, charges money, rebuilds and saves.
func _commit(label: String, fn: Callable, new_house: bool = false, origin: Vector2i = Vector2i.ZERO) -> bool:
	var h: HouseData
	var before: Variant = null
	if new_house:
		h = HouseData.new()
		h.id = _new_house_id()
		h.name = "House %d" % _house_counter
		h.origin = origin
		h.roof = {"follow": true, "auto": roof_settings()}
	else:
		if house == null:
			_say("Draw a room first.", "warn")
			sfx.play("error")
			return false
		h = house.data
		before = h.to_dict()
	var res: Dictionary = fn.call(h)
	if not res["ok"]:
		if before != null:
			house.replace_data(HouseData.from_dict(before))
		_say(str(res["msg"]), "warn")
		sfx.play("error")
		return false
	var cost := int(res.get("cost", 0))
	if GameState.mode == GameState.MODE_STORY and cost > GameState.money:
		if before != null:
			house.replace_data(HouseData.from_dict(before))
		_say("That costs £%d and there's only £%d in the town account." % [cost, GameState.money], "warn")
		sfx.play("error")
		return false
	if GameState.mode == GameState.MODE_STORY:
		GameState.money -= cost
	var after := h.to_dict()
	undo.push(label, h.id, before, after, cost if GameState.mode == GameState.MODE_STORY else 0)
	if new_house:
		house = world.call("add_house", h) as HouseView
		_house_counter += 1
		placing = null
		_apply_view()
	else:
		house.replace_data(h, before)
	world.call("house_changed", h)
	sfx.play("remove" if cost < 0 else "place")
	_say("%s%s" % [label, (" · £%d" % cost) if cost > 0 else ""], "done")
	changed.emit()
	return true


func _new_house_id() -> String:
	var n := _house_counter
	var ids: Array = (world.get("houses") as Array).map(func(hv: HouseView) -> String: return hv.data.id)
	while ids.has("house_%d" % n):
		n += 1
	return "house_%d" % n


func do_undo() -> void:
	_cancel()
	var step := undo.undo()
	if step.is_empty():
		_say("Nothing to undo.", "hint")
		return
	_restore(step)
	GameState.money += int(step.get("refund", 0))
	sfx.play("undo")
	_say("Undid: %s" % step["label"], "done")
	changed.emit()


func do_redo() -> void:
	_cancel()
	var step := undo.redo()
	if step.is_empty():
		_say("Nothing to redo.", "hint")
		return
	_restore(step)
	GameState.money -= int(step.get("charge", 0))
	sfx.play("place")
	_say("Redid: %s" % step["label"], "done")
	changed.emit()


func _restore(step: Dictionary) -> void:
	var hv := _view_for(str(step["house"]))
	if step["state"] == null:
		if hv != null:
			world.call("remove_house", hv.data.id)
			if hv == house:
				house = null
		return
	var data := HouseData.from_dict(step["state"])
	if hv == null:
		house = world.call("add_house", data) as HouseView
	else:
		hv.replace_data(data)
		house = hv
	world.call("house_changed", data)
	level = clampi(level, data.levels()[0], data.levels()[-1])
	_apply_view()


func _view_for(id: String) -> HouseView:
	for hv: HouseView in world.get("houses") as Array:
		if hv.data.id == id:
			return hv
	return null


func _say(text: String, kind: String) -> void:
	message.emit(text, kind)


# --- Room tool ---------------------------------------------------------------------------------------

func _corner(p: Vector3, hv: HouseView = house) -> Vector2i:
	var l := to_local_2d(p, hv)
	return Vector2i(roundi(l.x), roundi(l.y))


func _tile(p: Vector3, hv: HouseView = house) -> Vector2i:
	var l := to_local_2d(p, hv)
	return Vector2i(floori(l.x), floori(l.y))


func _rect_from_drag(p: Vector3) -> Rect2i:
	var a := _corner(_drag["start"])
	var b := _corner(p)
	if a == b:
		b = a + Vector2i(1, 1)
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(lo, Vector2i(maxi(hi.x - lo.x, 1), maxi(hi.y - lo.y, 1)))


func _room_preview(p: Vector3) -> void:
	if _drag.is_empty():
		_show_cursor(p)
		return
	var rect := _rect_from_drag(p)
	var check := _world_check(rect)
	var kit := MeshKit.new()
	var y := _plane_y()
	var ok := check == ""
	for edge: Array in _rect_edges(rect):
		_ghost_wall(kit, edge[0], edge[1], y, float(options["room_height"]))
	kit.quad("f", _v3(Vector2(rect.position), y + 0.02), _v3(Vector2(rect.end.x, rect.position.y), y + 0.02), _v3(Vector2(rect.end), y + 0.02), _v3(Vector2(rect.position.x, rect.end.y), y + 0.02),
		Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_guides(kit, rect, y)
	_set_preview(kit, ok)
	var cost := (rect.size.x * 2 + rect.size.y * 2) * Pieces.cost("wall_weatherboard") + rect.size.x * rect.size.y * Pieces.cost(str(options["room_floor"]))
	var text := "%d × %d m · %d m² · about £%d" % [rect.size.x, rect.size.y, rect.size.x * rect.size.y, cost]
	if _drag["shift"]:
		text = "Add to room · " + text
	_show_label(_v3(Vector2(rect.get_center()), y + float(options["room_height"]) + 0.6), text if ok else check, ok)


## World-level checks for a room rectangle in the edited (or new) house's space.
func _world_check(rect: Rect2i) -> String:
	var slice: MapSlice = world.get("slice")
	var grid := slice.grid
	var off := Vector2i.ZERO if house == null else Vector2i(roundi(house.position.x), roundi(house.position.z))
	var hmin := INF
	var hmax := -INF
	for y in range(rect.position.y, rect.end.y + 1):
		for x in range(rect.position.x, rect.end.x + 1):
			var wx := x + off.x
			var wz := y + off.y
			if wx < 0 or wz < 0 or wx > grid.width or wz > grid.height:
				return "That's outside the town."
			var h := grid.corner_height(wx, wz)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
	for y2 in range(rect.position.y, rect.end.y):
		for x2 in range(rect.position.x, rect.end.x):
			var wt := Vector2i(x2 + off.x, y2 + off.y)
			if grid.in_bounds(wt.x, wt.y) and grid.get_ground(wt.x, wt.y) in [Ground.Type.WATER, Ground.Type.MUD]:
				return "Too wet to build on."
			for l: Dictionary in slice.data["landmarks"]:
				if l["kind"] in ["plot"] or l.get("hidden", false):
					continue
				var r: Array = l.get("lot", l.get("rect"))
				if Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])).has_point(wt):
					return "That's on %s." % _landmark_name(str(l["id"]))
			for hv: HouseView in world.get("houses") as Array:
				if hv == house:
					continue
				var hb := hv.data.bounds().grow(1)
				hb.position += Vector2i(roundi(hv.position.x), roundi(hv.position.z))
				if hb.has_point(wt):
					return "Too close to %s." % hv.data.name
	var base := house.position.y if house != null else hmax
	if house != null and level == 0:
		var floor_level := base + house.builder.level_y(0)
		if floor_level - hmin > 1.95:
			return "Too steep: the stumps would be over 1.8 m."
	elif house == null and hmax - hmin > 1.2:
		return "Too steep here. Try flatter ground."
	return ""


func _landmark_name(id: String) -> String:
	return {"lm_siding": "the railway siding", "lm_mill": "the mill", "lm_agnes_cottage": "Mrs Doyle's block"}.get(id, "a landmark")


func _room_action(p: Vector3) -> Dictionary:
	var rect := _rect_from_drag(p)
	var check := _world_check(rect)
	if check != "":
		_say(check, "warn")
		sfx.play("error")
		return {}
	var opts := {"floor": options["room_floor"], "paint": options["room_paint"], "height": options["room_height"], "name": options["room_name"]}
	if house == null:
		var origin := rect.position
		var local := Rect2i(Vector2i.ZERO, rect.size)
		return {"label": "Build a %d × %d room" % [rect.size.x, rect.size.y], "confirm": true, "new_house": true, "origin": origin,
			"fn": func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 0, local, opts)}
	var lv := level
	if _drag["shift"]:
		return {"label": "Extend room", "confirm": true, "fn": func(h: HouseData) -> Dictionary: return BuildOps.extend_room(h, lv, rect, opts)}
	return {"label": "Build a %d × %d room" % [rect.size.x, rect.size.y], "confirm": true,
		"fn": func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, lv, rect, opts)}


# --- Wall tool ---------------------------------------------------------------------------------------

func _wall_end(p: Vector3) -> Vector2i:
	var a := _corner(_drag["start"])
	var b := _corner(p)
	var d := b - a
	if absi(d.x) > 2 * absi(d.y):
		return Vector2i(b.x, a.y)
	if absi(d.y) > 2 * absi(d.x):
		return Vector2i(a.x, b.y)
	var n := maxi(absi(d.x), absi(d.y))
	return a + Vector2i(signi(d.x) * n, signi(d.y) * n)


func _wall_preview(p: Vector3) -> void:
	if _drag.is_empty():
		_show_cursor(p, true)
		return
	var a := _corner(_drag["start"])
	var b := _wall_end(p)
	var kit := MeshKit.new()
	var y := _plane_y()
	var hh := float(HouseData.KIND_HEIGHTS.get(options["wall_kind"], options["room_height"]))
	if a != b:
		_ghost_wall(kit, Vector2(a), Vector2(b), y, hh)
	_set_preview(kit, true)
	var length := Vector2(a).distance_to(Vector2(b))
	var piece := "wall_half" if options["wall_kind"] != "full" else "wall_weatherboard"
	_show_label(_v3((Vector2(a) + Vector2(b)) * 0.5, y + hh + 0.5), "%.1f m %s wall · £%d" % [length, str(options["wall_kind"]), ceili(length) * Pieces.cost(piece)], true)


func _wall_action(p: Vector3) -> Dictionary:
	var a := _corner(_drag["start"])
	var b := _wall_end(p)
	if a == b:
		return {}
	var lv := level
	var kind := str(options["wall_kind"])
	if house == null:
		_say("Start with the Room tool to make a house, then add walls.", "warn")
		return {}
	return {"label": "Build a wall", "confirm": true, "fn": func(h: HouseData) -> Dictionary: return BuildOps.add_wall(h, lv, a, b, kind)}


# --- Select tool: push and pull, move rooms, pick doors and windows --------------------------------

func _near_edge(p: Vector3, hv: HouseView, lv: int, radius: float = 0.35) -> String:
	if hv == null:
		return ""
	var l := to_local_2d(p, hv)
	var best := ""
	var best_d := radius
	for k: String in hv.data.walls(lv):
		var pts := HouseData.edge_points(k)
		var q := Geometry2D.get_closest_point_to_segment(l, Vector2(pts[0]), Vector2(pts[1]))
		var d := l.distance_to(q)
		if d < best_d:
			best_d = d
			best = k
	return best


func _select_press(p: Vector3) -> void:
	if house == null:
		return
	var op := _opening_under(p)
	if not op.is_empty():
		selection = {"type": "opening", "id": op["id"]}
		_drag["mode"] = "opening"
		_drag["original"] = house.data.to_dict()
		_drag["o_start"] = float(op["x"]) if op["axis"] == "x" else float(op["z"])
		changed.emit()
		return
	var k := _near_edge(p, house, level)
	if k != "" and not HouseData.is_diagonal(k):
		var run := BuildOps.wall_run(house.data, level, k)
		selection = {"type": "run", "edge": k, "run": run}
		_drag["mode"] = "push"
		_drag["edge"] = k
		_drag["original"] = house.data.to_dict()
		_drag["delta"] = 0
		_highlight_run(run, true)
		changed.emit()
		return
	var t := _tile(p)
	var r := house.data.room_at_tile(level, t)
	if not r.is_empty():
		selection = {"type": "room", "tile": t}
		_drag["mode"] = "move"
		_drag["original"] = house.data.to_dict()
		_drag["offset"] = Vector2i.ZERO
		_drag["turns"] = 0
		changed.emit()
		return
	for st: Dictionary in house.data.stairs(level):
		if (house.data.stair_tiles(st, level)["lower"] as Array).has(t):
			selection = {"type": "stairs", "id": st["id"]}
			changed.emit()
			return
	selection.clear()
	changed.emit()


func _select_move(p: Vector3) -> void:
	if _drag.is_empty():
		var k := _near_edge(p, house, level)
		if k != "" and not HouseData.is_diagonal(k):
			_highlight_run(BuildOps.wall_run(house.data, level, k), false)
		else:
			_clear_preview()
		return
	match str(_drag.get("mode", "")):
		"push":
			var k2: String = _drag["edge"]
			var horizontal := k2.ends_with(",N")
			var l0 := to_local_2d(_drag["start"])
			var l1 := to_local_2d(p)
			var delta := roundi((l1.y - l0.y) if horizontal else (l1.x - l0.x))
			if delta != int(_drag["delta"]):
				_drag["delta"] = delta
				_live_apply(func(h: HouseData) -> Dictionary: return BuildOps.push_pull(h, level, k2, delta), "%+d m" % delta)
				sfx.play("tick")
		"move":
			var l2 := to_local_2d(_drag["start"])
			var l3 := to_local_2d(p)
			var off := Vector2i(roundi(l3.x - l2.x), roundi(l3.y - l2.y))
			if off != _drag["offset"]:
				_drag["offset"] = off
				_live_move()
				sfx.play("tick")
		"opening":
			var o := (HouseData.from_dict(_drag["original"]) as HouseData).opening_by_id(str(selection["id"]))
			var la := to_local_2d(_drag["start"])
			var lb := to_local_2d(p)
			var shift := (lb.x - la.x) if o["axis"] == "x" else (lb.y - la.y)
			var at := snappedf(float(_drag["o_start"]) + shift, 0.25 if not _drag["alt"] else 0.01)
			var key := "x" if o["axis"] == "x" else "z"
			if not is_equal_approx(at, float(_drag.get("o_at", -999.0))):
				_drag["o_at"] = at
				_live_apply(func(h: HouseData) -> Dictionary: return BuildOps.update_opening(h, str(selection["id"]), {key: at}), "")


func _live_move() -> void:
	var off: Vector2i = _drag["offset"]
	var turns: int = _drag["turns"]
	var t: Vector2i = selection["tile"]
	var lv := level
	_live_apply(func(h: HouseData) -> Dictionary: return BuildOps.move_room(h, lv, t, off, turns), "move %d, %d" % [off.x, off.y])


## Applies an op to a copy of the original and shows it live; the release commits it.
func _live_apply(fn: Callable, text: String) -> void:
	var temp := HouseData.from_dict(_drag["original"])
	var res: Dictionary = fn.call(temp)
	_drag["live_ok"] = res["ok"]
	_drag["live_cost"] = int(res.get("cost", 0))
	_drag["live_fn"] = fn
	if res["ok"]:
		house.replace_data(temp)
		_show_label(_pv(_hover_world) + Vector3(0, 1.2, 0), text, true)
	else:
		house.replace_data(HouseData.from_dict(_drag["original"]))
		_show_label(_pv(_hover_world) + Vector3(0, 1.2, 0), str(res["msg"]), false)
	_clear_preview_mesh()


func _finish_live(a: Dictionary) -> void:
	var original: Dictionary = a["original"]
	if not a.get("ok", false):
		house.replace_data(HouseData.from_dict(original))
		return
	var cost := int(a.get("cost", 0))
	if GameState.mode == GameState.MODE_STORY:
		GameState.money -= cost
	undo.push(str(a["label"]), house.data.id, original, house.data.to_dict(), cost if GameState.mode == GameState.MODE_STORY else 0)
	world.call("house_changed", house.data)
	sfx.play("place")
	_say(str(a["label"]), "done")
	if selection.get("type", "") == "room":
		var off: Vector2i = a.get("offset", Vector2i.ZERO)
		selection["tile"] = (selection["tile"] as Vector2i) + off
	changed.emit()


func _rotate(dirn: int) -> void:
	if tool == "garden":
		options["garden_rot"] = posmod(int(options["garden_rot"]) + dirn * 90, 360)
		sfx.play("tick")
		_garden_preview(_hover_world)
		changed.emit()
		return
	if tool == "stairs":
		var order := ["N", "E", "S", "W"]
		options["stairs_dir"] = order[(order.find(options["stairs_dir"]) + dirn + 4) % 4]
		sfx.play("tick")
		_stairs_preview(_hover_world)
		changed.emit()
	elif tool == "select" and selection.get("type", "") == "room":
		if _drag.is_empty() or str(_drag.get("mode", "")) != "move":
			_drag = {"mode": "move", "original": house.data.to_dict(), "offset": Vector2i.ZERO, "turns": 0, "start": _hover_world,
				"screen": Vector2.ZERO, "shift": false, "alt": false, "moved": true, "keyboard": true}
		_drag["turns"] = posmod(int(_drag["turns"]) + dirn, 4)
		_live_move()
		sfx.play("tick")
		if _drag.get("keyboard", false):
			_run_action(_action_for(_hover_world))
			_drag.clear()


func _nudge(key: Key) -> void:
	if selection.get("type", "") != "opening" or house == null:
		return
	var o := house.data.opening_by_id(str(selection["id"]))
	var changes: Dictionary = {}
	if key == KEY_UP or key == KEY_DOWN:
		if o["kind"] != "window":
			return
		changes["sill"] = snappedf(float(o.get("sill", 0.9)) + (0.1 if key == KEY_UP else -0.1), 0.05)
		if float(changes["sill"]) < 0.2:
			return
	else:
		var axis_key := "x" if o["axis"] == "x" else "z"
		changes[axis_key] = float(o[axis_key]) + (0.25 if key == KEY_RIGHT else -0.25)
	var oid := str(selection["id"])
	_commit("Nudge %s" % o["kind"], func(h: HouseData) -> Dictionary: return BuildOps.update_opening(h, oid, changes))


func delete_selection() -> void:
	if house == null or selection.is_empty():
		return
	match str(selection["type"]):
		"opening":
			var oid := str(selection["id"])
			_commit("Remove opening", func(h: HouseData) -> Dictionary: return BuildOps.remove_opening(h, oid))
		"stairs":
			var sid := str(selection["id"])
			_commit("Remove stairs", func(h: HouseData) -> Dictionary: return BuildOps.remove_stairs(h, sid))
		"room":
			var t: Vector2i = selection["tile"]
			var lv := level
			_commit("Clear room", func(h: HouseData) -> Dictionary: return BuildOps.remove_room(h, lv, t))
		"roof":
			var at: Vector2 = selection["at"]
			var lvr := int(selection["level"])
			_commit("Remove roof piece", func(h: HouseData) -> Dictionary:
				var pc := _roof_piece_at(h, lvr, at)
				return BuildOps.remove_roof_piece(h, str(pc.get("id", ""))) if not pc.is_empty() else BuildOps.fail("That roof piece has gone."))
		"verandah":
			var vid := str(selection["id"])
			_commit("Remove verandah", func(h: HouseData) -> Dictionary: return BuildOps.remove_verandah(h, vid))
		"chimney":
			var ci := int(selection["index"])
			_commit("Remove chimney", func(h: HouseData) -> Dictionary: return BuildOps.remove_chimney(h, ci))
		"run":
			var run: Array = selection["run"]
			var lv2 := level
			_commit("Remove wall", func(h: HouseData) -> Dictionary:
				var first := HouseData.edge_points(run[0])
				var last := HouseData.edge_points(run[run.size() - 1])
				return BuildOps.remove_walls(h, lv2, first[0], last[1]))
	selection.clear()
	changed.emit()


## Changes to the selected room or opening from the options panel.
func set_selection_prop(key: String, value: Variant) -> void:
	if house == null or selection.is_empty():
		return
	var lv := level
	match str(selection["type"]):
		"room":
			var t: Vector2i = selection["tile"]
			if key == "height":
				_commit("Change wall height", func(h: HouseData) -> Dictionary: return BuildOps.set_room_height(h, lv, t, float(value)))
			else:
				_commit("Change room", func(h: HouseData) -> Dictionary: return BuildOps.set_room_props(h, lv, t, {key: value}))
		"opening":
			var oid := str(selection["id"])
			_commit("Change %s" % house.data.opening_by_id(oid).get("kind", "opening"), func(h: HouseData) -> Dictionary: return BuildOps.update_opening(h, oid, {key: value}))
	changed.emit()


# --- Doors, windows and arches -----------------------------------------------------------------------

func _opening_template() -> Dictionary:
	var style := str(options["%s_style" % tool]) if tool != "arch" else "arch"
	var piece := Pieces.get_piece(style)
	var kind := tool if tool != "arch" else "arch"
	var o := {"kind": kind, "style": style, "width": float(piece.get("width", 0.9)), "height": float(piece.get("height", 2.05)),
		"swing": "in", "hinge": "start", "lock": false, "keys": [],
		"night": {"latch": options["latch_night"], "curtains": options["curtains_dusk"], "lock": options["lock_night"]}}
	if kind == "window":
		o["sill"] = float(piece.get("sill", 0.9))
	if piece.get("fanlight", false):
		o["fanlight"] = true
	return o


## Where an opening would go for the pointer: on the nearest straight wall, snapped to 0.25 m.
func _opening_at_pointer(p: Vector3, free: bool) -> Dictionary:
	if house == null:
		return {}
	var k := _near_edge(p, house, level, 0.6)
	if k == "" or HouseData.is_diagonal(k):
		return {}
	var o := _opening_template()
	var l := to_local_2d(p)
	var horizontal := k.ends_with(",N")
	var e := HouseData.parse_edge(k)
	var along := (l.x if horizontal else l.y) - float(o["width"]) * 0.5
	along = snappedf(along, 0.01 if free else 0.25)
	if horizontal:
		o["axis"] = "x"
		o["x"] = along
		o["z"] = int(e["y"])
	else:
		o["axis"] = "z"
		o["x"] = int(e["x"])
		o["z"] = along
	return o


func _opening_under(p: Vector3) -> Dictionary:
	var k := _near_edge(p, house, level, 0.5)
	if k == "":
		return {}
	var l := to_local_2d(p)
	for op in house.data.openings_on_edge(level, k):
		var o: Dictionary = op["o"]
		var start := float(o["x"]) if o["axis"] == "x" else float(o["z"])
		var along := l.x if o["axis"] == "x" else l.y
		if along >= start - 0.1 and along <= start + float(o["width"]) + 0.1:
			return o
	return {}


func _opening_preview(p: Vector3, free: bool) -> void:
	var o := _opening_at_pointer(p, free)
	if o.is_empty():
		_show_cursor(p, true)
		return
	var test := house.data.duplicate_house()
	var res := BuildOps.place_opening(test, level, o)
	var kit := MeshKit.new()
	var y := _plane_y()
	var bottom := float(o.get("sill", 0.0)) if o["kind"] == "window" else 0.0
	var h := float(o["height"]) + (0.42 if o.get("fanlight", false) else 0.0)
	var a: Vector2
	var b: Vector2
	if o["axis"] == "x":
		a = Vector2(float(o["x"]), float(o["z"]))
		b = a + Vector2(float(o["width"]), 0)
	else:
		a = Vector2(float(o["x"]), float(o["z"]))
		b = a + Vector2(0, float(o["width"]))
	var lo := y + bottom
	_ghost_box(kit, a, b, lo, lo + h, 0.2)
	_set_preview(kit, res["ok"])
	var piece := Pieces.get_piece(str(o["style"]))
	_show_label(_v3((a + b) * 0.5, lo + h + 0.4), ("%s · £%d" % [piece.get("name", o["style"]), Pieces.cost(str(o["style"]))]) if res["ok"] else str(res["msg"]), res["ok"])


func _opening_action(p: Vector3) -> Dictionary:
	var o: Dictionary = _drag.get("opening", {})
	if o.is_empty():
		o = _opening_at_pointer(p, _drag.get("alt", false))
	if o.is_empty():
		_say("Point at a wall.", "warn")
		return {}
	var lv := level
	var name := str(Pieces.get_piece(str(o["style"])).get("name", o["kind"]))
	return {"label": "Add %s" % name.to_lower(), "confirm": false, "fn": func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, lv, o)}


# --- Floors --------------------------------------------------------------------------------------------

func _floor_tiles(p: Vector3) -> Array[Vector2i]:
	var a := _tile(_drag.get("start", p))
	var b := _tile(p)
	var out: Array[Vector2i] = []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			out.append(Vector2i(x, y))
	return out


func _quarter_at(p: Vector3) -> int:
	var l := to_local_2d(p)
	var f := l - l.floor() - Vector2(0.5, 0.5)
	if absf(f.x) > absf(f.y):
		return HouseData.QE if f.x > 0 else HouseData.QW
	return HouseData.QS if f.y > 0 else HouseData.QN


func _floor_preview(p: Vector3) -> void:
	if house == null:
		_show_cursor(p)
		return
	var tiles := _floor_tiles(p) if not _drag.is_empty() else ([_tile(p)] as Array[Vector2i])
	var kit := MeshKit.new()
	var y := _plane_y() + 0.03
	var quarter := str(options["floor_mode"]) == "quarter"
	for t in tiles:
		if quarter and tiles.size() == 1:
			var c := Vector2(t) + Vector2(0.5, 0.5)
			var corners := [Vector2(t), Vector2(t.x + 1, t.y), Vector2(t) + Vector2(1, 1), Vector2(t.x, t.y + 1)]
			var q := _quarter_at(p)
			kit.tri("f", _v3(corners[q], y), _v3(corners[(q + 1) % 4], y), _v3(c, y), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		else:
			kit.quad("f", _v3(Vector2(t), y), _v3(Vector2(t.x + 1, t.y), y), _v3(Vector2(t) + Vector2(1, 1), y), _v3(Vector2(t.x, t.y + 1), y), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_set_preview(kit, true)
	_show_label(_v3(Vector2(tiles[tiles.size() - 1]) + Vector2(0.5, 0.5), y + 0.8), "%d tile%s · £%d" % [tiles.size(), "" if tiles.size() == 1 else "s", tiles.size() * Pieces.cost(str(options["floor"]))], true)


func _floor_action(p: Vector3) -> Dictionary:
	if house == null:
		_say("Draw a room first.", "warn")
		return {}
	var tiles := _floor_tiles(p)
	var mat := str(options["floor"])
	var rot := int(options["floor_rot"])
	var lv := level
	var quarters: Array = [0, 1, 2, 3]
	if str(options["floor_mode"]) == "quarter" and tiles.size() == 1:
		quarters = [_quarter_at(p)]
	return {"label": "Lay floor", "confirm": tiles.size() > 1, "fn": func(h: HouseData) -> Dictionary: return BuildOps.paint_floor(h, lv, tiles, mat, quarters, rot)}


# --- Paint ------------------------------------------------------------------------------------------

## The surface the Paint tool will apply, from its options.
func surface_from_options() -> Dictionary:
	match str(options["paint_kind"]):
		"wallpaper":
			return {"mat": "wallpaper", "pattern": options["wallpaper"], "colourway": options["colourway"]}
		"cladding":
			return {"mat": options["cladding"], "paint": options["paint_colour"]}
		"lining":
			var lining := {"mat": options["lining"]}
			if options["lining"] != "vj_panelling":
				lining["paint"] = options["paint_colour"]
			return lining
		_:
			return {"mat": "plaster", "paint": options["paint_colour"]}


## The wall face under the pointer: [edge, side], picking the side the pointer is on.
func _face_at(p: Vector3) -> Array:
	if house == null:
		return []
	var k := _near_edge(p, house, level, 0.55)
	if k == "":
		return []
	var pts := HouseData.edge_points(k)
	var mid := (Vector2(pts[0]) + Vector2(pts[1])) * 0.5
	var na3 := HouseMeshBuilder._side_normal3(k)
	var side := "a" if (to_local_2d(p) - mid).dot(Vector2(na3.x, na3.z)) > 0.0 else "b"
	return [k, side]


## Faces a click paints: one face, the room (Shift) or the whole house (Ctrl). Outside, Shift paints
## the storey's outside walls and Ctrl every outside wall.
func _paint_targets(p: Vector3) -> Array:
	var f := _face_at(p)
	if f.is_empty():
		return []
	var scope := str(options["paint_scope"])
	if not _drag.is_empty():
		if _drag.get("ctrl", false):
			scope = "house"
		elif _drag.get("shift", false) and not options["extend"]:
			scope = "room"
	var r := house.data.room_on_side(level, f[0], f[1])
	match scope:
		"room":
			if r.is_empty():
				return BuildOps.exterior_faces(house.data, level)
			return BuildOps.room_faces(house.data, level, r)
		"house":
			if r.is_empty():
				return BuildOps.exterior_faces(house.data)
			return BuildOps.interior_faces(house.data)
	return [f]


func _paint_preview(p: Vector3) -> void:
	if house == null:
		_clear_preview()
		return
	var faces := _paint_targets(p)
	var kit := MeshKit.new()
	for f: Array in faces:
		var lv: int = f[2] if f.size() > 2 else level
		var pts := HouseData.edge_points(f[0])
		var na3 := HouseMeshBuilder._side_normal3(f[0])
		var n := na3 if f[1] == "a" else -na3
		var off := Vector2(n.x, n.z) * 0.1
		var y := house.builder.level_y(lv)
		var hh := house.data.wall_h(lv, f[0])
		_ghost_box(kit, Vector2(pts[0]) + off, Vector2(pts[1]) + off, y, y + hh, 0.03)
	_set_preview(kit, true)
	if not faces.is_empty():
		var what := "Pick up this finish" if options["eyedropper"] else ("%d m of wall" % faces.size())
		_show_label(_pv(_hover_world) + Vector3(0, 1.6, 0), what, true)


func _paint_action(p: Vector3) -> Dictionary:
	if house == null:
		_say("Build a room first.", "warn")
		return {}
	var f := _face_at(p)
	if f.is_empty():
		_say("Point at a wall.", "warn")
		return {}
	if options["eyedropper"]:
		var picked := BuildOps.pick_surface(house.data, level, f[0], f[1])
		_apply_picked(picked)
		return {}
	var faces := _paint_targets(p)
	var surface := surface_from_options()
	var part := str(options["paint_part"])
	var lv := level
	if part == "dado":
		surface["h"] = float(options["dado_h"])
		if str(options["paint_kind"]) not in ["lining", "paint"]:
			surface = {"mat": options["lining"], "h": float(options["dado_h"])}
	var label := "Paint %d m of wall" % faces.size() if faces.size() > 1 else "Paint a wall"
	return {"label": label, "confirm": faces.size() > 1, "fn": func(h: HouseData) -> Dictionary: return BuildOps.paint_faces(h, lv, faces, surface, part)}


func _apply_picked(s: Dictionary) -> void:
	var mat := str(s.get("mat", "plaster"))
	if mat == "wallpaper":
		options["paint_kind"] = "wallpaper"
		options["wallpaper"] = s.get("pattern", "floral")
		options["colourway"] = s.get("colourway", "")
	elif MaterialLibrary.def(mat).get("category", "") == "cladding":
		options["paint_kind"] = "cladding"
		options["cladding"] = mat
	elif mat in ["wall_tiles", "vj_panelling"]:
		options["paint_kind"] = "lining"
		options["lining"] = mat
	else:
		options["paint_kind"] = "paint"
	if s.has("paint"):
		options["paint_colour"] = s["paint"]
	options["eyedropper"] = false
	sfx.play("click")
	_say("Picked up %s." % _surface_name(s), "done")
	changed.emit()


func _surface_name(s: Dictionary) -> String:
	if str(s.get("mat", "")) == "wallpaper":
		var p: Dictionary = (MaterialLibrary.palettes()["wallpapers"] as Dictionary).get(s.get("pattern", ""), {})
		return "%s wallpaper" % str(p.get("name", "patterned")).to_lower()
	var paint := str(s.get("paint", ""))
	return "%s %s" % [paint.replace("_", " "), str(s.get("mat", "paint")).replace("_", " ")]


# --- Stairs and posts ------------------------------------------------------------------------------------

func _stairs_def(p: Vector3) -> Dictionary:
	var t := _tile(p)
	return {"kind": options["stairs_kind"], "x": t.x, "y": t.y, "dir": options["stairs_dir"], "turn": "right"}


func _stairs_preview(p: Vector3) -> void:
	if house == null:
		_show_cursor(p)
		return
	var st := _stairs_def(p)
	var test := house.data.duplicate_house()
	var res := BuildOps.add_stairs(test, level, st)
	var info := house.data.stair_tiles(st, level)
	var kit := MeshKit.new()
	var y := _plane_y()
	var lower: Array = info["lower"]
	for i in lower.size():
		var t: Vector2i = lower[i]
		var hgt := 0.15 + 2.6 * float(i + 1) / lower.size()
		_ghost_box(kit, Vector2(t) + Vector2(0.05, 0.05), Vector2(t) + Vector2(0.95, 0.95), y, y + hgt, -1.0)
	var arr: Vector2i = info["arrival"]
	_ghost_box(kit, Vector2(arr) + Vector2(0.3, 0.3), Vector2(arr) + Vector2(0.7, 0.7), y + 3.0, y + 3.05, -1.0)
	_set_preview(kit, res["ok"])
	var name := str(Pieces.get_piece("stairs_" + str(st["kind"])).get("name", "Stairs"))
	_show_label(_v3(Vector2(lower[0]) + Vector2(0.5, 0.5), y + 3.4), ("%s, up to the %s · £%d" % [name, HouseData.storey_name(level + 1).to_lower(), Pieces.cost("stairs_" + str(st["kind"]))]) if res["ok"] else str(res["msg"]), res["ok"])


func _post_preview(p: Vector3) -> void:
	if house == null:
		_show_cursor(p)
		return
	var c := _corner(p)
	var kit := MeshKit.new()
	var y := _plane_y()
	_ghost_box(kit, Vector2(c) - Vector2(0.08, 0.08), Vector2(c) + Vector2(0.08, 0.08), y, y + house.data.storey_height(level), -1.0)
	_set_preview(kit, true)
	_show_label(_v3(Vector2(c), y + house.data.storey_height(level) + 0.4), "%s · £%d" % [Pieces.get_piece(str(options["post_kind"])).get("name", "Post"), Pieces.cost(str(options["post_kind"]))], true)


# --- Demolish ------------------------------------------------------------------------------------------

func _demolish_preview(p: Vector3) -> void:
	if house == null:
		_clear_preview()
		return
	var kit := MeshKit.new()
	var y := _plane_y()
	var text := ""
	if not _drag.is_empty() and _drag.has("wall_from"):
		var a: Vector2i = _drag["wall_from"]
		var b := _wall_end(p)
		_ghost_wall(kit, Vector2(a), Vector2(b), y, 2.8)
		text = "Remove walls"
	else:
		var op := _opening_under(p)
		if not op.is_empty():
			var oa := Vector2(float(op["x"]), float(op["z"]))
			var ob := oa + (Vector2(float(op["width"]), 0) if op["axis"] == "x" else Vector2(0, float(op["width"])))
			_ghost_box(kit, oa, ob, y, y + 2.2, 0.25)
			text = "Remove %s" % op["kind"]
		else:
			var k := _near_edge(p, house, level)
			if k != "":
				var pts := HouseData.edge_points(k)
				_ghost_wall(kit, Vector2(pts[0]), Vector2(pts[1]), y, 2.8)
				text = "Drag along to remove walls"
			else:
				var r := house.data.room_at_tile(level, _tile(p))
				if not r.is_empty():
					for t: Vector2i in r["tiles"]:
						kit.quad("f", _v3(Vector2(t), y + 0.03), _v3(Vector2(t.x + 1, t.y), y + 0.03), _v3(Vector2(t) + Vector2(1, 1), y + 0.03), _v3(Vector2(t.x, t.y + 1), y + 0.03), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
					text = "Clear the %s" % house.data.room_name(r).to_lower()
	_set_preview(kit, false)
	if text != "":
		_show_label(_pv(_hover_world) + Vector3(0, 1.5, 0), text, false)
	else:
		_label.visible = false


func _demolish_action(p: Vector3) -> Dictionary:
	var lv := level
	if _drag.get("moved", false):
		var a := _corner(_drag["start"])
		var b := _wall_end(p)
		if a != b:
			return {"label": "Remove walls", "confirm": true, "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_walls(h, lv, a, b)}
	var op := _opening_under(p)
	if not op.is_empty():
		var oid := str(op["id"])
		return {"label": "Remove %s" % op["kind"], "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_opening(h, oid)}
	var lp := to_local_2d(p)
	var gi := GardenOps.item_at(house.data, lp)
	if not gi.is_empty():
		var gid := str(gi["id"])
		return {"label": "Remove %s" % str(GardenOps.item_def(str(gi["kind"])).get("name", "item")).to_lower(), "fn": func(h: HouseData) -> Dictionary: return GardenOps.remove_item(h, gid)}
	var fk := GardenOps.fence_at(house.data, lp, 0.25)
	if fk != "" and _near_edge(p, house, lv) == "":
		var fpts := HouseData.edge_points(fk)
		return {"label": "Remove fence", "fn": func(h: HouseData) -> Dictionary: return GardenOps.remove_fence(h, fpts[0], fpts[1])}
	var ci := BuildOps.chimney_at(house.data, lp.x, lp.y)
	if ci >= 0:
		return {"label": "Remove chimney", "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_chimney(h, ci)}
	var c := _corner(p)
	for col: Dictionary in house.data.storey(lv).get("columns", []):
		if Vector2i(int(col["x"]), int(col["y"])) == c and to_local_2d(p).distance_to(Vector2(c)) < 0.3:
			return {"label": "Remove post", "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_column(h, lv, c)}
	var t := _tile(p)
	for st: Dictionary in house.data.stairs(lv):
		if (house.data.stair_tiles(st, lv)["lower"] as Array).has(t):
			var sid := str(st["id"])
			return {"label": "Remove stairs", "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_stairs(h, sid)}
	var k := _near_edge(p, house, lv)
	if k != "":
		var pts := HouseData.edge_points(k)
		return {"label": "Remove wall", "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_walls(h, lv, pts[0], pts[1])}
	if not house.data.room_at_tile(lv, t).is_empty():
		return {"label": "Clear room", "confirm": true, "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_room(h, lv, t)}
	if house.data.floors(lv).has(HouseData.tile_key(t.x, t.y)):
		return {"label": "Lift floor", "fn": func(h: HouseData) -> Dictionary: return BuildOps.remove_floor(h, lv, [t] as Array[Vector2i])}
	return {}


# --- Roofs ---------------------------------------------------------------------------------------------

func roof_settings() -> Dictionary:
	return {"shape": options["roof_shape"], "pitch": float(options["roof_pitch"]), "overhang": float(options["roof_overhang"]),
		"material": options["roof_material"]}


## Roofs the whole edited house from the plan with the current settings.
func roof_house() -> void:
	var s := roof_settings()
	_commit("Roof the house", func(h: HouseData) -> Dictionary: return BuildOps.auto_roof(h, s))


func take_roof_off() -> void:
	selection.clear()
	_commit("Take the roof off", func(h: HouseData) -> Dictionary: return BuildOps.remove_roof(h))


## The piece of h on a storey covering a plan point (topmost if pieces overlap).
func _roof_piece_at(h: HouseData, lv: int, at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_y := -INF
	for pc: Dictionary in Roofs.pieces(h):
		if int(pc.get("level", 0)) != lv:
			continue
		var y := Roofs.surface_y(pc, Roofs.eave_y(h, pc), at.x, at.y)
		if not is_nan(y) and y > best_y:
			best_y = y
			best = pc
	return best


## The selected roof piece, or {}.
func selected_roof() -> Dictionary:
	if house == null or selection.get("type", "") != "roof":
		return {}
	return _roof_piece_at(house.data, int(selection["level"]), selection["at"])


## The roof under the pointer: {hv, piece, point (house-local)} by marching the camera ray.
func _roof_hit(screen: Vector2) -> Dictionary:
	var cam := rig.camera
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var best: Dictionary = {}
	for hv: HouseView in world.get("houses") as Array:
		var pcs := Roofs.pieces(hv.data)
		if pcs.is_empty() or hv.data.locked:
			continue
		var eaves: Array[float] = []
		var top := -INF
		var bottom := INF
		for pc: Dictionary in pcs:
			var ey := Roofs.eave_y(hv.data, pc)
			eaves.append(ey)
			top = maxf(top, Roofs.ridge_y(pc, ey) + 0.1)
			bottom = minf(bottom, ey - 1.0)
		var lo := o - hv.position
		if absf(d.y) < 0.0001:
			continue
		var t0 := maxf(0.0, (top - lo.y) / d.y)
		var t1 := (bottom - lo.y) / d.y
		if t1 < t0:
			continue
		var t := t0
		while t <= t1:
			var q := lo + d * t
			for i in pcs.size():
				var y := Roofs.surface_y(pcs[i], eaves[i], q.x, q.z)
				if not is_nan(y) and q.y <= y:
					if best.is_empty() or t < float(best["t"]):
						best = {"hv": hv, "piece": pcs[i], "point": Vector3(q.x, y, q.z), "t": t}
					t = t1 + 1.0
					break
			t += 0.12
	return best


func _roof_press(screen: Vector2) -> void:
	if str(options["roof_mode"]) != "edit":
		return
	var hit := _roof_hit(screen)
	if hit.is_empty():
		var p := pick(screen)
		var hv := _house_at(p)
		if hv != null:
			var ci := BuildOps.chimney_at(hv.data, to_local_2d(p, hv).x, to_local_2d(p, hv).y)
			if ci >= 0:
				house = hv
				selection = {"type": "chimney", "index": ci}
				changed.emit()
				return
		selection.clear()
		changed.emit()
		return
	house = hit["hv"]
	var pc: Dictionary = hit["piece"]
	var pt: Vector3 = hit["point"]
	selection = {"type": "roof", "at": Vector2(pt.x, pt.z), "level": int(pc.get("level", 0))}
	_drag["roof"] = pc.duplicate(true)
	_drag["roof_y"] = pt.y
	# Near an edge: resize that side. Elsewhere: drag up and down to change the pitch.
	var r := Roofs.rect_of(pc)
	var l := Vector2(pt.x, pt.z)
	var dists := {"W": absf(l.x - r.position.x), "E": absf(l.x - r.end.x), "N": absf(l.y - r.position.y), "S": absf(l.y - r.end.y)}
	var side := ""
	var near := 0.7
	for sd: String in dists:
		if float(dists[sd]) < near:
			near = dists[sd]
			side = sd
	_drag["roof_side"] = side
	changed.emit()


## A plan point on the horizontal plane at height y (house-local), under the pointer.
func _pick_at_height(screen: Vector2, y: float) -> Vector2:
	var cam := rig.camera
	var o := cam.project_ray_origin(screen) - house.position
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector2(o.x, o.z)
	var q := o + d * ((y - o.y) / d.y)
	return Vector2(q.x, q.z)


## The piece being drawn or dragged, as it would be on release.
func _roof_candidate(screen: Vector2, p: Vector3) -> Dictionary:
	match str(options["roof_mode"]):
		"draw":
			if _drag.is_empty() or house == null:
				return {}
			var a := to_local_2d(_drag["start"])
			var b := to_local_2d(p)
			var lo := Vector2(snappedf(minf(a.x, b.x), 0.5), snappedf(minf(a.y, b.y), 0.5))
			var hi := Vector2(snappedf(maxf(a.x, b.x), 0.5), snappedf(maxf(a.y, b.y), 0.5))
			var r := Rect2(lo, hi - lo)
			var pc := roof_settings()
			pc["level"] = level
			pc["rect"] = [r.position.x, r.position.y, r.size.x, r.size.y]
			pc["axis"] = "x" if r.size.x >= r.size.y else "z"
			pc["high"] = "N" if r.size.x >= r.size.y else "W"
			pc["joins"] = []
			return pc
		"edit":
			if not _drag.has("roof"):
				return {}
			var pc2: Dictionary = (_drag["roof"] as Dictionary).duplicate(true)
			var side := str(_drag["roof_side"])
			var sy := (_drag["screen"] as Vector2).y
			if side == "":
				var steps := roundi((sy - screen.y) / 12.0)
				pc2["pitch"] = Roofs.clamp_pitch(str(pc2["shape"]), float(pc2["pitch"]) + steps * 1.0)
			else:
				var ey := Roofs.eave_y(house.data, pc2)
				var l := _pick_at_height(screen, ey)
				var r2 := Roofs.rect_of(pc2)
				match side:
					"W":
						var x0 := minf(snappedf(l.x, 0.5), r2.end.x - 1.0)
						r2 = Rect2(x0, r2.position.y, r2.end.x - x0, r2.size.y)
					"E":
						r2.size.x = maxf(snappedf(l.x, 0.5) - r2.position.x, 1.0)
					"N":
						var z0 := minf(snappedf(l.y, 0.5), r2.end.y - 1.0)
						r2 = Rect2(r2.position.x, z0, r2.size.x, r2.end.y - z0)
					"S":
						r2.size.y = maxf(snappedf(l.y, 0.5) - r2.position.y, 1.0)
				pc2["rect"] = [r2.position.x, r2.position.y, r2.size.x, r2.size.y]
			return pc2
	return {}


func _roof_ghost(kit: MeshKit, pc: Dictionary) -> void:
	var g := Roofs.geometry(pc, Roofs.eave_y(house.data, pc))
	for f: Dictionary in g["roof"]:
		var pts: Array = f["pts"]
		for i in range(1, pts.size() - 1):
			kit.tri("g", pts[0], pts[i], pts[i + 1], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	for f2: Dictionary in g["gable"]:
		var pts2: Array = f2["pts"]
		for i2 in range(1, pts2.size() - 1):
			kit.tri("g", pts2[0], pts2[i2], pts2[i2 + 1], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)


func _roof_preview(screen: Vector2, p: Vector3) -> void:
	var mode := str(options["roof_mode"])
	if mode == "chimney":
		var k := _near_edge(p, house, level, 0.5)
		if k == "" or HouseData.is_diagonal(k):
			_clear_preview()
			return
		var kit0 := MeshKit.new()
		var pts := HouseData.edge_points(k)
		var y0 := _plane_y()
		var mid := Vector2(pts[0] + pts[1]) * 0.5
		var along := Vector2(pts[1] - pts[0]).normalized()
		_ghost_box(kit0, mid - along * 0.6, mid + along * 0.6, y0, y0 + house.data.storey_height(level) + 1.6, 0.6)
		_set_preview(kit0, true)
		_show_label(_v3(mid, y0 + 3.2), "Brick chimney · £%d" % Pieces.cost("chimney"), true)
		return
	if mode == "auto":
		var hv := _house_at(p)
		if hv == null:
			_clear_preview()
			return
		_label.visible = false
		_preview.mesh = null
		_show_label(_pv(p) + Vector3(0, 1.0, 0), "Click to roof the house · %s" % Roofs.SHAPE_NAMES[options["roof_shape"]], true)
		return
	var pc := _roof_candidate(screen, p)
	if pc.is_empty():
		if mode == "edit" and _drag.is_empty():
			var hit := _roof_hit(screen)
			if not hit.is_empty() and hit["hv"] == house:
				var kit1 := MeshKit.new()
				_roof_ghost(kit1, hit["piece"])
				_set_preview(kit1, true)
				var hp: Vector3 = hit["point"]
				_show_label(hp + Vector3(0, 0.8, 0), "Drag up or down for pitch · drag an edge to resize", true)
				return
		_clear_preview()
		return
	var kit := MeshKit.new()
	_roof_ghost(kit, pc)
	_set_preview(kit, true)
	var r := Roofs.rect_of(pc)
	var top := Roofs.ridge_y(pc, Roofs.eave_y(house.data, pc))
	var text := "%s · %.0f° · %.1f × %.1f m · £%d" % [Roofs.SHAPE_NAMES.get(pc["shape"], pc["shape"]), float(pc["pitch"]), r.size.x, r.size.y, Roofs.cost(pc)]
	_show_label(Vector3(r.get_center().x, top + 0.8, r.get_center().y), text, true)


func _roof_action(p: Vector3) -> Dictionary:
	var mode := str(options["roof_mode"])
	match mode:
		"auto":
			var hv := _house_at(p)
			if hv == null:
				return {}
			house = hv
			var s := roof_settings()
			return {"label": "Roof the house", "fn": func(h: HouseData) -> Dictionary: return BuildOps.auto_roof(h, s)}
		"chimney":
			var k := _near_edge(p, house, level, 0.5)
			if k == "":
				_say("Point at a wall for the chimney.", "warn")
				return {}
			var lv := level
			return {"label": "Add chimney", "fn": func(h: HouseData) -> Dictionary: return BuildOps.add_chimney(h, lv, k)}
		"draw":
			var pc := _roof_candidate(_drag.get("last_screen", Vector2.ZERO), p)
			if pc.is_empty() or not _drag.get("moved", false):
				return {}
			var r := Roofs.rect_of(pc)
			var lv2 := level
			var opts := roof_settings()
			return {"label": "Add roof piece", "confirm": true, "fn": func(h: HouseData) -> Dictionary: return BuildOps.add_roof_piece(h, lv2, r, opts)}
		"edit":
			if not _drag.has("roof") or not _drag.get("moved", false):
				return {}
			var pc2 := _roof_candidate(_drag.get("last_screen", Vector2.ZERO), p)
			var orig: Dictionary = _drag["roof"]
			var at: Vector2 = selection["at"]
			var lv3 := int(orig.get("level", 0))
			var changes := {"pitch": pc2["pitch"], "rect": pc2["rect"]}
			var label := "Change roof pitch" if str(_drag["roof_side"]) == "" else "Resize roof"
			var r3 := Roofs.rect_of(pc2)
			selection["at"] = r3.get_center() if not r3.has_point(at) else at
			return {"label": label, "fn": func(h: HouseData) -> Dictionary:
				var cur := _roof_piece_at(h, lv3, at)
				if cur.is_empty():
					return BuildOps.fail("That roof piece has gone.")
				return BuildOps.update_roof_piece(h, str(cur["id"]), changes)}
	return {}


## Changes to the selected roof piece from the options panel (shape, pitch, overhang, material,
## turn = swap the ridge or move the high side round).
func set_roof_prop(key: String, value: Variant) -> void:
	var pc := selected_roof()
	if pc.is_empty():
		return
	var at: Vector2 = selection["at"]
	var lv := int(selection["level"])
	var changes: Dictionary = {}
	if key == "turn":
		if Roofs.is_mono(pc):
			var order := ["N", "E", "S", "W"]
			changes["high"] = order[(order.find(str(pc.get("high", "N"))) + 1) % 4]
		else:
			changes["axis"] = "z" if str(pc.get("axis", "x")) == "x" else "x"
	else:
		changes[key] = value
	_commit("Change roof", func(h: HouseData) -> Dictionary:
		var cur := _roof_piece_at(h, lv, at)
		if cur.is_empty():
			return BuildOps.fail("That roof piece has gone.")
		return BuildOps.update_roof_piece(h, str(cur["id"]), changes))
	changed.emit()


# --- Verandahs -----------------------------------------------------------------------------------------

func verandah_opts() -> Dictionary:
	return {"depth": float(options["v_depth"]), "shape": options["v_shape"], "post": options["v_post"], "lace": options["v_lace"],
		"rail": options["v_rail"], "lattice": bool(options["v_lattice"]), "material": options["v_material"], "colour": options["v_colour"]}


func selected_verandah() -> Dictionary:
	if house == null or selection.get("type", "") != "verandah":
		return {}
	return BuildOps.verandah_by_id(house.data, str(selection["id"]))


## Position along a verandah's wall line for a plan point.
func _v_along(v: Dictionary, l: Vector2) -> float:
	return l.x if str(v["side"]) in ["N", "S"] else l.y


## The verandah a drag would add: the whole outside run under the pointer, or the dragged part of it.
func _verandah_plan(p: Vector3) -> Dictionary:
	if house == null:
		return {}
	var start: Vector3 = _drag.get("start", p)
	var k := _near_edge(start, house, level, 0.6)
	if k == "":
		return {}
	var run := BuildOps.outside_run(house.data, level, k)
	if run.is_empty():
		return {}
	var v := verandah_opts()
	v.merge(run, true)
	if _drag.get("moved", false):
		var a := _v_along(run, to_local_2d(start))
		var b := _v_along(run, to_local_2d(p))
		v["from"] = clampf(snappedf(minf(a, b), 0.5), float(run["from"]), float(run["to"]))
		v["to"] = clampf(snappedf(maxf(a, b), 0.5), float(run["from"]), float(run["to"]))
	return v


func _verandah_press(p: Vector3) -> void:
	if house == null:
		return
	if str(options["v_mode"]) == "edit":
		var l := to_local_2d(p)
		var v := BuildOps.verandah_at(house.data, l.x, l.y)
		if v.is_empty():
			selection.clear()
		else:
			selection = {"type": "verandah", "id": v["id"]}
		changed.emit()


func _verandah_preview(p: Vector3) -> void:
	if house == null:
		_clear_preview()
		return
	var kit := MeshKit.new()
	var y := _plane_y()
	var l := to_local_2d(p)
	match str(options["v_mode"]):
		"add":
			var v := _verandah_plan(p)
			if v.is_empty():
				_clear_preview()
				return
			var r := BuildOps.verandah_rect(house.data, v)
			_ghost_box(kit, r.position, r.end, y - 0.1, y, -1.0)
			_ghost_box(kit, r.position, r.end, y + 2.2, y + 2.3, -1.0)
			_set_preview(kit, true)
			var length := float(v["to"]) - float(v["from"])
			var cost := ceili(length * float(v["depth"]) * Pieces.cost("verandah"))
			_show_label(_v3(r.get_center(), y + 2.8), "%s verandah · %.1f × %.1f m · £%d" % [str(v["shape"]).capitalize(), length, float(v["depth"]), cost], true)
		_:
			var vv := BuildOps.verandah_at(house.data, l.x, l.y)
			if vv.is_empty():
				_clear_preview()
				return
			var r2 := BuildOps.verandah_rect(house.data, vv)
			var text := {"edit": "Change this verandah", "steps": "Add or remove steps here", "sleepout": "Drag along to enclose a sleep-out"}[str(options["v_mode"])] as String
			if str(options["v_mode"]) == "sleepout" and not _drag.is_empty() and _drag.get("moved", false):
				var a := _v_along(vv, to_local_2d(_drag["start"]))
				var b := _v_along(vv, l)
				var rr := BuildOps.sleepout_rect(vv, roundf(minf(a, b)), roundf(maxf(a, b)))
				_ghost_box(kit, Vector2(rr.position), Vector2(rr.end), y, y + 2.4, -1.0)
				text = "Sleep-out · %d m" % maxi(rr.size.x, rr.size.y)
			else:
				_ghost_box(kit, r2.position, r2.end, y - 0.1, y + 0.02, -1.0)
			_set_preview(kit, true)
			_show_label(_v3(l, y + 1.6), text, true)


func _verandah_action(p: Vector3) -> Dictionary:
	if house == null:
		_say("Build a house first.", "warn")
		return {}
	var l := to_local_2d(p)
	match str(options["v_mode"]):
		"add":
			var v := _verandah_plan(p)
			if v.is_empty():
				_say("Point at an outside wall.", "warn")
				return {}
			var lv := level
			var opts := verandah_opts()
			return {"label": "Add verandah", "confirm": true, "fn": func(h: HouseData) -> Dictionary:
				return BuildOps.add_verandah(h, lv, v["side"], v["line"], v["from"], v["to"], opts)}
		"steps":
			var vs := BuildOps.verandah_at(house.data, l.x, l.y)
			if vs.is_empty():
				return {}
			var vid := str(vs["id"])
			var u := _v_along(vs, l)
			return {"label": "Verandah steps", "fn": func(h: HouseData) -> Dictionary: return BuildOps.toggle_steps(h, vid, u)}
		"sleepout":
			var start := to_local_2d(_drag.get("start", p))
			var vz := BuildOps.verandah_at(house.data, start.x, start.y)
			if vz.is_empty():
				return {}
			var vid2 := str(vz["id"])
			var a := _v_along(vz, start)
			var b := _v_along(vz, l)
			if not _drag.get("moved", false):
				a = float(vz["from"])
				b = float(vz["to"])
			return {"label": "Enclose sleep-out", "confirm": true, "fn": func(h: HouseData) -> Dictionary: return BuildOps.enclose_sleepout(h, vid2, a, b)}
	return {}


func remove_sleepout() -> void:
	var v := selected_verandah()
	if v.is_empty():
		return
	var vid := str(v["id"])
	_commit("Open up the sleep-out", func(h: HouseData) -> Dictionary: return BuildOps.remove_sleepout(h, vid))


## House trim colour (fascias, sashes, corner boards, barges).
func set_trim(colour: String) -> void:
	_commit("Trim colour", func(h: HouseData) -> Dictionary: return BuildOps.set_exterior(h, {"trim": colour}))


# --- Placing designs ------------------------------------------------------------------------------------

## Starts placing a design from the library or a share code: it follows the pointer until clicked.
func start_placing(h: HouseData, label: String) -> void:
	_cancel()
	selection.clear()
	placing = h
	placing_name = label if label != "" else (h.name if h.name != "" else "the design")
	house = null
	level = 0
	_apply_view()
	_say("Click where %s should go. Esc cancels." % placing_name, "hint")
	changed.emit()


func cancel_placing() -> void:
	placing = null
	_clear_preview()
	_say(HINTS.get(tool, ""), "hint")
	changed.emit()


func _place_origin(p: Vector3) -> Vector2i:
	var b := placing.bounds()
	return Vector2i(roundi(p.x), roundi(p.z)) - (b.position + b.size / 2)


func _place_preview(p: Vector3) -> void:
	var b := placing.bounds()
	var o := _place_origin(p)
	var rect := Rect2i(o + b.position, b.size)
	var check := _world_check(rect)
	var grid: WorldGrid = world.get("slice").grid
	var y := grid.height_at(rect.get_center().x, rect.get_center().y)
	var kit := MeshKit.new()
	_ghost_box(kit, Vector2(rect.position), Vector2(rect.end), y, y + 3.2, -1.0)
	var lot := Rect2(rect).grow(0.0)
	for e: Array in [[lot.position, Vector2(lot.end.x, lot.position.y)], [Vector2(lot.end.x, lot.position.y), lot.end], [lot.end, Vector2(lot.position.x, lot.end.y)], [Vector2(lot.position.x, lot.end.y), lot.position]]:
		_ghost_wall(kit, e[0], e[1], y, 0.1)
	_set_preview(kit, check == "")
	var cost := ShareCode.estimate_cost(placing)
	var text := check if check != "" else ("Place %s%s" % [placing_name, "" if GameState.is_sandbox() else " · about £%d" % cost])
	_show_label(Vector3(rect.get_center().x, y + 4.0, rect.get_center().y), text, check == "")


func _place_action(p: Vector3) -> Dictionary:
	var b := placing.bounds()
	var o := _place_origin(p)
	var check := _world_check(Rect2i(o + b.position, b.size))
	if check != "":
		_say(check, "warn")
		sfx.play("error")
		return {}
	var design := placing
	var cost := ShareCode.estimate_cost(design)
	return {"label": "Place %s" % placing_name, "confirm": true, "new_house": true, "origin": o, "fn": func(h: HouseData) -> Dictionary:
		ShareCode.apply_to(h, design)
		return BuildOps.ok(cost)}


# --- Terrain, garden and fences ------------------------------------------------------------------------

## Ground height at a lot corner, relative to the house's base (the house's own edits first).
static func _corner_height(h: HouseData, grid: WorldGrid, cx: int, cy: int) -> float:
	var key := HouseData.tile_key(cx, cy)
	if h.terrain.has(key):
		return float(h.terrain[key])
	return grid.corner_height(cx + h.origin.x, cy + h.origin.y) - h.base_y


func _ring(kit: MeshKit, centre: Vector2, radius: float) -> void:
	var grid: WorldGrid = world.get("slice").grid
	var origin := house.position
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		var p0 := centre + Vector2(cos(a0), sin(a0)) * radius
		var p1 := centre + Vector2(cos(a1), sin(a1)) * radius
		var y0 := grid.height_at(p0.x + origin.x, p0.y + origin.z) - origin.y + 0.06
		var y1 := grid.height_at(p1.x + origin.x, p1.y + origin.z) - origin.y + 0.06
		kit.beam("g", Vector3(p0.x, y0, p0.y), Vector3(p1.x, y1, p1.y), 0.06, 0.04)


func _ground_y(l: Vector2) -> float:
	var grid: WorldGrid = world.get("slice").grid
	return grid.height_at(l.x + house.position.x, l.y + house.position.z) - house.position.y


func _terrain_preview(p: Vector3) -> void:
	if house == null:
		_clear_preview()
		return
	var kit := MeshKit.new()
	var l := to_local_2d(p)
	if str(options["terrain_op"]) == "paint":
		var tiles := _floor_tiles(p) if not _drag.is_empty() else ([_tile(p)] as Array[Vector2i])
		for t in tiles:
			var c := Vector2(t) + Vector2(0.5, 0.5)
			var y := _ground_y(c) + 0.05
			kit.quad("f", _v3(Vector2(t), y), _v3(Vector2(t.x + 1, t.y), y), _v3(Vector2(t) + Vector2(1, 1), y), _v3(Vector2(t.x, t.y + 1), y), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		_set_preview(kit, true)
		var gname := str((GardenOps.catalogue()["grounds"] as Dictionary)[options["ground"]]["name"])
		_show_label(_v3(l, _ground_y(l) + 1.0), "%s · %d m²" % [gname, tiles.size()], true)
		return
	_ring(kit, l, float(options["terrain_radius"]))
	_set_preview(kit, GardenOps.in_lot(house.data, l))
	_show_label(_v3(l, _ground_y(l) + 1.2), {"raise": "Raise", "lower": "Lower", "flatten": "Flatten", "smooth": "Smooth"}[options["terrain_op"]], GardenOps.in_lot(house.data, l))
	if not _drag.is_empty():
		var pts: Array = _drag.get("brush", [])
		if pts.is_empty() or (pts[pts.size() - 1] as Vector2).distance_to(l) > float(options["terrain_radius"]) * 0.6:
			pts.append(l)
			_drag["brush"] = pts


func _terrain_action(p: Vector3) -> Dictionary:
	if house == null:
		_say("Landscaping goes round a house. Build one first.", "warn")
		return {}
	var op := str(options["terrain_op"])
	if op == "paint":
		var tiles := _floor_tiles(p)
		var gname := str(options["ground"])
		return {"label": "Lay %s" % str((GardenOps.catalogue()["grounds"] as Dictionary)[gname]["name"]).to_lower(),
			"fn": func(h: HouseData) -> Dictionary: return GardenOps.paint_ground(h, tiles, gname)}
	var pts: Array = _drag.get("brush", [])
	if pts.is_empty():
		pts = [to_local_2d(p)]
	var radius := float(options["terrain_radius"])
	var grid: WorldGrid = world.get("slice").grid
	return {"label": "%s the ground" % op.capitalize(), "fn": func(h: HouseData) -> Dictionary:
		var total := 0
		var any_ok := false
		var last := {}
		var target := float(_corner_height(h, grid, roundi((pts[0] as Vector2).x), roundi((pts[0] as Vector2).y)))
		for q: Vector2 in pts:
			var hf := func(cx: int, cy: int) -> float: return _corner_height(h, grid, cx, cy)
			if op == "flatten":
				# A flatten stroke holds the height where it started.
				hf = func(cx: int, cy: int) -> float:
					if cx == roundi(q.x) and cy == roundi(q.y):
						return target
					return _corner_height(h, grid, cx, cy)
			last = GardenOps.terrain_brush(h, op, q, radius, hf)
			if last["ok"]:
				any_ok = true
				total += int(last["cost"])
		return BuildOps.ok(total) if any_ok else last}


func garden_def() -> Dictionary:
	return GardenOps.item_def(str(options["garden_kind"]))


func _garden_preview(p: Vector3) -> void:
	if house == null:
		_clear_preview()
		return
	var l := to_local_2d(p)
	var it := {"kind": options["garden_kind"], "x": snappedf(l.x, 0.25), "z": snappedf(l.y, 0.25), "rot": float(options["garden_rot"])}
	var r := GardenOps.item_rect(it)
	var d := garden_def()
	var ht := float(d.get("height", 2.2))
	var y := _ground_y(r.get_center())
	var kit := MeshKit.new()
	_ghost_box(kit, r.position, r.end, y, y + ht, -1.0)
	var msg := GardenOps._item_check(house.data, it, "")
	_set_preview(kit, msg == "")
	_show_label(_v3(r.get_center(), y + ht + 0.6), ("%s · £%d" % [d.get("name", ""), int(d.get("cost", 1))]) if msg == "" else msg, msg == "")


func _garden_action(p: Vector3) -> Dictionary:
	if house == null:
		_say("Gardens go round a house. Build one first.", "warn")
		return {}
	var l := to_local_2d(p)
	var kind := str(options["garden_kind"])
	var rot := float(options["garden_rot"])
	return {"label": "Add %s" % str(garden_def().get("name", kind)).to_lower(), "fn": func(h: HouseData) -> Dictionary: return GardenOps.place_item(h, kind, l, rot)}


## The fence run a drag makes: from the start corner along the dominant axis.
func _fence_run(p: Vector3) -> Array[Vector2i]:
	var a := _corner(_drag.get("start", p))
	var b := _corner(p)
	if absi(b.x - a.x) >= absi(b.y - a.y):
		b.y = a.y
	else:
		b.x = a.x
	return [a, b]


func _fence_preview(p: Vector3) -> void:
	if house == null:
		_clear_preview()
		return
	var kit := MeshKit.new()
	var l := to_local_2d(p)
	var mode := str(options["fence_mode"])
	if mode == "gate":
		var k := GardenOps.fence_at(house.data, l)
		if k == "":
			_show_cursor(p, true)
			return
		var pts := HouseData.edge_points(k)
		var y := _ground_y(Vector2(pts[0]))
		_ghost_wall(kit, Vector2(pts[0]), Vector2(pts[1]), y, 1.2)
		_set_preview(kit, true)
		_show_label(_v3(Vector2(pts[0] + pts[1]) * 0.5, y + 1.8), "Gate", true)
		return
	if _drag.is_empty():
		_show_cursor(p, true)
		return
	var run := _fence_run(p)
	var y2 := _ground_y(Vector2(run[0]))
	var h := float((GardenOps.catalogue()["fences"] as Dictionary)[options["fence_type"]]["height"])
	_ghost_wall(kit, Vector2(run[0]), Vector2(run[1]), y2, h)
	_set_preview(kit, mode == "build")
	var n := absi(run[1].x - run[0].x) + absi(run[1].y - run[0].y)
	_show_label(_v3(Vector2(run[0] + run[1]) * 0.5, y2 + h + 0.6), ("%d m · £%d" % [n, n]) if mode == "build" else "Remove %d m" % n, mode == "build")


func _fence_action(p: Vector3) -> Dictionary:
	if house == null:
		_say("Fences go round a house. Build one first.", "warn")
		return {}
	var mode := str(options["fence_mode"])
	if mode == "gate":
		var k := GardenOps.fence_at(house.data, to_local_2d(p))
		if k == "":
			return {}
		return {"label": "Gate", "fn": func(h: HouseData) -> Dictionary: return GardenOps.toggle_gate(h, k)}
	var run := _fence_run(p)
	if run[0] == run[1]:
		return {}
	var type := str(options["fence_type"])
	if mode == "remove":
		return {"label": "Remove fence", "fn": func(h: HouseData) -> Dictionary: return GardenOps.remove_fence(h, run[0], run[1])}
	return {"label": "Build fence", "confirm": true, "fn": func(h: HouseData) -> Dictionary: return GardenOps.set_fence(h, run[0], run[1], type)}


# --- Actions ------------------------------------------------------------------------------------------

## What releasing the pointer here would do, as {label, fn, confirm} or a live edit to finish.
func _action_for(p: Vector3) -> Dictionary:
	if placing != null:
		return _place_action(p)
	match tool:
		"room":
			return _room_action(p)
		"wall":
			return _wall_action(p)
		"door", "window", "arch":
			return _opening_action(p)
		"floor":
			return _floor_action(p)
		"paint":
			return _paint_action(p)
		"roof":
			return _roof_action(p)
		"verandah":
			return _verandah_action(p)
		"terrain":
			return _terrain_action(p)
		"garden":
			return _garden_action(p)
		"fence":
			return _fence_action(p)
		"stairs":
			if house == null:
				_say("Draw a room first.", "warn")
				return {}
			var st := _stairs_def(p)
			var lv := level
			return {"label": "Add stairs", "fn": func(h: HouseData) -> Dictionary: return BuildOps.add_stairs(h, lv, st)}
		"post":
			if house == null:
				return {}
			var c := _corner(p)
			var kind := str(options["post_kind"])
			var lv2 := level
			return {"label": "Add post", "fn": func(h: HouseData) -> Dictionary: return BuildOps.add_column(h, lv2, c, kind)}
		"demolish":
			return _demolish_action(p)
		"select":
			var mode := str(_drag.get("mode", ""))
			if mode in ["push", "move", "opening"] and _drag.has("live_ok"):
				var labels := {"push": "Move wall", "move": "Move room", "opening": "Move opening"}
				var changed_any: bool = (mode == "push" and int(_drag.get("delta", 0)) != 0) or (mode == "move" and (_drag["offset"] != Vector2i.ZERO or int(_drag["turns"]) != 0)) or mode == "opening"
				if not changed_any:
					house.replace_data(HouseData.from_dict(_drag["original"]))
					return {}
				return {"live": true, "label": labels[mode], "original": _drag["original"], "ok": _drag["live_ok"],
					"cost": _drag.get("live_cost", 0), "offset": _drag.get("offset", Vector2i.ZERO), "confirm": false}
	return {}


# --- Previews ------------------------------------------------------------------------------------------

func _plane_y() -> float:
	if house == null:
		var grid: WorldGrid = world.get("slice").grid
		return grid.height_at(_hover_world.x, _hover_world.z) + 0.6
	return house.builder.level_y(level)


## Local 2D point to a preview-space 3D point (the preview lives in the house's space).
func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _rect_edges(r: Rect2i) -> Array:
	return [[Vector2(r.position), Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), Vector2(r.end)],
		[Vector2(r.end), Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), Vector2(r.position)]]


func _ghost_wall(kit: MeshKit, a: Vector2, b: Vector2, y: float, h: float) -> void:
	kit.beam("g", Vector3(a.x, y + h * 0.5, a.y), Vector3(b.x, y + h * 0.5, b.y), HouseData.WALL_THICKNESS + 0.02, h)


func _ghost_box(kit: MeshKit, a: Vector2, b: Vector2, y0: float, y1: float, depth: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	if depth > 0.0:
		if is_equal_approx(lo.y, hi.y):
			lo.y -= depth * 0.5
			hi.y += depth * 0.5
		else:
			lo.x -= depth * 0.5
			hi.x += depth * 0.5
	kit.box("g", Transform3D(Basis(), Vector3((lo.x + hi.x) * 0.5, (y0 + y1) * 0.5, (lo.y + hi.y) * 0.5)), Vector3(hi.x - lo.x, y1 - y0, hi.y - lo.y))


## Snapping guides: thin lines along the grid through a rectangle's edges, running past its corners.
func _guides(kit: MeshKit, r: Rect2i, y: float) -> void:
	var ext := 3.0
	var gy := y + 0.04
	for x: float in [r.position.x, r.end.x]:
		kit.beam("g", Vector3(x, gy, r.position.y - ext), Vector3(x, gy, r.end.y + ext), 0.025, 0.01)
	for z: float in [r.position.y, r.end.y]:
		kit.beam("g", Vector3(r.position.x - ext, gy, z), Vector3(r.end.x + ext, gy, z), 0.025, 0.01)


func _show_cursor(p: Vector3, corner: bool = false) -> void:
	var kit := MeshKit.new()
	var origin := Vector3.ZERO if house == null else house.position
	var l := to_local_2d(p)
	var y := _plane_y() if house != null else p.y - origin.y
	if corner:
		var c := Vector2(roundf(l.x), roundf(l.y))
		_ghost_box(kit, c - Vector2(0.09, 0.09), c + Vector2(0.09, 0.09), y, y + 0.4, -1.0)
	else:
		var t := l.floor()
		kit.quad("f", _v3(t, y + 0.03), _v3(t + Vector2(1, 0), y + 0.03), _v3(t + Vector2(1, 1), y + 0.03), _v3(t + Vector2(0, 1), y + 0.03), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_set_preview(kit, true)
	_label.visible = false


func _highlight_run(run: Array, strong: bool) -> void:
	var kit := MeshKit.new()
	var y := _plane_y()
	for k: String in run:
		var pts := HouseData.edge_points(k)
		_ghost_wall(kit, Vector2(pts[0]), Vector2(pts[1]), y, house.data.wall_h(level, k) + 0.05)
	_set_preview(kit, true)
	if strong:
		_show_label(_pv(_hover_world) + Vector3(0, 1.4, 0), "Drag to push or pull · %d m wall" % run.size(), true)


func _set_preview(kit: MeshKit, ok: bool) -> void:
	var origin := Vector3.ZERO if house == null else house.position
	_preview.position = origin
	if not kit.has_geometry():
		_preview.mesh = null
		return
	var mat := _blueprint if ok else _bad
	_preview.mesh = kit.commit({"g": mat, "f": mat}, false)


## Shows the floating label. at is in the preview's space (house-local, or world when there's no house).
func _show_label(at: Vector3, text: String, ok: bool) -> void:
	var origin := Vector3.ZERO if house == null else house.position
	_label.position = origin + at
	_label.text = text
	_label.modulate = Color("#00294D") if ok else Color("#940E16")
	_label.visible = true


## A world point in the preview's space.
func _pv(p: Vector3) -> Vector3:
	return p - (Vector3.ZERO if house == null else house.position)


func _clear_preview() -> void:
	_preview.mesh = null
	_label.visible = false


func _clear_preview_mesh() -> void:
	_preview.mesh = null
