class_name Hud
extends CanvasLayer
## The town HUD (layout from docs/mockups/ui-layout-town.png): top bar with date, time controls,
## money, residents and Town Trust; view chips; the bottom toolbar; and the debug panel.

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")
const GREEN := Color("#5CBD6C")

var world: Node3D
var _date: Label
var _speed_buttons: Array[Button] = []
var _walls_btn: Button
var _quality_btn: Button
var _rain_btn: Button
var _debug: PanelContainer
var _debug_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_t := 0.0
var _toolbar_panel: PanelContainer
var _build_panel: BuildPanel
var _money_label: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top_bar(root)
	_view_chips(root)
	_toolbar(root)
	_debug_panel(root)
	_toast_panel(root)
	EventBus.time_changed.connect(func(_d: int, _m: int) -> void: _refresh_date())
	EventBus.speed_changed.connect(func(_s: int) -> void: _refresh_speed())
	_refresh_date()
	_refresh_speed()


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


func _icon_button(icon_path: String, tip: String) -> Button:
	var b := Button.new()
	b.icon = load(icon_path) as Texture2D
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(44, 44)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Icons are white, tinted navy normally and left white on the navy pressed state.
	b.add_theme_color_override("icon_normal_color", NAVY)
	b.add_theme_color_override("icon_focus_color", NAVY)
	b.add_theme_color_override("icon_pressed_color", Color.WHITE)
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_hover_pressed_color", Color.WHITE)
	return b


func _top_bar(root: Control) -> void:
	var p := _panel(root)
	p.position = Vector2(16, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	var name_l := Label.new()
	name_l.theme_type_variation = &"HeadingLabel"
	name_l.text = "Hollow Creek"
	titles.add_child(name_l)
	_date = Label.new()
	_date.theme_type_variation = &"SecondaryLabel"
	_date.add_theme_font_size_override("font_size", 14)
	titles.add_child(_date)
	row.add_child(titles)
	var icons := ["res://assets/icons/ui/pause.svg", "res://assets/icons/ui/play.svg", "res://assets/icons/ui/fast.svg", "res://assets/icons/ui/faster.svg"]
	var tips := ["Pause (Space)", "Play (1)", "Fast (2)", "Faster (3)"]
	var speeds := [0, 1, 2, 4]
	for i in 4:
		var b := _icon_button(icons[i], tips[i])
		var s: int = speeds[i]
		b.pressed.connect(func() -> void: Clock.set_speed(s))
		row.add_child(b)
		_speed_buttons.append(b)
	var money_chip := _chip_label("£%s" % _money(GameState.money))
	_money_label = money_chip.get_child(0) as Label
	row.add_child(money_chip)
	row.add_child(_chip_label("1 resident"))
	var trust := HBoxContainer.new()
	trust.add_theme_constant_override("separation", 8)
	var tl := Label.new()
	tl.text = "Town trust"
	tl.add_theme_font_size_override("font_size", 15)
	trust.add_child(tl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(64, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = GameState.town_trust
	var fill := StyleBoxFlat.new()
	fill.bg_color = GREEN
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	trust.add_child(bar)
	var tv := Label.new()
	tv.text = str(GameState.town_trust)
	tv.add_theme_font_size_override("font_size", 15)
	trust.add_child(tv)
	row.add_child(_wrap_chip(trust))


## Pins a panel to a screen corner or edge at its minimum size, with a margin.
func _anchor(c: Control, preset: Control.LayoutPreset, margin: int) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)


func _chip_label(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return _wrap_chip(l)


func _wrap_chip(c: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EDF1F5")
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(c)
	return p


func _money(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _view_chips(root: Control) -> void:
	var p := _panel(root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	_walls_btn = _text_button("Walls: up", func() -> void:
		world.call("cycle_walls_mode")
		_refresh_view_chips())
	_quality_btn = _text_button("Quality: Medium", func() -> void:
		var order := Quality.NAMES
		var next := order[(order.find(str(world.get("quality"))) + 1) % order.size()]
		Settings.set_value("quality", next)
		world.call("set_quality", next)
		_refresh_view_chips())
	_rain_btn = _text_button("Rain: off", func() -> void:
		var r: Rain = world.get("rain")
		world.call("set_raining", r.target < 0.5)
		_refresh_view_chips())
	for b in [_walls_btn, _quality_btn, _rain_btn]:
		row.add_child(b)
	var dbg := _text_button("Debug", toggle_debug)
	row.add_child(dbg)
	_refresh_view_chips()
	# Second row on the right, under the top bar, so nothing overlaps at 1280 px.
	_anchor.call_deferred(p, Control.PRESET_TOP_RIGHT, 16)
	(func() -> void: p.offset_top += 92.0; p.offset_bottom += 92.0).call_deferred()


func _text_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	return b


func _refresh_view_chips() -> void:
	if world == null:
		return
	_walls_btn.text = "Walls: %s" % str(world.get("walls_mode"))
	_quality_btn.text = "Quality: %s" % str(world.get("quality")).capitalize()
	var r: Rain = world.get("rain")
	_rain_btn.text = "Rain: %s" % ("on" if r and r.target > 0.5 else "off")


func _toolbar(root: Control) -> void:
	var p := _panel(root)
	_toolbar_panel = p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	for t in ["Roads", "Build", "Furnish", "Lights", "Residents", "Case file"]:
		var b := Button.new()
		b.text = t
		b.disabled = t != "Build"
		b.custom_minimum_size = Vector2(80, 48)
		b.add_theme_font_size_override("font_size", 15)
		if t == "Build":
			b.theme_type_variation = &"PrimaryButton"
			b.tooltip_text = "Build (B)"
			b.pressed.connect(func() -> void: world.call("enter_build_mode"))
		row.add_child(b)
	_anchor.call_deferred(p, Control.PRESET_CENTER_BOTTOM, 16)


func _debug_panel(root: Control) -> void:
	_debug = _panel(root)
	_debug_label = Label.new()
	_debug_label.add_theme_font_override("font", load("res://assets/fonts/CourierPrime-Regular.ttf") as Font)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug.add_child(_debug_label)
	_debug.visible = false
	_anchor.call_deferred(_debug, Control.PRESET_BOTTOM_LEFT, 16)


func set_build_mode(on: bool) -> void:
	_toolbar_panel.visible = not on
	if on and _build_panel == null:
		_build_panel = BuildPanel.new()
		_build_panel.build = world.get("build")
		_build_panel.world = world
		get_child(0).add_child(_build_panel)
	if _build_panel:
		_build_panel.visible = on
	_refresh_view_chips()


func toggle_debug() -> void:
	_debug.visible = not _debug.visible


func _toast_panel(root: Control) -> void:
	_toast = _panel(root)
	_toast.custom_minimum_size = Vector2(600, 0)
	_toast_label = Label.new()
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.visible = false
	_anchor.call_deferred(_toast, Control.PRESET_CENTER_TOP, 110)


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast_t = 5.0


func _refresh_date() -> void:
	_date.text = "%s · %s" % [Clock.date_label(Clock.day), Clock.time_label(Clock.minute)]


func _refresh_speed() -> void:
	var speeds := [0, 1, 2, 4]
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(Clock.speed == speeds[i])


func _process(delta: float) -> void:
	if _money_label:
		_money_label.text = "£%s" % _money(GameState.money)
	if _toast.visible:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.visible = false
	if _debug.visible:
		_debug_label.text = "FPS %d   frame %.1f ms\ndraw calls %d\ntriangles %d\nsim %.2f ms   quality %s" % [
			Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			float(world.call("sim_ms")), str(world.get("quality"))]
