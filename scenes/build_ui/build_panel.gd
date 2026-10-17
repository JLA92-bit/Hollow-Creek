class_name BuildPanel
extends Control
## The build-mode interface (layout from docs/mockups/ui-layout-house-builder.png): the tool palette on
## the left, options for the current tool or selection on the right, the house panel with storeys,
## foundations and validation hints at the bottom left, and undo, redo, confirm and Done at the bottom
## right. Every control is at least 44 px tall.

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")
const SKY := Color("#4BC9F5")
const AMBER := Color("#FBAD45")
const SECONDARY := Color("#3D5670")
const TOOL_LABELS := {"room": "Room", "wall": "Wall", "select": "Select", "door": "Door", "window": "Window",
	"arch": "Arch", "floor": "Floor", "paint": "Paint", "roof": "Roof", "verandah": "Verandah", "stairs": "Stairs", "post": "Post", "terrain": "Terrain", "garden": "Garden", "fence": "Fence", "buy": "Furnish", "demolish": "Demolish"}
const PAINTS: Array[String] = ["cream", "ivory", "white", "butter", "apricot", "rose", "mint", "duck_egg", "sky", "sage"]
const OPTIONS_W := 320.0
const FLOORS: Array[String] = ["floor_boards", "pine_boards", "lino_checks", "decking", "concrete", "quarry_tiles"]

var build: BuildMode
var world: Node3D
var _tools: Dictionary = {}
var _options: VBoxContainer
var _options_panel: PanelContainer
var _options_scroll: ScrollContainer
var _palette_panel: PanelContainer
var _house_panel: PanelContainer
var _actions_panel: PanelContainer
var _house_box: VBoxContainer
var _status: Label
var _status_panel: PanelContainer
var _undo_btn: Button
var _redo_btn: Button
var _confirm_btn: Button
var _cancel_btn: Button
var _dialog: PanelContainer
var _dialog_box: VBoxContainer
var _awaiting_file := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette()
	_options_area()
	_house_area()
	_actions()
	_status_line()
	build.changed.connect(refresh)
	build.message.connect(_on_message)
	_on_message(str(BuildMode.HINTS.get(build.tool, "")), "hint")
	refresh()


# --- Building blocks -----------------------------------------------------------------------------

func _anchor(c: Control, preset: Control.LayoutPreset, margin: int, extra: Vector2 = Vector2.ZERO) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.offset_left += extra.x
	c.offset_right += extra.x
	c.offset_top += extra.y
	c.offset_bottom += extra.y


func _button(text: String, cb: Callable, min_w: float = 0.0, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 44)
	b.add_theme_font_size_override("font_size", 15)
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(func() -> void:
		build.sfx.play("click")
		cb.call())
	return b


func _toggle(text: String, on: bool, cb: Callable, min_w: float = 0.0) -> Button:
	var b := _button(text, cb, min_w)
	b.toggle_mode = true
	b.set_pressed_no_signal(on)
	return b


func _caps(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"CapsLabel"
	l.text = text.to_upper()
	return l


func _text(text: String, size: int = 15, colour: Color = NAVY) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _row(sep: int = 6) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	return r


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.custom_minimum_size = Vector2(OPTIONS_W - 28, 0)
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	return f


## A style card: name, price and a note, like the mockup's catalogue.
func _card(title: String, sub: String, selected: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.set_pressed_no_signal(selected)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(128, 54)
	b.text = "%s\n%s" % [title, sub]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(func() -> void:
		build.sfx.play("click")
		cb.call())
	return b


func _swatch(paint: String, selected: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(44, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = paint.replace("_", " ").capitalize()
	var sb := StyleBoxFlat.new()
	sb.bg_color = MaterialLibrary.paint(paint)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if selected else 1)
	sb.border_color = NAVY if selected else Color("#C9D2DC")
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func() -> void:
		build.sfx.play("click")
		cb.call())
	return b


# --- Areas ---------------------------------------------------------------------------------------

func _palette() -> void:
	var p := PanelContainer.new()
	_palette_panel = p
	add_child(p)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	p.add_child(grid)
	for t: String in BuildMode.TOOLS:
		var b := Button.new()
		b.text = TOOL_LABELS[t]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(78, 44)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void: build.set_tool(t))
		grid.add_child(b)
		_tools[t] = b
	for t2: String in []:
		var b2 := Button.new()
		b2.text = t2
		b2.disabled = true
		b2.custom_minimum_size = Vector2(78, 44)
		b2.add_theme_font_size_override("font_size", 14)
		grid.add_child(b2)


func _options_area() -> void:
	_options_panel = PanelContainer.new()
	add_child(_options_panel)
	_options_scroll = ScrollContainer.new()
	_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_panel.add_child(_options_scroll)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 8)
	_options.custom_minimum_size = Vector2(OPTIONS_W - 28, 0)
	_options_scroll.add_child(_options)


func _house_area() -> void:
	_house_panel = PanelContainer.new()
	add_child(_house_panel)
	_house_box = VBoxContainer.new()
	_house_box.add_theme_constant_override("separation", 6)
	_house_box.custom_minimum_size = Vector2(290, 0)
	_house_panel.add_child(_house_box)


func _actions() -> void:
	_actions_panel = PanelContainer.new()
	add_child(_actions_panel)
	var row := _row(8)
	_actions_panel.add_child(row)
	_cancel_btn = _button("Cancel", func() -> void: build.call("_cancel"), 90)
	_confirm_btn = _button("Build", func() -> void: build.confirm_pending(), 110, true)
	_undo_btn = _button("Undo", func() -> void: build.do_undo(), 80)
	_redo_btn = _button("Redo", func() -> void: build.do_redo(), 80)
	var done := _button("Done", func() -> void: world.call("exit_build_mode"), 90, true)
	var photo := _button("Photo", func() -> void: world.call("toggle_photo_mode"), 80)
	photo.tooltip_text = "Photo mode (F2)"
	for b in [_cancel_btn, _confirm_btn, _undo_btn, _redo_btn, photo, done]:
		row.add_child(b)


func _status_line() -> void:
	_status_panel = PanelContainer.new()
	add_child(_status_panel)
	_status = _text("", 15)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(420, 0)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_panel.add_child(_status)


func _on_message(text: String, kind: String) -> void:
	_status.text = text
	var colour := NAVY
	match kind:
		"warn":
			colour = MAROON
		"confirm":
			colour = NAVY
		"hint":
			colour = SECONDARY
	_status.add_theme_color_override("font_color", colour)
	_layout.call_deferred()


## Places each panel from its measured size: palette top left, options top right (scrolling when
## tall), house panel bottom left, actions bottom right, status bottom centre.
func _layout() -> void:
	var vp := get_viewport_rect().size
	_place(_palette_panel, Vector2(16, 128), false, false)
	var act := _actions_panel.get_combined_minimum_size()
	_place(_actions_panel, Vector2(16, 16), true, true)
	var house := _house_panel.get_combined_minimum_size()
	_place(_house_panel, Vector2(16, 16), false, true)
	var avail := vp.y - 176.0 - act.y - 40.0
	var want := _options.get_combined_minimum_size().y + 28.0
	_options_scroll.custom_minimum_size = Vector2(OPTIONS_W - 28, clampf(want - 28.0, 60.0, maxf(avail - 28.0, 60.0)))
	_place(_options_panel, Vector2(16, 176), true, false)
	var st := _status_panel.get_combined_minimum_size()
	_status_panel.anchor_left = 0.5
	_status_panel.anchor_right = 0.5
	_status_panel.anchor_top = 1.0
	_status_panel.anchor_bottom = 1.0
	var bottom := -16.0 - act.y - 10.0 if vp.x < house.x + act.x + st.x + 80.0 else -16.0
	_status_panel.offset_left = -st.x * 0.5
	_status_panel.offset_right = st.x * 0.5
	_status_panel.offset_bottom = bottom
	_status_panel.offset_top = bottom - st.y


func _place(c: Control, margin: Vector2, right: bool, bottom: bool) -> void:
	var sz := c.get_combined_minimum_size()
	c.anchor_left = 1.0 if right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	if right:
		c.offset_right = -margin.x
		c.offset_left = -margin.x - sz.x
	else:
		c.offset_left = margin.x
		c.offset_right = margin.x + sz.x
	if bottom:
		c.offset_bottom = -margin.y
		c.offset_top = -margin.y - sz.y
	else:
		c.offset_top = margin.y
		c.offset_bottom = margin.y + sz.y


# --- Refresh -------------------------------------------------------------------------------------

func refresh() -> void:
	for t: String in _tools:
		(_tools[t] as Button).set_pressed_no_signal(t == build.tool)
	_undo_btn.disabled = not build.undo.can_undo()
	_redo_btn.disabled = not build.undo.can_redo()
	_undo_btn.tooltip_text = "Undo %s (Ctrl+Z)" % build.undo.next_undo_label()
	_redo_btn.tooltip_text = "Redo %s (Ctrl+Y)" % build.undo.next_redo_label()
	_confirm_btn.visible = build.has_pending()
	_cancel_btn.visible = build.has_pending()
	_fill_options()
	_fill_house()
	_layout.call_deferred()


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill_options() -> void:
	_clear(_options)
	var o := build.options
	var sel := build.selection
	if build.tool == "select" and not sel.is_empty():
		_selection_options(sel)
		return
	match build.tool:
		"room":
			_heading("Room")
			var name_edit := LineEdit.new()
			name_edit.text = str(o["room_name"])
			name_edit.placeholder_text = "Room name"
			name_edit.custom_minimum_size = Vector2(0, 44)
			name_edit.text_changed.connect(func(t: String) -> void: o["room_name"] = t)
			_options.add_child(name_edit)
			_paints(str(o["room_paint"]), func(p: String) -> void: build.set_option("room_paint", p))
			_heights(float(o["room_height"]), func(h: float) -> void: build.set_option("room_height", h))
			_floors(str(o["room_floor"]), func(f: String) -> void: build.set_option("room_floor", f))
			_options.add_child(_toggle("Add to room (L-shapes)", bool(o["extend"]), func() -> void: build.set_option("extend", not bool(o["extend"]))))
		"wall":
			_heading("Walls")
			var r := _flow()
			for k: String in ["full", "half", "low"]:
				r.add_child(_card(k.capitalize(), {"full": "Room height", "half": "1.0 m", "low": "0.6 m"}[k], o["wall_kind"] == k, func() -> void: build.set_option("wall_kind", k)))
			_options.add_child(r)
			_options.add_child(_text("Full walls make rooms. Half and low walls divide space without closing it.", 13, SECONDARY))
		"door", "window", "arch":
			var cat := "door" if build.tool == "door" else ("window" if build.tool == "window" else "arch")
			_heading({"door": "Doors", "window": "Windows", "arch": "Arches and doorways"}[cat])
			_caps_add("Catalogue")
			var f := _flow()
			var styles: Array[String] = Pieces.of_category(cat)
			if cat == "arch":
				styles = ["arch", "doorway"]
			for st in styles:
				var piece := Pieces.get_piece(st)
				var key := "%s_style" % build.tool
				f.add_child(_card(str(piece["name"]), "£%d · %.1f m" % [int(piece["cost"]), float(piece.get("width", 0.9))], o.get(key, "") == st,
					func() -> void: build.set_option(key, st)))
			_options.add_child(f)
			if cat == "window":
				_caps_add("Options")
				_yes_no("Latch at night", bool(o["latch_night"]), func(v: bool) -> void: build.set_option("latch_night", v))
				_yes_no("Curtains drawn at dusk", bool(o["curtains_dusk"]), func(v: bool) -> void: build.set_option("curtains_dusk", v))
				_options.add_child(_text("New windows start unlatched.", 13, SECONDARY))
			elif cat == "door":
				_caps_add("Options")
				_yes_no("Locked at night", bool(o["lock_night"]), func(v: bool) -> void: build.set_option("lock_night", v))
		"floor":
			_heading("Floors")
			_floors(str(o["floor"]), func(f: String) -> void: build.set_option("floor", f))
			_caps_add("Paint")
			var r2 := _row()
			r2.add_child(_toggle("Whole tiles", o["floor_mode"] == "tile", func() -> void: build.set_option("floor_mode", "tile"), 120))
			r2.add_child(_toggle("Triangles", o["floor_mode"] == "quarter", func() -> void: build.set_option("floor_mode", "quarter"), 120))
			_options.add_child(r2)
			var r3 := _row()
			r3.add_child(_toggle("Boards east-west", int(o["floor_rot"]) == 0, func() -> void: build.set_option("floor_rot", 0), 120))
			r3.add_child(_toggle("North-south", int(o["floor_rot"]) == 90, func() -> void: build.set_option("floor_rot", 90), 120))
			_options.add_child(r3)
		"paint":
			_paint_options(o)
		"roof":
			_roof_options(o)
		"verandah":
			_verandah_options(o)
		"terrain":
			_terrain_options(o)
		"garden":
			_garden_options(o)
		"fence":
			_fence_options(o)
		"buy":
			_buy_options(o)
		"stairs":
			_heading("Stairs")
			var f2 := _flow()
			for k2: String in ["straight", "l", "u", "ladder"]:
				var piece2 := Pieces.get_piece("stairs_" + k2)
				f2.add_child(_card(str(piece2["name"]), "£%d" % int(piece2["cost"]), o["stairs_kind"] == k2, func() -> void: build.set_option("stairs_kind", k2)))
			_options.add_child(f2)
			var r4 := _row()
			r4.add_child(_button("Turn left", func() -> void: build.call("_rotate", -1), 110))
			r4.add_child(_button("Turn right", func() -> void: build.call("_rotate", 1), 110))
			_options.add_child(r4)
			_options.add_child(_text("Rising to the %s." % {"N": "north", "E": "east", "S": "south", "W": "west"}[o["stairs_dir"]], 13, SECONDARY))
			if build.house != null and not build.house.data.has_storey(build.level + 1):
				_options.add_child(_button("Add a storey above", func() -> void: build.add_storey(true), 0, true))
		"post":
			_heading("Posts and columns")
			var f3 := _flow()
			for k3: String in ["timber_post", "turned_post", "brick_pier"]:
				var piece3 := Pieces.get_piece(k3)
				f3.add_child(_card(str(piece3["name"]), "£%d" % int(piece3["cost"]), o["post_kind"] == k3, func() -> void: build.set_option("post_kind", k3)))
			_options.add_child(f3)
		"select":
			_heading("Select")
			_options.add_child(_text("Tap a wall, room, door or window to change it.", 14, SECONDARY))
		"demolish":
			_heading("Demolish")
			_options.add_child(_text("Removing things refunds nothing yet; undo puts them back.", 14, SECONDARY))


func _selection_options(sel: Dictionary) -> void:
	var h := build.house.data
	match str(sel["type"]):
		"room":
			var r := h.room_at_tile(build.level, sel["tile"])
			if r.is_empty():
				return
			_heading(h.room_name(r))
			_options.add_child(_text("%.0f m² · %s" % [float(r["area"]), HouseData.storey_name(build.level)], 13, SECONDARY))
			var name_edit := LineEdit.new()
			name_edit.text = h.room_name(r)
			name_edit.custom_minimum_size = Vector2(0, 44)
			name_edit.text_submitted.connect(func(t: String) -> void: build.set_selection_prop("name", t))
			_options.add_child(name_edit)
			_paints(h.room_paint(r), func(p: String) -> void: build.set_selection_prop("paint", p))
			var k0: String = h.room_walls(build.level, r)[0] if not h.room_walls(build.level, r).is_empty() else ""
			_heights(h.wall_h(build.level, k0) if k0 != "" else 2.7, func(v: float) -> void: build.set_selection_prop("height", v))
			var top_h := h.wall_h(build.level, k0) if k0 != "" else 2.7
			_yes_no("Picture rail", bool((r["props"] as Dictionary).get("picture_rail", top_h >= 2.9)), func(v: bool) -> void: build.set_selection_prop("picture_rail", v))
			_yes_no("Cornice", bool((r["props"] as Dictionary).get("cornice", false)), func(v: bool) -> void: build.set_selection_prop("cornice", v))
			var row := _row()
			row.add_child(_button("Turn left", func() -> void: build.call("_rotate", -1), 110))
			row.add_child(_button("Turn right", func() -> void: build.call("_rotate", 1), 110))
			_options.add_child(row)
			_options.add_child(_button("Clear this room", func() -> void: build.delete_selection()))
		"opening":
			var o := h.opening_by_id(str(sel["id"]))
			if o.is_empty():
				return
			var piece := Pieces.get_piece(str(o.get("style", o["kind"])))
			_heading(str(piece.get("name", o["kind"])))
			if o["kind"] == "window":
				var r2 := _row()
				var sill_l := _text("Sill %.2f m" % float(o.get("sill", 0.9)), 15)
				sill_l.autowrap_mode = TextServer.AUTOWRAP_OFF
				r2.add_child(sill_l)
				r2.add_child(_button("Lower", func() -> void: build.call("_nudge", KEY_DOWN), 80))
				r2.add_child(_button("Raise", func() -> void: build.call("_nudge", KEY_UP), 80))
				_options.add_child(r2)
			var r3 := _row()
			r3.add_child(_button("Slide left", func() -> void: build.call("_nudge", KEY_LEFT), 110))
			r3.add_child(_button("Slide right", func() -> void: build.call("_nudge", KEY_RIGHT), 110))
			_options.add_child(r3)
			var night: Dictionary = o.get("night", {})
			if o["kind"] == "door":
				var r4 := _row()
				r4.add_child(_toggle("Swings in", o.get("swing", "in") == "in", func() -> void: build.set_selection_prop("swing", "in"), 110))
				r4.add_child(_toggle("Swings out", o.get("swing", "in") == "out", func() -> void: build.set_selection_prop("swing", "out"), 110))
				_options.add_child(r4)
				_options.add_child(_button("Swap hinge side", func() -> void: build.set_selection_prop("hinge", "end" if o.get("hinge", "start") == "start" else "start")))
				_yes_no("Has a lock", bool(o.get("lock", false)), func(v: bool) -> void: build.set_selection_prop("lock", v))
				if o.get("lock", false):
					_caps_add("Key holders")
					var kf := _flow()
					var keys: Array = o.get("keys", [])
					for who: String in ["Household", "Constable", "Landlord"]:
						var has := keys.has(who)
						kf.add_child(_toggle(who, has, func() -> void:
							var nk: Array = keys.duplicate()
							if has:
								nk.erase(who)
							else:
								nk.append(who)
							build.set_selection_prop("keys", nk), 100))
					_options.add_child(kf)
				_yes_no("Locked at night", bool(night.get("lock", false)), func(v: bool) -> void:
					var n := night.duplicate()
					n["lock"] = v
					build.set_selection_prop("night", n))
			elif o["kind"] == "window":
				_yes_no("Latch at night", bool(night.get("latch", false)), func(v: bool) -> void:
					var n2 := night.duplicate()
					n2["latch"] = v
					build.set_selection_prop("night", n2))
				_yes_no("Curtains drawn at dusk", bool(night.get("curtains", true)), func(v: bool) -> void:
					var n3 := night.duplicate()
					n3["curtains"] = v
					build.set_selection_prop("night", n3))
			_options.add_child(_button("Remove", func() -> void: build.delete_selection()))
		"run":
			_heading("Wall")
			_options.add_child(_text("%d m long. Drag it to push or pull the room." % (sel["run"] as Array).size(), 14, SECONDARY))
			_options.add_child(_button("Remove this wall", func() -> void: build.delete_selection()))
		"stairs":
			_heading("Stairs")
			_options.add_child(_button("Remove these stairs", func() -> void: build.delete_selection()))


func _heading(text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = &"HeadingLabel"
	l.add_theme_font_size_override("font_size", 24)
	l.text = text
	_options.add_child(l)


func _caps_add(text: String) -> void:
	_options.add_child(_caps(text))


func _yes_no(label: String, on: bool, cb: Callable) -> void:
	var r := _row()
	var l := _text(label, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(_toggle("Yes", on, func() -> void: cb.call(true), 56))
	r.add_child(_toggle("No", not on, func() -> void: cb.call(false), 56))
	_options.add_child(r)


func _paints(current: String, cb: Callable) -> void:
	_caps_add("Paint")
	var f := _flow()
	for p in PAINTS:
		f.add_child(_swatch(p, p == current, func() -> void: cb.call(p)))
	_options.add_child(f)


func _roof_options(o: Dictionary) -> void:
	var pc := build.selected_roof()
	if build.selection.get("type", "") == "chimney":
		_heading("Chimney")
		_options.add_child(_text("Its stack clears the roof by 0.6 m wherever the roof goes.", 13, SECONDARY))
		_options.add_child(_button("Remove chimney", func() -> void: build.delete_selection()))
		return
	var editing := not pc.is_empty()
	_heading("Roof piece" if editing else "Roof")
	if not editing:
		var modes := _flow()
		for md: String in ["auto", "draw", "edit", "chimney"]:
			modes.add_child(_toggle({"auto": "Whole house", "draw": "Draw a piece", "edit": "Change a piece", "chimney": "Chimney"}[md],
				o["roof_mode"] == md, func() -> void: build.set_option("roof_mode", md), 136))
		_options.add_child(modes)
	var cur_shape := str(pc.get("shape", o["roof_shape"]))
	var cur_pitch := float(pc.get("pitch", o["roof_pitch"]))
	var cur_over := float(pc.get("overhang", o["roof_overhang"]))
	var cur_mat := str(pc.get("material", o["roof_material"]))
	_caps_add("Shape")
	var f := _flow()
	for sh: String in Roofs.SHAPES:
		f.add_child(_card(Roofs.SHAPE_NAMES[sh], {"hip": "Four slopes", "gable": "Two slopes, gable ends", "half_hip": "Gable, hipped top",
			"dutch": "Hip with a gablet", "skillion": "One slope", "flat": "Just enough fall"}[sh], cur_shape == sh,
			func() -> void: build.set_option("roof_shape", sh)))
	_options.add_child(f)
	if cur_shape != "flat":
		_caps_add("Pitch")
		var r := _row()
		r.add_child(_button("Flatter", func() -> void: build.set_option("roof_pitch", Roofs.clamp_pitch(cur_shape, cur_pitch - 5.0)), 90))
		var pl := _text("%.0f°" % cur_pitch, 16)
		pl.custom_minimum_size = Vector2(56, 0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(pl)
		r.add_child(_button("Steeper", func() -> void: build.set_option("roof_pitch", Roofs.clamp_pitch(cur_shape, cur_pitch + 5.0)), 90))
		_options.add_child(r)
	_caps_add("Eaves")
	var r2 := _row()
	for ov: float in [0.3, 0.45, 0.6, 0.9]:
		r2.add_child(_toggle("%.2f m" % ov, is_equal_approx(cur_over, ov), func() -> void: build.set_option("roof_overhang", ov), 64))
	_options.add_child(r2)
	_caps_add("Roofing")
	var f2 := _flow()
	for mat: String in Roofs.MATERIALS:
		var piece := Pieces.get_piece(mat)
		f2.add_child(_card(str(piece.get("name", mat)), "£%d per 2 m²" % int(piece.get("cost", 1)), cur_mat == mat, func() -> void: build.set_option("roof_material", mat)))
	_options.add_child(f2)
	if editing:
		var r3 := _row()
		r3.add_child(_button("Turn the ridge" if not Roofs.is_mono(pc) else "Turn the slope", func() -> void: build.set_roof_prop("turn", true), 140))
		r3.add_child(_button("Remove piece", func() -> void: build.delete_selection(), 120))
		_options.add_child(r3)
		_options.add_child(_text("Drag the roof up or down to change its pitch, or drag near an edge to stretch it.", 13, SECONDARY))
	elif build.house != null and not build.house.data.roof.is_empty():
		var r4 := _row()
		r4.add_child(_button("Roof the whole house", func() -> void: build.roof_house(), 160, true))
		r4.add_child(_button("Take it off", func() -> void: build.take_roof_off(), 110))
		_options.add_child(r4)
		if bool(build.house.data.roof.get("follow", false)):
			_options.add_child(_text("The roof follows the plan as you build. Change a piece to set it by hand.", 13, SECONDARY))
	elif build.house != null:
		_options.add_child(_button("Roof the whole house", func() -> void: build.roof_house(), 0, true))


func _verandah_options(o: Dictionary) -> void:
	var v := build.selected_verandah()
	var editing := not v.is_empty()
	_heading("Verandah" if editing else "Verandahs")
	if not editing:
		var modes := _flow()
		for md: String in ["add", "edit", "steps", "sleepout"]:
			modes.add_child(_toggle({"add": "Add", "edit": "Change", "steps": "Steps", "sleepout": "Sleep-out"}[md], o["v_mode"] == md,
				func() -> void: build.set_option("v_mode", md), 66))
		_options.add_child(modes)
	var cur := func(key: String) -> Variant: return v.get(key, o["v_" + key]) if editing else o["v_" + key]
	_caps_add("Roof")
	var f := _flow()
	for sh: String in BuildOps.VERANDAH_SHAPES:
		f.add_child(_card(sh.capitalize(), {"bullnose": "Curved iron", "skillion": "Straight fall", "gable": "Gable to the front"}[sh], cur.call("shape") == sh,
			func() -> void: build.set_option("v_shape", sh)))
	_options.add_child(f)
	var r0 := _row()
	for mt: String in ["corrugated_iron", "roof_paint_red", "roof_paint_green"]:
		r0.add_child(_toggle({"corrugated_iron": "Iron", "roof_paint_red": "Red", "roof_paint_green": "Green"}[mt], cur.call("material") == mt,
			func() -> void: build.set_option("v_material", mt), 70))
	_options.add_child(r0)
	_caps_add("Depth")
	var r := _row()
	for d: float in [1.5, 1.8, 2.1, 2.4, 3.0]:
		r.add_child(_toggle("%.1f m" % d, is_equal_approx(float(cur.call("depth")), d), func() -> void: build.set_option("v_depth", d), 50))
	_options.add_child(r)
	_caps_add("Posts")
	var r2 := _row()
	for pk: String in ["timber_post", "turned_post", "cast_iron"]:
		r2.add_child(_toggle({"timber_post": "Square", "turned_post": "Turned", "cast_iron": "Cast iron"}[pk], cur.call("post") == pk,
			func() -> void: build.set_option("v_post", pk), 90))
	_options.add_child(r2)
	_caps_add("Frieze and brackets")
	var r3 := _row()
	for lk: String in ["none", "lace", "fretwork"]:
		r3.add_child(_toggle({"none": "Plain", "lace": "Cast iron lace", "fretwork": "Fretwork"}[lk], cur.call("lace") == lk,
			func() -> void: build.set_option("v_lace", lk), 90))
	_options.add_child(r3)
	_caps_add("Rail")
	var r4 := _row()
	for rk: String in ["none", "timber", "lace"]:
		r4.add_child(_toggle({"none": "Open", "timber": "Timber", "lace": "Lace"}[rk], cur.call("rail") == rk,
			func() -> void: build.set_option("v_rail", rk), 90))
	_options.add_child(r4)
	_yes_no("Lattice underneath", bool(cur.call("lattice")), func(on: bool) -> void: build.set_option("v_lattice", on))
	_caps_add("Colour")
	var f2 := _flow()
	for pn in MaterialLibrary.paint_names("trims"):
		f2.add_child(_swatch(pn, pn == str(cur.call("colour")), func() -> void: build.set_option("v_colour", pn)))
	_options.add_child(f2)
	if editing:
		if v.has("sleepout"):
			_options.add_child(_button("Open up the sleep-out", func() -> void: build.remove_sleepout()))
		_options.add_child(_button("Remove verandah", func() -> void: build.delete_selection()))


func _terrain_options(o: Dictionary) -> void:
	_heading("Terrain")
	var r := _flow()
	for op: String in ["raise", "lower", "flatten", "smooth", "paint"]:
		r.add_child(_toggle(op.capitalize(), o["terrain_op"] == op, func() -> void: build.set_option("terrain_op", op), 88))
	_options.add_child(r)
	if o["terrain_op"] == "paint":
		_caps_add("Ground")
		var f := _flow()
		var grounds: Dictionary = GardenOps.catalogue()["grounds"]
		for g: String in grounds:
			f.add_child(_card(str(grounds[g]["name"]), "£%d per 2 m²" % int(grounds[g]["cost"]) if int(grounds[g]["cost"]) > 0 else "Free", o["ground"] == g,
				func() -> void: build.set_option("ground", g)))
		_options.add_child(f)
		_options.add_child(_text("Drag over the yard to lay it.", 13, SECONDARY))
	else:
		_caps_add("Brush")
		var r2 := _row()
		for rad: float in [1.5, 2.5, 4.0]:
			r2.add_child(_toggle({1.5: "Small", 2.5: "Medium", 4.0: "Large"}[rad], is_equal_approx(float(o["terrain_radius"]), rad),
				func() -> void: build.set_option("terrain_radius", rad), 88))
		_options.add_child(r2)
		_options.add_child(_text("Click or drag round the house. The ground under the house stays below its floor.", 13, SECONDARY))


func _garden_options(o: Dictionary) -> void:
	_heading("Garden")
	var cats := _row()
	for c: String in ["plants", "outbuildings", "items"]:
		cats.add_child(_toggle({"plants": "Plants", "outbuildings": "Sheds", "items": "Yard"}[c], o["garden_cat"] == c, func() -> void:
			build.options["garden_kind"] = (GardenOps.catalogue()[c] as Dictionary).keys()[0]
			build.set_option("garden_cat", c), 90))
	_options.add_child(cats)
	var f := _flow()
	var items: Dictionary = GardenOps.catalogue()[o["garden_cat"]]
	for k: String in items:
		f.add_child(_card(str(items[k]["name"]), "£%d · %s" % [int(items[k]["cost"]), str(items[k].get("blurb", ""))], o["garden_kind"] == k,
			func() -> void: build.set_option("garden_kind", k)))
	_options.add_child(f)
	var r := _row()
	r.add_child(_button("Turn left", func() -> void: build.call("_rotate", -1), 110))
	r.add_child(_button("Turn right", func() -> void: build.call("_rotate", 1), 110))
	_options.add_child(r)


func _fence_options(o: Dictionary) -> void:
	_heading("Fences and gates")
	var modes := _row()
	for md: String in ["build", "gate", "remove"]:
		modes.add_child(_toggle(md.capitalize(), o["fence_mode"] == md, func() -> void: build.set_option("fence_mode", md), 90))
	_options.add_child(modes)
	var f := _flow()
	var fences: Dictionary = GardenOps.catalogue()["fences"]
	for k: String in fences:
		f.add_child(_card(str(fences[k]["name"]), "£%d a metre · %.1f m" % [int(fences[k]["cost"]), float(fences[k]["height"])], o["fence_type"] == k,
			func() -> void: build.set_option("fence_type", k)))
	_options.add_child(f)


const STYLES_PATH := "user://styles.json"


func _buy_options(o: Dictionary) -> void:
	var objs := build.selected_objects()
	if not objs.is_empty() and str(o["buy_item"]) == "":
		_design_options(objs)
		return
	_heading("Furnish")
	_scores()
	var search := LineEdit.new()
	search.placeholder_text = "Search the catalogue"
	search.text = str(o["buy_query"])
	search.custom_minimum_size = Vector2(0, 44)
	search.text_submitted.connect(func(t: String) -> void: build.set_option("buy_query", t))
	_options.add_child(search)
	var rooms := _flow()
	for r: String in [""] + Array(Catalogue.data()["rooms"]):
		rooms.add_child(_toggle("All rooms" if r == "" else r.capitalize(), o["buy_room"] == r, func() -> void: build.set_option("buy_room", r), 70))
	_options.add_child(rooms)
	var fns := _flow()
	for fn: String in [""] + Array(Catalogue.data()["functions"]):
		fns.add_child(_toggle("Everything" if fn == "" else fn.capitalize(), o["buy_function"] == fn, func() -> void: build.set_option("buy_function", fn), 70))
	_options.add_child(fns)
	var ids := Catalogue.search(str(o["buy_query"]), str(o["buy_room"]), str(o["buy_function"]))
	var cards := _flow()
	for id in ids:
		var it := Catalogue.item(id)
		var c := _card(str(it["name"]), "£%d · %s" % [int(it["price"]), str(it.get("function", "")).capitalize()], o["buy_item"] == id, func() -> void: build.choose_item(id))
		c.tooltip_text = str(it.get("note", ""))
		cards.add_child(c)
	if ids.is_empty():
		_options.add_child(_text("Nothing matches. Try fewer words.", 13, SECONDARY))
	_options.add_child(cards)
	if str(o["buy_item"]) != "":
		var note := str(Catalogue.item(str(o["buy_item"])).get("note", ""))
		if note != "":
			_options.add_child(_text(note, 13, SECONDARY))
		_options.add_child(_button("Put it back (select instead)", func() -> void: build.choose_item("")))
	_caps_add("Placement")
	var r2 := _row()
	for sn: String in ["grid", "half", "free"]:
		r2.add_child(_toggle({"grid": "Grid 0.5 m", "half": "Half 0.25 m", "free": "Free"}[sn], o["buy_snap"] == sn, func() -> void: build.set_option("buy_snap", sn), 92))
	_options.add_child(r2)
	var r3 := _row()
	r3.add_child(_button("Turn left", func() -> void: build.call("_rotate", -1), 100))
	r3.add_child(_button("Turn right", func() -> void: build.call("_rotate", 1), 100))
	r3.add_child(_toggle("Stack", bool(o["buy_stack"]), func() -> void: build.set_option("buy_stack", not bool(o["buy_stack"])), 70))
	_options.add_child(r3)


## The home scores as compact bars.
func _scores() -> void:
	if build.house == null:
		return
	var s := HomeScores.compute(build.house.data)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	for k in HomeScores.NAMES:
		var row := _row(6)
		var l := _text(k.capitalize(), 13)
		l.custom_minimum_size = Vector2(62, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(56, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.value = int(s[k])
		row.add_child(bar)
		var v := _text(str(s[k]), 13)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(v)
		grid.add_child(row)
	_options.add_child(grid)


## The Design tool for the selected pieces: every material slot, library materials and colours,
## saved styles, and for lamps their brightness and colour temperature.
func _design_options(objs: Array) -> void:
	var first: Dictionary = objs[0]
	var it := Catalogue.item(Catalogue.id_of(first))
	_heading(str(it.get("name", "Furniture")) if objs.size() == 1 else "%d pieces" % objs.size())
	if objs.size() == 1:
		_options.add_child(_text("£%d · %s" % [int(it.get("price", 0)), str(it.get("note", ""))], 13, SECONDARY))
	var r := _row()
	r.add_child(_button("Turn left", func() -> void: build.call("_rotate", -1), 100))
	r.add_child(_button("Turn right", func() -> void: build.call("_rotate", 1), 100))
	r.add_child(_button("Remove", func() -> void: build.delete_selection(), 90))
	_options.add_child(r)
	if objs.size() == 1 and str(it.get("place", "")) == "wall":
		var rr := _row()
		rr.add_child(_button("Lower", func() -> void: build.call("_nudge", KEY_DOWN), 90))
		rr.add_child(_button("Raise", func() -> void: build.call("_nudge", KEY_UP), 90))
		_options.add_child(rr)
	var mats := Catalogue.design_materials()
	var slots: Dictionary = it.get("slots", {})
	for slot: String in slots:
		var cur := Catalogue.slot_value(first, slot)
		_caps_add(slot.capitalize() if not slot.contains("_0") else "Finish")
		var cat := str(MaterialLibrary.def(str(cur.get("mat", ""))).get("category", "")) if str(cur.get("mat", "")) != "" else ""
		if cat != "" and mats.has(cat):
			var mf := _flow()
			for mid: String in mats[cat]:
				var mname := str(MaterialLibrary.def(mid).get("name", mid.replace("_", " ").capitalize()))
				mf.add_child(_toggle(mname, str(cur.get("mat", "")) == mid, func() -> void: build.set_object_slot(slot, {"mat": mid}), 80))
			_options.add_child(mf)
		var cf := _flow()
		for pn in MaterialLibrary.paint_names("walls").slice(0, 6) + MaterialLibrary.paint_names("trims").slice(0, 5):
			var hexc := "#" + MaterialLibrary.paint(pn).to_html(false)
			cf.add_child(_swatch(pn, hexc.to_lower() == str(cur.get("colour", "")).to_lower(), func() -> void: build.set_object_slot(slot, {"colour": hexc})))
		var pick := ColorPickerButton.new()
		pick.custom_minimum_size = Vector2(44, 44)
		pick.tooltip_text = "Mix a colour"
		pick.color = Color(str(cur.get("colour", "#FFFFFF")))
		pick.popup_closed.connect(func() -> void: build.set_object_slot(slot, {"colour": "#" + pick.color.to_html(false)}))
		cf.add_child(pick)
		_options.add_child(cf)
	# Saved styles: this piece's slots by name, to put on any piece with the same slots.
	_caps_add("Styles")
	var styles := _load_styles()
	var sf := _flow()
	for sname: String in styles:
		sf.add_child(_button(sname, func() -> void: build.apply_style(styles[sname]), 90))
	_options.add_child(sf)
	var sr := _row()
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Style name"
	name_edit.custom_minimum_size = Vector2(170, 44)
	sr.add_child(name_edit)
	sr.add_child(_button("Save style", func() -> void:
		var st: Dictionary = {}
		for slot2: String in slots:
			st[slot2] = Catalogue.slot_value(first, slot2)
		var nm := name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Style %d" % (styles.size() + 1)
		styles[nm] = st
		_save_styles(styles)
		refresh(), 110))
	_options.add_child(sr)
	var ld := Catalogue.light_of(first)
	if not ld.is_empty():
		_caps_add("Lamp")
		var energy := float(ld.get("energy", 1.0))
		var kelvin := float(ld.get("kelvin", 2700))
		var lr := _row()
		lr.add_child(_button("Dimmer", func() -> void: build.set_object_light(energy - 0.2, kelvin), 90))
		var el := _text("%d%%" % roundi(energy * 100), 15)
		el.autowrap_mode = TextServer.AUTOWRAP_OFF
		lr.add_child(el)
		lr.add_child(_button("Brighter", func() -> void: build.set_object_light(energy + 0.2, kelvin), 90))
		_options.add_child(lr)
		var kr := _flow()
		for kv: Array in [[1900, "Flame"], [2700, "Warm"], [3500, "Neutral"], [5000, "Daylight"]]:
			var kk: float = kv[0]
			kr.add_child(_toggle("%s %dK" % [kv[1], kk], absf(kelvin - kk) < 1.0, func() -> void: build.set_object_light(energy, kk), 90))
		_options.add_child(kr)
	_options.add_child(_text("Drag to move. Ctrl-click adds to the selection; arrows nudge, Shift for fine.", 13, SECONDARY))


func _load_styles() -> Dictionary:
	if not FileAccess.file_exists(STYLES_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STYLES_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _save_styles(styles: Dictionary) -> void:
	var f := FileAccess.open(STYLES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(styles))
		f.close()


const LININGS := {"wall_tiles": "Wall tiles", "vj_panelling": "VJ panelling"}
const CLADDINGS := {"weatherboard": "Weatherboard", "fibro": "Fibro", "brick_red": "Red brick", "render": "Render",
	"corrugated_wall": "Corrugated iron"}


func _paint_options(o: Dictionary) -> void:
	_heading("Paint and wallpaper")
	var kinds := _row()
	for k: String in ["paint", "wallpaper", "lining", "cladding"]:
		kinds.add_child(_toggle(k.capitalize(), o["paint_kind"] == k, func() -> void: build.set_option("paint_kind", k), 66))
	_options.add_child(kinds)
	var kind := str(o["paint_kind"])
	if kind == "wallpaper":
		var papers: Dictionary = MaterialLibrary.palettes()["wallpapers"]
		for pat: String in papers:
			_caps_add(str(papers[pat]["name"]))
			var f := _flow()
			var ways: Dictionary = papers[pat]["colourways"]
			for cw: String in ways:
				f.add_child(_paper_swatch(pat, cw, ways[cw], o["wallpaper"] == pat and o["colourway"] == cw))
			_options.add_child(f)
	elif kind == "lining" or kind == "cladding":
		var names: Dictionary = LININGS if kind == "lining" else CLADDINGS
		var f2 := _flow()
		for m: String in names:
			f2.add_child(_card(names[m], "£1 a metre", o[kind] == m, func() -> void: build.set_option(kind, m)))
		_options.add_child(f2)
	if kind == "paint" or (kind == "lining" and o["lining"] != "vj_panelling") or kind == "cladding":
		for group: String in ["walls", "trims"]:
			_caps_add("Wall colours" if group == "walls" else "Trim colours")
			var f3 := _flow()
			for pn in MaterialLibrary.paint_names(group):
				f3.add_child(_swatch(pn, pn == o["paint_colour"], func() -> void: build.set_option("paint_colour", pn)))
			if group == "trims":
				var pick := ColorPickerButton.new()
				pick.custom_minimum_size = Vector2(44, 44)
				pick.tooltip_text = "Mix a custom colour"
				pick.color = MaterialLibrary.paint(str(o["paint_colour"]))
				pick.popup_closed.connect(func() -> void: build.set_option("paint_colour", "#" + pick.color.to_html(false)))
				f3.add_child(pick)
			_options.add_child(f3)
	if kind == "cladding" and build.house != null:
		_caps_add("House trims")
		var tf := _flow()
		for tn in MaterialLibrary.paint_names("trims"):
			tf.add_child(_swatch(tn, tn == str(build.house.data.exterior.get("trim", "white")), func() -> void: build.set_trim(tn)))
		_options.add_child(tf)
	if kind != "cladding":
		_caps_add("Part of the wall")
		var r := _row()
		r.add_child(_toggle("Whole wall", o["paint_part"] == "finish", func() -> void: build.set_option("paint_part", "finish"), 120))
		r.add_child(_toggle("Lower (dado)", o["paint_part"] == "dado", func() -> void: build.set_option("paint_part", "dado"), 120))
		_options.add_child(r)
		if o["paint_part"] == "dado":
			var r2 := _row()
			for dh: float in [0.9, 1.0, 1.2]:
				r2.add_child(_toggle("%.1f m" % dh, is_equal_approx(float(o["dado_h"]), dh), func() -> void: build.set_option("dado_h", dh), 70))
			_options.add_child(r2)
	_caps_add("Apply to")
	var sc := _row()
	for s: String in ["face", "room", "house"]:
		sc.add_child(_toggle({"face": "One wall", "room": "Room", "house": "Whole house"}[s], o["paint_scope"] == s,
			func() -> void: build.set_option("paint_scope", s), 90))
	_options.add_child(sc)
	_options.add_child(_toggle("Eyedropper (I)", bool(o["eyedropper"]), func() -> void: build.set_option("eyedropper", not bool(o["eyedropper"]))))
	_options.add_child(_text("Shift paints the room, Ctrl the whole house. Outside walls take the outside.", 13, SECONDARY))


func _paper_swatch(pat: String, cw: String, cols: Array, selected: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(60, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = cw.replace("_", " ").capitalize()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(str(cols[0]))
	sb.border_color = Color(str(cols[1]))
	sb.set_border_width_all(4 if not selected else 6)
	if selected:
		sb.border_color = NAVY
	sb.set_corner_radius_all(10)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	var dot := ColorRect.new()
	dot.color = Color(str(cols[2]))
	dot.custom_minimum_size = Vector2(12, 12)
	dot.position = Vector2(24, 16)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(dot)
	b.pressed.connect(func() -> void:
		build.sfx.play("click")
		build.options["wallpaper"] = pat
		build.set_option("colourway", cw))
	return b


func _heights(current: float, cb: Callable) -> void:
	_caps_add("Wall height")
	var r := _row()
	for hgt: float in [2.4, 2.7, 3.0, 3.3]:
		r.add_child(_toggle("%.1f m" % hgt, is_equal_approx(current, hgt), func() -> void: cb.call(hgt), 62))
	_options.add_child(r)


func _floors(current: String, cb: Callable) -> void:
	_caps_add("Floor")
	var f := _flow()
	for fl in FLOORS:
		var piece := Pieces.get_piece(fl)
		f.add_child(_card(str(piece.get("name", fl)), "£%d a tile" % int(piece.get("cost", 1)), fl == current, func() -> void: cb.call(fl)))
	_options.add_child(f)


func _fill_house() -> void:
	_clear(_house_box)
	var hv := build.house
	if hv == null:
		var l := Label.new()
		l.theme_type_variation = &"HeadingLabel"
		l.add_theme_font_size_override("font_size", 22)
		l.text = "New house"
		_house_box.add_child(l)
		_house_box.add_child(_text("Use the Room tool on open ground to start, or place a design from the library.", 14, SECONDARY))
		_house_box.add_child(_button("Library", open_library, 120))
		return
	var h := hv.data
	var title := _row()
	var tl := Label.new()
	tl.theme_type_variation = &"HeadingLabel"
	tl.add_theme_font_size_override("font_size", 22)
	tl.text = h.name
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	var rooms_l := _text("%d room%s" % [_room_count(h), "" if _room_count(h) == 1 else "s"], 14, SECONDARY)
	rooms_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_child(rooms_l)
	_house_box.add_child(title)
	# Storeys.
	var srow := _row()
	srow.add_child(_button("Down", func() -> void: build.set_level(build.level - 1), 70))
	var sl := _text(HouseData.storey_name(build.level), 15)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.custom_minimum_size = Vector2(110, 0)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	srow.add_child(sl)
	srow.add_child(_button("Up", func() -> void: build.set_level(build.level + 1), 70))
	_house_box.add_child(srow)
	var arow := _row()
	if h.levels()[-1] < HouseData.MAX_LEVEL:
		arow.add_child(_button("Add storey", func() -> void: build.add_storey(true), 120))
	if h.levels()[0] > HouseData.MIN_LEVEL:
		arow.add_child(_button("Dig cellar", func() -> void: build.add_storey(false), 120))
	_house_box.add_child(arow)
	# Foundations.
	var f := h.foundation
	var frow := _row()
	frow.add_child(_toggle("Stumps %.1f m" % float(f.get("height", 0.6)), f.get("type", "stumps") == "stumps", func() -> void:
		var hh := float(f.get("height", 0.6))
		var next := 0.3 if hh >= 1.8 else snappedf(hh + 0.3, 0.1)
		build.call("_commit", "Stump height", func(d: HouseData) -> Dictionary: return BuildOps.set_foundation(d, "stumps", next)), 130))
	frow.add_child(_toggle("Slab", f.get("type", "stumps") == "slab", func() -> void:
		build.call("_commit", "Concrete slab", func(d: HouseData) -> Dictionary: return BuildOps.set_foundation(d, "slab", 0.15)), 70))
	_house_box.add_child(frow)
	if not GameState.is_sandbox():
		var st: Dictionary = world.call("construction_status", h.id)
		if not st.is_empty():
			var line := "Materials arrive at the siding tomorrow" if st["waiting"] else "%s · %d%% · about %d day%s" % [st["stage"], st["percent"], ceili(float(st["days"])), "" if ceili(float(st["days"])) == 1 else "s"]
			_house_box.add_child(_text(line, 14, NAVY))
		var qrow := _row()
		for tier: String in ["rough", "standard", "fine"]:
			qrow.add_child(_toggle(str(Construction.TIERS[tier]["name"]), h.quality == tier, func() -> void:
				build.call("_commit", "%s work" % Construction.TIERS[tier]["name"], func(d: HouseData) -> Dictionary: return BuildOps.set_quality(d, tier)), 92))
		_house_box.add_child(qrow)
	var share_row := _row()
	share_row.add_child(_button("Share", open_share, 90))
	share_row.add_child(_button("Library", open_library, 90))
	_house_box.add_child(share_row)
	# Validation hints.
	var hints := h.validate()
	if hints.is_empty():
		_house_box.add_child(_text("No problems spotted.", 14, Color("#2E7D3E")))
	else:
		for hint in hints.slice(0, 4):
			_house_box.add_child(_text(hint, 14, MAROON))
		if hints.size() > 4:
			_house_box.add_child(_text("and %d more." % (hints.size() - 4), 13, SECONDARY))


# --- Share and library dialogs -------------------------------------------------------------------

func _open_dialog(title: String) -> VBoxContainer:
	_close_dialog()
	_dialog = PanelContainer.new()
	_dialog.custom_minimum_size = Vector2(560, 0)
	add_child(_dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_dialog.add_child(box)
	var head := _row()
	var tl := Label.new()
	tl.theme_type_variation = &"HeadingLabel"
	tl.add_theme_font_size_override("font_size", 24)
	tl.text = title
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(_button("Close", _close_dialog, 90))
	box.add_child(head)
	_dialog_box = box
	_center_dialog.call_deferred()
	return box


func _center_dialog() -> void:
	if _dialog:
		_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _close_dialog() -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null


func _code_box(code: String, editable: bool) -> TextEdit:
	var te := TextEdit.new()
	te.text = code
	te.editable = editable
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(0, 110)
	te.add_theme_font_override("font", load("res://assets/fonts/CourierPrime-Regular.ttf") as Font)
	te.add_theme_font_size_override("font_size", 12)
	return te


## Shows the edited house's share code with copy, .hollow download and save-to-library.
func open_share() -> void:
	if build.house == null:
		return
	var h := build.house.data
	var code := ShareCode.encode(h)
	var box := _open_dialog("Share %s" % h.name)
	box.add_child(_text("Anyone can paste this code into their own Hollow Creek to build a copy, garden and all.", 14, SECONDARY))
	box.add_child(_code_box(code, false))
	var row := _row()
	row.add_child(_button("Copy code", func() -> void:
		DisplayServer.clipboard_set(code)
		build.call("_say", "Share code copied (%d characters)." % code.length(), "done"), 130, true))
	row.add_child(_button("Save .hollow file", func() -> void: _save_hollow(h.name, code), 170))
	box.add_child(row)
	_caps_into(box, "Save to your library")
	var name_row := _row()
	var name_edit := LineEdit.new()
	name_edit.text = h.name
	name_edit.custom_minimum_size = Vector2(300, 44)
	name_row.add_child(name_edit)
	name_row.add_child(_button("Save", func() -> void:
		var file := Blueprints.save(name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else h.name, h)
		build.call("_say", "Saved to the library." if file != "" else "Couldn't save that.", "done" if file != "" else "warn")
		_close_dialog(), 90))
	box.add_child(name_row)


func _caps_into(box: Container, text: String) -> void:
	box.add_child(_caps(text))


func _save_hollow(name: String, code: String) -> void:
	var file := "%s.%s" % [Blueprints._safe(name), ShareCode.FILE_EXT]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(code.to_utf8_buffer(), file, "text/plain")
		build.call("_say", "Downloading %s." % file, "done")
		return
	DirAccess.make_dir_recursive_absolute(Blueprints.DIR)
	var f := FileAccess.open("%s/%s" % [Blueprints.DIR, file], FileAccess.WRITE)
	if f:
		f.store_string(code)
		f.close()
		build.call("_say", "Saved %s in %s." % [file, ProjectSettings.globalize_path(Blueprints.DIR)], "done")


## The blueprint library: saved designs to place, copy or delete, and importing a code or file.
func open_library() -> void:
	var box := _open_dialog("Blueprint library")
	var entries := Blueprints.list()
	if entries.is_empty():
		box.add_child(_text("Nothing saved yet. Use Share on a house to save it here.", 14, SECONDARY))
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, mini(entries.size(), 4) * 56)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for e: Dictionary in entries:
			var row := _row()
			var l := _text("%s · %d rooms · %s" % [e["name"], int(e.get("rooms", 0)), e.get("saved", "")], 15)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.clip_text = true
			row.add_child(l)
			var file := str(e["file"])
			var code := str(e["code"])
			var nm := str(e["name"])
			row.add_child(_button("Place", func() -> void:
				var d := ShareCode.decode(code)
				if d != null:
					_close_dialog()
					build.start_placing(d, nm), 80, true))
			row.add_child(_button("Copy", func() -> void: DisplayServer.clipboard_set(code), 70))
			row.add_child(_button("Delete", func() -> void:
				Blueprints.remove(file)
				open_library(), 80))
			list.add_child(row)
		box.add_child(scroll)
	_caps_into(box, "Import a share code")
	var te := _code_box("", true)
	te.placeholder_text = "Paste a HOLLOW1 code here"
	box.add_child(te)
	var row2 := _row()
	row2.add_child(_button("Place it", func() -> void: _import_code(te.text, false), 110, true))
	row2.add_child(_button("Save to library", func() -> void: _import_code(te.text, true), 150))
	row2.add_child(_button("Open .hollow file", _open_hollow_file, 170))
	box.add_child(row2)


func _import_code(code: String, keep: bool) -> void:
	var d := ShareCode.decode(code)
	if d == null:
		build.call("_say", "That code doesn't read right. Check it was copied in full.", "warn")
		return
	if keep:
		Blueprints.save(d.name if d.name != "" else "Imported house", d)
		open_library()
		return
	_close_dialog()
	build.start_placing(d, d.name)


func _open_hollow_file() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			window.hcImport = null;
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.hollow,.txt';
			input.onchange = function (e) {
				var f = e.target.files[0];
				if (!f) { return; }
				var reader = new FileReader();
				reader.onload = function () { window.hcImport = String(reader.result); };
				reader.readAsText(f);
			};
			input.click();
		""", true)
		_awaiting_file = true
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.hollow ; Hollow Creek designs"])
	fd.file_selected.connect(func(path: String) -> void:
		_import_code(FileAccess.get_file_as_string(path), false)
		fd.queue_free())
	add_child(fd)
	fd.popup_centered(Vector2i(800, 500))


func _process(_delta: float) -> void:
	if _awaiting_file and OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.hcImport || ''", true)
		if v is String and (v as String) != "":
			_awaiting_file = false
			JavaScriptBridge.eval("window.hcImport = null;", true)
			_import_code(v as String, false)


func _room_count(h: HouseData) -> int:
	var n := 0
	for l in h.levels():
		n += h.rooms(l).size()
	return n
