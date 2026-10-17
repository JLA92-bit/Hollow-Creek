extends GutTest
## docs/HOUSE_BUILDING.md share codes: export then import gives an identical house (garden and all),
## broken codes are refused, and the blueprint library keeps designs.


func _finished_house() -> HouseData:
	var h := HouseData.new()
	h.id = "house_7"
	h.name = "Rosebank"
	h.origin = Vector2i(40, 30)
	h.base_y = 12.5
	BuildOps.add_room(h, 0, Rect2i(0, 0, 5, 4), {"name": "Parlour", "paint": "duck_egg"})
	BuildOps.add_room(h, 0, Rect2i(5, 0, 4, 4), {"name": "Kitchen", "paint": "mint"})
	BuildOps.place_opening(h, 0, {"kind": "door", "style": "front_door", "axis": "x", "x": 2.0, "z": 0.0, "width": 0.82, "height": 2.1})
	BuildOps.paint_faces(h, 0, BuildOps.room_faces(h, 0, h.room_at_tile(0, Vector2i(1, 1))), {"mat": "wallpaper", "pattern": "floral", "colourway": "cream_rose"})
	BuildOps.auto_roof(h, {"shape": "dutch", "material": "roof_terracotta"})
	var run := BuildOps.outside_run(h, 0, HouseData.hkey(2, 0))
	BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], {"lace": "lace", "rail": "timber"})
	BuildOps.add_chimney(h, 0, HouseData.vkey(5, 1))
	GardenOps.place_item(h, "rose", Vector2(1, -4))
	GardenOps.place_item(h, "dunny", Vector2(8, 10))
	GardenOps.set_fence(h, Vector2i(-3, -6), Vector2i(12, -6), "picket")
	GardenOps.paint_ground(h, [Vector2i(2, -5)] as Array[Vector2i], "gravel")
	GardenOps.terrain_brush(h, "raise", Vector2(-4, 8), 2.0, func(_x: int, _y: int) -> float: return -0.4)
	return h


func test_round_trip_is_identical() -> void:
	var h := _finished_house()
	var code := ShareCode.encode(h)
	assert_true(code.begins_with("HOLLOW1:"))
	var back := ShareCode.decode(code)
	assert_not_null(back)
	assert_eq(ShareCode.fingerprint(back), ShareCode.fingerprint(h), "the design comes back exactly")
	assert_true(is_nan(back.base_y), "where it stood isn't part of the design")
	assert_eq(back.origin, Vector2i.ZERO)
	assert_eq(back.name, "Rosebank")


func test_codes_survive_line_breaks() -> void:
	var h := _finished_house()
	var code := ShareCode.encode(h)
	var wrapped := ""
	for i in range(0, code.length(), 60):
		wrapped += code.substr(i, 60) + "\n  "
	assert_not_null(ShareCode.decode(wrapped))


func test_broken_codes_are_refused() -> void:
	var code := ShareCode.encode(_finished_house())
	assert_null(ShareCode.decode(""))
	assert_null(ShareCode.decode("HC1:12:abc"))
	assert_null(ShareCode.decode(code.substr(0, code.length() / 2)), "a code cut short")
	assert_null(ShareCode.decode("HOLLOW1:99999999999:AAAA"))


func test_apply_to_keeps_the_new_place() -> void:
	var src := ShareCode.decode(ShareCode.encode(_finished_house()))
	var h := HouseData.new()
	h.id = "house_9"
	h.origin = Vector2i(80, 20)
	ShareCode.apply_to(h, src)
	assert_eq(h.id, "house_9")
	assert_eq(h.origin, Vector2i(80, 20))
	assert_eq(h.rooms(0).size(), 2)
	assert_eq(ShareCode.fingerprint(h), ShareCode.fingerprint(src))
	assert_gt(ShareCode.estimate_cost(h), 50, "a finished house costs something in the story")


func test_blueprint_library() -> void:
	var h := _finished_house()
	var file := Blueprints.save("Test Rosebank", h)
	assert_ne(file, "")
	var found := false
	for e: Dictionary in Blueprints.list():
		if e["file"] == file:
			found = true
			assert_eq(int(e["rooms"]), 2)
	assert_true(found)
	var back := Blueprints.load_design(file)
	assert_eq(ShareCode.fingerprint(back), ShareCode.fingerprint(h))
	assert_true(Blueprints.remove(file))
