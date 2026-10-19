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
var _confessed := false
var _face: MeshInstance3D
var _shown: Dictionary = {}   ## blend shape name -> the weight now on the face
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
	# The head-and-shoulders model with a face if the characters pack has it; else the whole body.
	var path := "res://assets/characters/%s_portrait.glb" % look["model"]
	if not ResourceLoader.exists(path):
		path = "res://assets/characters/%s.glb" % look["model"]
	_model = (load(path) as PackedScene).instantiate() as Node3D
	_vp.add_child(_model)
	ResidentLook.apply(_model, look)
	_head_height = float(look["height"]) * 0.88
	_face = _find_face(_model)
	if _face == null:
		var p := CharacterAnims.attach(_model)
		if p.has_animation("idle"):
			p.play("idle")
	_frame()


func set_mood(composure: float, pressure: float, confessed: bool = false) -> void:
	_composure = composure
	_pressure = pressure
	_confessed = confessed


## The face for a mood: weights for MPFB's face action units. Composure is how together they are,
## pressure how hard they're being pushed, and a confession is the end of it.
static func expression_weights(composure: float, pressure: float, confessed: bool = false) -> Dictionary:
	var strain := 1.0 - clampf(composure / 100.0, 0.0, 1.0)
	var fear := clampf(pressure / 100.0, 0.0, 1.0)
	var calm := 1.0 - strain
	var w := {
		"eyebrows-left-inner-up": strain * 0.9, "eyebrows-right-inner-up": strain * 0.9,
		"eyebrows-left-up": fear * 0.5, "eyebrows-right-up": fear * 0.5,
		"eyebrows-left-down": calm * fear * 0.7, "eyebrows-right-down": calm * fear * 0.7,
		"eye-left-opened-up": fear * 0.5 + strain * 0.2, "eye-right-opened-up": fear * 0.5 + strain * 0.2,
		"eye-left-slit": calm * fear * 0.4, "eye-right-slit": calm * fear * 0.4,
		"mouth-compression": calm * fear * 0.6, "mouth-depression": strain * 0.7, "mouth-open": fear * strain * 0.4,
		"eye-left-closure": strain * 0.15, "eye-right-closure": strain * 0.15,
		"mouth-corner-puller": calm * (1.0 - fear) * 0.15}
	if confessed:
		w["mouth-depression"] = 0.9
		w["eyebrows-left-inner-up"] = 1.0
		w["eyebrows-right-inner-up"] = 1.0
		w["eye-left-closure"] = 0.5
		w["eye-right-closure"] = 0.5
		w["mouth-open"] = 0.0
	return w


static func _find_face(root: Node) -> MeshInstance3D:
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh != null and mi.mesh.get_blend_shape_count() > 0:
			return mi
	return null


func _frame() -> void:
	var cam := _vp.get_node("Cam") as Camera3D
	if _face != null:
		# Close on the face: the cropped chest edge stays out of frame.
		var focus := _head_height * 1.03
		cam.fov = 26.0
		cam.look_at_from_position(Vector3(0.0, focus + 0.02, _head_height * 0.78), Vector3(0.0, focus - 0.02, 0.0), Vector3.UP)
		return
	cam.look_at_from_position(Vector3(0.0, _head_height + 0.02, 2.4), Vector3(0.0, _head_height - 0.04, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _model == null:
		return
	_t += delta
	if _face != null:
		var want := expression_weights(_composure, _pressure, _confessed)
		var k := 1.0 - exp(-delta * 6.0)   # the face eases from one look to the next
		for i in _face.mesh.get_blend_shape_count():
			var nm := str(_face.mesh.get_blend_shape_name(i))
			var v := lerpf(float(_shown.get(nm, 0.0)), clampf(float(want.get(nm, 0.0)), 0.0, 1.0), k)
			_shown[nm] = v
			_face.set_blend_shape_value(i, v)
	var calm := _composure / 100.0
	# Composed people stand straight and face you; rattled ones lean back, droop and look away.
	var lean := (1.0 - calm) * 9.0
	var turn := _pressure / 100.0 * 22.0 + sin(_t * 0.7) * 1.2
	_model.rotation_degrees = Vector3(-lean * 0.5 + sin(_t * 1.3) * 0.4, turn, 0.0)
	_model.position.y = -(1.0 - calm) * 0.02
