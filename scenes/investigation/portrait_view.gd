class_name PortraitView
extends SubViewportContainer
## A live 3D portrait of a resident for the interview screen: their mannequin under a small
## portrait light rig (warm key, cool fill, rim), framed head and shoulders. The placeholder
## mannequins have no face, so mood shows in the pose: they straighten when composed, lean away and
## drop their head as composure goes, and turn aside when pressure is high. (The MPFB face rig
## will take over expressions; see docs/BACKLOG.md.)

const BACKDROP := Color("#CFC7B8")

var rid := ""
var _vp: SubViewport
var _model: Node3D
var _head_height := 1.55
var _composure := 100.0
var _pressure := 0.0
var _t := 0.0


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(150, 170)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKDROP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B9B2A6")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#FFE2BE")
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-30, -35, 0)
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#BFD0E6")
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-10, 55, 0)
	_vp.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#FFF1DC")
	rim.light_energy = 0.8
	rim.rotation_degrees = Vector3(-15, 170, 0)
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 28.0
	cam.current = true
	_vp.add_child(cam)


## Show a resident. `d` is their entry in data/residents.json.
func show_resident(p_rid: String, d: Dictionary) -> void:
	if p_rid == rid and _model != null:
		return
	rid = p_rid
	if _model != null:
		_model.queue_free()
	var look := ResidentLook.for_resident(p_rid, d)
	_model = (load("res://assets/characters/%s.glb" % look["model"]) as PackedScene).instantiate() as Node3D
	_vp.add_child(_model)
	ResidentLook.apply(_model, look)
	_head_height = float(look["height"]) * 0.88
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var p := aps[0] as AnimationPlayer
		if p.has_animation("idle"):
			p.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			p.play("idle")
	_frame()


func set_mood(composure: float, pressure: float) -> void:
	_composure = composure
	_pressure = pressure


func _frame() -> void:
	var cam := _vp.get_node("Cam") as Camera3D
	cam.look_at_from_position(Vector3(0.0, _head_height + 0.02, 2.4), Vector3(0.0, _head_height - 0.04, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _model == null:
		return
	_t += delta
	var calm := _composure / 100.0
	# Composed people stand straight and face you; rattled ones lean back, droop and look away.
	var lean := (1.0 - calm) * 9.0
	var turn := _pressure / 100.0 * 22.0 + sin(_t * 0.7) * 1.2
	_model.rotation_degrees = Vector3(-lean * 0.5 + sin(_t * 1.3) * 0.4, turn, 0.0)
	_model.position.y = -(1.0 - calm) * 0.02
