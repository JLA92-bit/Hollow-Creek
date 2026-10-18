extends GutTest
## docs/SIMULATION.md "Tests": statement generation for an honest resident, a Loyal resident
## protecting a friend, and a culprit lying about where they were.

static var _town: SimTown


func _sim() -> Sim:
	if _town == null:
		var slice := MapSlice.load_default()
		var hs: Array = DemoTown.houses()
		for l: Dictionary in slice.data["landmarks"]:
			if l["kind"] == "house":
				var a := HouseData.load_file(str(l["house"]))
				var o: Array = l["origin"]
				a.origin = Vector2i(int(o[0]), int(o[1]))
				hs.append(a)
		_town = SimTown.build(slice.grid, hs, slice.data["landmarks"], slice.creek_points)
	var s := Sim.new(1952)
	s.setup(_town, Sim.load_data(), DemoTown.homes(), 5, 21 * 60)
	return s


func _see(s: Sim, observer: String, subject: String, minute: int, id: String, detail: String = "behind the store") -> void:
	(s.residents[observer]["memories"] as Array).append({"id": id, "day": 5, "minute": minute, "kind": "saw_person", "subject": subject,
		"detail": detail, "place": "outside the General store", "tile": [60, 50], "confidence": 0.8, "source": "firsthand"})


func _incident() -> Dictionary:
	return {"culprit": "r_len", "victim": "r_frank", "day": 5, "minute": 21 * 60 + 5, "touches": ["s_davey_smoking"],
		"cover": {"place": "at the dance", "minute": 21 * 60}}


func test_an_honest_resident_tells_what_they_saw() -> void:
	var s := _sim()
	_see(s, "r_halina", "r_len", 20 * 60 + 50, "m1", "leaving the shed")
	var out := Statements.build(s, "r_halina", _incident())
	assert_eq(Statements.decide(s, "r_halina", _incident())["stance"], "honest")
	assert_eq(out.size(), 1)
	assert_eq(out[0]["stance"], "honest")
	assert_string_contains(out[0]["text"], "Len Pike")
	assert_eq(out[0]["text"], out[0]["truth"])


func test_a_loyal_friend_of_the_culprits_family_denies_it() -> void:
	var s := _sim()
	_see(s, "r_agnes", "r_len", 21 * 60 + 12, "m2")
	var d := Statements.decide(s, "r_agnes", _incident())
	assert_eq(d["stance"], "lie")
	assert_eq(d["why"], "protecting a friend")
	var out := Statements.build(s, "r_agnes", _incident())
	assert_eq(out[0]["stance"], "lie")
	assert_false("Len" in str(out[0]["text"]), "the lie doesn't name him")
	assert_string_contains(out[0]["truth"], "Len Pike")
	assert_eq(out[0]["memory_id"], "m2", "the lie keeps its link to the true memory")


func test_the_culprit_gives_a_false_alibi() -> void:
	var s := _sim()
	var out := Statements.build(s, "r_len", _incident())
	assert_eq(out.size(), 1)
	assert_eq(out[0]["kind"], "false_location")
	assert_string_contains(out[0]["text"], "the dance")
	assert_eq(out[0]["stance"], "lie")


func test_family_protects_family() -> void:
	var s := _sim()
	assert_eq(Statements.decide(s, "r_marge", _incident())["why"], "protecting family")


func test_a_secret_the_truth_would_expose_means_a_lie() -> void:
	var s := _sim()
	assert_eq(Statements.decide(s, "r_davey", {"culprit": "r_len", "touches": ["s_davey_smoking"]})["stance"], "lie")


func test_someone_afraid_of_the_culprit_leaves_it_out() -> void:
	var s := _sim()
	s.grievances.append({"owner": "r_len", "target": "r_tomasz", "reason": "test", "weight": 50.0, "day": 0})
	assert_eq(Statements.decide(s, "r_tomasz", _incident())["stance"], "omit")
	_see(s, "r_tomasz", "r_len", 21 * 60 + 8, "m3")
	var out := Statements.build(s, "r_tomasz", _incident())
	assert_eq(out[0]["stance"], "omit")
	assert_eq(out[0]["why"], "afraid of the culprit")


func test_memories_outside_the_window_are_ignored() -> void:
	var s := _sim()
	_see(s, "r_halina", "r_len", 9 * 60, "m4")
	assert_eq(Statements.build(s, "r_halina", _incident()).size(), 0)


func test_a_lie_can_be_contradicted_by_an_honest_witness() -> void:
	var s := _sim()
	_see(s, "r_agnes", "r_len", 21 * 60 + 12, "m2")
	_see(s, "r_halina", "r_len", 21 * 60 + 8, "m5")
	var lie: Dictionary = Statements.build(s, "r_agnes", _incident())[0]
	var found := Statements.contradictions(s, lie, _incident())
	assert_eq(found.size(), 1)
	assert_eq(found[0]["owner"], "r_halina")


func test_statements_are_deterministic() -> void:
	var a := _sim()
	var b := _sim()
	_see(a, "r_agnes", "r_len", 21 * 60 + 12, "m2")
	_see(b, "r_agnes", "r_len", 21 * 60 + 12, "m2")
	assert_eq(Statements.build(a, "r_agnes", _incident()), Statements.build(b, "r_agnes", _incident()))
