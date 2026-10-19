extends GutTest
## The portrait's faces: every action unit the mood asks for exists on the model, and the mood
## reads as the right expression.


func test_every_resident_has_a_portrait_with_every_face_key() -> void:
	var data: Dictionary = Sim.load_data()["residents"]
	for rid: String in data:
		var look := ResidentLook.for_resident(rid, data[rid])
		var path := "res://assets/characters/%s_portrait.glb" % look["model"]
		assert_true(ResourceLoader.exists(path), path)
		var root := (load(path) as PackedScene).instantiate()
		var face := PortraitView._find_face(root)
		assert_not_null(face, "%s has a face with morph targets" % rid)
		if face == null:
			continue
		var names: Array[String] = []
		for i in face.mesh.get_blend_shape_count():
			names.append(str(face.mesh.get_blend_shape_name(i)))
		for key: String in PortraitView.expression_weights(50.0, 50.0, true):
			assert_true(names.has(key), "%s has %s" % [rid, key])
		root.free()


func test_a_composed_unpressed_person_is_nearly_neutral() -> void:
	var w := PortraitView.expression_weights(100.0, 0.0)
	for k: String in w:
		assert_lt(float(w[k]), 0.3, k)
	assert_eq(float(w["worried"]), 0.0)


func test_a_rattled_person_looks_worried() -> void:
	var w := PortraitView.expression_weights(30.0, 20.0)
	assert_gt(float(w["worried"]), 0.5)
	assert_lt(float(w["stern"]), 0.2)


func test_a_composed_person_under_pressure_looks_stern() -> void:
	var w := PortraitView.expression_weights(95.0, 80.0)
	assert_gt(float(w["stern"]), 0.5)
	assert_lt(float(w["worried"]), 0.2)


func test_a_person_at_the_end_of_their_tether_looks_afraid_then_broken() -> void:
	assert_gt(float(PortraitView.expression_weights(20.0, 90.0)["afraid"]), 0.7)
	assert_gt(float(PortraitView.expression_weights(5.0, 0.0)["broken"]), 0.4)


func test_a_confession_is_the_broken_face() -> void:
	var w := PortraitView.expression_weights(0.0, 0.0, true)
	assert_eq(float(w["broken"]), 1.0)
	assert_eq(float(w["smile"]), 0.0)


func test_the_face_moves_with_the_mood() -> void:
	var data: Dictionary = Sim.load_data()["residents"]
	var v := PortraitView.new()
	add_child_autofree(v)
	v.show_resident("r_len", data["r_len"])
	v.set_mood(10.0, 60.0)
	for i in 30:
		await get_tree().process_frame
	var face := PortraitView._find_face(v._model)
	var idx := face.find_blend_shape_by_name("worried")
	assert_gt(face.get_blend_shape_value(idx), 0.2, "the worried face has come on")
