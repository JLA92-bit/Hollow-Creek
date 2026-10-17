extends GutTest
## M3 surfaces: per-face paint, wallpapers, dado panelling and tiles, room and house painting, the
## eyedropper, and surfaces surviving push, pull and undo.


func _cottage() -> HouseData:
	var h := HouseData.new()
	BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 4), {"name": "Kitchen", "paint": "mint", "height": 3.0})
	BuildOps.add_room(h, 0, Rect2i(4, 0, 3, 4), {"name": "Bedroom", "paint": "rose", "height": 3.0})
	return h


func _names(h: HouseData) -> Array[String]:
	var b := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	b.build_walls(kit, 0, func(_k: String) -> bool: return false)
	var mesh := kit.commit(b.mats)
	var out: Array[String] = []
	for i in mesh.get_surface_count():
		out.append(mesh.surface_get_name(i))
	return out


func test_paint_one_face_with_a_custom_colour() -> void:
	var h := _cottage()
	var k := HouseData.hkey(1, 0)
	assert_true(BuildOps.paint_faces(h, 0, [[k, "b"]], {"mat": "plaster", "paint": "#123456"})["ok"])
	assert_eq(str((((h.walls(0)[k] as Dictionary)["f"] as Dictionary)["b"] as Dictionary)["paint"]), "#123456")
	assert_has(_names(h), "plaster#123456")


func test_paint_a_whole_room() -> void:
	var h := _cottage()
	var r := h.room_at_tile(0, Vector2i(5, 1))
	var faces := BuildOps.room_faces(h, 0, r)
	assert_eq(faces.size(), 14, "a 3 x 4 room has 14 m of wall")
	BuildOps.paint_faces(h, 0, faces, {"mat": "wallpaper", "pattern": "floral", "colourway": "cream_rose"})
	var names := _names(h)
	assert_has(names, "wallpaper:floral:cream_rose")
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("plaster#")), "the kitchen keeps its paint")


func test_whole_house_and_exterior() -> void:
	var h := _cottage()
	var inside := BuildOps.interior_faces(h)
	var outside := BuildOps.exterior_faces(h)
	assert_eq(outside.size(), 22, "perimeter of a 7 x 4 house")
	assert_eq(inside.size(), 16 + 14, "every inside face: 16 m of kitchen and 14 m of bedroom")
	BuildOps.paint_faces(h, 0, outside, {"mat": "fibro", "paint": "light_stone"})
	assert_has(_names(h), "fibro#%s" % MaterialLibrary.paint("light_stone").to_html(false))


func test_dado_panelling_splits_the_wall() -> void:
	var h := _cottage()
	var r := h.room_at_tile(0, Vector2i(1, 1))
	BuildOps.paint_faces(h, 0, BuildOps.room_faces(h, 0, r), {"mat": "vj_panelling", "h": 1.2}, "dado")
	var names := _names(h)
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("vj_panelling")), "panelling below")
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("plaster#%s" % MaterialLibrary.paint("mint").to_html(false))), "paint above")
	# Repainting the finish keeps the dado.
	BuildOps.paint_faces(h, 0, BuildOps.room_faces(h, 0, h.room_at_tile(0, Vector2i(1, 1))), {"mat": "plaster", "paint": "butter"})
	var fd: Dictionary = ((h.walls(0)[HouseData.hkey(1, 0)] as Dictionary)["f"] as Dictionary)["b"]
	assert_eq(str((fd["dado"] as Dictionary)["mat"]), "vj_panelling")


func test_eyedropper_reads_defaults_and_painted_faces() -> void:
	var h := _cottage()
	var picked := BuildOps.pick_surface(h, 0, HouseData.hkey(1, 0), "a")
	assert_eq(str(picked["mat"]), "weatherboard", "outside defaults to the house cladding")
	var inner := BuildOps.pick_surface(h, 0, HouseData.hkey(1, 0), "b")
	assert_eq(str(inner["paint"]), "mint")
	BuildOps.paint_faces(h, 0, [[HouseData.hkey(1, 0), "b"]], {"mat": "wall_tiles", "paint": "white"})
	assert_eq(str(BuildOps.pick_surface(h, 0, HouseData.hkey(1, 0), "b")["mat"]), "wall_tiles")


func test_wallpaper_survives_push_pull_and_undo() -> void:
	var h := _cottage()
	var k := HouseData.vkey(7, 1)
	BuildOps.paint_faces(h, 0, [[k, "a"]], {"mat": "wallpaper", "pattern": "stripe", "colourway": "sage_cream"})
	var before := h.to_dict()
	BuildOps.push_pull(h, 0, k, 2)
	var moved: Dictionary = ((h.walls(0)[HouseData.vkey(9, 1)] as Dictionary)["f"] as Dictionary)["a"]
	assert_eq(str(moved["pattern"]), "stripe")
	var back := HouseData.from_dict(before)
	assert_eq(str((((back.walls(0)[k] as Dictionary)["f"] as Dictionary)["a"] as Dictionary)["pattern"]), "stripe")


func test_room_trims() -> void:
	var h := _cottage()
	BuildOps.set_room_props(h, 0, Vector2i(1, 1), {"cornice": true, "picture_rail": false})
	var r := h.room_at_tile(0, Vector2i(1, 1))
	assert_true(bool((r["props"] as Dictionary)["cornice"]))
	assert_gt(_names(h).size(), 0)
