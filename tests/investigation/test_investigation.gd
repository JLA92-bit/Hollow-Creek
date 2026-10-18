extends GutTest
## The Cash Tin played through the Investigation rules (docs/CASE_00_CASH_TIN.md).

const CASE := "res://data/cases/case_00_cash_tin.json"
var inv: Investigation


func before_each() -> void:
	inv = Investigation.new(Investigation.load_case(CASE))


func _solve_to_evidence() -> void:
	for t: String in ["t_window", "t_tin", "t_prints_in", "t_prints_out", "t_mud_track"]:
		inv.search(t)
	inv.measure("t_prints_in")
	inv.interview("r_frank", 6)
	inv.press("r_frank", 6)
	inv.interview("r_edna", 6)
	inv.interview("r_halina", 6)
	inv.press("r_halina", 6)
	inv.interview("r_davey", 6)
	inv.present("r_davey", "t_mud_track", 6)
	inv.press("r_davey", 6)
	inv.interview("r_agnes", 6)
	inv.press("r_agnes", 6)
	inv.present("r_agnes", "rec_exchange", 6)
	inv.present("r_agnes", "t_prints_in_measured", 6)
	inv.interview("r_len", 6)
	inv.present("r_len", "st_halina_mud", 6)
	inv.present("r_len", "st_agnes_saw_len", 6)
	inv.present("r_len", "rec_ledger", 6)


func test_case_data_loads() -> void:
	assert_eq(inv.title(), "The Cash Tin")
	assert_eq(inv.traces().size(), 5)
	assert_eq(inv.deductions().size(), 6)


func test_searching_finds_traces_in_order_and_costs_time() -> void:
	var r := inv.search("t_window")
	assert_true(r["ok"])
	assert_eq(r["number"], 1)
	assert_eq(inv.minutes_spent, 30)
	var again := inv.search("t_window")
	assert_true(again["again"])
	assert_eq(inv.minutes_spent, 30, "reading a trace again is free")
	assert_eq(inv.search("t_tin")["number"], 2)


func test_measuring_needs_the_trace_first() -> void:
	assert_false(inv.measure("t_prints_in")["ok"])
	inv.search("t_prints_in")
	var m := inv.measure("t_prints_in")
	assert_true(m["ok"])
	assert_true(inv.knows("t_prints_in_measured"))
	assert_string_contains(m["text"], "Size 10")


func test_frank_and_edna_hand_over_the_records() -> void:
	inv.interview("r_frank", 6)
	assert_false(inv.knows("rec_ledger"))
	var p := inv.press("r_frank", 6)
	assert_true(inv.knows("rec_ledger"))
	assert_true(inv.records.has("rec_ledger"))
	assert_true(p["ok"])
	inv.interview("r_edna", 6)
	assert_true(inv.knows("rec_exchange"))


func test_pressing_twice_gets_nothing_more() -> void:
	inv.interview("r_halina", 6)
	assert_true(inv.press("r_halina", 6)["ok"])
	assert_false(inv.press("r_halina", 6)["ok"])
	assert_true(inv.knows("st_halina_mud"))


func test_agnes_breaks_in_two_steps() -> void:
	inv.search("t_prints_in")
	inv.measure("t_prints_in")
	inv.interview("r_edna", 6)
	inv.interview("r_agnes", 6)
	assert_eq(inv.current_statement("r_agnes")["id"], "st_agnes_1")
	inv.press("r_agnes", 6)
	assert_eq(inv.current_statement("r_agnes")["id"], "st_agnes_2")
	var a := inv.present("r_agnes", "rec_exchange", 6)
	assert_true(a["hit"])
	assert_eq(a["composure"], 60)
	assert_string_contains(a["text"], "man in a hat")
	var b := inv.present("r_agnes", "t_prints_in_measured", 6)
	assert_eq(b["composure"], 0)
	assert_true(inv.knows("st_agnes_saw_len"))


func test_wrong_evidence_adds_pressure_until_they_refuse() -> void:
	inv.search("t_window")
	inv.interview("r_len", 6)
	for i in 4:
		var r := inv.present("r_len", "t_window", 6)
		assert_false(r["hit"])
		assert_eq(r["pressure"], (i + 1) * 20)
	var last := inv.present("r_len", "t_window", 6)
	assert_true(last["refused"])
	assert_false(inv.can_talk("r_len", 6))
	assert_true(inv.can_talk("r_len", 7), "he'll talk again tomorrow")


func test_witnesses_without_a_pressure_meter_never_refuse() -> void:
	inv.search("t_window")
	inv.interview("r_halina", 6)
	for i in 8:
		inv.present("r_halina", "t_window", 6)
	assert_true(inv.can_talk("r_halina", 6))
	assert_eq(inv.people["r_halina"]["pressure"], 0)


func test_cannot_present_what_you_do_not_have() -> void:
	inv.interview("r_len", 6)
	assert_false(inv.present("r_len", "rec_ledger", 6)["ok"])


func test_len_confesses_at_zero_composure() -> void:
	_solve_to_evidence()
	assert_eq(inv.people["r_len"]["composure"], 0)
	assert_true(inv.knows("confession_len"))
	assert_true(inv.people["r_len"]["confessed"])


func test_davey_is_cleared_without_being_accused() -> void:
	_solve_to_evidence()
	assert_true(inv.knows("st_davey_saw_dad"))
	assert_true(inv.link("d_davey_cleared", {})["proven"])


func test_a_deduction_needs_its_evidence_and_the_right_answer() -> void:
	assert_eq(inv.link("d_entry", {"entry": "back window"})["reason"], "no evidence")
	inv.search("t_window")
	inv.search("t_prints_in")
	assert_eq(inv.link("d_entry", {"entry": "front door"})["reason"], "wrong")
	assert_false(inv.proven.has("d_entry"))
	assert_true(inv.link("d_entry", {"entry": "back window"})["proven"])


func test_len_out_is_provable_from_either_witness() -> void:
	inv.interview("r_halina", 6)
	inv.press("r_halina", 6)
	assert_true(inv.supported("d_len_out"))
	var other := Investigation.new(Investigation.load_case(CASE))
	other.interview("r_davey", 6)
	other.search("t_mud_track")
	other.present("r_davey", "t_mud_track", 6)
	other.press("r_davey", 6)
	assert_true(other.supported("d_len_out"))


func _prove_everything() -> void:
	_solve_to_evidence()
	inv.link("d_entry", {"entry": "back window"})
	inv.link("d_size", {"size": "10", "sole": "hobnail"})
	inv.link("d_agnes_awake", {"person": "Agnes Doyle", "time": "10:40 pm"})
	inv.link("d_len_out", {"from": "8:50 pm", "to": "9:35 pm"})
	inv.link("d_motive", {"motive": "refused credit and in debt"})


func test_full_solution_meets_all_four_requirements_after_the_warrant() -> void:
	_prove_everything()
	var before := inv.requirements()
	assert_false(before["means"], "size 10 prints aren't enough without the boots")
	assert_true(inv.request_warrant("h_pike")["right"])
	var r := inv.requirements()
	assert_true(r["opportunity"] and r["means"] and r["motive"] and r["lie"])
	assert_true(inv.complete())


func test_right_person_complete_then_choose_restitution() -> void:
	_prove_everything()
	inv.request_warrant("h_pike")
	var a := inv.accuse("r_len")
	assert_true(a["right"] and a["complete"])
	assert_false(inv.closed())
	var res := inv.resolve("restitution")
	assert_eq(res["trust"], 6)
	assert_true(inv.closed())
	assert_eq(inv.take_trust(), 6)
	assert_true(inv.unlocked.has("footpaths") and inv.unlocked.has("street_lamps"))


func test_charge_gives_ten_trust() -> void:
	_prove_everything()
	inv.request_warrant("h_pike")
	inv.accuse("r_len")
	inv.resolve("charge")
	assert_eq(inv.take_trust(), 10)


func test_right_person_with_holes_gets_three() -> void:
	_solve_to_evidence()
	var a := inv.accuse("r_len")
	assert_true(a["right"])
	assert_false(a["complete"])
	assert_eq(inv.take_trust(), 3)
	assert_true(inv.closed())
	assert_true(inv.resolve("charge").is_empty(), "no choice when the case has holes")


func test_wrong_person_costs_fifteen() -> void:
	_solve_to_evidence()
	var a := inv.accuse("r_davey")
	assert_false(a["right"])
	assert_eq(inv.take_trust(), -15)


func test_wrong_warrant_costs_five_and_finds_nothing() -> void:
	var r := inv.request_warrant("h_hayward")
	assert_false(r["right"])
	assert_eq(inv.take_trust(), -5)
	assert_false(inv.knows("t_tin_woodpile"))


func test_right_warrant_finds_the_tin() -> void:
	var r := inv.request_warrant("h_pike")
	assert_true(r["right"])
	assert_true(inv.knows("t_tin_woodpile"))
	assert_string_contains(r["text"], "£23 10s")


func test_snapshot_restores_exactly() -> void:
	_solve_to_evidence()
	var snap := inv.snapshot()
	var other := Investigation.new(Investigation.load_case(CASE))
	other.restore(snap)
	assert_eq(other.snapshot(), snap)
	other.accuse("r_davey")
	assert_eq(inv.accused, "", "restoring copies, it doesn't alias")


func test_every_fact_the_case_refers_to_can_be_learned() -> void:
	# Solvability: play everything available to a fixpoint and check nothing the case needs is out of reach.
	_prove_everything()
	inv.request_warrant("h_pike")
	var data := inv.data
	var needed: Array[String] = []
	for d: Dictionary in data["deductions"]:
		for f: String in d.get("proven_by", []):
			needed.append(f)
	for p: String in data["people"]:
		for s: Dictionary in data["people"][p]["statements"]:
			for c: Dictionary in s.get("contradicted_by", []):
				needed.append(str(c["fact"]))
	for f in needed:
		assert_true(inv.knows(f), "reachable: %s" % f)
