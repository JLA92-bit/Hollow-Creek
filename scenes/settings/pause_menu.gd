class_name PauseMenu
extends CanvasLayer
## Esc in the world: resume, save, settings, or back to the title. Time stops while it's open.

signal resumed

var resume_button: Button
var settings_button: Button
var save_button: Button
var title_button: Button
var _speed_before := 0


func _ready() -> void:
	layer = 35
	_speed_before = Clock.speed
	Clock.set_speed(0)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFFFF")
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Paused"
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color("#00294D"))
	v.add_child(t)
	resume_button = _button(v, "Resume", resume, true)
	save_button = _button(v, "Save the game", func() -> void:
		SaveSystem.save_slot("autosave" if not GameState.is_sandbox() else "sandbox")
		save_button.text = "Saved"
		save_button.disabled = true)
	settings_button = _button(v, "Settings and saves", func() -> void:
		var s := SettingsScreen.new()
		s.in_game = true
		s.loaded.connect(func() -> void:
			LoadingScreen.show_loading("Reading your saved game")
			await get_tree().process_frame
			await get_tree().process_frame
			get_tree().change_scene_to_file("res://scenes/world/world.tscn"))
		add_child(s))
	title_button = _button(v, "Quit to title", func() -> void:
		SaveSystem.save_slot("autosave" if not GameState.is_sandbox() else "sandbox")
		Clock.set_speed(0)
		get_tree().change_scene_to_file("res://scenes/title/title.tscn"))


func resume() -> void:
	Clock.set_speed(_speed_before)
	resumed.emit()
	queue_free()


func _button(parent: Control, text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
