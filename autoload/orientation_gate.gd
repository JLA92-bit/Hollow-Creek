extends CanvasLayer
## Hollow Creek is a landscape game. On a touch screen held upright, a cover asks the player to turn
## the phone sideways; it goes away by itself when they do. Desktop windows are never covered.

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")

var _cover: ColorRect
var _phone: Panel
var _lines: Array[Label] = []
var _sizes: Array[float] = [0.95, 0.6]  # font sizes as fractions of the logical width / 18


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.color = Color("#F7EFE0")
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(centre)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	centre.add_child(box)
	# A phone lying on its side, drawn as an outlined rounded box (the font has no rotate glyph).
	_phone = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFFFF")
	sb.set_border_width_all(10)
	sb.border_color = MAROON
	sb.set_corner_radius_all(28)
	_phone.add_theme_stylebox_override("panel", sb)
	_phone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_phone)
	_lines.append(_line("Please turn your phone sideways", NAVY))
	_lines.append(_line("Hollow Creek is played in landscape.", Color("#3D5670")))
	for l in _lines:
		box.add_child(l)
	get_tree().root.size_changed.connect(_update)
	_update()


static func should_show(size: Vector2, touch: bool) -> bool:
	return touch and size.y > size.x


func _update() -> void:
	var forced := OS.get_environment("HC_FORCE_GATE") != ""   # for the preview script
	_cover.visible = should_show(Vector2(get_tree().root.size), DisplayServer.is_touchscreen_available() or forced)
	# The logical screen is 1280 wide even on a narrow phone, so size everything from the width.
	var w := get_viewport().get_visible_rect().size.x
	_phone.custom_minimum_size = Vector2(w * 0.36, w * 0.19)
	for i in _lines.size():
		_lines[i].add_theme_font_size_override("font_size", int(w / 18.0 * _sizes[i]))
		_lines[i].custom_minimum_size = Vector2(w * 0.86, 0)


func _line(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
