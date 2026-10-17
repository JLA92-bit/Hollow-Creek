extends SceneTree
## Builds the base UI theme from Josh's colours and the project fonts.
## Run: tools/bin/godot --headless --path . -s tools/make_theme.gd

const NAVY := Color("#00294D")
const MAROON := Color("#940E16")
const SECONDARY := Color("#3D5670")
const CHIP := Color("#EDF1F5")
const OUT := "res://assets/theme/hollow_creek.tres"


func _box(bg: Color, radius: int, border: Color = Color.TRANSPARENT, border_w: int = 0, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow:
		sb.shadow_color = Color(0, 0.08, 0.16, 0.16)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 3)
	sb.anti_aliasing = true
	return sb


func _initialize() -> void:
	var body := load("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf") as FontFile
	var bold := load("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf") as FontFile
	var fraunces := load("res://assets/fonts/Fraunces.ttf") as FontFile
	var heading := FontVariation.new()
	heading.base_font = fraunces
	heading.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700,
		TextServerManager.get_primary_interface().name_to_tag("opsz"): 72}

	var t := Theme.new()
	t.default_font = body
	t.default_font_size = 18

	t.set_color("font_color", "Label", NAVY)
	t.set_color("font_color", "RichTextLabel", NAVY)
	t.set_color("default_color", "RichTextLabel", NAVY)

	# Type variations used across scenes.
	t.add_type("HeadingLabel")
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", heading)
	t.set_font_size("font_size", "HeadingLabel", 28)
	t.add_type("TitleLabel")
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", heading)
	t.set_font_size("font_size", "TitleLabel", 96)
	t.add_type("SecondaryLabel")
	t.set_type_variation("SecondaryLabel", "Label")
	t.set_color("font_color", "SecondaryLabel", SECONDARY)
	t.set_font_size("font_size", "SecondaryLabel", 16)
	t.add_type("CapsLabel")
	t.set_type_variation("CapsLabel", "Label")
	t.set_font("font", "CapsLabel", bold)
	t.set_font_size("font_size", "CapsLabel", 13)
	t.set_color("font_color", "CapsLabel", SECONDARY)

	# Panels: white, 14 px radius, soft shadow.
	t.set_stylebox("panel", "PanelContainer", _box(Color.WHITE, 14, Color.TRANSPARENT, 0, true))
	t.set_stylebox("panel", "Panel", _box(Color.WHITE, 14, Color.TRANSPARENT, 0, true))

	# Buttons: navy outline by default, navy fill when pressed or hovered. 44 px minimum height.
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Button", NAVY)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", NAVY)
	t.set_color("font_disabled_color", "Button", Color(SECONDARY, 0.5))
	t.set_stylebox("normal", "Button", _box(Color.WHITE, 12, NAVY, 2))
	t.set_stylebox("hover", "Button", _box(NAVY, 12, NAVY, 2))
	t.set_stylebox("pressed", "Button", _box(NAVY.darkened(0.2), 12, NAVY, 2))
	t.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, 12, Color("#4BC9F5"), 2))
	t.set_stylebox("disabled", "Button", _box(Color.WHITE, 12, Color(SECONDARY, 0.3), 2))
	t.set_constant("h_separation", "Button", 8)

	# Primary (maroon) action, such as Present or Investigate.
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	t.set_color("font_color", "PrimaryButton", Color.WHITE)
	t.set_color("font_focus_color", "PrimaryButton", Color.WHITE)
	t.set_stylebox("normal", "PrimaryButton", _box(MAROON, 12))
	t.set_stylebox("hover", "PrimaryButton", _box(MAROON.lightened(0.1), 12))
	t.set_stylebox("pressed", "PrimaryButton", _box(MAROON.darkened(0.2), 12))

	# Pill chips for the top bar.
	t.add_type("ChipLabel")
	t.set_type_variation("ChipLabel", "Label")
	t.set_font("font", "ChipLabel", bold)
	t.set_font_size("font_size", "ChipLabel", 15)
	var chip := _box(CHIP, 16)
	chip.content_margin_top = 6
	chip.content_margin_bottom = 6
	chip.content_margin_left = 14
	chip.content_margin_right = 14
	t.set_stylebox("normal", "ChipLabel", chip)

	# Progress bars (needs, scores, Composure).
	t.set_stylebox("background", "ProgressBar", _box(Color("#E3E8EE"), 4))
	t.set_stylebox("fill", "ProgressBar", _box(NAVY, 4))

	var err := ResourceSaver.save(t, OUT)
	print("Saved theme: ", OUT, " (", error_string(err), ")")
	quit(0 if err == OK else 1)
