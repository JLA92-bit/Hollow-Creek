extends GutTest
## docs/BUILDING.md "Sightlines" and "Light": every case. A 4 x 4 kitchen at (10, 10) with a door on
## the north wall, a curtained window on the east wall, a bare window on the south wall and a lamp.

const DAY := 12 * 60
const NIGHT := 23 * 60
const NEW_MOON_DAY := 21

var awake := {"awake": true}


func _house() -> HouseData:
	var h := HouseData.new()
	h.id = "t"
	h.origin = Vector2i(10, 10)
	h.base_y = 0.0
	assert_true(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 4), {"name": "Kitchen"})["ok"])
	assert_true(BuildOps.place_opening(h, 0, {"kind": "door", "style": "four_panel", "axis": "x", "x": 1.5, "z": 0.0, "width": 0.82, "height": 2.05})["ok"])
	assert_true(BuildOps.place_opening(h, 0, {"kind": "window", "style": "double_hung", "axis": "z", "x": 4.0, "z": 1.5, "width": 0.9, "height": 1.5, "sill": 0.9,
		"night": {"curtains": true}})["ok"])
	assert_true(BuildOps.place_opening(h, 0, {"kind": "window", "style": "double_hung", "axis": "x", "x": 2.5, "z": 4.0, "width": 0.9, "height": 1.5, "sill": 0.9,
		"night": {"curtains": false}})["ok"])
	assert_true(FurnitureOps.place(h, 0, "kerosene_lamp", Vector2(1.5, 1.5))["ok"] or FurnitureOps.place(h, 0, "standard_lamp", Vector2(0.5, 3.5))["ok"])
	return h


func _map(h: HouseData = null, grid: WorldGrid = null) -> SightMap:
	var g := grid if grid else WorldGrid.new(40, 40)
	return SightMap.build(g, [h if h else _house()])


func _light(s: SightMap, minute: int, occupied: Dictionary = {}, day: int = NEW_MOON_DAY) -> LightGrid:
	return LightGrid.compute(s, day, minute, false, occupied)


func _rid(s: SightMap) -> String:
	return s.room_at(Vector2i(11, 11))


func test_open_ground_by_day() -> void:
	var s := _map()
	var l := _light(s, DAY)
	assert_true(s.look(Vector2i(2, 30), Vector2i(19, 30), awake, l)["seen"], "17 m in daylight")
	assert_eq(s.look(Vector2i(2, 30), Vector2i(22, 30), awake, l)["reason"], "too far", "20 m is past 18")


func test_blocked_by_a_wall() -> void:
	var s := _map()
	var l := _light(s, DAY)
	assert_eq(s.look(Vector2i(11, 11), Vector2i(11, 18), awake, l)["reason"], "wall")
	assert_eq(s.look(Vector2i(5, 12), Vector2i(18, 12), awake, l)["reason"], "wall", "straight through the house")


func test_through_a_window() -> void:
	var s := _map()
	var l := _light(s, DAY)
	assert_true(s.look(Vector2i(12, 11), Vector2i(18, 11), awake, l)["seen"], "out of the east window")
	assert_true(s.look(Vector2i(18, 11), Vector2i(12, 11), awake, l)["seen"], "and in through it")
	assert_true(s.look(Vector2i(12, 12), Vector2i(12, 20), awake, l)["seen"], "out of the south window")


func test_closed_door_blocks() -> void:
	var s := _map()
	var l := _light(s, DAY)
	assert_eq(s.look(Vector2i(11, 12), Vector2i(11, 4), awake, l)["reason"], "door")


func test_blocked_by_curtains_at_night() -> void:
	var s := _map()
	var occupied := {_rid(s): true}
	var night := _light(s, NIGHT, occupied)
	assert_eq(s.look(Vector2i(12, 11), Vector2i(15, 11), awake, night)["reason"], "curtains", "drawn at night")
	assert_true(s.look(Vector2i(12, 11), Vector2i(15, 11), awake, _light(s, DAY))["seen"], "open by day")
	assert_true(s.look(Vector2i(16, 11), Vector2i(12, 11), awake, night)["seen"] == false)


func test_lit_versus_unlit_at_night() -> void:
	var s := _map()
	var dark := _light(s, NIGHT)
	assert_almost_eq(dark.at(Vector2i(30, 30)), LightGrid.NIGHT, 0.001)
	# A man 5 m away in the dark: only 3 m at night unless the tile is lit.
	assert_eq(s.look(Vector2i(12, 21), Vector2i(12, 16), awake, dark)["reason"], "too dark")
	assert_true(s.look(Vector2i(12, 18), Vector2i(12, 16), awake, dark)["seen"], "2 m is close enough")
	# Somebody awake in the kitchen lights the lamp; light spills 3 m out of the bare south window.
	var lit := _light(s, NIGHT, {_rid(s): true})
	assert_true(lit.lit_rooms.has(_rid(s)))
	assert_gte(lit.at(Vector2i(12, 16)), SightMap.LIT, "2 m from the window is lit")
	assert_lt(lit.at(Vector2i(12, 19)), SightMap.LIT, "5 m away isn't")
	var seen := s.look(Vector2i(12, 21), Vector2i(12, 16), awake, lit)
	assert_true(seen["seen"], "5 m away, but the target stands in the window light")
	# Through the curtained east window the light only reaches 1.5 m.
	assert_gte(lit.at(Vector2i(14, 11)), SightMap.LIT)
	assert_lt(lit.at(Vector2i(16, 11)), SightMap.LIT)
	# Nobody awake in the room, no lamp.
	assert_lt(_light(s, NIGHT, {}).at(Vector2i(12, 16)), SightMap.LIT)


func test_moonlight_and_daylight() -> void:
	var s := _map()
	assert_false(_light(s, DAY).night)
	assert_almost_eq(_light(s, DAY).at(Vector2i(1, 1)), 1.0, 0.001)
	assert_almost_eq(_light(s, NIGHT, {}, LightGrid.FULL_MOON_DAY).at(Vector2i(1, 1)), LightGrid.MOON, 0.001)
	assert_almost_eq(LightGrid.compute(s, LightGrid.FULL_MOON_DAY, NIGHT, true, {}).at(Vector2i(1, 1)), LightGrid.NIGHT, 0.001, "clouds hide the moon")
	assert_almost_eq(_light(s, DAY).at(Vector2i(11, 11)), LightGrid.ROOM_DAY, 0.001)
	assert_almost_eq(_light(s, NIGHT).at(Vector2i(11, 11)), LightGrid.ROOM_DARK, 0.001)


func test_trees_fences_and_furniture() -> void:
	var g := WorldGrid.new(40, 40)
	g.add_object({"id": "tree_1", "kind": "gum", "x": 5.5, "y": 30.5, "blocks": true})
	var h := _house()
	assert_true(GardenOps.set_fence(h, Vector2i(-6, 8), Vector2i(-6, 12), "paling")["ok"])
	assert_true(GardenOps.set_fence(h, Vector2i(10, 8), Vector2i(10, 12), "picket")["ok"])
	var s := SightMap.build(g, [h])
	var l := _light(s, DAY)
	assert_eq(s.look(Vector2i(2, 30), Vector2i(9, 30), awake, l)["reason"], "tree", "a gum trunk in the way")
	assert_eq(s.look(Vector2i(2, 20), Vector2i(7, 20), awake, l)["reason"], "fence", "a paling fence is solid")
	assert_true(s.look(Vector2i(18, 20), Vector2i(23, 20), awake, l)["seen"], "a picket fence isn't")
	var h2 := _house()
	assert_true(FurnitureOps.place(h2, 0, "wardrobe", Vector2(2.6, 1.0), 90.0)["ok"])
	var s2 := SightMap.build(WorldGrid.new(40, 40), [h2])
	assert_eq(s2.look(Vector2i(11, 11), Vector2i(18, 11), awake, _light(s2, DAY))["reason"], "furniture", "the wardrobe stands in front of the window")


func test_asleep_or_busy_sees_nothing() -> void:
	var s := _map()
	var l := _light(s, DAY)
	assert_eq(s.look(Vector2i(2, 30), Vector2i(4, 30), {"awake": false}, l)["reason"], "asleep")
	assert_eq(s.look(Vector2i(2, 30), Vector2i(4, 30), {"awake": true, "focused": true}, l)["reason"], "busy")


func test_confidence() -> void:
	var s := _map()
	var day := _light(s, DAY)
	var near := float(s.look(Vector2i(2, 30), Vector2i(4, 30), awake, day)["confidence"])
	var far := float(s.look(Vector2i(2, 30), Vector2i(17, 30), awake, day)["confidence"])
	assert_gt(near, far, "nearer is surer")
	var sharp := float(s.look(Vector2i(2, 30), Vector2i(17, 30), {"awake": true, "observant": true}, day)["confidence"])
	assert_almost_eq(sharp, minf(1.0, far + 0.2), 0.011, "Observant +0.2")
	var lit := _light(s, NIGHT, {_rid(s): true})
	var young := float(s.look(Vector2i(12, 18), Vector2i(12, 16), awake, lit)["confidence"])
	var old := float(s.look(Vector2i(12, 18), Vector2i(12, 16), {"awake": true, "elderly": true}, lit)["confidence"])
	assert_almost_eq(old, young - 0.1, 0.011, "elderly at night -0.1")
	var drunk := float(s.look(Vector2i(2, 30), Vector2i(4, 30), {"awake": true, "drunk": true}, day)["confidence"])
	assert_almost_eq(drunk, near - 0.4, 0.011, "drunk -0.4")
	assert_lt(young, near, "night costs confidence")


func test_diagonal_corners() -> void:
	var s := _map()
	var l := _light(s, DAY)
	# A diagonal step past the house's north-west corner: clear round the outside of it.
	assert_true(s.look(Vector2i(9, 10), Vector2i(10, 9), awake, l)["seen"], "around the outside corner")
	assert_eq(s.look(Vector2i(10, 10), Vector2i(9, 9), awake, l)["reason"], "wall", "out through the corner isn't")
