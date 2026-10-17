class_name ResidentPanel
extends PanelContainer
## The resident card (docs/mockups/ui-layout-town.png): name, age and job, traits, needs and mood,
## what they're doing, their home and wishes, the people who matter to them, and what happened lately.

signal closed
signal follow(rid: String)

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")
const BARS := {"energy": Color("#FBAD45"), "social": Color("#F26839"), "hunger": Color("#5CBD6C"), "fun": Color("#4BC9F5"), "mood": Color("#00294D")}
const DOING := {"sleep": "Asleep", "cook": "Cooking a meal", "snack": "Having a bite to eat", "wireless": "Listening to the wireless",
	"sit": "Sitting down for a spell", "garden": "Pottering in the garden", "shop": "Shopping at the store", "fish": "Fishing at the creek",
	"potter": "Pottering about at home", "idle": "Standing about", "sit_up": "Sitting up late", "loiter": "Hanging about"}
const GOING := {"sleep": "Off to bed", "cook": "Going to cook", "snack": "Going for a bite", "wireless": "Going to the wireless",
	"sit": "Going to sit down", "garden": "Heading into the garden", "shop": "Walking to the store", "fish": "Walking down to the creek",
	"potter": "Heading home", "idle": "Out walking", "sit_up": "Going to sit up", "loiter": "Out walking"}

var rid := ""
var _body: VBoxContainer
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(300, 452)
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)


func show_resident(id: String) -> void:
	rid = id
	visible = true
	_rebuild()


func _process(delta: float) -> void:
	if not visible or rid == "":
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_rebuild()


static func job_name(sim: Sim, r: Dictionary) -> String:
	var j := str(r["job"])
	if j == "retired":
		return "Retired"
	return str((sim.data["jobs"] as Dictionary).get(j, {}).get("name", j.capitalize()))


## What someone's up to, in words: "Walking to the store", "Working at the mill".
static func doing(sim: Sim, r: Dictionary) -> String:
	var act: Dictionary = r["action"]
	var kind := str(act.get("kind", "idle"))
	var walking := not (r["route"] as Array).is_empty()
	var place := str(act.get("place", ""))
	if kind == "work":
		var where := "at the mill" if place == "lm_mill" else "at the telephone exchange" if place.ends_with("exchange") else "in the shop" if place.ends_with("shop") else "at home" if place == "home" else "at work"
		return ("Off to work %s" if walking else "Working %s") % where
	if kind == "visit":
		var who := place.trim_prefix("visit:")
		var name := str((sim.residents.get(who, {}) as Dictionary).get("first", "a friend"))
		return ("Walking over to see %s" if walking else "Visiting %s") % name
	return str((GOING if walking else DOING).get(kind, "Busy"))


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var sim := SimHost.sim
	if not sim.residents.has(rid):
		return
	var r: Dictionary = sim.residents[rid]
	var d: Dictionary = (sim.data["residents"] as Dictionary).get(rid, {})
	var head := HBoxContainer.new()
	var name_l := Label.new()
	name_l.theme_type_variation = &"HeadingLabel"
	name_l.text = "%s %s" % [r["first"], r["last"]]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name_l)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "Close"
	close.custom_minimum_size = Vector2(44, 44)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	head.add_child(close)
	_body.add_child(head)
	_body.add_child(_small("%d · %s" % [int(r["age"]), job_name(sim, r)]))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for t: String in r["traits"]:
		chips.add_child(_chip(t.capitalize()))
	_body.add_child(chips)
	for n: String in ["energy", "social", "hunger", "fun"]:
		_body.add_child(_bar(n.capitalize(), float(r["needs"][n]), BARS[n]))
	_body.add_child(_bar("Mood", float(r["mood"]), BARS["mood"]))
	_body.add_child(_heading("NOW"))
	_body.add_child(_text(doing(sim, r) if r["status"] == "living" else "Waiting at the siding for a home"))
	# What they remember (newest first), as in the town mockup.
	var mem: Array = r.get("memories", [])
	if not mem.is_empty():
		_body.add_child(_heading("RECENT MEMORY"))
		for i in range(mem.size() - 1, maxi(-1, mem.size() - 3), -1):
			var m: Dictionary = mem[i]
			var card2 := PanelContainer.new()
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color("#F4F1EA")
			sb2.set_corner_radius_all(8)
			sb2.set_content_margin_all(8)
			card2.add_theme_stylebox_override("panel", sb2)
			var v2 := VBoxContainer.new()
			card2.add_child(v2)
			var ml := _text("%s · %s" % [Clock.time_label(int(m["minute"])), Memories.describe(sim, m)])
			ml.add_theme_font_override("font", load("res://assets/fonts/CourierPrime-Regular.ttf") as Font)
			ml.add_theme_font_size_override("font_size", 14)
			v2.add_child(ml)
			var cl := _text("Confidence: %s" % Memories.confidence_word(float(m["confidence"])))
			cl.add_theme_font_override("font", load("res://assets/fonts/CourierPrime-Regular.ttf") as Font)
			cl.add_theme_font_size_override("font_size", 14)
			cl.add_theme_color_override("font_color", MAROON)
			v2.add_child(cl)
			_body.add_child(card2)
	# Home and wishes.
	var hid := str(r["household"])
	var home := str(sim.households[hid].get("home", ""))
	_body.add_child(_heading("HOME"))
	if home == "":
		_body.add_child(_text("No home yet. Offer one from the Residents list."))
	else:
		var score := float(sim.home_scores.get(home, 0.0))
		var rent := int(sim.households[hid].get("rent", 0))
		_body.add_child(_text("%s · home score %d%s" % [SimHost.house_name(home), roundi(score), " · rent £%d a week" % rent if rent > 0 else ""]))
	for wid: String in sim.wishes:
		var w: Dictionary = sim.wishes[wid]
		if str(w["owner"]) != rid:
			continue
		var met := int(w["met"]) >= 0
		var l := _text(("✓ " if met else "Wish: ") + str(w["text"]))
		l.add_theme_color_override("font_color", Color("#3F8F4C") if met else MAROON)
		_body.add_child(l)
	# People.
	var people: Array = []
	for k: String in sim.relationships:
		if not k.begins_with(rid + ">"):
			continue
		var other := k.substr(rid.length() + 1)
		var rel: Dictionary = sim.relationships[k]
		var weight := absf(float(rel["friendship"])) + float(rel["romance"])
		if weight >= 15.0 and sim.residents.has(other):
			people.append([weight, other])
	people.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and str(a[1]) < str(b[1])))
	if not people.is_empty():
		_body.add_child(_heading("PEOPLE"))
		for p: Array in people.slice(0, 4):
			_body.add_child(_text("%s · %s" % [sim.residents[p[1]]["first"], sim.rel_label(rid, str(p[1]))]))
	# Lately.
	var lately: Array = []
	for i in range(sim.events.size() - 1, -1, -1):
		var e: Dictionary = sim.events[i]
		if str(e.get("who", "")) == rid:
			lately.append(e)
		if lately.size() >= 3:
			break
	if not lately.is_empty():
		_body.add_child(_heading("LATELY"))
		for e: Dictionary in lately:
			var card := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#F4F1EA")
			sb.set_corner_radius_all(8)
			sb.set_content_margin_all(8)
			card.add_theme_stylebox_override("panel", sb)
			var l2 := _text("%s · %s" % [Clock.time_label(int(e["minute"])), e["text"]])
			l2.add_theme_font_override("font", load("res://assets/fonts/CourierPrime-Regular.ttf") as Font)
			l2.add_theme_font_size_override("font_size", 14)
			card.add_child(l2)
			_body.add_child(card)
	if r["status"] == "living":
		var fb := Button.new()
		fb.text = "Follow %s" % r["first"]
		fb.custom_minimum_size = Vector2(0, 44)
		fb.focus_mode = Control.FOCUS_NONE
		fb.pressed.connect(func() -> void: follow.emit(rid))
		_body.add_child(fb)
	if d.has("note"):
		_body.add_child(_small(str(d["note"])))


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"SecondaryLabel"
	l.add_theme_font_size_override("font_size", 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	return l


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("#5A6472"))
	return l


func _chip(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EDF1F5")
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	p.add_child(l)
	return p


func _bar(label: String, value: float, colour: Color) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(190, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.value = value
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#E3E7EC")
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	return row
