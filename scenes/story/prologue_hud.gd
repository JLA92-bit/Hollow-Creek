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
	SimHost.prologue_progressed.connect(func(_d: Array) -> void: _sig = "")
	_refresh()


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.4
		_refresh()


func _refresh() -> void:
	var p := SimHost.prologue
	if p == null:
		_card.visible = false
		return
	var s := p.current()
	var list := p.checklist()
	var sig := "%s|%s|%s" % [p.current_id(), str(list), Settings.get_value("hints")]
	if sig == _sig:
		return
	_sig = sig
	_card.visible = not s.is_empty()
	for c in _body.get_children():
		c.queue_free()
	continue_button = null
	if s.is_empty():
		return
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
	if bool(Settings.get_value("hints")):
		_body.add_child(_para(str(s["hint"]), MAROON, 14))
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


func _para(t: String, c: Color, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l
