class_name SettingsScreen
extends CanvasLayer
## Settings, saves and credits in one modal: picture quality, text size, volume, reduce motion, hints,
## building while time runs, the save slots with save codes, and the credits. Opened from the title
## menu and the pause menu. Controls are public so tests can press them.

signal closed
signal loaded   ## a save was loaded: the caller should go to the world

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")
const QUALITIES: Array[String] = ["low", "medium", "high"]

var in_game := false          ## in a game: slots can be saved as well as loaded
var quality_buttons: Dictionary = {}
var text_slider: HSlider
var volume_slider: HSlider
var motion_check: CheckButton
var hints_check: CheckButton
var build_check: CheckButton
var code_box: TextEdit
var status: Label
var credits_button: Button
var close_button: Button
var slot_buttons: Dictionary = {}   ## slot -> {save: Button, load: Button}

var _body: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 40
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFFFF")
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var vp := get_viewport().get_visible_rect().size
	var panel_h := minf(600.0, vp.y - 24.0)   # fits a phone held sideways
	panel.custom_minimum_size = Vector2(minf(640.0, vp.x - 24.0), panel_h)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", NAVY)
	outer.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, maxf(120.0, panel_h - 130.0))
	outer.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)
	_scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	pad.add_child(_body)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", MAROON)
	outer.add_child(status)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	credits_button = Button.new()
	credits_button.text = "Credits"
	credits_button.custom_minimum_size = Vector2(120, 48)
	credits_button.pressed.connect(open_credits)
	bottom.add_child(credits_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	close_button = Button.new()
	close_button.text = "Done"
	close_button.theme_type_variation = &"PrimaryButton"
	close_button.custom_minimum_size = Vector2(140, 48)
	close_button.pressed.connect(close)
	bottom.add_child(close_button)
	outer.add_child(bottom)
	_build()


func close() -> void:
	closed.emit()
	queue_free()


func _build() -> void:
	_heading("PICTURE")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for q: String in QUALITIES:
		var b := Button.new()
		b.text = q.capitalize()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = str(Settings.get_value("quality")) == q
		b.pressed.connect(func() -> void: set_quality(q))
		row.add_child(b)
		quality_buttons[q] = b
	_body.add_child(row)
	_note("Medium suits most computers and phones. Low is for older phones; High for a good computer.")
	motion_check = _toggle("Reduce motion (no camera easing)", bool(Settings.get_value("reduce_motion")), func(v: bool) -> void: Settings.set_value("reduce_motion", v))
	_heading("TEXT AND SOUND")
	text_slider = _slider("Text size", 0.8, 1.5, float(Settings.get_value("text_scale")), func(v: float) -> void: Settings.set_value("text_scale", snappedf(v, 0.05)))
	volume_slider = _slider("Volume", 0.0, 1.0, float(Settings.get_value("master_volume")), func(v: float) -> void: Settings.set_value("master_volume", snappedf(v, 0.05)))
	_heading("PLAYING")
	hints_check = _toggle("Show hints", bool(Settings.get_value("hints")), func(v: bool) -> void: Settings.set_value("hints", v))
	build_check = _toggle("Keep time running while building", bool(Settings.get_value("build_while_time_runs")), func(v: bool) -> void: Settings.set_value("build_while_time_runs", v))
	_heading("SAVES")
	for slot: String in SaveSystem.MANUAL_SLOTS:
		_slot_row(slot, slot.replace("slot", "Slot "))
	_slot_row("autosave", "Autosave")
	if FileAccess.file_exists("%s/sandbox.json" % SaveSystem.DIR):
		_slot_row("sandbox", "Sandbox")
	_heading("SAVE CODE")
	_note("A save code is your whole game as text. Copy it somewhere safe, or paste one here to carry on from it.")
	code_box = TextEdit.new()
	code_box.custom_minimum_size = Vector2(0, 90)
	code_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_box.placeholder_text = "HC1:... (paste a save code here)"
	_body.add_child(code_box)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	if in_game:
		var ex := Button.new()
		ex.text = "Export my game"
		ex.custom_minimum_size = Vector2(0, 46)
		ex.pressed.connect(export_code)
		r2.add_child(ex)
	var im := Button.new()
	im.text = "Load this code"
	im.custom_minimum_size = Vector2(0, 46)
	im.pressed.connect(import_code)
	r2.add_child(im)
	_body.add_child(r2)


func _slot_row(slot: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = "%s: %s" % [label, SaveSystem.slot_label(slot)]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var entry := {}
	var exists := bool(SaveSystem.slot_info(slot)["exists"])
	if in_game and slot != "autosave" and slot != "sandbox":
		var sv := Button.new()
		sv.text = "Save"
		sv.custom_minimum_size = Vector2(80, 44)
		sv.pressed.connect(func() -> void: save_to(slot))
		row.add_child(sv)
		entry["save"] = sv
	var ld := Button.new()
	ld.text = "Load"
	ld.disabled = not exists
	ld.custom_minimum_size = Vector2(80, 44)
	ld.pressed.connect(func() -> void: load_from(slot))
	row.add_child(ld)
	entry["load"] = ld
	slot_buttons[slot] = entry
	_body.add_child(row)


func set_quality(q: String) -> void:
	Settings.set_value("quality", q)
	for k: String in quality_buttons:
		(quality_buttons[k] as Button).set_pressed_no_signal(k == q)


func save_to(slot: String) -> void:
	var err := SaveSystem.save_slot(slot)
	say("Saved to %s." % slot.replace("slot", "slot ") if err == OK else "Couldn't save (error %d)." % err)
	_refresh_saves()


func load_from(slot: String) -> void:
	if SaveSystem.load_slot(slot):
		loaded.emit()
	else:
		say("That slot couldn't be read.")


func export_code() -> void:
	var code := SaveSystem.export_code()
	code_box.text = code
	DisplayServer.clipboard_set(code)
	say("Save code copied. %d characters." % code.length())


func import_code() -> void:
	if SaveSystem.import_code(code_box.text):
		loaded.emit()
	else:
		say("That code doesn't read right. Check it was copied in full.")


func say(t: String) -> void:
	status.text = t


func _refresh_saves() -> void:
	for c in _body.get_children():
		c.queue_free()
	quality_buttons.clear()
	slot_buttons.clear()
	_build.call_deferred()


func open_credits() -> void:
	var c := CreditsScreen.new()
	add_child(c)


# --- Widgets ----------------------------------------------------------------------------------------

func _heading(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("#4A5A6A"))
	_body.add_child(l)


func _note(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("#4A5A6A"))
	_body.add_child(l)


func _toggle(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.custom_minimum_size = Vector2(0, 44)
	c.toggled.connect(cb)
	_body.add_child(c)
	return c


func _slider(text: String, lo: float, hi: float, v: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 44)
	s.value_changed.connect(cb)
	row.add_child(s)
	_body.add_child(row)
	return s
