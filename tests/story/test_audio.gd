extends GutTest
## The audio director's rules (which sound plays when) and that the files are there.


func test_daylight_eases_across_dawn_and_dusk() -> void:
	assert_eq(AudioDirector.daylight(2.0 * 60.0), 0.0)
	assert_eq(AudioDirector.daylight(12.0 * 60.0), 1.0)
	assert_between(AudioDirector.daylight(6.0 * 60.0), 0.1, 0.9)
	assert_between(AudioDirector.daylight(18.5 * 60.0), 0.1, 0.9)
	assert_eq(AudioDirector.daylight(22.0 * 60.0), 0.0)


func test_the_files_exist_and_load() -> void:
	for n in ["ambience_day", "ambience_night", "rain", "search", "found", "alert", "phone", "solved", "knock"]:
		assert_not_null(load("res://assets/audio/world/%s.ogg" % n), n)
	for n in ["music_title", "music_dance"]:
		assert_not_null(load("res://assets/audio/music/%s.ogg" % n), n)


func test_the_band_plays_only_during_the_dance() -> void:
	SimHost.reset()
	SimHost.begin_prologue()
	SimHost.night = CashTinNight.new_state("house_store", 5)
	Clock.day = 5
	Clock.minute = 18 * 60
	assert_false(AudioDirector.dance_on())
	Clock.minute = 20 * 60
	assert_true(AudioDirector.dance_on())
	Clock.minute = 23 * 60 + 30
	assert_false(AudioDirector.dance_on())
	SimHost.reset()
	assert_false(AudioDirector.dance_on(), "not at all outside the prologue")


func test_a_director_runs_in_the_world_without_errors() -> void:
	var d := AudioDirector.new()
	add_child_autofree(d)
	await get_tree().process_frame
	d.cue("found")
	d.cue("nonsense")
	await get_tree().process_frame
	assert_not_null(d.day_player.stream)


func test_packs_are_listed_and_count_as_loaded_when_the_files_are_in_the_project() -> void:
	assert_true(ContentPacks.packs.has("music"))
	assert_true(ContentPacks.is_loaded("music"), "on desktop the project has the files")
	assert_eq(ContentPacks.progress("music"), 1.0)
	assert_false(ContentPacks.is_loaded("nonsense"))
