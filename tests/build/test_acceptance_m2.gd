extends GutTest
## M2 acceptance at the data level: a two-storey shop with a residence above and a single-storey
## cottage on stumps, designed from scratch, edited freely, and every step undone. (The same build is
## driven through the real tools with mouse events in scenes/build_ui/build_demo.gd.)

var _undo: UndoStack
var _history: Array[String] = []


func _step(h: HouseData, label: String, res_fn: Callable) -> void:
	var before := h.to_dict()
	var res: Dictionary = res_fn.call(h)
	assert_true(res["ok"], "%s: %s" % [label, res["msg"]])
	_undo.push(label, h.id, before, h.to_dict(), int(res.get("cost", 0)))
	_history.append(JSON.stringify(before))


func test_shop_with_residence_and_cottage_on_stumps() -> void:
	_undo = UndoStack.new()
	var shop := HouseData.new()
	shop.id = "shop"
	var empty_shop := JSON.stringify(shop.to_dict())
	_step(shop, "Shop", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 0, Rect2i(0, 0, 8, 6), {"name": "Shop", "height": 3.0}))
	_step(shop, "Storeroom", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 0, Rect2i(0, 6, 5, 3), {"name": "Storeroom", "floor": "concrete"}))
	_step(shop, "Exchange", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 0, Rect2i(5, 6, 3, 3), {"name": "Exchange"}))
	_step(shop, "Front door", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "door", "style": "front_door", "axis": "x", "x": 3.5, "z": 0, "width": 0.82, "height": 2.1, "fanlight": true}))
	_step(shop, "Shop window", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "window", "style": "shop_window", "axis": "x", "x": 0.5, "z": 0, "width": 2.5, "height": 1.9, "sill": 0.5}))
	_step(shop, "Inner door", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "door", "axis": "x", "x": 2.0, "z": 6, "width": 0.82, "height": 2.05}))
	_step(shop, "Exchange door", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "door", "axis": "z", "x": 5, "z": 7.0, "width": 0.82, "height": 2.05}))
	_step(shop, "Back window", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "window", "axis": "x", "x": 1.0, "z": 9, "width": 0.9, "height": 1.2, "sill": 0.9}))
	_step(shop, "Exchange window", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "window", "axis": "z", "x": 8, "z": 7.0, "width": 0.9, "height": 1.2, "sill": 0.9}))
	_step(shop, "Side window", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "window", "axis": "z", "x": 8, "z": 2.0, "width": 0.9, "height": 1.5, "sill": 0.9}))
	_step(shop, "First floor", func(h: HouseData) -> Dictionary: return BuildOps.add_storey(h, 1))
	_step(shop, "Living", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 1, Rect2i(0, 0, 5, 4), {"name": "Living room"}))
	_step(shop, "Bedroom", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 1, Rect2i(5, 0, 3, 4), {"name": "Bedroom"}))
	_step(shop, "Kitchen", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 1, Rect2i(0, 4, 8, 5), {"name": "Kitchen"}))
	for spec: Array in [["z", 5, 1.5, "door"], ["x", 2.0, 4, "door"], ["x", 1.0, 0, "window"], ["x", 6.0, 0, "window"], ["x", 4.0, 9, "window"]]:
		var o := {"kind": spec[3], "axis": spec[0], "width": 0.82 if spec[3] == "door" else 0.9, "height": 2.05 if spec[3] == "door" else 1.2, "sill": 0.9}
		if spec[0] == "x":
			o["x"] = spec[1]
			o["z"] = spec[2]
		else:
			o["x"] = spec[1]
			o["z"] = spec[2]
		_step(shop, "Upstairs %s" % spec[3], func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 1, o))
	_step(shop, "Stairs", func(h: HouseData) -> Dictionary: return BuildOps.add_stairs(h, 0, {"kind": "straight", "x": 0, "y": 5, "dir": "N"}))
	assert_eq(shop.rooms(0).size(), 3)
	assert_eq(shop.rooms(1).size(), 3)
	assert_eq(shop.validate(), [] as Array[String], "the shop is sound")
	assert_true(HousePathing.build(shop).reachable(0, Vector2i(4, -1), 1, Vector2i(6, 2)), "street to the upstairs bedroom")

	var cottage := HouseData.new()
	cottage.id = "cottage"
	var empty_cottage := JSON.stringify(cottage.to_dict())
	_step(cottage, "Stumps", func(h: HouseData) -> Dictionary: return BuildOps.set_foundation(h, "stumps", 0.9))
	_step(cottage, "Living", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 4), {"name": "Living room"}))
	_step(cottage, "Bedroom", func(h: HouseData) -> Dictionary: return BuildOps.add_room(h, 0, Rect2i(4, 0, 3, 4), {"name": "Bedroom"}))
	_step(cottage, "L-shape", func(h: HouseData) -> Dictionary: return BuildOps.extend_room(h, 0, Rect2i(0, 4, 3, 2)))
	_step(cottage, "Push", func(h: HouseData) -> Dictionary: return BuildOps.push_pull(h, 0, HouseData.vkey(7, 2), 1))
	_step(cottage, "Front door", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "door", "axis": "x", "x": 1.5, "z": 0, "width": 0.82, "height": 2.05}))
	_step(cottage, "Inner door", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "door", "axis": "z", "x": 4, "z": 2.0, "width": 0.82, "height": 2.05}))
	_step(cottage, "Window", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "window", "axis": "z", "x": 0, "z": 1.5, "width": 0.9, "height": 1.2, "sill": 0.9}))
	_step(cottage, "Bedroom window", func(h: HouseData) -> Dictionary: return BuildOps.place_opening(h, 0, {"kind": "window", "axis": "x", "x": 5.5, "z": 0, "width": 0.9, "height": 1.2, "sill": 0.9}))
	_step(cottage, "Lino", func(h: HouseData) -> Dictionary: return BuildOps.paint_floor(h, 0, [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)] as Array[Vector2i], "lino_checks"))
	_step(cottage, "Move bedroom", func(h: HouseData) -> Dictionary: return BuildOps.move_room(h, 0, Vector2i(5, 1), Vector2i(0, 1)))
	_step(cottage, "Move it back", func(h: HouseData) -> Dictionary: return BuildOps.move_room(h, 0, Vector2i(5, 2), Vector2i(0, -1)))
	assert_eq(cottage.rooms(0).size(), 2)
	assert_eq(float(cottage.foundation["height"]), 0.9)
	assert_eq(cottage.validate(), [] as Array[String], "the cottage is sound")
	# The builder makes meshes for both.
	for h: HouseData in [shop, cottage]:
		var b := HouseMeshBuilder.new(h)
		for l in h.levels():
			var kit := MeshKit.new()
			b.build_walls(kit, l, func(_k: String) -> bool: return false)
			b.build_structure(kit, l)
			assert_true(kit.has_geometry())

	# Undo every step: each state matches what it was before that step.
	var states: Dictionary = {"shop": shop, "cottage": cottage}
	var i := _history.size() - 1
	while _undo.can_undo():
		var step := _undo.undo()
		var restored := HouseData.from_dict(step["state"])
		assert_eq(JSON.stringify(restored.to_dict()), _history[i], "undo %d restores %s" % [i, step["label"]])
		states[step["house"]] = restored
		i -= 1
	assert_eq(JSON.stringify((states["shop"] as HouseData).to_dict()), empty_shop)
	assert_eq(JSON.stringify((states["cottage"] as HouseData).to_dict()), empty_cottage)


func test_houses_survive_a_save_and_load() -> void:
	var h := HouseData.new()
	h.id = "house_test"
	BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3), {"name": "Hut"})
	h.base_y = 4.25
	var keep := GameState.houses.duplicate(true)
	GameState.houses = {h.id: h.to_dict()}
	var save := SaveSystem.build_save()
	GameState.houses = {}
	assert_true(SaveSystem.apply_save(JSON.parse_string(JSON.stringify(save)) as Dictionary))
	var back := HouseData.from_dict(GameState.houses["house_test"])
	assert_eq(back.rooms(0).size(), 1)
	assert_almost_eq(back.base_y, 4.25, 0.001)
	GameState.houses = keep
