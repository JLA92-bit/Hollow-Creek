class_name ResidentsList
extends PanelContainer
## The Residents list: every household, who's in it and where they live, and the families waiting
## at the siding with their briefs. Offer a waiting family any finished, empty house; they say
## beforehand what they'd make of it, and react when they move in.

signal resident_chosen(rid: String)
signal moved_in(hid: String, reaction: Dictionary)

const MAROON := Color("#940E16")
const VERDICT_COLOURS := {"delighted": Color("#3F8F4C"), "content": Color("#00294D"), "disappointed": Color("#940E16")}

var _body: VBoxContainer
var _t := 0.0
var _sig := ""


func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(360, 480)
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	SimHost.town_changed.connect(func() -> void: _sig = "")
	refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		refresh()


## Rebuilds the list when who lives where (or which houses stand empty) has changed.
func refresh() -> void:
	var sim := SimHost.sim
	var sig := "%s|%s" % [JSON.stringify(SimHost.waiting()), JSON.stringify(SimHost.vacant_houses())]
	for hid: String in sim.households:
		sig += str(sim.households[hid].get("home", ""))
	if sig == _sig:
		return
	_sig = sig
	for c in _body.get_children():
		c.queue_free()
	var title := Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = "Residents"
	_body.add_child(title)
	var ids := sim.households.keys()
	ids.sort()
	for hid: String in ids:
		if str(sim.households[hid].get("home", "")) != "":
			_household(hid)
	var waiting := SimHost.waiting()
	if not waiting.is_empty():
		var w := Label.new()
		w.text = "WAITING AT THE SIDING"
		w.add_theme_font_size_override("font_size", 13)
		w.add_theme_color_override("font_color", Color("#5A6472"))
		_body.add_child(w)
		for hid: String in waiting:
			_household(hid)


func _household(hid: String) -> void:
	var sim := SimHost.sim
	var h: Dictionary = sim.households[hid]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F7F8FA")
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var name_l := Label.new()
	name_l.text = "The %ss" % h["name"]
	name_l.add_theme_font_override("font", load("res://assets/fonts/Fraunces.ttf") as Font)
	name_l.add_theme_font_size_override("font_size", 19)
	v.add_child(name_l)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for rid in sim.members(hid):
		var b := Button.new()
		b.text = str(sim.residents[rid]["first"])
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: resident_chosen.emit(rid))
		row.add_child(b)
	v.add_child(row)
	var home := str(h.get("home", ""))
	if home != "":
		v.add_child(_text("%s · rent £%d a week" % [SimHost.house_name(home), int(h.get("rent", 0))] if int(h.get("rent", 0)) > 0 else SimHost.house_name(home)))
	else:
		var brief: Dictionary = (sim.data["households"][hid] as Dictionary).get("brief", {})
		var bl := _text("“%s”" % str(brief.get("text", "Anywhere with a roof.")))
		bl.add_theme_font_override("font", load("res://assets/fonts/Caveat.ttf") as Font)
		bl.add_theme_font_size_override("font_size", 20)
		v.add_child(bl)
		var vac := SimHost.vacant_houses()
		if vac.is_empty():
			v.add_child(_text("No empty houses yet. Build one, and they'll take a look."))
		for house_id in vac:
			var pre := SimHost.preview_reaction(hid, house_id)
			var verdict := str(pre.get("verdict", "content"))
			var ob := Button.new()
			ob.text = "Offer %s (they'd be %s)" % [SimHost.house_name(house_id), verdict]
			ob.tooltip_text = "\n".join(PackedStringArray((pre.get("pros", []) as Array) + (pre.get("cons", []) as Array)))
			ob.custom_minimum_size = Vector2(0, 44)
			ob.focus_mode = Control.FOCUS_NONE
			ob.add_theme_color_override("font_color", VERDICT_COLOURS.get(verdict, Color.BLACK))
			ob.pressed.connect(func() -> void:
				var res := SimHost.offer_home(hid, house_id)
				moved_in.emit(hid, res)
				_sig = ""
				refresh())
			v.add_child(ob)
	_body.add_child(card)


func _text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	return l
