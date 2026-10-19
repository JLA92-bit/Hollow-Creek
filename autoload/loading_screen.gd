extends CanvasLayer
## A cover with a progress bar for the long loads (opening the valley). Whoever starts the load calls
## `show_loading`; the world reports each step with `set_progress` and calls `hide_loading` when it is
## ready to play. While it is showing the world builds itself a step at a time, a frame apart, so the
## bar and message actually get drawn (a single long step would freeze the screen).

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")

var _cover: ColorRect
var _bar: ProgressBar
var _message: Label
var _title: Label
var _tip_t := 0.0


func _ready() -> void:
	layer = 95
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
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(520, 0)
	centre.add_child(box)
	_title = Label.new()
	_title.text = "Hollow Creek"
	_title.theme_type_variation = &"HeadingLabel"
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", NAVY)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = MAROON
	fill.set_corner_radius_all(7)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#E3D9C6")
	back.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", Color("#3D5670"))
	_message.add_theme_font_size_override("font_size", 18)
	box.add_child(_message)
	_cover.visible = false


func is_showing() -> bool:
	return _cover != null and _cover.visible


func show_loading(message: String = "Loading") -> void:
	_cover.visible = true
	set_progress(0.0, message)


func set_progress(fraction: float, message: String = "") -> void:
	if _cover == null or not _cover.visible:
		return
	_bar.value = clampf(fraction, 0.0, 1.0)
	if message != "":
		_message.text = message


func hide_loading() -> void:
	if _cover != null:
		_cover.visible = false
