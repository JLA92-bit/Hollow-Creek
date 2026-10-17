extends GutTest
## The M1 cottage template still loads into the edge-based model.

var _h: HouseData


func before_all() -> void:
	_h = HouseData.load_file("res://data/houses/agnes_cottage.json")


func test_template_converts_to_rooms() -> void:
	var rooms := _h.rooms(0)
	assert_eq(rooms.size(), 5)
	var names: Array[String] = []
	for r in rooms:
		names.append(_h.room_name(r))
	names.sort()
	assert_eq(names, ["Bedroom", "Hall", "Kitchen", "Sewing room", "Sitting room"] as Array[String])
	assert_eq(_h.footprint(), Rect2i(0, 0, 10, 8))


func test_perimeter_and_faces() -> void:
	var outside := 0
	for k: String in _h.walls(0):
		if _h.room_on_side(0, k, "a").is_empty() or _h.room_on_side(0, k, "b").is_empty():
			outside += 1
	assert_eq(outside, 36, "10 x 8 perimeter in 1 m edges")
	var kitchen := _h.room_at_tile(0, Vector2i(8, 6))
	assert_eq(_h.room_paint(kitchen), "mint")


func test_openings_sit_on_walls() -> void:
	for o: Dictionary in _h.openings(0):
		for k in HouseData.opening_edges(o):
			assert_true(_h.walls(0).has(k), "%s on %s" % [o["id"], k])


func test_validation_is_happy_with_the_cottage() -> void:
	assert_eq(_h.validate(), [] as Array[String])


func test_round_trip() -> void:
	# Compare after one trip through JSON, since JSON turns every number into a float.
	var once := JSON.stringify(JSON.parse_string(JSON.stringify(_h.to_dict())))
	var back := HouseData.from_dict(JSON.parse_string(once) as Dictionary)
	assert_eq(JSON.stringify(JSON.parse_string(JSON.stringify(back.to_dict()))), once)
