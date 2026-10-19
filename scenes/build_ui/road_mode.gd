class_name RoadMode
extends CanvasLayer
## The Roads tool: tap points on the ground to lay out a road, choose dirt, gravel or footpath, and
## lay it. In the prologue a "Follow the ghost path" button lays the guided road in one go. Pauses
## resident picking while open. Lives in the world; opened from the HUD's Roads button.

signal closed

var world: Node3D
var active := false
var kind := "dirt"
var points: Array = []
var lay_button: Button
var ghost_button: Button
var kind_buttons: Dictionary = {}
var message := ""

var _panel: PanelContainer
var _msg: Label
var _preview: MeshInstance3D
var _mat: StandardMaterial3D


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
	var title := Label.new()
	title.text = "ROADS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("#4A5A6A"))
	v.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for k: String in RoadOps.KINDS:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s%s" % [RoadOps.KINDS[k]["label"], "" if int(RoadOps.KINDS[k]["cost"]) == 0 else " £%d" % int(RoadOps.KINDS[k]["cost"])]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func() -> void: set_kind(k))
		row.add_child(b)
		kind_buttons[k] = b
	v.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	ghost_button = Button.new()
	ghost_button.text = "Follow the ghost path"
	ghost_button.custom_minimum_size = Vector2(0, 44)
	ghost_button.pressed.connect(follow_ghost)
	row2.add_child(ghost_button)
	lay_button = Button.new()
	lay_button.text = "Lay road"
	lay_button.theme_type_variation = &"PrimaryButton"
	lay_button.custom_minimum_size = Vector2(0, 44)
	lay_button.pressed.connect(lay)
	row2.add_child(lay_button)
	var undo := Button.new()
	undo.text = "Undo point"
	undo.custom_minimum_size = Vector2(0, 44)
	undo.pressed.connect(func() -> void:
		if not points.is_empty():
			points.pop_back()
		_redraw())
	row2.add_child(undo)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(close)
	row2.add_child(done)
	v.add_child(row2)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(420, 0)
	_msg.add_theme_font_size_override("font_size", 15)
	v.add_child(_msg)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -270
	_panel.offset_right = 270
	_panel.offset_top = -190
	_panel.offset_bottom = -90
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color("#4BC9F5")
	_preview = MeshInstance3D.new()
	world.add_child(_preview)
	visible = false
	set_kind("dirt")


func open() -> void:
	active = true
	visible = true
	points.clear()
	ghost_button.visible = SimHost.prologue != null and SimHost.prologue.current_id() == "road"
	lay_button.theme_type_variation = &"PrimaryButton"
	if ghost_button.visible:
		ghost_button.theme_type_variation = &"PrimaryButton"
		lay_button.theme_type_variation = &""
		_ghost_pulse = Pulse.start(ghost_button, self)
		say("Tap Follow the ghost path and the road is laid along the yellow dots for you. Or tap the ground to place your own points, then Lay road.")
	else:
		say("Tap the ground to add points along your road, then Lay road.")
	_redraw()


func close() -> void:
	Pulse.stop(ghost_button, _ghost_pulse)
	_ghost_pulse = null
	active = false
	visible = false
	points.clear()
	_redraw()
	closed.emit()


func set_kind(k: String) -> void:
	kind = k
	for key: String in kind_buttons:
		(kind_buttons[key] as Button).set_pressed_no_signal(key == k)


func say(t: String) -> void:
	message = t
	_msg.text = t


## The prologue's guided path, laid in one go.
func follow_ghost() -> void:
	if SimHost.prologue == null:
		return
	var r: Dictionary = world.call("lay_road", (SimHost.prologue.data["road"] as Dictionary)["points"], kind if kind != "footpath" else "dirt")
	say("%s Tap Done to close this panel." % str(r["msg"]) if bool(r.get("ok", false)) else str(r["msg"]))
	Pulse.stop(ghost_button, _ghost_pulse)
	_ghost_pulse = null
	SimHost.refresh_story()


func lay() -> void:
	if points.size() < 2:
		say("Add at least two points first.")
		return
	var r: Dictionary = world.call("lay_road", points.duplicate(), kind)
	say(str(r["msg"]))
	if bool(r["ok"]):
		points.clear()
		_redraw()
		SimHost.refresh_story()


func add_point(world_pos: Vector3) -> void:
	points.append([snappedf(world_pos.x, 0.5), snappedf(world_pos.z, 0.5)])
	_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if (event as InputEventMouseButton).position.distance_to(_press) > 8.0:
			return
		var cam: Camera3D = (world.get("rig") as CameraRig).camera
		var o := cam.project_ray_origin(mb.position)
		var d := cam.project_ray_normal(mb.position)
		var grid: WorldGrid = world.get("slice").grid
		var y := grid.height_at(o.x, o.z)
		for i in 4:
			if absf(d.y) < 0.001:
				return
			var t := (y - o.y) / d.y
			var hit := o + d * t
			y = grid.height_at(hit.x, hit.z)
			if i == 3:
				add_point(Vector3(hit.x, y, hit.z))
		get_viewport().set_input_as_handled()
	elif mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_press = mb.position


var _press := Vector2.ZERO
var _ghost_pulse: Tween


func _redraw() -> void:
	var im := ImmediateMesh.new()
	if points.size() >= 2:
		var grid: WorldGrid = world.get("slice").grid
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _mat)
		for p: Array in points:
			im.surface_add_vertex(Vector3(float(p[0]), grid.height_at(float(p[0]), float(p[1])) + 0.3, float(p[1])))
		im.surface_end()
	_preview.mesh = im
