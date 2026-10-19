extends CanvasLayer
## Hollow Creek is a landscape game. On a touch screen held upright, a cover asks the player to turn
## the phone sideways; it goes away by itself when they do. Desktop windows are never covered.

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")

var _cover: ColorRect
var _lines: Array[Label] = []
var _sizes: Array[float] = [2.6, 0.95, 0.6]  # font size as a fraction of the logical width / 18


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.color = Color("#F7EFE0")
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_cover.add_child(box)
	var icon := Label.new()
	icon.text = "↻"
	icon.add_theme_color_override("font_color", MAROON)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(icon)
	_lines.append(icon)
	_lines.append(_line("Please turn your phone sideways", NAVY))
	_lines.append(_line("Hollow Creek is played in landscape.", Color("#3D5670")))
	for l in _lines.slice(1):
		box.add_child(l)
	get_tree().root.size_changed.connect(_update)
	_update()


static func should_show(size: Vector2, touch: bool) -> bool:
	return touch and size.y > size.x


func _update() -> void:
	_cover.visible = should_show(Vector2(get_tree().root.size), DisplayServer.is_touchscreen_available())
	# The logical screen is 1280 wide even on a narrow phone, so size the text from the width.
	var w := get_viewport().get_visible_rect().size.x
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
