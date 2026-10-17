extends SceneTree
## Renders every roof shape and material side by side to a PNG, for checking roofs by eye.
## xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 -s tools/previews/roof_preview.gd -- out.png

var _frames := 0
var _out := "user://roof_preview.png"


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
	var layouts := [
		["hip", "corrugated_iron", [Rect2i(0, 0, 9, 6)]],
		["gable", "roof_terracotta", [Rect2i(0, 0, 9, 5), Rect2i(0, 5, 4, 4)]],
		["half_hip", "roof_slate", [Rect2i(0, 0, 9, 6)]],
		["dutch", "roof_paint_red", [Rect2i(0, 0, 9, 6)]],
		["hip", "roof_paint_green", [Rect2i(0, 0, 11, 5), Rect2i(4, 5, 4, 4)]],
		["skillion", "corrugated_iron_old", [Rect2i(0, 0, 6, 4)]],
		["gable", "roof_shingles", [Rect2i(0, 0, 8, 7)]],
		["flat", "corrugated_iron", [Rect2i(0, 0, 6, 5)]],
	]
	for i in layouts.size():
		var lay: Array = layouts[i]
		var h := HouseData.new()
		h.id = "p%d" % i
		for r: Rect2i in lay[2]:
			BuildOps.add_room(h, 0, r)
		BuildOps.auto_roof(h, {"shape": lay[0], "material": lay[1]})
		if i == 0:
			BuildOps.add_chimney(h, 0, HouseData.hkey(6, 0))
		var hv := HouseView.new()
		root3.add_child(hv)
		hv.position = Vector3((i % 4) * 14.0 - 24.0, 0, (i / 4) * 15.0 - 8.0)
		hv.setup(h, func(_x: float, _z: float) -> float: return 0.0)
	# A two-storey house with a lean-to.
	var h2 := HouseData.new()
	h2.id = "two"
	BuildOps.add_room(h2, 0, Rect2i(0, 0, 8, 8))
	BuildOps.add_storey(h2, 1)
	BuildOps.add_room(h2, 1, Rect2i(0, 0, 8, 5))
	BuildOps.auto_roof(h2, {"shape": "hip", "material": "roof_terracotta"})
	var hv2 := HouseView.new()
	root3.add_child(hv2)
	hv2.position = Vector3(32, 0, -2)
	hv2.setup(h2, func(_x: float, _z: float) -> float: return 0.0)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.fov = 40
	var view := args[1] if args.size() > 1 else "high"
	var eye := {"high": Vector3(4, 30, 44), "low": Vector3(-4, 9, 30), "right": Vector3(30, 12, 26), "back": Vector3(0, 16, -40)}[view] as Vector3
	var at := {"high": Vector3(4, 0, 2), "low": Vector3(-6, 3, 0), "right": Vector3(24, 3, -2), "back": Vector3(0, 2, 0)}[view] as Vector3
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
