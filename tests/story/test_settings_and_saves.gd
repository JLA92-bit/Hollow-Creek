extends GutTest
## Settings take effect, slots describe themselves, and a save code carries a game.

var _keep := {}


func before_each() -> void:
	for k in ["text_scale", "master_volume", "quality", "hints", "reduce_motion"]:
		_keep[k] = Settings.get_value(k)


func after_each() -> void:
	for k in _keep:
		Settings.set_value(k, _keep[k])


func test_text_size_scales_the_whole_ui() -> void:
	Settings.set_value("text_scale", 1.25)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.25, 0.001)
	Settings.set_value("text_scale", 5.0)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.5, 0.001, "clamped")


func test_volume_sets_the_master_bus() -> void:
	Settings.set_value("master_volume", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01)
	Settings.set_value("master_volume", 0.0)
	assert_lt(AudioServer.get_bus_volume_db(0), -60.0)


func test_the_settings_screen_drives_the_settings() -> void:
	var s := SettingsScreen.new()
	add_child_autofree(s)
	await get_tree().process_frame
	s.quality_buttons["low"].pressed.emit()
	assert_eq(Settings.get_value("quality"), "low")
	s.hints_check.button_pressed = false
	assert_false(Settings.get_value("hints"))
	s.motion_check.button_pressed = true
	assert_true(Settings.get_value("reduce_motion"))
	s.text_slider.value = 1.2
	assert_almost_eq(float(Settings.get_value("text_scale")), 1.2, 0.001)


func test_an_empty_slot_says_so_and_cannot_be_loaded() -> void:
	assert_eq(SaveSystem.slot_label("no_such_slot"), "Empty")
	var s := SettingsScreen.new()
	add_child_autofree(s)
	await get_tree().process_frame
	assert_true((s.slot_buttons["slot3"]["load"] as Button).disabled or SaveSystem.slot_info("slot3")["exists"])


func test_a_save_code_round_trips_the_game() -> void:
	GameState.reset()
	SimHost.reset()
	GameState.money = 777
	GameState.town_trust = 63
	GameState.roads["10,10"] = "dirt"
	var code := SaveSystem.export_code()
	assert_true(code.begins_with("HC1:"))
	GameState.reset()
	assert_ne(GameState.money, 777)
	assert_true(SaveSystem.import_code(code))
	assert_eq(GameState.money, 777)
	assert_eq(GameState.town_trust, 63)
	assert_eq(GameState.roads.get("10,10"), "dirt", "roads are in the save")


func test_a_bad_code_is_refused_without_changing_anything() -> void:
	GameState.money = 123
	assert_false(SaveSystem.import_code("not a code"))
	assert_false(SaveSystem.import_code("HC1:5:@@@"))
	assert_eq(GameState.money, 123)


func test_the_prologue_survives_a_save_and_load() -> void:
	GameState.reset()
	SimHost.reset()
	SimHost.begin_prologue()
	SimHost.prologue.acknowledge()
	SimHost.prologue.update({})
	var code := SaveSystem.export_code()
	SimHost.reset()
	assert_null(SimHost.prologue)
	assert_true(SaveSystem.import_code(code))
	assert_not_null(SimHost.prologue)
	assert_eq(SimHost.prologue.current_id(), "road")


func test_credits_list_the_engine_and_the_assets() -> void:
	var t := CreditsScreen.build_text()
	assert_string_contains(t, "Godot")
	assert_string_contains(t, "Fraunces")
	assert_string_contains(t, "CC0")
