extends GutTest
## The solver bot and the solvability check, on the authored Cash Tin and on broken cases.

const CASE := "res://data/cases/case_00_cash_tin.json"


func _tin() -> Dictionary:
	return Investigation.load_case(CASE)


func test_the_bot_solves_the_authored_cash_tin() -> void:
	var inv := Investigation.new(_tin())
	var res := SolverBot.play(inv)
	assert_eq(res["accused"], "r_len")
	assert_true(res["right"] and res["complete"], str(res))
	assert_true(inv.requirements("r_len")["lie"])


func test_the_cash_tin_passes_the_solvability_check() -> void:
	var a := Solvability.analyse(_tin())
	assert_true(a["solvable"], str(a["reasons"]))


func test_the_bot_does_not_convict_davey() -> void:
	var inv := Investigation.new(_tin())
	SolverBot.play(inv, false)
	assert_false(inv.complete("r_davey"))
	assert_false(inv.complete("r_agnes"))


func test_a_case_without_a_motive_is_not_solvable() -> void:
	var c := _tin()
	c["records"] = []
	for p: Dictionary in c["people"].values():
		for s: Dictionary in p["statements"]:
			if s.has("press"):
				(s["press"] as Dictionary)["gives"] = (s["press"]["gives"] as Array).filter(func(g: String) -> bool: return g != "rec_ledger")
	var a := Solvability.analyse(c)
	assert_false(a["solvable"])


func test_a_case_where_the_means_are_missing_is_not_solvable() -> void:
	var c := _tin()
	c["warrant"]["target"] = "h_nobody"
	var a := Solvability.analyse(c)
	assert_false(a["solvable"], "without the warrant find there's no means")


func test_a_case_where_a_second_person_fits_everything_is_not_solvable() -> void:
	var c := _tin()
	c["proof"] = {"r_davey": c["accusation"].duplicate(true)}
	c["proof"]["r_davey"]["lie"] = {"broken_by": "r_len"}
	var a := Solvability.analyse(c)
	assert_false(a["solvable"])
	assert_true("r_davey" in str(a["reasons"]))


func test_an_or_rule_needs_only_one_branch() -> void:
	var inv := Investigation.new(_tin())
	assert_false(inv._meets({"or": [{"any_fact": ["nothing"]}, {"any_fact": ["also nothing"]}]}))
	inv.facts["x"] = true
	assert_true(inv._meets({"or": [{"any_fact": ["nothing"]}, {"any_fact": ["x"]}]}))


func test_an_answer_can_list_several_acceptable_values() -> void:
	var c := _tin()
	(c["deductions"][0] as Dictionary)["answer"] = {"entry": ["back window", "window"]}
	var inv := Investigation.new(c)
	inv.search("t_window")
	inv.search("t_prints_in")
	assert_true(inv.link("d_entry", {"entry": "window"})["proven"])
