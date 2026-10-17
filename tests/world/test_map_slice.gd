extends GutTest

var _slice: MapSlice


func before_all() -> void:
	_slice = MapSlice.load_default()


func test_size() -> void:
	assert_eq(_slice.grid.width, 144)
	assert_eq(_slice.grid.height, 96)


func test_has_creek_mud_and_siding() -> void:
	assert_gt(_slice.grid.count_ground(Ground.Type.WATER), 400, "creek water tiles")
	assert_gt(_slice.grid.count_ground(Ground.Type.MUD), 300, "muddy banks and the creek track")
	assert_eq(_slice.grid.get_ground(5, 30), Ground.Type.GRAVEL, "siding yard")


func test_creek_track_is_mud_behind_the_store_plot() -> void:
	# Case 0 needs the creek track to stay mud (docs/CASE_00_CASH_TIN.md).
	var found := false
	for y in range(70, 78):
		for x in range(68, 80):
			if _slice.grid.get_ground(x, y) == Ground.Type.MUD:
				found = true
	assert_true(found)


func test_landmarks_present() -> void:
	for id in ["lm_siding", "lm_mill", "lm_agnes_cottage", "lm_old_town"]:
		assert_false(_slice.landmark(id).is_empty(), id)


func test_water_sits_below_the_banks() -> void:
	var p := _slice.creek_points[_slice.creek_points.size() / 2]
	var level := _slice.creek_level_at(p)
	assert_lt(_slice.grid.height_at(p.x, p.y), level, "bed is under water")
	assert_gt(_slice.grid.height_at(p.x, p.y - 9.0), level, "bank is above water")


func test_cottage_lot_is_level_and_clear_of_trees() -> void:
	var lot: Array = _slice.landmark("lm_agnes_cottage")["lot"]
	var hs: Array[float] = []
	for y in range(int(lot[1]) + 4, int(lot[1]) + 13):
		for x in range(int(lot[0]) + 4, int(lot[0]) + 14):
			hs.append(_slice.grid.height_at(x, y))
	assert_lt(hs.max() - hs.min(), 0.6, "cottage block nearly level")
	for o in _slice.grid.objects:
		var inside := Rect2(float(lot[0]), float(lot[1]), float(lot[2]), float(lot[3])).has_point(Vector2(float(o["x"]), float(o["y"])))
		assert_false(inside and o["kind"] == "gum" and o["id"] != "tree_2", "no scattered trees on the lot")


func test_trees_scattered() -> void:
	assert_gt(_slice.grid.objects.size(), 100)


func test_deterministic() -> void:
	var again := MapSlice.load_default()
	assert_eq(again.grid.ground, _slice.grid.ground)
	assert_eq(again.grid.heights, _slice.grid.heights)
	assert_eq(JSON.stringify(again.grid.objects), JSON.stringify(_slice.grid.objects))
