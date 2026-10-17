extends GutTest

var _dn: DayNight


func before_all() -> void:
	_dn = DayNight.new()
	_dn.data = JSON.parse_string(FileAccess.get_file_as_string(DayNight.PATH)) as Dictionary
	_dn.keys = _dn.data["keys"]


func after_all() -> void:
	_dn.free()


func test_noon_sun_is_high_in_the_north() -> void:
	var s := _dn.sample(12 * 60 + 30)
	assert_gt(float(s["sun_el"]), 30.0)
	assert_lt(absf(float(s["sun_az"])), 20.0, "Southern Hemisphere: noon sun is due north")
	assert_false(s["moon"])
	assert_almost_eq(float(s["lamps"]), 0.0, 0.01)


func test_morning_sun_in_the_east_and_dusk_in_the_west() -> void:
	assert_gt(float(_dn.sample(8 * 60)["sun_az"]), 30.0)
	assert_lt(float(_dn.sample(17 * 60 + 30)["sun_az"]), -30.0)


func test_night_has_moonlight_and_lamps() -> void:
	var s := _dn.sample(22 * 60)
	assert_true(s["moon"])
	assert_almost_eq(float(s["lamps"]), 1.0, 0.01)


func test_wraps_past_midnight() -> void:
	assert_eq(_dn.sample(1440 + 60), _dn.sample(60))


func test_keys_are_in_order() -> void:
	for i in _dn.keys.size() - 1:
		assert_lt(float(_dn.keys[i]["m"]), float(_dn.keys[i + 1]["m"]))
