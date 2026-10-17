extends SceneTree
## Renders the placeholder mannequins walking, standing and sitting, for checking them by eye.
## xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 -s tools/previews/people_preview.gd -- out.png

var _frames := 0
var _out := "user://people_preview.png"
var _players: Array[AnimationPlayer] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#FFFFFF")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	root3.add_child(ground)
	var data: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/residents.json")) as Dictionary)["residents"]
	var ids := data.keys()
	ids.sort()
	var specs: Array = []
	for j in ids.size():
		specs.append([ids[j], ["walk", "idle", "walk", "idle", "sit"][j % 5], 0.15 * j])
	for i in specs.size():
		var sp: Array = specs[i]
		var look := ResidentLook.for_resident(sp[0], data[sp[0]])
		var n := (load("res://assets/characters/%s.glb" % look["model"]) as PackedScene).instantiate() as Node3D
		root3.add_child(n)
		ResidentLook.apply(n, look)
		n.position = Vector3(i * 0.75 - 3.4, 0.0, 0)
		n.rotation_degrees.y = 25.0
		var ap := n.find_children("*", "AnimationPlayer", true, false)
		if not ap.is_empty():
			var p := ap[0] as AnimationPlayer
			p.play(sp[1])
			p.seek(float(sp[2]), true)
			p.pause()
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.fov = 45
	cam.transform = Transform3D(Basis(), Vector3(0, 1.3, 5.6)).looking_at(Vector3(0, 0.95, 0))
	cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		get_root().get_texture().get_image().save_png(_out)
		quit()
	return false
