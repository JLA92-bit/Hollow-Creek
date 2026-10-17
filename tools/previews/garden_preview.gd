extends SceneTree
## Renders a finished house and garden (plants, sheds, items, fences, a gate, a path) to a PNG.
## xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 -s tools/previews/garden_preview.gd -- out.png [view]

var _frames := 0
var _out := "user://garden_preview.png"


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
	var h := HouseData.new()
	h.id = "garden"
	h.base_y = 0.6
	BuildOps.add_room(h, 0, Rect2i(0, 0, 9, 6))
	BuildOps.auto_roof(h, {"shape": "hip"})
	var run := BuildOps.outside_run(h, 0, HouseData.hkey(3, 0))
	var vr := BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], {"lace": "lace", "post": "turned_post"})
	BuildOps.toggle_steps(h, str(vr["id"]), 4.5)
	BuildOps.add_chimney(h, 0, HouseData.vkey(9, 3))
	GardenOps.set_fence(h, Vector2i(-6, -7), Vector2i(15, -7), "picket")
	GardenOps.toggle_gate(h, HouseData.hkey(4, -7))
	GardenOps.set_fence(h, Vector2i(-6, -7), Vector2i(-6, 12), "paling")
	GardenOps.set_fence(h, Vector2i(15, -7), Vector2i(15, 12), "post_wire")
	GardenOps.set_fence(h, Vector2i(-6, 12), Vector2i(15, 12), "corrugated")
	var path: Array[Vector2i] = []
	for z in range(-7, -2):
		path.append(Vector2i(4, z))
	GardenOps.paint_ground(h, path, "gravel")
	for x: float in [1.0, 2.2, 6.6, 7.8]:
		GardenOps.place_item(h, "rose", Vector2(x, -4.5))
	GardenOps.place_item(h, "hydrangea", Vector2(-1.5, -3.5))
	GardenOps.place_item(h, "agapanthus", Vector2(10.5, -3.5))
	GardenOps.place_item(h, "lavender", Vector2(3.4, -5.5))
	GardenOps.place_item(h, "lavender", Vector2(5.6, -5.5))
	GardenOps.place_item(h, "geranium", Vector2(9.5, -1.0))
	for x2: float in [-5.0, -4.0, -3.0]:
		GardenOps.place_item(h, "box_hedge", Vector2(x2 + 0.5, -6.4))
	GardenOps.place_item(h, "letterbox", Vector2(6.0, -7.6))
	GardenOps.place_item(h, "lemon_tree", Vector2(-3.5, 3.0))
	GardenOps.place_item(h, "apple_tree", Vector2(12.5, 4.0))
	GardenOps.place_item(h, "wattle", Vector2(12.5, -4.0))
	GardenOps.place_item(h, "hills_hoist", Vector2(4.5, 9.0))
	GardenOps.place_item(h, "dunny", Vector2(13.5, 10.5))
	GardenOps.place_item(h, "woodshed", Vector2(-4.0, 10.5))
	GardenOps.place_item(h, "wash_house", Vector2(10.0, 9.5))
	GardenOps.place_item(h, "chook_pen", Vector2(-3.5, 6.5))
	GardenOps.place_item(h, "water_tank", Vector2(11.0, 1.0))
	GardenOps.place_item(h, "vegie_bed", Vector2(1.0, 9.5))
	GardenOps.place_item(h, "garden_bench", Vector2(-2.0, -1.5), 90.0)
	GardenOps.place_item(h, "birdbath", Vector2(-0.5, -5.5))
	GardenOps.place_item(h, "wheelbarrow", Vector2(7.5, 7.0))
	GardenOps.place_item(h, "woodpile", Vector2(-1.5, 8.0))
	var hv := HouseView.new()
	root3.add_child(hv)
	hv.setup(h, func(_x: float, _z: float) -> float: return -0.6)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.fov = 40
	var view := args[1] if args.size() > 1 else "front"
	var eye := {"front": Vector3(4, 14, -24), "back": Vector3(5, 13, 30), "close": Vector3(-1, 3, -12)}[view] as Vector3
	var at := {"front": Vector3(4.5, 0, 1), "back": Vector3(4.5, 0, 4), "close": Vector3(3, 1, -3)}[view] as Vector3
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
