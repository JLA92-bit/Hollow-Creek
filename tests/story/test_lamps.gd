extends GutTest
## Street lamps: placing and removing, light on the ground, the save, and what they do to crime.

static var _town: SimTown


func before_each() -> void:
	GameState.reset()
	SimHost.reset()


func _sim(lamps: Array = []) -> Sim:
	var slice := MapSlice.load_default()
	var hs: Array = DemoTown.houses()
	for l: Dictionary in slice.data["landmarks"]:
		if l["kind"] == "house":
			var a := HouseData.load_file(str(l["house"]))
			var o: Array = l["origin"]
			a.origin = Vector2i(int(o[0]), int(o[1]))
			hs.append(a)
	var town := SimTown.build(slice.grid, hs, slice.data["landmarks"], slice.creek_points, lamps)
	var s := Sim.new(1952)
	s.setup(town, Sim.load_data(), DemoTown.homes(), 5, 21 * 60)
	return s


func test_a_lamp_goes_up_and_comes_down() -> void:
	var lamps: Array = []
	var r := LampOps.place(lamps, Vector2(60.2, 50.1))
	assert_true(r["ok"])
	assert_eq(r["cost"], 15)
	assert_eq(lamps, [[60.0, 50.0]], "snapped to half a metre")
	assert_eq(LampOps.remove_at(lamps, Vector2(60.4, 50.3)), 8)
	assert_true(lamps.is_empty())
	assert_eq(LampOps.remove_at(lamps, Vector2(10, 10)), -1)


func test_lamps_keep_their_distance_and_stay_out_of_the_water() -> void:
	var lamps: Array = [[60.0, 50.0]]
	assert_false(LampOps.place(lamps, Vector2(61.0, 50.0))["ok"], "too close")
	assert_true(LampOps.place(lamps, Vector2(66.0, 50.0))["ok"])
	assert_false(LampOps.place(lamps, Vector2(80.0, 50.0), func(_p: Vector2) -> bool: return true)["ok"], "blocked")


func test_lamps_are_in_the_save() -> void:
	GameState.lamps = [[61.0, 44.5], [70.0, 44.5]]
	var d := GameState.to_dict()
	GameState.reset()
	assert_true(GameState.lamps.is_empty())
	GameState.from_dict(d)
	assert_eq(GameState.lamps.size(), 2)


func test_a_lamp_lights_the_ground_at_night_but_not_by_day() -> void:
	var s := _sim([[40.0, 40.0]])
	var night := LightGrid.compute(s.town.sight, 5, 23 * 60, false, {})
	var day := LightGrid.compute(s.town.sight, 5, 12 * 60, false, {})
	var near := Vector2i(41, 40)
	assert_gte(night.at(near), 0.55, "bright under the lamp at night")
	assert_lt(night.at(Vector2i(60, 40)), 0.3, "dark away from it")
	assert_eq(day.at(near), day.outdoor)


func test_lamps_near_a_home_take_pressure_off_the_robbers() -> void:
	var bare := _sim()
	var c0 := 0.0
	for x: Dictionary in Motives.candidates(bare, "theft"):
		if x["culprit"] == "r_len" and x["target"] == "r_frank":
			c0 = float(x["pressure"])
	assert_gt(c0, 0.0)
	# Four lamps round the store.
	var store: Vector2i = bare.town.origins["house_store"]
	var lamps: Array = []
	for d in [Vector2(-3, 4), Vector2(14, 4), Vector2(5, -3), Vector2(5, 12)]:
		lamps.append([float(store.x) + d.x, float(store.y) + d.y])
	var lit := _sim(lamps)
	assert_eq(Motives.safety(lit, "r_frank"), 24.0)
	assert_eq(Motives.safety(bare, "r_frank"), 0.0)
	var c1 := 0.0
	for x: Dictionary in Motives.candidates(lit, "theft"):
		if x["culprit"] == "r_len" and x["target"] == "r_frank":
			c1 = float(x["pressure"])
	assert_lt(c1, c0, "the same man, less tempted")
