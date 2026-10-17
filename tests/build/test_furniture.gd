extends GutTest
## docs/HOUSE_BUILDING.md Buy mode: the catalogue searches and filters, furniture goes in rooms without
## piling into itself, wall items hang on walls, surface items stand on tables and move with them,
## groups move and turn together, and every catalogue object can be recoloured per slot.


func _house() -> HouseData:
	var h := HouseData.new()
	h.id = "buy_test"
	BuildOps.add_room(h, 0, Rect2i(0, 0, 5, 4), {"name": "Kitchen"})
	BuildOps.add_room(h, 0, Rect2i(5, 0, 4, 4), {"name": "Bedroom"})
	return h


func _ok(res: Dictionary) -> String:
	assert_true(res["ok"], str(res["msg"]))
	return str(res.get("id", ""))


func test_catalogue_search_and_filters() -> void:
	assert_gt(Catalogue.items().size(), 25)
	assert_true(Catalogue.search("bath").has("clawfoot_bath"))
	for id in Catalogue.search("", "kitchen"):
		var rooms: Array = Catalogue.item(id)["rooms"]
		assert_true(rooms.has("kitchen") or rooms.has("any"))
	for id2 in Catalogue.search("", "", "lighting"):
		assert_eq(str(Catalogue.item(id2)["function"]), "lighting")
	for id3 in Catalogue.search("", "", "", 3):
		assert_true(int(Catalogue.item(id3)["price"]) <= 3)
	assert_true(Catalogue.search("", "", "", 0, "1950s").has("laminex_table"))


func test_every_item_has_a_model_and_slots() -> void:
	for id: String in Catalogue.items():
		var it := Catalogue.item(id)
		assert_true(ResourceLoader.exists(Catalogue.model_path(str(it["model"]))), "%s has its model" % id)
		assert_false((it.get("slots", {}) as Dictionary).is_empty(), "%s can be recoloured" % id)
		var scene := load(Catalogue.model_path(str(it["model"]))) as PackedScene
		var n := scene.instantiate() as Node3D
		var names: Dictionary = {}
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				names[m.resource_name if m else ""] = true
		for slot: String in it["slots"]:
			assert_true(names.has(slot), "%s has a %s slot in its model" % [id, slot])
		n.free()


func test_floor_items_stay_in_rooms_and_apart() -> void:
	var h := _house()
	var table := _ok(FurnitureOps.place(h, 0, "laminex_table", Vector2(2.5, 2.0)))
	assert_false(FurnitureOps.place(h, 0, "settee", Vector2(2.5, 2.0))["ok"], "not on top of the table")
	assert_false(FurnitureOps.place(h, 0, "settee", Vector2(4.8, 2.0))["ok"], "not through a wall")
	assert_false(FurnitureOps.place(h, 0, "settee", Vector2(20, 20))["ok"], "not outside")
	_ok(FurnitureOps.place(h, 0, "kitchen_chair", Vector2(2.5, 1.2), 180.0))
	_ok(FurnitureOps.update(h, table, {"rot": 90.0}))
	assert_almost_eq(FurnitureOps.rect_of(FurnitureOps.object_by_id(h, table)).size.x, 0.76, 0.001, "turning swaps its footprint")


func test_surface_items_ride_along() -> void:
	var h := _house()
	var table := _ok(FurnitureOps.place(h, 0, "laminex_table", Vector2(2.5, 2.0)))
	var radio := _ok(FurnitureOps.place(h, 0, "wireless_set", Vector2(2.3, 2.0)))
	var r := FurnitureOps.object_by_id(h, radio)
	assert_eq(str(r["on"]), table)
	assert_almost_eq(float(r["y"]), 0.76, 0.001, "it stands on the table top")
	_ok(FurnitureOps.update(h, table, {"x": 2.0}))
	assert_almost_eq(float(FurnitureOps.object_by_id(h, radio)["x"]), 1.8, 0.001, "and moves with it")
	_ok(FurnitureOps.remove(h, table))
	assert_true(FurnitureOps.object_by_id(h, radio).is_empty(), "clearing the table clears what's on it")


func test_stacking_crates() -> void:
	var h := _house()
	var a := _ok(FurnitureOps.place(h, 0, "crate", Vector2(1.0, 1.0)))
	var b := _ok(FurnitureOps.place(h, 0, "crate", Vector2(1.0, 1.0), 0.0, {"stack": true}))
	assert_almost_eq(float(FurnitureOps.object_by_id(h, b)["y"]), 0.35, 0.001)
	assert_eq(str(FurnitureOps.object_by_id(h, b)["on"]), a)


func test_wall_and_ceiling_items() -> void:
	var h := _house()
	var phone := _ok(FurnitureOps.place(h, 0, "wall_telephone", Vector2(2.0, 0.2)))
	var o := FurnitureOps.object_by_id(h, phone)
	assert_almost_eq(float(o["z"]), HouseData.WALL_THICKNESS * 0.5 + FurnitureOps.WALL_GAP, 0.001, "against the north wall")
	assert_eq(float(o["rot"]), 0.0, "facing into the room")
	assert_eq(float(o["y"]), 1.25)
	_ok(FurnitureOps.update(h, phone, {"y": 1.5}))
	assert_eq(float(FurnitureOps.object_by_id(h, phone)["y"]), 1.5, "raised")
	var east := _ok(FurnitureOps.place(h, 0, "picture_frame", Vector2(8.8, 2.0)))
	assert_eq(float(FurnitureOps.object_by_id(h, east)["rot"]), -90.0, "on the east wall it faces west")
	assert_false(FurnitureOps.place(h, 0, "picture_frame", Vector2(2.0, 2.0))["ok"], "needs a wall nearby")
	var light := _ok(FurnitureOps.place(h, 0, "pendant_light", Vector2(2.5, 2.0)))
	assert_almost_eq(float(FurnitureOps.object_by_id(h, light)["y"]), 2.7, 0.001, "hangs from the ceiling")


func test_group_moves_and_turns() -> void:
	var h := _house()
	var t := _ok(FurnitureOps.place(h, 0, "laminex_table", Vector2(2.5, 2.0)))
	var c1 := _ok(FurnitureOps.place(h, 0, "kitchen_chair", Vector2(2.5, 1.2), 180.0))
	var c2 := _ok(FurnitureOps.place(h, 0, "kitchen_chair", Vector2(2.5, 2.8)))
	_ok(FurnitureOps.move_group(h, [t, c1, c2], Vector2(-0.5, 0.0), 1))
	assert_almost_eq(float(FurnitureOps.object_by_id(h, t)["x"]), 2.0, 0.001)
	assert_eq(float(FurnitureOps.object_by_id(h, t)["rot"]), 90.0)
	assert_false(FurnitureOps.move_group(h, [t, c1, c2], Vector2(9.0, 0.0))["ok"], "the group can't go outside")
	assert_almost_eq(float(FurnitureOps.object_by_id(h, t)["x"]), 2.0, 0.001, "and stays put when it can't")


func test_design_slots_and_styles() -> void:
	var h := _house()
	var bed := _ok(FurnitureOps.place(h, 0, "iron_bed", Vector2(7.0, 2.0)))
	var o := FurnitureOps.object_by_id(h, bed)
	assert_eq(str(Catalogue.slot_value(o, "blanket")["mat"]), "chenille", "defaults from the catalogue")
	_ok(FurnitureOps.set_slot(h, bed, "blanket", {"mat": "velvet", "colour": "#5A2238"}))
	assert_eq(str(Catalogue.slot_value(o, "blanket")["mat"]), "velvet")
	assert_false(FurnitureOps.set_slot(h, bed, "laminex", {"mat": "laminex"})["ok"])
	var lamp := _ok(FurnitureOps.place(h, 0, "standard_lamp", Vector2(8.3, 0.5)))
	_ok(FurnitureOps.apply_style(h, lamp, {"brass": {"mat": "chrome", "colour": "#E8E8E8"}, "blanket": {"mat": "velvet"}}))
	assert_eq(str(Catalogue.slot_value(FurnitureOps.object_by_id(h, lamp), "brass")["mat"]), "chrome")
	_ok(FurnitureOps.set_light(h, lamp, 1.5, 3200.0))
	assert_eq(float(Catalogue.light_of(FurnitureOps.object_by_id(h, lamp))["kelvin"]), 3200.0)
	assert_lt(Catalogue.kelvin_colour(1900).b, Catalogue.kelvin_colour(5000).b, "candlelight is warmer than daylight")


func test_objects_survive_a_share_code() -> void:
	var h := _house()
	var bed := _ok(FurnitureOps.place(h, 0, "iron_bed", Vector2(7.0, 2.0)))
	FurnitureOps.set_slot(h, bed, "blanket", {"colour": "#E9C3C0"})
	var back := ShareCode.decode(ShareCode.encode(h))
	assert_eq(str(Catalogue.slot_value(FurnitureOps.object_by_id(back, bed), "blanket")["colour"]), "#E9C3C0")
