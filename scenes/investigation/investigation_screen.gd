class_name InvestigationScreen
extends Control
## The investigation screen (docs/mockups/ui-layout-investigation.png). The left is the scene itself:
## the real 3D world seen through with walls down, tap-targets where traces can be found and numbered
## markers where they were. The right is the interview (live portrait, statement, Press and Present),
## the case file, the deductions to fill in, and the warrant and accusation. All the rules are in
## Investigation; this only draws them and passes taps through.
##
## Controls are kept in public dictionaries so the scripted demo can tap the same buttons a player does.

signal closed
signal finished(result: Dictionary)

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")
const GREEN := Color("#2F7D45")
const PAPER := Color("#F4F1EA")
const MONO := "res://assets/fonts/CourierPrime-Regular.ttf"
const PANEL_W := 560.0

var inv: Investigation
var anchor := Vector3.ZERO          ## world position of the scene's origin tile
var person := ""                    ## who is being interviewed
var fact := ""                      ## what's selected in the case file
var reaction := ""                  ## the last thing said
var hotspots: Dictionary = {}       ## trace id -> Button (not yet found)
var markers: Dictionary = {}        ## trace id -> Button (found)
var person_chips: Dictionary = {}
var fact_chips: Dictionary = {}
var slot_options: Dictionary = {}   ## deduction id -> {slot key -> OptionButton}
var link_buttons: Dictionary = {}
var press_button: Button
var present_button: Button
var measure_button: Button
var warrant_button: Button
var warrant_choice: OptionButton
var accuse_button: Button
var accuse_choice: OptionButton
var accuse_confirm: Button
var resolution_buttons: Dictionary = {}
var caption := ""

var _synced := 0
var _marker_layer: Control
var _body: VBoxContainer
var _scroll: ScrollContainer
var _portrait: PortraitView
var _caption_label: Label
var _traces_chip: Label
var _time_label: Label
var _overlay: PanelContainer
var _overlay_body: VBoxContainer
var _last_trace := ""
var _group: ButtonGroup


func _ready() -> void:
	# Under a CanvasLayer there's no parent rect to anchor to, so follow the viewport.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit()
	get_viewport().size_changed.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_layer = Control.new()
	_marker_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_layer)
	_header()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("#FFFFFFF2"), 14, 14))
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = -PANEL_W - 16
	card.offset_right = -16
	card.offset_top = 16
	card.offset_bottom = -16
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 18)
	_scroll.add_child(pad)
	pad.add_child(_body)
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", _box(Color("#EEF6EF"), 10, 10))
	cap.anchor_top = 1.0
	cap.anchor_bottom = 1.0
	cap.offset_left = 16
	cap.offset_right = -PANEL_W - 32
	cap.anchor_right = 1.0
	cap.offset_top = -86
	cap.offset_bottom = -16
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)
	_caption_label = Label.new()
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.add_theme_color_override("font_color", NAVY)
	_caption_label.add_theme_font_size_override("font_size", 17)
	cap.add_child(_caption_label)
	_overlay = PanelContainer.new()
	_overlay.add_theme_stylebox_override("panel", _box(Color("#FFFFFF"), 16, 18))
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.custom_minimum_size = Vector2(520, 0)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.visible = false
	add_child(_overlay)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 10)
	_overlay.add_child(_overlay_body)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## Open a case. `p_anchor` is where the scene's tile (0, 0) is in the world.
func open(p_inv: Investigation, p_anchor: Vector3) -> void:
	inv = p_inv
	anchor = p_anchor
	_synced = inv.minutes_spent
	var ids := (inv.data["people"] as Dictionary).keys()
	person = str(ids[0])
	_build_hotspots()
	_rebuild()
	set_caption("Search the scene. Tap where something looks wrong.")
	visible = true


func set_caption(t: String) -> void:
	caption = t
	if _caption_label:
		_caption_label.text = t


# --- Scene ------------------------------------------------------------------------------------------

func _trace_world(t: Dictionary) -> Vector3:
	var p: Array = t["pos"]
	return anchor + Vector3(float(p[0]) + 0.5, 0.9, float(p[1]) + 0.5)


func _build_hotspots() -> void:
	for c in _marker_layer.get_children():
		c.queue_free()
	hotspots.clear()
	markers.clear()
	for t: Dictionary in inv.traces():
		var id := str(t["id"])
		if inv.found.has(id):
			_add_marker(id)
			continue
		var b := _round_button("?", Color("#FFFFFF"), NAVY)
		b.tooltip_text = str(t["prompt"])
		b.pressed.connect(tap_trace.bind(id))
		_marker_layer.add_child(b)
		hotspots[id] = b


func _add_marker(id: String) -> void:
	var b := _round_button(str(inv.found.find(id) + 1), MAROON, Color("#FFFFFF"))
	b.pressed.connect(tap_trace.bind(id))
	_marker_layer.add_child(b)
	markers[id] = b


func _round_button(text: String, fill: Color, ink: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(44, 44)
	b.size = Vector2(44, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	var sb := _box(fill, 22, 0)
	sb.border_color = Color("#FFFFFF") if fill != Color("#FFFFFF") else NAVY
	sb.set_border_width_all(3)
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, sb)
	return b


func _process(_delta: float) -> void:
	if inv == null or not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for id: String in hotspots:
		_place(hotspots[id] as Button, cam, inv.trace(id))
	for id: String in markers:
		_place(markers[id] as Button, cam, inv.trace(id))


func _place(b: Button, cam: Camera3D, t: Dictionary) -> void:
	var w := _trace_world(t)
	var behind := cam.is_position_behind(w)
	b.visible = not behind
	if not behind:
		b.position = cam.unproject_position(w) - b.size * 0.5


## Tap a trace (or its marker): search it the first time, read it again after.
func tap_trace(id: String) -> void:
	var r := inv.search(id)
	if not r["ok"]:
		return
	if not bool(r.get("again", false)):
		AudioDirector.play_cue("found")
	_last_trace = id
	AudioDirector.play_cue("search" if hotspots.has(id) else "knock")
	if hotspots.has(id):
		(hotspots[id] as Button).queue_free()
		hotspots.erase(id)
		_add_marker(id)
	var t := inv.trace(id)
	var text := str(r["text"])
	if t.has("measure") and not inv.knows(str(t["measure"]["fact"])):
		text += "  [Measure it below]"
	set_caption("%d. %s" % [int(r["number"]), text])
	_sync_clock()
	_rebuild()


func measure_last() -> void:
	var m := inv.measure(_last_trace)
	if m["ok"]:
		set_caption("Measured: %s" % m["text"])
		_sync_clock()
		_rebuild()


# --- Interview ---------------------------------------------------------------------------------------

func pick_person(pid: String) -> void:
	person = pid
	fact = ""
	var r := inv.interview(pid, Clock.day)
	reaction = str(r.get("text", "")) if bool(r.get("refused", false)) else ""
	_sync_clock()
	_rebuild()


func tap_press() -> void:
	var r := inv.press(person, Clock.day)
	reaction = str(r.get("text", ""))
	_sync_clock()
	_rebuild()


func tap_present() -> void:
	if fact == "":
		return
	var r := inv.present(person, fact, Clock.day)
	reaction = str(r.get("text", ""))
	_sync_clock()
	_rebuild()


func select_fact(f: String) -> void:
	fact = f if fact != f else ""
	_rebuild()


# --- Case board ---------------------------------------------------------------------------------------

func tap_link(id: String) -> void:
	var answers := {}
	for k: String in (slot_options.get(id, {}) as Dictionary):
		var ob: OptionButton = slot_options[id][k]
		answers[k] = ob.get_item_text(ob.selected)
	var r := inv.link(id, answers)
	if bool(r["proven"]):
		set_caption("Proven: %s" % _filled(inv.deduction(id)))
	elif str(r["reason"]) == "wrong":
		set_caption("That doesn't fit what you've found.")
	else:
		set_caption("You haven't got the evidence for that yet.")
	_rebuild()


func tap_warrant() -> void:
	if warrant_choice == null:
		return
	var hh := str(warrant_choice.get_item_metadata(warrant_choice.selected))
	var r := inv.request_warrant(hh)
	set_caption(str(r["text"]))
	_sync_clock()
	_bank()
	_rebuild()


func open_accuse() -> void:
	_overlay.visible = true
	_rebuild_overlay()


func tap_accuse() -> void:
	var pid := str(accuse_choice.get_item_metadata(accuse_choice.selected))
	inv.accuse(pid)
	_bank()
	_rebuild_overlay()
	_rebuild()


func tap_resolve(id: String) -> void:
	inv.resolve(id)
	_bank()
	_rebuild_overlay()
	_rebuild()
	if inv.closed():
		finished.emit(result())


func result() -> Dictionary:
	return {"accused": inv.accused, "outcome": inv.outcome.duplicate(true), "resolution": inv.resolution, "unlocked": inv.unlocked.duplicate(),
		"minutes": inv.minutes_spent}


func _bank() -> void:
	if SimHost.has_method("bank_case"):
		SimHost.call("bank_case")


## In-game time spent on the case moves the clock.
func _sync_clock() -> void:
	var owed := inv.minutes_spent - _synced
	_synced = inv.minutes_spent
	for i in maxi(0, owed):
		Clock.advance_minute()
	if _time_label:
		_time_label.text = _clock_text()


func _clock_text() -> String:
	return Clock.time_label(Clock.minute)


# --- Drawing ------------------------------------------------------------------------------------------

func _header() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(Color("#FFFFFFE6"), 12, 10))
	bar.offset_left = 16
	bar.offset_top = 16
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", NAVY)
	row.add_child(title)
	_time_label = Label.new()
	_time_label.add_theme_color_override("font_color", Color("#4A5A6A"))
	row.add_child(_time_label)
	_traces_chip = Label.new()
	_traces_chip.add_theme_color_override("font_color", MAROON)
	_traces_chip.add_theme_font_size_override("font_size", 16)
	row.add_child(_traces_chip)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(70, 44)
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	row.add_child(close)


func _rebuild() -> void:
	var keep := _scroll.scroll_vertical
	for c in _body.get_children():
		c.queue_free()
	person_chips.clear()
	fact_chips.clear()
	slot_options.clear()
	link_buttons.clear()
	_group = ButtonGroup.new()
	var title := find_child("Title", true, false) as Label
	if title:
		title.text = inv.title()
	_time_label.text = "%s · Day %d" % [_clock_text(), Clock.day]
	_traces_chip.text = "Traces found %d of %d" % [inv.traces_found(), inv.traces().size()]
	_people_row()
	_interview()
	_case_file()
	_deductions()
	_actions()
	await get_tree().process_frame
	_scroll.scroll_vertical = keep


func _people_row() -> void:
	_body.add_child(_heading("INTERVIEW"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for pid: String in (inv.data["people"] as Dictionary):
		var b := Button.new()
		b.text = _first_name(pid)
		b.toggle_mode = true
		b.button_pressed = pid == person
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(pick_person.bind(pid))
		flow.add_child(b)
		person_chips[pid] = b
	_body.add_child(flow)


func _first_name(pid: String) -> String:
	var d: Dictionary = (SimHost.sim.data["residents"] as Dictionary).get(pid, {}) if SimHost.sim else {}
	return str(d.get("first", pid))


func _full_name(pid: String) -> String:
	var d: Dictionary = (SimHost.sim.data["residents"] as Dictionary).get(pid, {}) if SimHost.sim else {}
	return "%s %s" % [d.get("first", pid), d.get("last", "")]


func _interview() -> void:
	var p := inv.person(person)
	var ps: Dictionary = inv.people[person]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_portrait = PortraitView.new()
	head.add_child(_portrait)
	if SimHost.sim:
		_portrait.show_resident(person, (SimHost.sim.data["residents"] as Dictionary).get(person, {}))
	_portrait.set_mood(float(ps["composure"]), float(ps["pressure"]), bool(ps["confessed"]))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	var role := _small("INTERVIEW · %s" % str(p.get("role", "")).to_upper())
	col.add_child(role)
	var name_l := Label.new()
	name_l.text = _full_name(person)
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", NAVY)
	col.add_child(name_l)
	col.add_child(_small(str(p.get("note", ""))))
	col.add_child(_meter("Composure", int(ps["composure"]), NAVY))
	if inv.has_pressure(person):
		col.add_child(_meter("Pressure", int(ps["pressure"]), MAROON))
	head.add_child(col)
	_body.add_child(head)
	var st := inv.current_statement(person)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PAPER, 12, 12))
	var v := VBoxContainer.new()
	card.add_child(v)
	var n := inv.statements(person).size()
	var i := mini(int(ps["index"]) + 1, n)
	if bool(ps["met"]):
		v.add_child(_small("STATEMENT %d OF %d" % [i, n]))
		var q := _mono('"%s"' % str(st.get("text", "(nothing more to say)")), 17)
		v.add_child(q)
	else:
		v.add_child(_mono("Tap their name to start talking.", 16))
	if reaction != "":
		var rl := _mono(reaction, 15)
		rl.add_theme_color_override("font_color", MAROON)
		v.add_child(rl)
	if bool(ps["confessed"]):
		var cl := _small("CONFESSED")
		cl.add_theme_color_override("font_color", MAROON)
		v.add_child(cl)
	_body.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	press_button = Button.new()
	press_button.text = "Press"
	press_button.custom_minimum_size = Vector2(0, 48)
	press_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	press_button.disabled = not bool(ps["met"]) or not inv.can_talk(person, Clock.day)
	press_button.pressed.connect(tap_press)
	row.add_child(press_button)
	present_button = Button.new()
	present_button.text = "Present: %s" % (inv.label_of(fact) if fact != "" else "pick from the case file")
	present_button.custom_minimum_size = Vector2(0, 48)
	present_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	present_button.disabled = fact == "" or not bool(ps["met"]) or not inv.can_talk(person, Clock.day)
	present_button.clip_text = true
	present_button.pressed.connect(tap_present)
	row.add_child(present_button)
	_body.add_child(row)


func _case_file() -> void:
	_body.add_child(_heading("CASE FILE"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for f in inv.presentable():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _group
		b.button_pressed = f == fact
		b.text = _short(f)
		b.tooltip_text = inv.label_of(f)
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(select_fact.bind(f))
		flow.add_child(b)
		fact_chips[f] = b
	_body.add_child(flow)
	if _last_trace != "" and inv.trace(_last_trace).has("measure") and inv.found.has(_last_trace):
		measure_button = Button.new()
		measure_button.text = "Measure the %s" % str(inv.trace(_last_trace)["label"]).to_lower()
		measure_button.custom_minimum_size = Vector2(0, 44)
		measure_button.disabled = inv.knows(str(inv.trace(_last_trace)["measure"]["fact"]))
		measure_button.pressed.connect(measure_last)
		_body.add_child(measure_button)
	else:
		measure_button = null


## A chip label: the trace or record's short name, else the statement's first words.
func _short(f: String) -> String:
	if inv.short_of(f) != "":
		return inv.short_of(f)
	var r := inv.record(f)
	if not r.is_empty():
		return str(r["name"])
	var t := inv.trace(f)
	if not t.is_empty():
		var s := str(t["label"])
		return s if s.length() <= 22 else s.substr(0, 20) + "..."
	var l := inv.label_of(f)
	if f.ends_with("_measured"):
		return l
	if f == "confession_len":
		return "Confession"
	return "Statement: " + (l if l.length() <= 18 else l.substr(0, 16) + "...")


func _deductions() -> void:
	_body.add_child(_heading("DEDUCTIONS"))
	for d: Dictionary in inv.deductions():
		var id := str(d["id"])
		if not inv.supported(id) and not inv.proven.has(id):
			continue
		var card := PanelContainer.new()
		var done := inv.proven.has(id)
		card.add_theme_stylebox_override("panel", _box(Color("#E9F5EC") if done else Color("#FFFFFF"), 10, 10))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		if done:
			v.add_child(_text("%s  ·  proven" % _filled(d), GREEN))
		else:
			var flow := HFlowContainer.new()
			var sentence := str(d["sentence"])
			var opts := {}
			var parts := sentence.split("[")
			flow.add_child(_text(parts[0], NAVY))
			for k in range(1, parts.size()):
				var seg := parts[k].split("]")
				var key := seg[0]
				var slot := _slot(d, key)
				var ob := OptionButton.new()
				ob.custom_minimum_size = Vector2(120, 40)
				ob.add_item("?")
				for o in slot.get("options", []):
					ob.add_item(str(o))
				ob.selected = 0
				flow.add_child(ob)
				opts[key] = ob
				if seg.size() > 1:
					flow.add_child(_text(seg[1], NAVY))
			slot_options[id] = opts
			v.add_child(flow)
			var lb := Button.new()
			lb.text = "Link"
			lb.custom_minimum_size = Vector2(0, 44)
			lb.pressed.connect(tap_link.bind(id))
			v.add_child(lb)
			link_buttons[id] = lb
		_body.add_child(card)


func _slot(d: Dictionary, key: String) -> Dictionary:
	for s: Dictionary in d.get("slots", []):
		if str(s["key"]) == key:
			return s
	return {}


## A deduction's sentence with its answers filled in.
func _filled(d: Dictionary) -> String:
	var s := str(d["sentence"])
	var ans: Dictionary = d.get("answer", {})
	for k: String in ans:
		s = s.replace("[%s]" % k, str((ans[k] as Array)[0]) if ans[k] is Array else str(ans[k]))
	return s


func _actions() -> void:
	_body.add_child(_heading("WARRANT AND ACCUSATION"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	warrant_choice = OptionButton.new()
	warrant_choice.custom_minimum_size = Vector2(0, 44)
	warrant_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var i := 0
	for hid: String in _households():
		warrant_choice.add_item("Search the %s house" % hid.trim_prefix("h_").capitalize())
		warrant_choice.set_item_metadata(i, hid)
		i += 1
	row.add_child(warrant_choice)
	warrant_button = Button.new()
	warrant_button.text = "Warrant"
	warrant_button.custom_minimum_size = Vector2(110, 44)
	warrant_button.disabled = inv.warrant_used and inv.warrant_target == "h_pike"
	warrant_button.pressed.connect(tap_warrant)
	row.add_child(warrant_button)
	_body.add_child(row)
	var note := _small("A wrong search costs 5 Town Trust and sours the household.")
	_body.add_child(note)
	accuse_button = Button.new()
	accuse_button.text = "Accuse..." if inv.accused == "" else ("Accused: %s" % _full_name(inv.accused))
	accuse_button.custom_minimum_size = Vector2(0, 52)
	accuse_button.disabled = inv.accused != ""
	accuse_button.pressed.connect(open_accuse)
	_body.add_child(accuse_button)


func _households() -> Array[String]:
	var out: Array[String] = []
	if SimHost.sim:
		for hid: String in SimHost.sim.households:
			if str(hid).begins_with("h_"):
				out.append(hid)
	out.sort()
	return out


func _rebuild_overlay() -> void:
	for c in _overlay_body.get_children():
		c.queue_free()
	resolution_buttons.clear()
	var t := Label.new()
	t.text = "Make your accusation"
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", NAVY)
	_overlay_body.add_child(t)
	if inv.accused == "":
		accuse_choice = OptionButton.new()
		accuse_choice.custom_minimum_size = Vector2(0, 48)
		var i := 0
		for pid: String in (inv.data["people"] as Dictionary):
			accuse_choice.add_item(_full_name(pid))
			accuse_choice.set_item_metadata(i, pid)
			i += 1
		_overlay_body.add_child(accuse_choice)
		var req := inv.requirements()
		for k: String in ["opportunity", "means", "motive", "lie"]:
			_overlay_body.add_child(_text("%s %s" % ["✓" if bool(req[k]) else "·", k.capitalize() if k != "lie" else "A broken lie"], GREEN if bool(req[k]) else Color("#7A7468")))
		accuse_confirm = Button.new()
		accuse_confirm.text = "Accuse"
		accuse_confirm.custom_minimum_size = Vector2(0, 52)
		accuse_confirm.pressed.connect(tap_accuse)
		_overlay_body.add_child(accuse_confirm)
		var back := Button.new()
		back.text = "Not yet"
		back.custom_minimum_size = Vector2(0, 44)
		back.pressed.connect(func() -> void: _overlay.visible = false)
		_overlay_body.add_child(back)
		return
	_overlay_body.add_child(_text(str(inv.outcome["text"]), NAVY))
	if bool(inv.outcome["right"]) and bool(inv.outcome["complete"]) and inv.resolution == "":
		for r: Dictionary in inv.resolutions():
			var b := Button.new()
			b.text = "%s: %s" % [r["label"], r["text"]]
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(0, 64)
			b.pressed.connect(tap_resolve.bind(str(r["id"])))
			_overlay_body.add_child(b)
			resolution_buttons[str(r["id"])] = b
	elif inv.resolution != "":
		for r: Dictionary in inv.resolutions():
			if str(r["id"]) == inv.resolution:
				_overlay_body.add_child(_text(str(r["text"]), GREEN))
		_overlay_body.add_child(_text(str(inv.data.get("tip", "")), Color("#4A5A6A")))
	var done := Button.new()
	done.text = "Close the case file" if inv.closed() else "Back"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(func() -> void:
		_overlay.visible = false
		if inv.closed():
			visible = false
			closed.emit())
	_overlay_body.add_child(done)


# --- Small widgets ---------------------------------------------------------------------------------

static func _box(c: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _heading(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("#4A5A6A"))
	return l


func _small(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("#4A5A6A"))
	return l


func _text(t: String, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", c)
	l.add_theme_font_size_override("font_size", 17)
	return l


func _mono(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", load(MONO) as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#2A2A2A"))
	return l


func _meter(label: String, v: int, c: Color) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(92, 0)
	l.add_theme_font_size_override("font_size", 15)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = v
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fg := _box(c, 7, 0)
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", _box(Color("#E4E6E8"), 7, 0))
	row.add_child(bar)
	var n := Label.new()
	n.text = str(v)
	n.add_theme_font_size_override("font_size", 15)
	row.add_child(n)
	return row
