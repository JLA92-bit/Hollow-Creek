class_name CreditsScreen
extends CanvasLayer
## Credits: every external file in the game with its author, source and licence (from
## data/asset_credits.json, written by tools/assets/write_credits.py), after the engine, fonts and our own work.

const TOOLS := [
	["Godot Engine 4.7.2", "Juan Linietsky, Ariel Manzur and contributors", "MIT"],
	["Fraunces", "Undercase Type", "SIL OFL 1.1"],
	["Atkinson Hyperlegible", "Braille Institute of America", "SIL OFL 1.1"],
	["Courier Prime", "Alan Dague-Greene", "SIL OFL 1.1"],
	["Caveat", "Impallari Type", "SIL OFL 1.1"],
	["Residents, 1950s props, architecture and sound effects", "Made for Hollow Creek", "Ours"],
]

var text := ""


func _ready() -> void:
	layer = 50
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFFFF")
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var vp := get_viewport().get_visible_rect().size
	var panel_h := minf(560.0, vp.y - 24.0)
	panel.custom_minimum_size = Vector2(minf(640.0, vp.x - 24.0), panel_h)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Credits"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#00294D"))
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, maxf(120.0, panel_h - 130.0))
	v.add_child(scroll)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(minf(580.0, vp.x - 60.0), 0)
	text = build_text()
	label.text = text
	scroll.add_child(label)
	var back := Button.new()
	back.text = "Back"
	back.theme_type_variation = &"PrimaryButton"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(queue_free)
	v.add_child(back)


static func build_text() -> String:
	var out: PackedStringArray = ["Hollow Creek", "", "ENGINE, FONTS AND OUR OWN WORK"]
	for t: Array in TOOLS:
		out.append("%s - %s - %s" % [t[0], t[1], t[2]])
	out.append("")
	out.append("MATERIALS, MODELS AND SKIES")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_credits.json"))
	if parsed is Dictionary:
		var keys := (parsed as Dictionary).keys()
		keys.sort()
		for k: String in keys:
			var e: Dictionary = parsed[k]
			out.append("%s - %s - %s - %s" % [e.get("name", k), ", ".join(PackedStringArray(e.get("authors", []))), e.get("licence", ""), e.get("source", "")])
	return "\n".join(out)
