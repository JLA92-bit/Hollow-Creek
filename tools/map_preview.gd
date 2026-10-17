extends SceneTree
## Saves a top-down preview of the map slice: ground colours shaded by height, trees as dots.
## Run: tools/bin/godot --headless --path . -s tools/map_preview.gd -- [out.png]

const COLOURS := [Color("#b8a46a"), Color("#9c6b43"), Color("#8f8a80"), Color("#5b4632"), Color("#4b7f99"),
	Color("#555555"), Color("#c9b48a"), Color("#d8c39a")]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "docs/screens/m1/map_preview.png"
	var m := MapSlice.load_default()
	var g := m.grid
	var s := 6
	var img := Image.create(g.width * s, g.height * s, false, Image.FORMAT_RGB8)
	for y in g.height:
		for x in g.width:
			var c: Color = COLOURS[g.get_ground(x, y)]
			var h := g.height_at(x + 0.5, y + 0.5)
			var shade := clampf(0.75 + (g.height_at(x + 1.0, y + 0.5) - g.height_at(x, y + 0.5)) * -0.8 + h * 0.03, 0.5, 1.25)
			img.fill_rect(Rect2i(x * s, y * s, s, s), c * shade)
	for o in g.objects:
		var r := int(3 * float(o["scale"]))
		img.fill_rect(Rect2i(int(float(o["x"]) * s) - r, int(float(o["y"]) * s) - r, r * 2, r * 2), Color("#2f4a2a"))
	for l: Dictionary in m.data["landmarks"]:
		var rr: Array = l.get("lot", l.get("rect"))
		var rect := Rect2i(int(rr[0]) * s, int(rr[1]) * s, int(rr[2]) * s, int(rr[3]) * s)
		var col := Color("#940E16") if l["kind"] != "plot" else Color("#4BC9F5")
		for i in rect.size.x:
			img.set_pixel(rect.position.x + i, rect.position.y, col)
			img.set_pixel(rect.position.x + i, rect.end.y - 1, col)
		for j in rect.size.y:
			img.set_pixel(rect.position.x, rect.position.y + j, col)
			img.set_pixel(rect.end.x - 1, rect.position.y + j, col)
	img.save_png(out)
	print("Saved ", out)
	quit()
