extends SceneTree
## Renders the retargeted animations side by side (assets/characters/animations.glb), each frozen
## part-way through, for checking the retarget by eye.
## xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 -s tools/previews/anim_preview.gd -- out.png [name name ...]

var _frames := 0
var _out := "user://anim_preview.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var names: Array = args.slice(1) if args.size() > 1 else ["idle", "walk", "walk_formal", "talk", "sit", "sit_talk", "crouch", "sneak", "interact", "pickup", "dance", "push"]
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#FFFFFF")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.6
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	root3.add_child(sun)
	var scene := load("res://assets/characters/animations.glb") as PackedScene
	for i in names.size():
		var n := scene.instantiate() as Node3D
		root3.add_child(n)
		n.position = Vector3((i % 6) * 1.1 - 2.75, 0.0, -(i / 6) * 1.9)
		n.rotation_degrees.y = 25.0
		var ap := n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var nm := str(names[i])
		if ap.has_animation(nm):
			ap.play(nm)
			ap.seek(ap.get_animation(nm).length * 0.35, true)
			ap.pause()
		else:
			print("no animation ", nm, " in ", ap.get_animation_list())
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.fov = 40
	cam.transform = Transform3D(Basis(), Vector3(0, 1.6, 7.5)).looking_at(Vector3(0, 0.75, -0.8))
	cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		get_root().get_viewport().get_texture().get_image().save_png(_out)
		print("wrote ", _out)
		quit()
	return false
