class_name BuildMode
extends Node
## Build mode: turns pointer, keyboard and touch input into BuildOps edits on the town's houses, with
## live previews (blueprint ghosts, snapping guides, dimension and cost labels), unlimited undo and
## redo, sounds, money and autosave. The world owns the houses; this node owns the tools.

signal changed
signal message(text: String, kind: String)

const TOOLS: Array[String] = ["room", "wall", "select", "door", "window", "arch", "floor", "stairs", "post", "demolish"]
const HINTS := {
	"room": "Drag to draw a room. Hold Shift (or tap Add to room) to extend the room you start in.",
	"wall": "Drag along the grid to draw a wall. Drag at 45 degrees for a diagonal.",
	"select": "Drag a wall to push or pull it. Drag inside a room to move it, and turn it with , and .",
	"door": "Point at a wall and click to place a door. Hold Alt for free placement.",
	"window": "Point at a wall and click to place a window. Arrow keys nudge and raise a selected window.",
	"arch": "Point at a wall and click to open an archway.",
	"floor": "Drag over tiles to lay floor. Quarter mode paints triangles.",
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
	tool = t
	selection.clear()
	sfx.play("click")
	_say(HINTS.get(t, ""), "hint")
	changed.emit()


func set_option(key: String, value: Variant) -> void:
	options[key] = value
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
	if house != null:
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
		var b := hv.data.bounds().grow(2)
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
		if not _drag.is_empty() or not _pending.is_empty():
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
		var keys := {KEY_R: "room", KEY_W: "", KEY_T: "wall", KEY_V: "select", KEY_D: "door", KEY_N: "window", KEY_F: "floor", KEY_G: "stairs", KEY_X: "demolish"}
		if keys.has(k.keycode) and str(keys[k.keycode]) != "" and not k.ctrl_pressed:
			set_tool(str(keys[k.keycode]))
			return
		return
	get_viewport().set_input_as_handled()


func _press(screen: Vector2, shift: bool, alt: bool) -> void:
	if not _pending.is_empty():
		_cancel()
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
	_drag = {"start": p, "screen": screen, "shift": shift or options["extend"], "alt": alt or options["free"], "moved": false}
	match tool:
		"select":
			_select_press(p)
		"door", "window", "arch":
			_drag["opening"] = _opening_at_pointer(p, alt or options["free"])
		_:
			pass
	_move(screen, alt)


func _move(screen: Vector2, alt: bool = false) -> void:
	var p := pick(screen)
	_hover_world = p
	if not _drag.is_empty() and (screen - (_drag["screen"] as Vector2)).length() > 6.0:
		_drag["moved"] = true
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
		"stairs":
			_stairs_preview(p)
		"post":
			_post_preview(p)
		"demolish":
			_demolish_preview(p)


func _release(screen: Vector2) -> void:
	if _drag.is_empty():
		return
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
		h.roof = {"type": "hip", "pitch": 28, "overhang": 0.45, "material": "corrugated_iron"}
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


# --- Actions ------------------------------------------------------------------------------------------

## What releasing the pointer here would do, as {label, fn, confirm} or a live edit to finish.
func _action_for(p: Vector3) -> Dictionary:
	match tool:
		"room":
			return _room_action(p)
		"wall":
			return _wall_action(p)
		"door", "window", "arch":
			return _opening_action(p)
		"floor":
			return _floor_action(p)
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
