extends GutTest
## docs/HOUSE_BUILDING.md tests: the room tool, push and pull and move room keep valid closed rooms;
## stairs cut the right floor opening and connect pathfinding; faces survive push, pull and undo.


func _house() -> HouseData:
	var h := HouseData.new()
	h.id = "test"
	return h


func _ok(res: Dictionary) -> void:
	assert_true(res["ok"], str(res["msg"]))


func test_room_tool_makes_a_closed_room() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3), {"name": "Kitchen", "paint": "mint"}))
	var rooms := h.rooms(0)
	assert_eq(rooms.size(), 1)
	assert_eq(float(rooms[0]["area"]), 12.0)
	assert_eq(h.walls(0).size(), 14)
	assert_eq(h.floors(0).size(), 12)
	assert_eq(h.room_name(rooms[0]), "Kitchen")


func test_neighbouring_rooms_share_a_wall() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3)))
	_ok(BuildOps.add_room(h, 0, Rect2i(4, 0, 3, 3)))
	assert_eq(h.rooms(0).size(), 2)
	assert_eq(h.walls(0).size(), 14 + 9, "the shared wall isn't doubled")


func test_l_shaped_room() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3)))
	_ok(BuildOps.extend_room(h, 0, Rect2i(0, 3, 2, 2)))
	var rooms := h.rooms(0)
	assert_eq(rooms.size(), 1, "one L-shaped room")
	assert_eq(float(rooms[0]["area"]), 16.0)
	assert_false(h.walls(0).has(HouseData.hkey(0, 3)), "wall between the two parts is gone")


func test_push_wall_out_grows_the_room_and_keeps_it_closed() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3)))
	_ok(BuildOps.push_pull(h, 0, HouseData.vkey(4, 1), 2))
	var rooms := h.rooms(0)
	assert_eq(rooms.size(), 1)
	assert_eq(float(rooms[0]["area"]), 18.0, "6 x 3")
	assert_eq(h.floors(0).size(), 18, "floor followed the wall")
	assert_true(h.walls(0).has(HouseData.vkey(6, 0)))
	assert_false(h.walls(0).has(HouseData.vkey(4, 0)))


func test_pull_wall_in_shrinks_the_room() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 5, 4)))
	_ok(BuildOps.push_pull(h, 0, HouseData.hkey(2, 4), -1))
	var rooms := h.rooms(0)
	assert_eq(rooms.size(), 1)
	assert_eq(float(rooms[0]["area"]), 15.0, "5 x 3")
	assert_eq(h.floors(0).size(), 15)
	assert_eq(h.walls(0).size(), 16)


func test_push_stops_at_another_wall() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 3, 3)))
	_ok(BuildOps.add_room(h, 0, Rect2i(5, 0, 3, 3)))
	assert_false(BuildOps.push_pull(h, 0, HouseData.vkey(3, 1), 3)["ok"])


func test_faces_and_openings_travel_with_push_pull_and_survive_undo() -> void:
	var h := _house()
	var undo := UndoStack.new()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3), {"paint": "rose"}))
	_ok(BuildOps.paint_face(h, 0, HouseData.vkey(4, 1), "b", {"mat": "weatherboard", "paint": "duck_egg"}))
	_ok(BuildOps.place_opening(h, 0, {"kind": "window", "style": "double_hung", "axis": "z", "x": 4, "z": 1.0, "width": 0.9, "height": 1.2, "sill": 0.9}))
	var before := h.to_dict()
	_ok(BuildOps.push_pull(h, 0, HouseData.vkey(4, 1), 1))
	undo.push("Push wall", h.id, before, h.to_dict())
	var moved: Dictionary = h.walls(0)[HouseData.vkey(5, 1)]
	assert_eq(str(((moved["f"] as Dictionary)["b"] as Dictionary)["paint"]), "duck_egg", "outside face moved")
	assert_eq(str(((moved["f"] as Dictionary)["a"] as Dictionary)["paint"]), "rose", "inside face moved")
	assert_eq(int((h.openings(0)[0] as Dictionary)["x"]), 5, "window moved with the wall")
	var step := undo.undo()
	h = HouseData.from_dict(step["state"])
	assert_eq(JSON.stringify(h.to_dict()), JSON.stringify(before), "undo restores exactly")
	var face: Dictionary = ((h.walls(0)[HouseData.vkey(4, 1)] as Dictionary)["f"] as Dictionary)["b"]
	assert_eq(str(face["paint"]), "duck_egg")


func test_move_room_keeps_it_closed_and_leaves_shared_walls() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3), {"name": "Shed"}))
	_ok(BuildOps.move_room(h, 0, Vector2i(1, 1), Vector2i(6, 2)))
	var rooms := h.rooms(0)
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0]["bounds"], Rect2i(6, 2, 4, 3))
	assert_eq(h.room_name(rooms[0]), "Shed")
	assert_eq(h.floors(0).size(), 12)


func test_rotate_room() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 2)))
	_ok(BuildOps.place_opening(h, 0, {"kind": "door", "style": "four_panel", "axis": "x", "x": 1.0, "z": 0, "width": 0.82, "height": 2.05}))
	_ok(BuildOps.move_room(h, 0, Vector2i(0, 0), Vector2i.ZERO, 1))
	var rooms := h.rooms(0)
	assert_eq(rooms.size(), 1)
	assert_eq((rooms[0]["bounds"] as Rect2i).size, Vector2i(2, 4), "turned on its side")
	var door: Dictionary = h.openings(0)[0]
	assert_eq(str(door["axis"]), "z", "door turned with the wall")
	for k in HouseData.opening_edges(door):
		assert_true(h.walls(0).has(k))


func test_move_room_away_from_neighbour() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 3, 3)))
	_ok(BuildOps.add_room(h, 0, Rect2i(3, 0, 3, 3)))
	_ok(BuildOps.move_room(h, 0, Vector2i(4, 1), Vector2i(4, 0)))
	assert_eq(h.rooms(0).size(), 2, "both rooms stay closed")
	assert_true(h.walls(0).has(HouseData.vkey(3, 1)), "first room kept its wall")


func test_move_room_cannot_overlap() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 3, 3)))
	_ok(BuildOps.add_room(h, 0, Rect2i(5, 0, 3, 3)))
	assert_false(BuildOps.move_room(h, 0, Vector2i(1, 1), Vector2i(4, 0))["ok"])


func test_diagonal_wall_splits_a_room_and_half_walls_dont() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 4)))
	_ok(BuildOps.add_wall(h, 0, Vector2i(0, 2), Vector2i(4, 2), "half"))
	assert_eq(h.rooms(0).size(), 1, "half wall doesn't divide the room")
	_ok(BuildOps.remove_walls(h, 0, Vector2i(0, 2), Vector2i(4, 2)))
	_ok(BuildOps.add_wall(h, 0, Vector2i(0, 0), Vector2i(4, 4)))
	var rooms := h.rooms(0)
	assert_eq(rooms.size(), 2, "diagonal wall makes two rooms")
	assert_eq(float(rooms[0]["area"]), 8.0)


func test_wall_tool_rejects_odd_angles() -> void:
	assert_false(BuildOps.add_wall(_house(), 0, Vector2i(0, 0), Vector2i(3, 1))["ok"])


func test_openings_need_walls_and_dont_overlap_but_can_stack() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3), {"height": 3.3}))
	assert_false(BuildOps.place_opening(h, 0, {"kind": "window", "axis": "x", "x": 1.0, "z": 1, "width": 0.9, "height": 1.2, "sill": 0.9})["ok"], "no wall there")
	_ok(BuildOps.place_opening(h, 0, {"kind": "window", "axis": "x", "x": 1.0, "z": 0, "width": 0.9, "height": 1.0, "sill": 0.8}))
	assert_false(BuildOps.place_opening(h, 0, {"kind": "window", "axis": "x", "x": 1.5, "z": 0, "width": 0.9, "height": 1.0, "sill": 0.8})["ok"], "overlap")
	_ok(BuildOps.place_opening(h, 0, {"kind": "window", "axis": "x", "x": 1.0, "z": 0, "width": 0.9, "height": 0.8, "sill": 2.2}))
	assert_false(BuildOps.place_opening(h, 0, {"kind": "door", "axis": "x", "x": 2.5, "z": 0, "width": 0.82, "height": 3.4})["ok"], "too tall")


func test_room_height_change_is_checked() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 3), {"height": 3.0}))
	_ok(BuildOps.place_opening(h, 0, {"kind": "window", "axis": "x", "x": 1.0, "z": 0, "width": 0.9, "height": 1.6, "sill": 0.9}))
	assert_false(BuildOps.set_room_height(h, 0, Vector2i(1, 1), 2.4)["ok"], "window wouldn't fit")
	_ok(BuildOps.set_room_height(h, 0, Vector2i(1, 1), 3.3))
	assert_almost_eq(h.wall_h(0, HouseData.hkey(0, 0)), 3.3, 0.001)


func test_quarter_tile_floors() -> void:
	var h := _house()
	_ok(BuildOps.paint_floor(h, 0, [Vector2i(0, 0)] as Array[Vector2i], "lino_checks"))
	_ok(BuildOps.paint_floor(h, 0, [Vector2i(0, 0)] as Array[Vector2i], "floor_boards", [0, 2], 90))
	var f: Dictionary = h.floors(0)["0,0"]
	assert_eq(f["m"], ["floor_boards", "lino_checks", "floor_boards", "lino_checks"])
	assert_eq(int(f["rot"]), 90)


func _two_storey() -> HouseData:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 6, 5), {"name": "Shop", "height": 3.0}))
	_ok(BuildOps.place_opening(h, 0, {"kind": "door", "axis": "x", "x": 2.0, "z": 5, "width": 0.82, "height": 2.05}))
	_ok(BuildOps.add_storey(h, 1))
	_ok(BuildOps.add_room(h, 1, Rect2i(0, 0, 6, 5), {"name": "Residence"}))
	return h


func test_upper_rooms_need_support() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 3, 3)))
	_ok(BuildOps.add_storey(h, 1))
	assert_false(BuildOps.add_room(h, 1, Rect2i(10, 10, 3, 3))["ok"])


func test_stairs_cut_the_floor_above_and_connect_pathing() -> void:
	var h := _two_storey()
	var before := HousePathing.build(h)
	assert_false(before.reachable(0, Vector2i(2, 6), 1, Vector2i(4, 1)), "no way up without stairs")
	var res := BuildOps.add_stairs(h, 0, {"kind": "straight", "x": 0, "y": 4, "dir": "N"})
	_ok(res)
	var info := h.stair_tiles(h.stairs(0)[0], 0)
	var wells := h.stairwell_tiles(1)
	assert_eq(wells.size(), (info["lower"] as Array).size(), "one cut tile per flight tile")
	for t: Vector2i in info["lower"]:
		assert_true(wells.has(HouseData.tile_key(t.x, t.y)))
	assert_false(wells.has(HouseData.tile_key(info["arrival"].x, info["arrival"].y)), "you arrive on solid floor")
	var after := HousePathing.build(h)
	assert_true(after.reachable(0, Vector2i(2, 6), 1, Vector2i(4, 1)), "from the street to upstairs via the shop and the stairs")
	assert_false(after.reachable(1, Vector2i(0, 2), 1, Vector2i(4, 1)), "the stairwell isn't walkable upstairs")


func test_stair_shapes_have_the_expected_footprints() -> void:
	var h := _two_storey()
	var l := h.stair_tiles({"kind": "l", "x": 1, "y": 4, "dir": "N"}, 0)
	assert_eq((l["lower"] as Array).size(), 5)
	assert_eq(l["arrival"], Vector2i(4, 2))
	var u := h.stair_tiles({"kind": "u", "x": 1, "y": 4, "dir": "N"}, 0)
	assert_eq((u["lower"] as Array).size(), 6)
	assert_eq(u["arrival"], Vector2i(2, 5))
	var ladder := h.stair_tiles({"kind": "ladder", "x": 1, "y": 4, "dir": "N"}, 0)
	assert_eq((ladder["lower"] as Array).size(), 1)


func test_stairs_rejected_through_walls_or_without_an_upper_floor() -> void:
	var h := _two_storey()
	_ok(BuildOps.add_wall(h, 0, Vector2i(0, 2), Vector2i(2, 2)))
	assert_false(BuildOps.add_stairs(h, 0, {"kind": "straight", "x": 0, "y": 4, "dir": "N"})["ok"], "wall across")
	var h2 := _house()
	_ok(BuildOps.add_room(h2, 0, Rect2i(0, 0, 6, 5)))
	assert_false(BuildOps.add_stairs(h2, 0, {"kind": "straight", "x": 0, "y": 4, "dir": "N"})["ok"], "no storey above")


func test_storey_limits() -> void:
	var h := _house()
	_ok(BuildOps.add_storey(h, -1))
	assert_false(BuildOps.add_storey(h, 2)["ok"], "need the first floor first")
	_ok(BuildOps.add_storey(h, 1))
	_ok(BuildOps.add_storey(h, 2))
	assert_false(BuildOps.add_storey(h, 3)["ok"])
	assert_eq(h.levels(), [-1, 0, 1, 2] as Array[int])


func test_validation_hints() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 3, 3), {"name": "Bedroom"}))
	var hints := h.validate()
	assert_has(hints, "The bedroom has no way in.")
	assert_has(hints, "The bedroom has no window.")
	_ok(BuildOps.place_opening(h, 0, {"kind": "door", "axis": "x", "x": 1.0, "z": 3, "width": 0.82, "height": 2.05}))
	_ok(BuildOps.place_opening(h, 0, {"kind": "window", "axis": "z", "x": 0, "z": 1.0, "width": 0.9, "height": 1.2, "sill": 0.9}))
	assert_eq(h.validate(), [] as Array[String])


func test_undo_stack_order() -> void:
	var u := UndoStack.new()
	u.push("one", "h", null, {"v": 1})
	u.push("two", "h", {"v": 1}, {"v": 2})
	assert_eq(u.undo()["state"], {"v": 1})
	assert_eq(u.undo()["state"], null)
	assert_eq(u.redo()["state"], {"v": 1})
	u.push("three", "h", {"v": 1}, {"v": 3})
	assert_false(u.can_redo(), "a new edit clears redo")
