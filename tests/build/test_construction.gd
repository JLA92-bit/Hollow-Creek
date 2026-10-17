extends GutTest
## docs/HOUSE_BUILDING.md construction in story mode: blueprints until the materials reach the siding,
## then crews work through the stages over days, slower in the rain, faster for rough work, and the
## house is drawn as it stands at each stage.


func _cottage() -> HouseData:
	var h := HouseData.new()
	h.id = "c"
	BuildOps.add_room(h, 0, Rect2i(0, 0, 5, 4), {"name": "Kitchen"})
	BuildOps.add_room(h, 0, Rect2i(5, 0, 4, 4), {"name": "Bedroom"})
	BuildOps.place_opening(h, 0, {"kind": "door", "style": "front_door", "axis": "x", "x": 2.0, "z": 0.0, "width": 0.82, "height": 2.1})
	BuildOps.place_opening(h, 0, {"kind": "window", "style": "double_hung", "axis": "x", "x": 6.5, "z": 0.0, "width": 0.9, "height": 1.5, "sill": 0.9})
	BuildOps.auto_roof(h, {"shape": "hip"})
	BuildOps.paint_faces(h, 0, BuildOps.room_faces(h, 0, h.room_at_tile(0, Vector2i(1, 1))), {"mat": "plaster", "paint": "mint"})
	return h


func _empty() -> HouseData:
	var e := HouseData.new()
	e.id = "c"
	return e


func test_work_covers_every_stage_of_a_new_house() -> void:
	var w := Construction.work(_empty(), _cottage())
	for s in ["stumps", "floor_frame", "floors", "wall_frames", "roof_frame", "roofing", "cladding", "joinery", "paint"]:
		assert_gt(w[Construction.STAGE_INDEX[s]], 0.0, "%s has work" % s)
	assert_eq(w[0], 0.0, "nothing to knock down")
	var days := Construction.days_left(w, 0.0, 2, "standard")
	assert_between(days, 5.0, 20.0, "a two-room cottage takes a week or two (%.1f days)" % days)
	assert_lt(Construction.days_left(w, 0.0, 2, "rough"), days)
	assert_gt(Construction.days_left(w, 0.0, 2, "fine"), days)
	assert_lt(Construction.days_left(w, 0.0, 3, "standard"), days, "another crew helps")


func test_stages_draw_the_house_as_it_stands() -> void:
	var before := _empty()
	var after := _cottage()
	var k := HouseData.hkey(1, 0)
	var blue := Construction.display(before, after, -1, false)
	assert_eq(str(blue.wall(0, k).get("stage", "")), "blueprint", "blueprints until the materials come")
	assert_eq(str((blue.floors(0)["1,1"] as Dictionary).get("stage", "")), "blueprint")
	assert_true(blue.openings(0).is_empty())
	assert_true(blue.roof.is_empty())
	var frames := Construction.display(before, after, Construction.STAGE_INDEX["wall_frames"], true)
	assert_eq(str(frames.wall(0, k).get("stage", "")), "frame")
	assert_false((frames.floors(0)["1,1"] as Dictionary).has("stage"), "floors are down by then")
	var roofing := Construction.display(before, after, Construction.STAGE_INDEX["roof_frame"], true)
	assert_eq(str(roofing.roof.get("stage", "")), "frame")
	var clad := Construction.display(before, after, Construction.STAGE_INDEX["cladding"], true)
	assert_false(clad.wall(0, k).has("stage"))
	assert_eq(str(((clad.wall(0, k)["f"] as Dictionary)["b"] as Dictionary)["paint"]), Construction.RAW_INSIDE, "unpainted until the painters come")
	assert_true(clad.openings(0).is_empty(), "no doors or windows yet")
	var joinery := Construction.display(before, after, Construction.STAGE_INDEX["joinery"], true)
	assert_eq(joinery.openings(0).size(), 2)
	var done := Construction.display(before, after, Construction.STAGES.size(), true)
	assert_eq(ShareCode.fingerprint(done), ShareCode.fingerprint(after))
	# Every stage still draws.
	for s in range(-1, Construction.STAGES.size()):
		var b := HouseMeshBuilder.new(Construction.display(before, after, s, true))
		var kit := MeshKit.new()
		b.build_structure(kit, 0)
		b.build_walls(kit, 0, func(_k: String) -> bool: return false)
		b.build_roof(kit)


func test_demolition_comes_first() -> void:
	var before := _cottage()
	var after := before.duplicate_house()
	var k := HouseData.vkey(5, 1)
	BuildOps.remove_walls(after, 0, Vector2i(5, 0), Vector2i(5, 4))
	var w := Construction.work(before, after)
	assert_gt(w[0], 0.0)
	assert_true(Construction.display(before, after, 0, true).walls(0).has(k), "still standing during demolition")
	assert_false(Construction.display(before, after, 1, true).walls(0).has(k))


func test_crews_build_over_days() -> void:
	var plan := _cottage()
	var p := Construction.new_project(_empty().to_dict(), 0, 10 * 60)
	var w := Construction.work(_empty(), plan)
	assert_eq(Construction.tick(p, w, 0, 12 * 60, 2, false), -1, "nothing before the materials arrive")
	var day := 1
	var stages_seen: Dictionary = {}
	var finished_day := -1
	while day < 60 and finished_day < 0:
		for minute in range(0, 24 * 60, 1):
			var s := Construction.tick(p, w, day, minute, 2, false)
			stages_seen[s] = true
			if s >= Construction.STAGES.size():
				finished_day = day
				break
		day += 1
	assert_gt(finished_day, 3, "it takes days")
	assert_lt(finished_day, 30)
	for s2 in range(1, Construction.STAGES.size()):
		assert_true(stages_seen.has(s2), "stage %s happens" % Construction.STAGES[s2])
	var wet := Construction.new_project(_empty().to_dict(), 0, 10 * 60)
	for minute2 in range(8 * 60, 16 * 60):
		Construction.tick(wet, w, 1, minute2, 2, true)
		Construction.tick(p, w, 1, minute2, 2, false)
	var dry := Construction.new_project(_empty().to_dict(), 0, 10 * 60)
	for minute3 in range(8 * 60, 16 * 60):
		Construction.tick(dry, w, 1, minute3, 2, false)
	assert_lt(float(wet["done"]), float(dry["done"]), "rain slows the outside work")
	var sunday := Construction.new_project(_empty().to_dict(), 0, 10 * 60)
	for minute4 in range(8 * 60, 16 * 60):
		Construction.tick(sunday, w, 6, minute4, 2, false)
	assert_eq(float(sunday["done"]), 0.0, "nobody works on Sunday")


func test_quality_tiers_show_in_style() -> void:
	var h := _cottage()
	var std := int(HomeScores.compute(h)["style"])
	BuildOps.set_quality(h, "fine")
	assert_gt(int(HomeScores.compute(h)["style"]), std)
	BuildOps.set_quality(h, "rough")
	assert_lt(int(HomeScores.compute(h)["style"]), std)
	assert_false(BuildOps.set_quality(h, "gold")["ok"])
