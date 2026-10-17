extends GutTest
## docs/BUILDING.md "Ground and traces": bootprints by ground and wetness, muddy floors, fading;
## and the town's paperwork (time cards, the store's ledger, the exchange log).


## A strip of valley 40 m long: grass, mud, gravel, dirt (10 m each), with a little room on the gravel.
func _sim(with_house: bool = false) -> Sim:
	var g := WorldGrid.new(40, 10)
	for y in 10:
		for x in 40:
			g.set_ground(x, y, [Ground.Type.GRASS, Ground.Type.MUD, Ground.Type.GRAVEL, Ground.Type.DIRT][x / 10])
	var hs: Array = []
	if with_house:
		var h := HouseData.new()
		h.id = "shed"
		h.origin = Vector2i(22, 3)
		h.base_y = 0.0
		BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 4), {"name": "Shed"})
		hs.append(h)
	var s := Sim.new(1)
	s.town = SimTown.build(g, hs, [], PackedVector2Array())
	s.data = Sim.load_data()
	return s


func _len() -> Dictionary:
	return {"id": "r_len", "route": [[0, 0.5, 5.5], [0, 39.5, 5.5]], "first": "Len"}


func _count(s: Sim, x0: int, x1: int, y: int = 5) -> int:
	var n := 0
	for x in range(x0, x1):
		n += Traces.read(s, Vector2i(x, y)).size()
	return n


func test_prints_by_ground() -> void:
	var s := _sim()
	Traces.walk(s, _len(), 0.0, 39.0)
	assert_eq(_count(s, 0, 10), 0, "no prints on dry grass")
	assert_eq(_count(s, 10, 20), 10, "every step in the mud")
	assert_eq(_count(s, 20, 30), 0, "none on gravel")
	var dirt := _count(s, 30, 40)
	assert_between(dirt, 1, 9, "faint, every other step or so, on dry dirt (%d)" % dirt)
	var p: Dictionary = Traces.read(s, Vector2i(12, 5))[0]
	assert_eq([p["size"], p["sole"], p["clarity"], p["heading"]], ["10", "hobnail work boot", "clear", "E"], "Len's work boots, heading east")
	assert_false(p.has("who"), "an investigator reads boots, not names")


func test_wet_ground_and_muddy_floors() -> void:
	var s := _sim(true)
	s.raining = true
	Traces.walk(s, _len(), 0.0, 39.0)
	var grass := _count(s, 0, 10)
	assert_between(grass, 1, 9, "faint prints on wet grass (%d)" % grass)
	assert_eq(_count(s, 30, 40), 10, "clear prints on wet dirt")
	assert_eq(_count(s, 22, 26), 4, "mud carried onto the shed floor")
	assert_true(Traces.read(s, Vector2i(23, 5))[0]["muddy"])
	assert_eq(_count(s, 20, 22), 0, "gravel still takes none")


func test_prints_fade() -> void:
	var s := _sim()
	Traces.walk(s, _len(), 0.0, 20.0)
	assert_eq(_count(s, 10, 20), 10)
	s.ticks += 2 * 1440 - 1
	Traces.fade(s)
	assert_eq(_count(s, 10, 20), 10, "still there just under 2 days later")
	s.ticks += 1
	Traces.fade(s)
	assert_eq(_count(s, 10, 20), 0, "gone after 2 days")
	var s2 := _sim()
	Traces.walk(s2, _len(), 0.0, 20.0)
	s2.rain_minutes += 6 * 60
	Traces.fade(s2)
	assert_eq(_count(s2, 10, 20), 0, "washed out by 6 hours of rain")


func test_town_records() -> void:
	var t := SimTown.build(MapSlice.load_default().grid, DemoTown.houses(), MapSlice.load_default().data["landmarks"], PackedVector2Array())
	var s := Sim.new(1952)
	s.setup(t, Sim.load_data(), DemoTown.homes(), 0, 6 * 60)
	s.run_ticks(3 * 1440)
	var cards: Array = s.records["time_cards"]
	var len_days := 0
	for c: Dictionary in cards:
		if c["rid"] == "r_len":
			len_days += 1
			assert_between(int(c["in"]), 6 * 60, 7 * 60 + 30, "Len clocks on about seven")
			assert_between(int(c["out"]), 15 * 60, 16 * 60, "and off about half past three")
	assert_eq(len_days, 3, "three days of time cards for Len")
	gut.p("Ledger: %s" % [s.records["ledger"].slice(0, 3)])
	gut.p("Exchange: %s" % [s.records["exchange"].slice(0, 3)])
	for e: Dictionary in s.records["ledger"]:
		assert_gt(int(e["pence"]), 0)
	var walked := 0
	for k: String in s.traces:
		walked += (s.traces[k] as Array).size()
	gut.p("Bootprints in the town after 3 days: %d" % walked)
	assert_gt(walked, 0, "the town is full of bootprints")
