extends GutTest
## docs/HOUSE_BUILDING.md "Wishes, briefs and life changes": wishes are checked against the house as
## built, families react to their homes against their brief, met wishes lift moods and earn trust,
## ignored ones turn into grievances, and rent comes in every Monday.


func _ok(res: Dictionary) -> void:
	assert_true(res["ok"], str(res.get("msg", "")))


## A kitchen, a bedroom with an east window, a living room with a fireplace and an armchair.
func _cottage() -> HouseData:
	var h := HouseData.new()
	h.id = "life"
	h.base_y = 0.0
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 5, 4), {"name": "Kitchen", "paint": "cream"}))
	_ok(BuildOps.add_room(h, 0, Rect2i(5, 0, 4, 4), {"name": "Bedroom", "paint": "cream"}))
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 4, 5, 4), {"name": "Living room", "paint": "cream"}))
	_ok(BuildOps.place_opening(h, 0, {"kind": "door", "style": "front_door", "axis": "x", "x": 2.0, "z": 0.0, "width": 0.82, "height": 2.1}))
	_ok(BuildOps.place_opening(h, 0, {"kind": "door", "style": "four_panel", "axis": "z", "x": 5.0, "z": 1.5, "width": 0.82, "height": 2.05}))
	_ok(BuildOps.place_opening(h, 0, {"kind": "door", "style": "four_panel", "axis": "x", "x": 2.0, "z": 4.0, "width": 0.82, "height": 2.05}))
	for w: Dictionary in [{"axis": "z", "x": 0.0, "z": 1.5}, {"axis": "z", "x": 9.0, "z": 1.5}, {"axis": "x", "x": 2.0, "z": 8.0}]:
		var o := {"kind": "window", "style": "double_hung", "width": 0.9, "height": 1.5, "sill": 0.9}
		o.merge(w)
		_ok(BuildOps.place_opening(h, 0, o))
	_ok(BuildOps.auto_roof(h, {"shape": "hip"}))
	for p: Array in [["wood_stove", 1.0, 3.3], ["kitchen_sink", 3.2, 0.6], ["icebox", 4.3, 3.2], ["iron_bed", 7.0, 2.6],
			["settee", 2.5, 7.4], ["armchair", 4.2, 5.0], ["standard_lamp", 0.5, 7.5]]:
		_ok(FurnitureOps.place(h, 0, p[0], Vector2(p[1], p[2])))
	_ok(BuildOps.add_chimney(h, 0, HouseData.hkey(1, 4)))
	return h


func _wish(id: String) -> Dictionary:
	for w: Dictionary in Sim.load_data()["wishes"]:
		if w["id"] == id:
			return w
	return {}


func test_wishes_are_checked_against_the_house() -> void:
	var h := _cottage()
	var bare := HouseData.new()
	_ok(BuildOps.add_room(bare, 0, Rect2i(0, 0, 4, 4), {"name": "Living room"}))
	assert_true(HomeLife.wish_met(_wish("w_agnes_warm"), h), "an armchair by the fire")
	assert_false(HomeLife.wish_met(_wish("w_agnes_warm"), bare))
	var sewing := _wish("w_halina_sewing")
	assert_false(HomeLife.wish_met(sewing, h), "the east bedroom has no table yet")
	_ok(FurnitureOps.place(h, 0, "side_table", Vector2(8.4, 3.4)))
	assert_true(HomeLife.wish_met(sewing, h), "a table in a room with morning light")
	var vegies := _wish("w_marge_vegies")
	_ok(GardenOps.place_item(h, "vegie_bed", Vector2(2.0, -3.0)))
	assert_false(HomeLife.wish_met(vegies, h), "2.4 square metres isn't 4")
	_ok(GardenOps.place_item(h, "vegie_bed", Vector2(5.0, -3.0)))
	assert_true(HomeLife.wish_met(vegies, h))
	var shed := _wish("w_len_shed")
	assert_false(HomeLife.wish_met(shed, h))
	_ok(GardenOps.place_item(h, "woodshed", Vector2(3.0, 11.0)))
	assert_true(HomeLife.wish_met(shed, h))


func test_sleepout_wish() -> void:
	var h := _cottage()
	var wish := _wish("w_piotr_sleepout")
	var run := BuildOps.outside_run(h, 0, HouseData.hkey(6, 0))
	var id := str(BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], {"depth": 2.4})["id"])
	_ok(BuildOps.enclose_sleepout(h, id, 5.0, 9.0))
	assert_false(HomeLife.wish_met(wish, h), "a sleep-out with no bed in it")
	_ok(FurnitureOps.place(h, 0, "day_bed", Vector2(7.0, -1.2)))
	assert_true(HomeLife.wish_met(wish, h))


func test_move_in_reactions_follow_the_brief() -> void:
	var h := _cottage()
	var easy := {"bedrooms": 1, "rooms": ["kitchen"], "rent": 4, "wants": ["armchair"]}
	var r := HomeLife.reaction(easy, h, 2)
	gut.p("Reaction: %s" % r)
	assert_eq(r["verdict"], "delighted")
	assert_true((r["pros"] as Array).has("A club armchair, just what we wanted"))
	var pike: Dictionary = Sim.load_data()["households"]["h_pike"]["brief"]
	var r2 := HomeLife.reaction(pike, h, 3)
	assert_eq(r2["verdict"], "disappointed", "one bedroom and one bed for a family of three")
	assert_true((r2["cons"] as Array).has("Only 1 bedroom; we asked for 2"))
	var hut := HouseData.new()
	_ok(BuildOps.add_room(hut, 0, Rect2i(0, 0, 3, 3), {"name": "Room"}))
	assert_eq(HomeLife.reaction(easy, hut, 2)["verdict"], "disappointed")
	assert_between(HomeLife.rent(r["scores"]), 2, 4)
	assert_eq(HomeLife.rent(HomeScores.compute(hut, 2)), 1)


func test_history_card() -> void:
	var hist := {}
	HomeLife.record(hist, "house_1", 3, "Built for the Pikes")
	HomeLife.record(hist, "house_1", 40, "Sleep-out added for Piotr")
	assert_eq((hist["house_1"] as Array).size(), 2)
	assert_eq(hist["house_1"][1]["text"], "Sleep-out added for Piotr")


func _sim() -> Sim:
	var t := SimTown.build(MapSlice.load_default().grid, DemoTown.houses(), [], [])
	var s := Sim.new(77)
	var homes := DemoTown.homes()
	homes.erase("h_pike")
	s.setup(t, Sim.load_data(), homes, 0, 6 * 60)
	return s


func test_wishes_moods_trust_and_grievances() -> void:
	var s := _sim()
	var agnes: Dictionary = s.residents["r_agnes"]
	assert_eq(int(s.wishes["w_marge_vegies"]["since"]), -1, "the Pikes have no home yet")
	s.review_homes({"lm_agnes_cottage": {"score": 70.0, "wishes_met": ["w_agnes_warm"]}})
	assert_eq(int(s.wishes["w_agnes_warm"]["met"]), 0)
	assert_eq(s.trust_change, 1, "a met wish earns Town Trust")
	assert_eq(int(agnes["boost_until"]), 7, "a good week for Agnes")
	s.review_homes({"lm_agnes_cottage": {"score": 70.0, "wishes_met": ["w_agnes_warm"]}})
	assert_eq(s.trust_change, 1, "only once")
	s.run_ticks(29 * 1440)
	s.review_homes({})
	var sour := 0
	for g: Dictionary in s.grievances:
		if g["target"] == Sim.PLAYER:
			sour += 1
			assert_ne(g["owner"], "r_marge", "the Pikes' wishes wait until they have a home")
	assert_gt(sour, 0, "ignored wishes turn into grievances against the Administrator")


func test_move_in_and_rent() -> void:
	var s := _sim()
	var home: String = DemoTown.homes()["h_pike"]
	assert_eq(s.residents["r_len"]["status"], "away")
	var mood := float(s.residents["r_len"]["mood"])
	s.move_household("h_pike", home, {"verdict": "delighted", "rent": 2, "scores": {"comfort": 80}})
	assert_eq(s.residents["r_len"]["status"], "living")
	assert_almost_eq(float(s.residents["r_len"]["mood"]), mood + 15.0, 0.01)
	assert_eq(int(s.wishes["w_len_shed"]["since"]), 0)
	s.run_ticks(7 * 1440)
	assert_gte(s.collected, 2, "rent on Monday")
	assert_eq(int(s.households["h_pike"]["last_week"]["rent"]), 2)
	var s2 := _sim()
	s2.move_household("h_pike", home, {"verdict": "disappointed", "rent": 2, "cons": ["Only 1 bedroom; we asked for 2"]})
	var found := false
	for g: Dictionary in s2.grievances:
		found = found or (g["target"] == Sim.PLAYER and str(g["reason"]).contains("bedroom"))
	assert_true(found, "a disappointed family holds it against the Administrator")
