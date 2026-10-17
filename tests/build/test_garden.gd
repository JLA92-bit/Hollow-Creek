extends GutTest
## docs/HOUSE_BUILDING.md landscaping: terrain shaping keeps the ground under the house below its
## floor, paths stay in the yard, plants and sheds don't pile up, fences and gates, and the garden
## travels with the house through to_dict.


func _house() -> HouseData:
	var h := HouseData.new()
	h.id = "garden_test"
	h.base_y = 10.0
	BuildOps.add_room(h, 0, Rect2i(0, 0, 6, 4))
	return h


func _ok(res: Dictionary) -> void:
	assert_true(res["ok"], str(res["msg"]))


## JSON text with numbers in one form, so 0 and 0.0 compare equal.
func _canon(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)))


func _flat(_cx: int, _cy: int) -> float:
	return -0.5


func test_raise_and_lower_in_the_yard() -> void:
	var h := _house()
	_ok(GardenOps.terrain_brush(h, "raise", Vector2(3, 9), 2.0, _flat))
	assert_almost_eq(float(h.terrain["3,9"]), -0.25, 0.001, "the centre rises a step")
	assert_false(h.terrain.has("3,12"), "nothing past the brush")
	_ok(GardenOps.terrain_brush(h, "lower", Vector2(3, 9), 2.0, func(cx: int, cy: int) -> float: return float(h.terrain.get("%d,%d" % [cx, cy], -0.5))))
	assert_almost_eq(float(h.terrain["3,9"]), -0.5, 0.001)
	assert_false(GardenOps.terrain_brush(h, "raise", Vector2(40, 40), 2.0, _flat)["ok"], "outside the lot")


func test_ground_under_the_house_stays_below_the_floor() -> void:
	var h := _house()
	var high := func(_cx: int, _cy: int) -> float: return 0.4
	for i in 8:
		GardenOps.terrain_brush(h, "raise", Vector2(3, 1), 4.0, func(cx: int, cy: int) -> float: return float(h.terrain.get("%d,%d" % [cx, cy], high.call(cx, cy))))
	assert_true(float(h.terrain["3,2"]) <= h.floor_y() - 0.3 + 0.001)
	assert_gt(float(h.terrain.get("3,-2", 0.0)), 0.4, "the yard can still be raised")


func test_flatten_and_smooth() -> void:
	var h := _house()
	var bumpy := func(cx: int, cy: int) -> float: return 0.5 if (cx + cy) % 2 == 0 else -0.5
	_ok(GardenOps.terrain_brush(h, "smooth", Vector2(3, 10), 2.0, bumpy))
	assert_lt(absf(float(h.terrain["3,10"])), 0.5, "smoothing pulls bumps in")
	_ok(GardenOps.terrain_brush(h, "flatten", Vector2(3, 10), 2.0, bumpy))


func test_paths_and_beds_stay_in_the_yard() -> void:
	var h := _house()
	_ok(GardenOps.paint_ground(h, [Vector2i(2, 5), Vector2i(2, 6)] as Array[Vector2i], "gravel"))
	assert_eq(str(h.ground["2,5"]), "gravel")
	assert_false(GardenOps.paint_ground(h, [Vector2i(2, 2)] as Array[Vector2i], "gravel")["ok"], "not under the house")
	assert_false(GardenOps.paint_ground(h, [Vector2i(2, 6)] as Array[Vector2i], "lava")["ok"])


func test_plants_and_sheds() -> void:
	var h := _house()
	_ok(GardenOps.place_item(h, "rose", Vector2(1, 6)))
	_ok(GardenOps.place_item(h, "rose", Vector2(1.25, 6)))
	var shed := GardenOps.place_item(h, "dunny", Vector2(8, 10))
	_ok(shed)
	assert_false(GardenOps.place_item(h, "woodshed", Vector2(8.5, 10))["ok"], "sheds don't overlap")
	assert_false(GardenOps.place_item(h, "lemon_tree", Vector2(3, 2))["ok"], "nothing under the house")
	assert_false(GardenOps.place_item(h, "rose", Vector2(50, 50))["ok"], "nothing past the lot")
	_ok(GardenOps.update_item(h, str(shed["id"]), {"rot": 90.0}))
	assert_eq(GardenOps.item_at(h, Vector2(8, 10))["kind"], "dunny")
	_ok(GardenOps.remove_item(h, str(shed["id"])))
	assert_eq(h.garden.size(), 2)


func test_fences_and_gates() -> void:
	var h := _house()
	_ok(GardenOps.set_fence(h, Vector2i(-3, 8), Vector2i(9, 8), "picket"))
	assert_eq(h.fences.size(), 12)
	assert_false(GardenOps.set_fence(h, Vector2i(-3, 8), Vector2i(9, 9), "picket")["ok"], "fences run straight")
	assert_false(GardenOps.set_fence(h, Vector2i(0, 0), Vector2i(6, 0), "picket")["ok"], "not along the house walls")
	var k := GardenOps.fence_at(h, Vector2(3.5, 8.1))
	assert_eq(k, HouseData.hkey(3, 8))
	_ok(GardenOps.toggle_gate(h, k))
	assert_true(bool(h.fences[k]["gate"]))
	_ok(GardenOps.remove_fence(h, Vector2i(-3, 8), Vector2i(0, 8)))
	assert_eq(h.fences.size(), 9)


func test_garden_round_trips_and_builds() -> void:
	var h := _house()
	GardenOps.place_item(h, "hills_hoist", Vector2(3, 9))
	GardenOps.place_item(h, "water_tank", Vector2(8, 2))
	GardenOps.place_item(h, "box_hedge", Vector2(0, 7))
	GardenOps.place_item(h, "vegie_bed", Vector2(-3, 9))
	GardenOps.place_item(h, "apple_tree", Vector2(-6, 2))
	GardenOps.set_fence(h, Vector2i(-8, 12), Vector2i(10, 12), "paling")
	GardenOps.paint_ground(h, [Vector2i(3, 5)] as Array[Vector2i], "footpath")
	GardenOps.terrain_brush(h, "raise", Vector2(-5, 10), 2.0, _flat)
	var copy := HouseData.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	assert_eq(_canon(copy.to_dict()), _canon(h.to_dict()), "the garden survives a round trip")
	var b := HouseMeshBuilder.new(copy)
	var kit := MeshKit.new()
	GardenBuilder.new(b).build(kit)
	assert_true(kit.has_geometry())
