extends SceneTree
## Renders verandah variants (shapes, posts, lace, rails, lattice, steps, a sleep-out) to a PNG.
## xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 -s tools/previews/exterior_preview.gd -- out.png [view]

var _frames := 0
var _out := "user://exterior_preview.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#BFD4E6")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.82)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#8A9A5B")
	ground.material_override = gm
	root3.add_child(ground)
	var specs := [
		{"side": "N", "opts": {"shape": "bullnose", "lace": "lace", "lattice": true, "post": "cast_iron", "rail": "lace"}, "steps": 4.0},
		{"side": "N", "opts": {"shape": "skillion", "post": "turned_post", "rail": "timber", "material": "roof_paint_red"}, "steps": 2.0},
		{"side": "N", "opts": {"shape": "gable", "lace": "fretwork", "post": "timber_post"}, "steps": 4.5},
		{"side": "N", "opts": {"shape": "bullnose", "post": "timber_post", "depth": 2.4}, "sleepout": true},
	]
	for i in specs.size():
		var sp: Dictionary = specs[i]
		var h := HouseData.new()
		h.id = "v%d" % i
		BuildOps.add_room(h, 0, Rect2i(0, 0, 9, 6))
		BuildOps.add_room(h, 0, Rect2i(0, 6, 9, 3))
		BuildOps.auto_roof(h, {"shape": "hip" if i % 2 == 0 else "gable", "material": "corrugated_iron"})
		var run := BuildOps.outside_run(h, 0, HouseData.hkey(3, 0))
		var res := BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], sp["opts"])
		if sp.has("steps"):
			BuildOps.toggle_steps(h, str(res["id"]), float(sp["steps"]))
		if sp.get("sleepout", false):
			print(BuildOps.enclose_sleepout(h, str(res["id"]), 5.0, 9.0))
		var side_run := BuildOps.outside_run(h, 0, HouseData.vkey(9, 2))
		BuildOps.add_verandah(h, 0, side_run["side"], side_run["line"], side_run["from"], side_run["from"] + 4.0, {"shape": "skillion", "depth": 1.8})
		var hv := HouseView.new()
		root3.add_child(hv)
		hv.position = Vector3(i * 15.0 - 22.0, 0, 0)
		hv.setup(h, func(_x: float, _z: float) -> float: return -0.6)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.fov = 40
	var view := args[1] if args.size() > 1 else "front"
	var eye := {"front": Vector3(4, 9, -22), "close": Vector3(-14, 3.2, -8), "right": Vector3(40, 7, -10), "close2": Vector3(36, 4.5, -12), "sleep": Vector3(20, 5, -12)}[view] as Vector3
	var at := {"front": Vector3(4, 1.5, 4), "close": Vector3(-17, 2, 0), "right": Vector3(24, 1.5, 4), "close2": Vector3(27, 2, 0), "sleep": Vector3(27, 2, 0)}[view] as Vector3
	cam.transform = Transform3D(Basis(), eye).looking_at(at)
	cam.current = true
	get_root().size = Vector2i(1600, 900)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 12:
		var img := get_root().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
