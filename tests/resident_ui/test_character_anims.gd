extends GutTest
## The shared animation set and which animation a resident plays.


func test_the_library_has_the_retargeted_set() -> void:
	var lib := CharacterAnims.library()
	for n in ["idle", "walk", "walk_formal", "sit", "sit_talk", "talk", "crouch", "sneak", "interact", "dance", "pickup", "torch"]:
		assert_true(lib.has_animation(n), n)
	assert_eq(lib.get_animation("walk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(lib.get_animation("pickup").loop_mode, Animation.LOOP_NONE)


func test_a_resident_model_gets_the_set_and_it_drives_the_skeleton() -> void:
	var m := (load("res://assets/characters/agnes.glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	var p := CharacterAnims.attach(m)
	assert_true(p.has_animation("walk") and p.has_animation("sit"))
	# Every track must find its bone, or the animation does nothing.
	var skel := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var walk := p.get_animation("walk")
	var missing := 0
	for i in walk.get_track_count():
		var bone := str(walk.track_get_path(i)).get_slice(":", 1)
		if skel.find_bone(bone) < 0:
			missing += 1
	assert_eq(missing, 0, "every bone the animation names is on the model")
	p.play("walk")
	p.seek(0.3, true)
	await get_tree().process_frame
	var thigh := skel.find_bone("thigh_l")
	assert_ne(skel.get_bone_pose_rotation(thigh), skel.get_bone_rest(thigh).basis.get_rotation_quaternion(), "the leg moves")


func test_the_mannequins_keep_their_own_animations() -> void:
	var m := (load("res://assets/characters/mannequin_m.glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	var before := m.find_children("*", "AnimationPlayer", true, false).size()
	var p := CharacterAnims.attach(m)
	assert_eq(m.find_children("*", "AnimationPlayer", true, false).size(), before, "no second player")
	assert_true(p.has_animation("walk"))


func test_what_people_do_picks_the_animation() -> void:
	assert_eq(CharacterAnims.pick("work", true, "stand", 40), "walk")
	assert_eq(CharacterAnims.pick("work", true, "stand", 67), "walk_formal", "the elderly walk more formally")
	assert_eq(CharacterAnims.pick("sneak", true, "stand", 44), "sneak")
	assert_eq(CharacterAnims.pick("sneak", false, "stand", 44), "crouch")
	assert_eq(CharacterAnims.pick("wireless", false, "sit", 30), "sit")
	assert_eq(CharacterAnims.pick("cook", false, "stand", 30), "interact")
	assert_eq(CharacterAnims.pick("dance", false, "stand", 30), "dance")
	assert_eq(CharacterAnims.pick("idle", false, "stand", 30), "idle")
