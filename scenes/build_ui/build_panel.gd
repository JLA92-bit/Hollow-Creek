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
	"arch": "Arch", "floor": "Floor", "paint": "Paint", "stairs": "Stairs", "post": "Post", "demolish": "Demolish"}
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
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	p.add_child(grid)
	for t: String in BuildMode.TOOLS:
		var b := Button.new()
		b.text = TOOL_LABELS[t]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 46)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void: build.set_tool(t))
		grid.add_child(b)
		_tools[t] = b
	for t2: String in ["Roof", "Verandah", "Furnish"]:
		var b2 := Button.new()
		b2.text = t2
		b2.disabled = true
		b2.custom_minimum_size = Vector2(84, 46)
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
	for b in [_cancel_btn, _confirm_btn, _undo_btn, _redo_btn, done]:
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
		_house_box.add_child(_text("Use the Room tool on open ground to start.", 14, SECONDARY))
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
	# Validation hints.
	var hints := h.validate()
	if hints.is_empty():
		_house_box.add_child(_text("No problems spotted.", 14, Color("#2E7D3E")))
	else:
		for hint in hints.slice(0, 4):
			_house_box.add_child(_text(hint, 14, MAROON))
		if hints.size() > 4:
			_house_box.add_child(_text("and %d more." % (hints.size() - 4), 13, SECONDARY))


func _room_count(h: HouseData) -> int:
	var n := 0
	for l in h.levels():
		n += h.rooms(l).size()
	return n
