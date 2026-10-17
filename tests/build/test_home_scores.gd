extends GutTest
## docs/HOUSE_BUILDING.md home scores: a bare shell scores low, a furnished cottage scores as expected,
## and each score answers to the things it's built from. Buy mode previews come from scoring a copy.


func _shell() -> HouseData:
	var h := HouseData.new()
	h.id = "scores"
	BuildOps.add_room(h, 0, Rect2i(0, 0, 5, 4), {"name": "Kitchen", "paint": "cream"})
	BuildOps.add_room(h, 0, Rect2i(5, 0, 4, 4), {"name": "Bedroom", "paint": "cream"})
	BuildOps.add_room(h, 0, Rect2i(0, 4, 5, 4), {"name": "Living room", "paint": "cream"})
	return h


## The furnished cottage: doors, windows (an east kitchen window), a roof, a stove, a full kitchen,
## a bed, a settee and lamps, a verandah, a garden and a fence.
func _cottage() -> HouseData:
	var h := _shell()
	var night := {"lock": true, "latch": true, "curtains": true}
	BuildOps.place_opening(h, 0, {"kind": "door", "style": "front_door", "axis": "x", "x": 2.0, "z": 0.0, "width": 0.82, "height": 2.1, "lock": true, "night": night})
	BuildOps.place_opening(h, 0, {"kind": "door", "style": "four_panel", "axis": "z", "x": 5.0, "z": 1.5, "width": 0.82, "height": 2.05})
	BuildOps.place_opening(h, 0, {"kind": "door", "style": "four_panel", "axis": "x", "x": 2.0, "z": 4.0, "width": 0.82, "height": 2.05})
	for w: Dictionary in [{"axis": "z", "x": 0.0, "z": 1.5}, {"axis": "x", "x": 6.5, "z": 0.0}, {"axis": "z", "x": 9.0, "z": 1.5},
			{"axis": "x", "x": 2.0, "z": 8.0}, {"axis": "z", "x": 0.0, "z": 5.5}]:
		var o := {"kind": "window", "style": "double_hung", "width": 0.9, "height": 1.5, "sill": 0.9, "night": night}
		o.merge(w)
		BuildOps.place_opening(h, 0, o)
	BuildOps.auto_roof(h, {"shape": "hip"})
	for p: Array in [["wood_stove", 1.0, 3.3], ["kitchen_sink", 3.2, 0.6], ["icebox", 4.3, 3.2], ["laminex_table", 2.6, 2.0],
			["kitchen_chair", 2.6, 1.2], ["kitchen_chair", 2.6, 2.8], ["iron_bed", 7.0, 2.6], ["wardrobe", 8.2, 0.5],
			["settee", 2.5, 7.4], ["armchair", 4.2, 5.0], ["standard_lamp", 0.5, 7.5], ["picture_frame", 2.5, 4.2]]:
		var res := FurnitureOps.place(h, 0, p[0], Vector2(p[1], p[2]))
		assert_true(res["ok"], "%s: %s" % [p[0], res["msg"]])
	BuildOps.add_chimney(h, 0, HouseData.hkey(1, 4))
	var run := BuildOps.outside_run(h, 0, HouseData.hkey(2, 0))
	BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], {"lace": "lace", "rail": "timber"})
	for x in 6:
		GardenOps.place_item(h, "rose", Vector2(x + 0.5, -4.0))
	GardenOps.set_fence(h, Vector2i(-4, -6), Vector2i(13, -6), "picket")
	GardenOps.toggle_gate(h, HouseData.hkey(2, -6))
	return h


func test_bare_shell_scores_low() -> void:
	var s := HomeScores.compute(_shell())
	assert_lt(int(s["comfort"]), 35)
	assert_lt(int(s["warmth"]), 35, "no roof and no fire")
	assert_lt(int(s["light"]), 25, "no windows")
	assert_lt(int(s["security"]), 25)


func test_furnished_cottage_scores_as_expected() -> void:
	var s := HomeScores.compute(_cottage(), 2)
	gut.p("Cottage scores: %s" % s)
	assert_between(int(s["comfort"]), 70, 100)
	assert_between(int(s["style"]), 45, 85)
	assert_between(int(s["warmth"]), 60, 100)
	assert_between(int(s["light"]), 55, 100)
	assert_between(int(s["space"]), 75, 100)
	assert_between(int(s["privacy"]), 70, 100)
	assert_between(int(s["security"]), 65, 100)


func test_each_score_answers_to_its_inputs() -> void:
	var h := _cottage()
	var base := HomeScores.compute(h)
	var no_roof := h.duplicate_house()
	BuildOps.remove_roof(no_roof)
	assert_lt(int(HomeScores.compute(no_roof)["warmth"]), int(base["warmth"]), "a roof keeps the warmth in")
	assert_lt(int(HomeScores.compute(h, 6)["space"]), int(base["space"]), "six people crowd it")
	var unlocked := h.duplicate_house()
	for o: Dictionary in unlocked.openings(0):
		o["night"] = {"lock": false, "latch": false, "curtains": false}
	assert_lt(int(HomeScores.compute(unlocked)["security"]), int(base["security"]))
	assert_lt(int(HomeScores.compute(unlocked)["privacy"]), int(base["privacy"]), "curtains matter")


func test_preview_shows_what_a_purchase_adds() -> void:
	var h := _shell()
	var diff := HomeScores.preview(h, func(c: HouseData) -> Dictionary: return FurnitureOps.place(c, 0, "settee", Vector2(2.5, 6.0)))
	assert_gt(int(diff.get("comfort", 0)), 0)
	assert_string_contains(HomeScores.describe(diff), "Comfort")
	assert_eq(h.objects.size(), 0, "previewing doesn't change the house")
	assert_true(HomeScores.preview(h, func(c: HouseData) -> Dictionary: return FurnitureOps.place(c, 0, "settee", Vector2(40, 40))).is_empty())
