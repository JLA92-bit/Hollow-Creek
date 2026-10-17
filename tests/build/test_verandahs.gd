extends GutTest
## docs/HOUSE_BUILDING.md exterior: verandahs along any outside wall, steps, sleep-outs that become
## real rooms, and the auto-roof leaving sleep-outs to the verandah roof.


func _house() -> HouseData:
	var h := HouseData.new()
	h.id = "v_test"
	BuildOps.add_room(h, 0, Rect2i(0, 0, 8, 5))
	BuildOps.add_room(h, 0, Rect2i(0, 5, 8, 3))
	return h


func _ok(res: Dictionary) -> void:
	assert_true(res["ok"], str(res["msg"]))


func test_outside_run_finds_each_side() -> void:
	var h := _house()
	var n := BuildOps.outside_run(h, 0, HouseData.hkey(3, 0))
	assert_eq(str(n["side"]), "N")
	assert_eq(float(n["from"]), 0.0)
	assert_eq(float(n["to"]), 8.0)
	assert_eq(str(BuildOps.outside_run(h, 0, HouseData.hkey(3, 8))["side"]), "S")
	var w := BuildOps.outside_run(h, 0, HouseData.vkey(0, 2))
	assert_eq(str(w["side"]), "W")
	assert_eq(float(w["to"]) - float(w["from"]), 8.0, "the west wall runs past the inside wall")
	assert_eq(str(BuildOps.outside_run(h, 0, HouseData.vkey(8, 6))["side"]), "E")
	assert_true(BuildOps.outside_run(h, 0, HouseData.hkey(3, 5)).is_empty(), "inside walls have no outside")


func test_verandah_on_every_side() -> void:
	var h := _house()
	for k: String in [HouseData.hkey(3, 0), HouseData.hkey(3, 8), HouseData.vkey(0, 2), HouseData.vkey(8, 2)]:
		var run := BuildOps.outside_run(h, 0, k)
		_ok(BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], {"depth": 2.0}))
	assert_eq(h.verandahs.size(), 4)
	var n := BuildOps.verandah_rect(h, h.verandahs[0])
	assert_lt(n.end.y, 0.0, "the north verandah is outside the north wall")
	var e := BuildOps.verandah_rect(h, h.verandahs[3])
	assert_gt(e.position.x, 8.0, "the east verandah is outside the east wall")
	assert_false(BuildOps.verandah_at(h, 4.0, -1.0).is_empty())
	assert_true(BuildOps.verandah_at(h, 4.0, 3.0).is_empty(), "the house isn't verandah")
	var run2 := BuildOps.outside_run(h, 0, HouseData.hkey(3, 0))
	assert_false(BuildOps.add_verandah(h, 0, run2["side"], run2["line"], 2.0, 5.0)["ok"], "no doubling up")
	var b := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	b.build_structure(kit, 0)
	b.build_roof(kit)
	assert_true(kit.has_geometry())


func test_steps_toggle() -> void:
	var h := _house()
	var run := BuildOps.outside_run(h, 0, HouseData.hkey(3, 0))
	var id := str(BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"])["id"])
	_ok(BuildOps.toggle_steps(h, id, 4.0))
	assert_eq((BuildOps.verandah_by_id(h, id)["steps"] as Array).size(), 1)
	_ok(BuildOps.toggle_steps(h, id, 4.2))
	assert_eq((BuildOps.verandah_by_id(h, id)["steps"] as Array).size(), 0, "tapping the steps again takes them away")


func test_sleepout_is_a_room_under_the_verandah_roof() -> void:
	var h := _house()
	_ok(BuildOps.auto_roof(h, {"shape": "hip"}))
	var run := BuildOps.outside_run(h, 0, HouseData.hkey(3, 0))
	var id := str(BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], {"depth": 2.4})["id"])
	var before := h.rooms(0).size()
	_ok(BuildOps.enclose_sleepout(h, id, 4.0, 8.0))
	assert_eq(h.rooms(0).size(), before + 1, "the sleep-out is a room")
	var r := h.room_at_tile(0, Vector2i(5, -1))
	assert_eq(h.room_name(r), "Sleep-out")
	assert_true(bool((r["props"] as Dictionary).get("sleepout", false)))
	assert_eq(str(BuildOps.verandah_by_id(h, id)["shape"]), "skillion", "sleep-outs sit under a skillion")
	var windows := 0
	for o: Dictionary in h.storey(0)["openings"]:
		if o["kind"] == "window" and float(o["z"]) == -2.0:
			windows += 1
	assert_eq(windows, 3, "louvres along the outer wall")
	# The house roof doesn't spread over the sleep-out.
	for p: Dictionary in Roofs.pieces(h):
		assert_true(Roofs.rect_of(p).position.y >= 0.0)
	assert_false(BuildOps.toggle_steps(h, id, 6.0)["ok"], "no steps into the sleep-out")
	_ok(BuildOps.remove_sleepout(h, id))
	assert_eq(h.rooms(0).size(), before)


func test_sleepout_needs_depth() -> void:
	var h := _house()
	var run := BuildOps.outside_run(h, 0, HouseData.hkey(3, 0))
	var id := str(BuildOps.add_verandah(h, 0, run["side"], run["line"], run["from"], run["to"], {"depth": 1.5})["id"])
	assert_false(BuildOps.enclose_sleepout(h, id, 2.0, 6.0)["ok"])


func test_legacy_verandah_still_builds() -> void:
	var h := HouseData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/agnes_cottage.json")))
	var r := BuildOps.verandah_rect(h, h.verandahs[0])
	assert_almost_eq(r.size.y, 2.1, 0.001)
	var b := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	b.build_structure(kit, 0)
	b.build_roof(kit)
	assert_true(kit.has_geometry())
