extends GutTest


func test_presets_have_every_setting() -> void:
	for name in Quality.NAMES:
		var p := Quality.preset(name)
		for key in ["render_scale", "shadow_size", "shadow_splits", "ssao", "lamps", "msaa", "texture_size", "resident_lod_m"]:
			assert_true(p.has(key), "%s.%s" % [name, key])
	assert_eq(int(Quality.preset("low")["lamps"]), 4)
	assert_eq(int(Quality.preset("medium")["lamps"]), 8)
	assert_eq(int(Quality.preset("high")["lamps"]), 16)


func test_benchmark_thresholds() -> void:
	assert_eq(Quality.pick_from_frame_ms(9.0), "high")
	assert_eq(Quality.pick_from_frame_ms(22.0), "medium")
	assert_eq(Quality.pick_from_frame_ms(60.0), "low")


func test_every_library_material_loads() -> void:
	var mats: Dictionary = MaterialLibrary.data()["materials"]
	for id: String in mats:
		var m := MaterialLibrary.get_material(id)
		assert_not_null(m, id)
		if mats[id].has("tex"):
			assert_not_null(m.albedo_texture, "%s albedo" % id)


func test_paint_tints_are_cached_per_colour() -> void:
	var a := MaterialLibrary.get_material("plaster", MaterialLibrary.paint("mint"))
	var b := MaterialLibrary.get_material("plaster", MaterialLibrary.paint("mint"))
	var c := MaterialLibrary.get_material("plaster", MaterialLibrary.paint("rose"))
	assert_same(a, b)
	assert_ne(a, c)


func test_manifest_models_exist() -> void:
	var manifest := JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_manifest.json")) as Dictionary
	for m: Dictionary in manifest["polyhaven"]["models"]:
		assert_true(ResourceLoader.exists("res://assets/models/%s/%s.gltf" % [m["id"], m["id"]]), str(m["id"]))
	var credits := JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_credits.json")) as Dictionary
	assert_eq(credits.size(), (manifest["polyhaven"]["textures"] as Array).size() + (manifest["polyhaven"]["hdris"] as Array).size()
		+ (manifest["polyhaven"]["models"] as Array).size(), "every fetched asset is credited")


func test_eucalypts_are_deterministic_and_lod_is_cheaper() -> void:
	var a := EucalyptBuilder.build("gum", 99)
	var b := EucalyptBuilder.build("gum", 99)
	var far := EucalyptBuilder.build("gum", 99, 1)
	var count := func(m: ArrayMesh) -> int:
		var n := 0
		for i in m.get_surface_count():
			n += m.surface_get_array_index_len(i)
		return n
	assert_eq(count.call(a), count.call(b))
	assert_lt(count.call(far), count.call(a))
