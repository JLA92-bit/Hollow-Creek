class_name PrologueHud
extends CanvasLayer
## The prologue's objective card (top left, under the clock): which step you're on, what to do, a
## checklist when there is one, and Continue on the steps that wait for you. Reads SimHost.prologue.

const NAVY := Color("#00294D")
const GREEN := Color("#2F7D45")
const MAROON := Color("#940E16")

var _card: PanelContainer
var _body: VBoxContainer
var _t := 0.0
var _sig := ""
var continue_button: Button
var _expanded := false   ## on a compact screen in build mode the card is a one line pill until tapped
var _pill_mode := false
var _coach_mode := false   ## compact screen outside build mode: title and the next instruction only
var _last_step := ""
var _pill_width := 170.0


func _ready() -> void:
	layer = 6
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFFFFEE")
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	_card.add_theme_stylebox_override("panel", sb)
	_card.position = Vector2(16, 128)
	_card.custom_minimum_size = Vector2(340, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_card.add_child(_body)
	SimHost.prologue_progressed.connect(func(done: Array) -> void:
		_sig = ""
		if "arrive" in done:
			_frame_road())
	_refresh()


func _process(delta: float) -> void:
	_avoid_build_palette()
	_update_pointer()
	_hide_under_roads_panel()
	_t -= delta
	if _t <= 0.0:
		_t = 0.4
		_refresh()


## In build mode the tool palette takes the top left corner, so the card moves to its right. On a
## compact screen (a phone held sideways) it shrinks to a one line pill that opens when tapped.
func _avoid_build_palette() -> void:
	var x := 16.0
	var y := 128.0
	var pill := false
	var coach := false
	var compact := Settings.is_compact(get_viewport().get_visible_rect().size.y)
	var panel := get_tree().get_first_node_in_group(&"build_panel") as BuildPanel
	if panel != null and panel.is_visible_in_tree():
		x = panel.palette_right() + 16.0
		if compact:
			x = panel.pill_rect().position.x
			y = panel.pill_rect().position.y
			_pill_width = panel.pill_rect().size.x - 28.0
			pill = true
	elif compact:
		y = 98.0
		coach = true
	if pill != _pill_mode or coach != _coach_mode:
		_pill_mode = pill
		_coach_mode = coach
		_sig = ""
	if not is_equal_approx(_card.position.x, x) or not is_equal_approx(_card.position.y, y):
		_card.position = Vector2(x, y)


func _refresh() -> void:
	var p := SimHost.prologue
	if p == null:
		_card.visible = false
		return
	var s := p.current()
	var list := p.checklist()
	if str(s.get("id", "")) != _last_step:
		_last_step = str(s.get("id", ""))
		_expanded = false
	var warn := _wrong_mode(s)
	var sig := "%s|%s|%s|%s|%s|%s|%d|%s" % [p.current_id(), str(list), Settings.get_value("hints"), _pill_mode, _expanded, warn, _how_done(s), _coach_mode]
	if sig == _sig:
		return
	_sig = sig
	_card.visible = not s.is_empty()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	continue_button = null
	if s.is_empty():
		return
	if _coach_mode and not _expanded:
		_card.custom_minimum_size = Vector2(0, 0)
		_card.reset_size()
		var t := Label.new()
		t.text = "%d/%d  %s" % [p.step + 1, p.steps().size(), str(s["title"])]
		t.add_theme_font_size_override("font_size", 18)
		t.add_theme_color_override("font_color", NAVY)
		_body.add_child(t)
		var how_now: Array = s.get("how", [])
		var next_line := str(s["text"])
		if warn != "":
			next_line = warn
		elif bool(Settings.get_value("hints")) and not how_now.is_empty():
			next_line = "%s" % how_now[mini(_how_done(s), how_now.size() - 1)]
		var nl := _para(next_line, MAROON if warn != "" else Color("#2A2A2A"), 15)
		nl.custom_minimum_size = Vector2(250, 0)
		_body.add_child(nl)
		if str(s["check"]) == "ack":
			continue_button = Button.new()
			continue_button.text = "Continue"
			continue_button.custom_minimum_size = Vector2(0, 48)
			continue_button.theme_type_variation = &"PrimaryButton"
			continue_button.pressed.connect(func() -> void:
				p.acknowledge()
				SimHost.refresh_story()
				_sig = "")
			_body.add_child(continue_button)
		var more := Button.new()
		more.text = "All steps"
		more.custom_minimum_size = Vector2(0, 44)
		more.pressed.connect(func() -> void:
			_expanded = true
			_sig = "")
		_body.add_child(more)
		return
	if _pill_mode and not _expanded:
		_card.custom_minimum_size = Vector2(0, 0)
		_card.reset_size()
		var pill := Button.new()
		pill.text = "%d/%d  %s  \u25BE" % [p.step + 1, p.steps().size(), str(s["title"])]
		pill.clip_text = true
		pill.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pill.custom_minimum_size = Vector2(_pill_width, 44)
		pill.add_theme_font_size_override("font_size", 15)
		pill.pressed.connect(func() -> void:
			_expanded = true
			_sig = "")
		_body.add_child(pill)
		return
	_card.custom_minimum_size = Vector2(340, 0)
	if _coach_mode:
		_card.custom_minimum_size = Vector2(300, 0)
	var head := Label.new()
	head.text = "PROLOGUE  ·  %d OF %d" % [p.step + 1, p.steps().size()]
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", Color("#4A5A6A"))
	_body.add_child(head)
	var title := Label.new()
	title.text = str(s["title"])
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", NAVY)
	_body.add_child(title)
	_body.add_child(_para(str(s["text"]), Color("#2A2A2A"), 16))
	for item: Dictionary in list:
		var row := _para("%s %s" % ["✓" if bool(item["done"]) else "○", item["text"]], GREEN if bool(item["done"]) else Color("#4A5A6A"), 15)
		_body.add_child(row)
	if warn != "":
		_body.add_child(_para(warn, MAROON, 16))
	if bool(Settings.get_value("hints")):
		var how: Array = s.get("how", [])
		var ticked := _how_done(s)
		for i in how.size():
			if i < ticked:
				_body.add_child(_para("\u2713  %s" % how[i], GREEN, 15))
			else:
				_body.add_child(_para("%d.  %s" % [i + 1, how[i]], NAVY, 15))
		if str(s["hint"]) != "":
			_body.add_child(_para(str(s["hint"]), Color("#4A5A6A"), 14))
	if str(s["check"]) == "ack":
		continue_button = Button.new()
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(0, 48)
		continue_button.theme_type_variation = &"PrimaryButton"
		continue_button.pressed.connect(func() -> void:
			p.acknowledge()
			SimHost.refresh_story()
			_sig = "")
		_body.add_child(continue_button)
	if _pill_mode or _coach_mode:
		var hide := Button.new()
		hide.text = "Hide"
		hide.custom_minimum_size = Vector2(0, 44)
		hide.pressed.connect(func() -> void:
			_expanded = false
			_sig = "")
		_body.add_child(hide)


## The world this card belongs to (it is added as a child of the world).
func _world() -> Node:
	return get_parent()


## On a phone the Roads panel needs the middle of the screen and says what to do itself, so the card steps aside.
func _hide_under_roads_panel() -> void:
	var w := _world()
	if w == null or SimHost.prologue == null:
		return
	var road: RoadMode = w.get("road")
	var covered := _coach_mode and road != null and road.active
	_card.visible = not covered and not SimHost.prologue.current().is_empty()


## Which toolbar button to flash: the one the current step wants, unless the player is already
## inside a tool (building, laying roads) where the toolbar is hidden or busy.
func _update_pointer() -> void:
	var w := _world()
	if w == null or SimHost.prologue == null:
		return
	var hud: Node = w.get("hud")
	if hud == null:
		return
	var want := str(SimHost.prologue.current().get("point_at", ""))
	var road: RoadMode = w.get("road")
	if bool(w.get("building")) or (road != null and road.active):
		want = ""
	hud.call("point_at", want)


## How many of the step's how-to lines the player has already done, so they can see where they are.
func _how_done(s: Dictionary) -> int:
	var w := _world()
	if w == null:
		return 0
	var road: RoadMode = w.get("road")
	match str(s.get("id", "")):
		"road":
			return 1 if road != null and road.active else 0
		"store", "houses":
			return 1 if bool(w.get("building")) else 0
	return 0


## A line for when the player is in the wrong place for the step (the usual way to get lost).
func _wrong_mode(s: Dictionary) -> String:
	var w := _world()
	if w == null or s.is_empty():
		return ""
	var road: RoadMode = w.get("road")
	var id := str(s.get("id", ""))
	if id == "road" and road != null and road.active:
		return "The Roads panel is open. Tap Follow the ghost path."
	if bool(w.get("building")) and str(s.get("point_at", "")) in ["Roads", "Residents", "Case file"]:
		return "You are in Build mode. Tap Done (bottom right) first."
	return ""


## When the road step begins, swing the camera high over the yellow dots so the path is in view.
func _frame_road() -> void:
	var w := _world()
	if w == null or SimHost.prologue == null:
		return
	var rig: CameraRig = w.get("rig")
	var slice: MapSlice = w.get("slice")
	if rig == null or slice == null:
		return
	var pts: Array = SimHost.prologue.data["road"]["points"]
	var a: Array = pts[0]
	var b: Array = pts[pts.size() - 1]
	var c := Vector2((float(a[0]) + float(b[0])) * 0.5, (float(a[1]) + float(b[1])) * 0.5)
	rig.set_view(Vector3(c.x, slice.grid.height_at(c.x, c.y), c.y), 180.0, 55.0, 62.0)


func _para(t: String, c: Color, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l
