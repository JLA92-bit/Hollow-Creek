class_name LampMode
extends CanvasLayer
## The Lights tool: tap the ground to put up a street lamp, tap a lamp to take it down. Lamps cost
## £15 each (£8 back when taken down). Opened from the HUD's Lights button once the prologue has
## unlocked them.

signal closed

var world: Node3D
var active := false
var message := ""
var done_button: Button

var _panel: PanelContainer
var _msg: Label
var _count: Label
var _press := Vector2.ZERO


func _ready() -> void:
	layer = 7
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFFFFF0")
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var t := Label.new()
	t.text = "STREET LAMPS"
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color("#4A5A6A"))
	v.add_child(t)
	_count = Label.new()
	v.add_child(_count)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(420, 0)
	_msg.add_theme_font_size_override("font_size", 15)
	v.add_child(_msg)
	done_button = Button.new()
	done_button.text = "Done"
	done_button.theme_type_variation = &"PrimaryButton"
	done_button.custom_minimum_size = Vector2(0, 46)
	done_button.pressed.connect(close)
	v.add_child(done_button)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -250
	_panel.offset_right = 250
	_panel.offset_top = -200
	_panel.offset_bottom = -90
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	visible = false


func open() -> void:
	active = true
	visible = true
	say("Tap the ground to put up a lamp (£%d). Tap a lamp to take it down." % LampOps.COST)


func close() -> void:
	active = false
	visible = false
	closed.emit()


func say(t: String) -> void:
	message = t
	_msg.text = t
	_count.text = "%d lamps up" % GameState.lamps.size()


## Tapping a spot: down if there's a lamp there, up if not.
func tap(p: Vector2) -> void:
	var removed := int(world.call("take_down_lamp", p))
	if removed >= 0:
		say("Lamp down%s." % ("" if removed == 0 or GameState.is_sandbox() else ", £%d back" % removed))
		return
	var r: Dictionary = world.call("put_up_lamp", p)
	say(str(r["msg"]) if not bool(r["ok"]) else "Lamp up%s." % ("" if int(r["cost"]) == 0 else " for £%d" % int(r["cost"])))


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press = mb.position
		return
	if _press.distance_to(mb.position) > 8.0:
		return
	var cam: Camera3D = (world.get("rig") as CameraRig).camera
	var o := cam.project_ray_origin(mb.position)
	var d := cam.project_ray_normal(mb.position)
	var grid: WorldGrid = world.get("slice").grid
	var y := grid.height_at(o.x, o.z)
	var hit := o
	for i in 4:
		if absf(d.y) < 0.001:
			return
		hit = o + d * ((y - o.y) / d.y)
		y = grid.height_at(hit.x, hit.z)
	tap(Vector2(hit.x, hit.z))
	get_viewport().set_input_as_handled()
