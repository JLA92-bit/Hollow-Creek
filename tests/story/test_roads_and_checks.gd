extends GutTest
## Roads, the store check against the demo store, templates, and the prologue's world questions.


func _grid() -> WorldGrid:
	return MapSlice.load_default().grid


func test_a_road_covers_its_width_without_duplicates() -> void:
	var t := RoadOps.tiles_along([[10, 10], [20, 10]], 3)
	var seen := {}
	for v in t:
		assert_false(seen.has(v), "no duplicate tiles")
		seen[v] = true
	assert_true(seen.has(Vector2i(15, 10)) and seen.has(Vector2i(15, 9)) and seen.has(Vector2i(15, 11)))
	assert_false(seen.has(Vector2i(15, 13)))


func test_dirt_is_free_gravel_costs_by_the_tile() -> void:
	var t := RoadOps.tiles_along([[10, 10], [20, 10]], 3)
	assert_eq(RoadOps.cost("dirt", {}, t), 0)
	assert_eq(RoadOps.cost("gravel", {}, t), t.size() * 2)
	var roads := {}
	RoadOps.lay(roads, "gravel", t, Vector2i(144, 96))
	assert_eq(RoadOps.cost("gravel", roads, t), 0, "already laid costs nothing")


func test_laying_stays_inside_the_map() -> void:
	var roads := {}
	var n := RoadOps.lay(roads, "dirt", RoadOps.tiles_along([[-5, 5], [3, 5]], 3), Vector2i(144, 96))
	for k: String in roads:
		assert_true(HouseData.parse_tile(k).x >= 0)
	assert_gt(n, 0)


func test_the_guided_road_starts_unlaid_and_is_done_once_painted() -> void:
	var g := _grid()
	var pro := Prologue.new()
	var road: Dictionary = pro.data["road"]
	assert_lt(StoryChecks.road_done(g, road["points"], int(road["width"])), float(road["needed"]), "not already there")
	for t in RoadOps.tiles_along(road["points"], int(road["width"])):
		g.set_ground(t.x, t.y, Ground.Type.DIRT)
	assert_gte(StoryChecks.road_done(g, road["points"], int(road["width"])), float(road["needed"]))


func test_the_demo_store_has_a_door_a_back_window_and_an_exchange() -> void:
	var g := _grid()
	var slice := MapSlice.load_default()
	var store := DemoTown.store()
	# No road yet: the door isn't on one.
	var before := StoryChecks.store(store, g, slice.creek_points)
	assert_false(before["door"])
	assert_true(before["window"], "the back windows face the creek")
	assert_true(before["exchange"])
	for t in RoadOps.tiles_along((Prologue.new().data["road"] as Dictionary)["points"], 3):
		g.set_ground(t.x, t.y, Ground.Type.DIRT)
	var after := StoryChecks.store(store, g, slice.creek_points)
	assert_true(after["door"], "the front door now opens onto the road")


func test_the_store_template_is_on_the_plot_and_the_cottages_have_beds() -> void:
	var tpl := Blueprints.templates()
	assert_eq(tpl.size(), 3)
	var found := false
	for e: Dictionary in tpl:
		var h := ShareCode.decode(str(e["code"]))
		assert_not_null(h, str(e["name"]))
		if h == null:
			continue
		if str(e["file"]) == "general_store.json":
			found = true
			var slice := MapSlice.load_default()
			h.origin = Vector2i(70, 46)
			assert_true(StoryChecks.on_plot(h, Rect2i(68, 44, 12, 14)))
			assert_true(StoryChecks.store(h, slice.grid, slice.creek_points)["exchange"])
		else:
			assert_true(StoryChecks.has_bed(h), "%s has somewhere to sleep" % e["name"])
	assert_true(found)
