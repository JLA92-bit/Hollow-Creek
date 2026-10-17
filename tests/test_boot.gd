extends GutTest


func test_project_name_and_renderer() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Hollow Creek")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_boot_scene_loads() -> void:
	var packed := load("res://scenes/boot/boot.tscn") as PackedScene
	assert_not_null(packed)
	var boot := packed.instantiate()
	add_child_autofree(boot)
	var version := boot.find_child("Version", true, false) as Label
	assert_not_null(version)
	assert_string_contains(version.text, GameState.version())


func test_clock_labels() -> void:
	assert_eq(Clock.time_label(0), "12:00 am")
	assert_eq(Clock.time_label(22 * 60 + 40), "10:40 pm")
	assert_eq(Clock.date_label(0), "Mon 2 June 1952")
	assert_eq(Clock.date_label(12), "Sat 14 June 1952")
	assert_eq(Clock.date_label(29), "Tue 1 July 1952")


func test_save_code_round_trip() -> void:
	var data := {"save_version": 1, "game": {"money": 1240, "town_trust": 62}}
	var code := SaveSystem.encode_code(data)
	assert_true(code.begins_with("HC1:"))
	var back := SaveSystem.decode_code(code)
	assert_eq(int(back["save_version"]), 1)
	assert_eq(int((back["game"] as Dictionary)["money"]), 1240)
	assert_eq(SaveSystem.decode_code("rubbish"), {})


func test_save_migration_rejects_unknown_versions() -> void:
	assert_eq(SaveSystem.migrate({"save_version": 99}), {})
	assert_false(SaveSystem.migrate({"save_version": 1}).is_empty())
