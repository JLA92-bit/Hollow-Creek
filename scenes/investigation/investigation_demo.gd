extends "res://scenes/resident_ui/residents_demo.gd"
## M7 acceptance demo: The Cash Tin solved with scripted taps. The new game gets its town and
## residents, an incident alert opens the case on Saturday night, and then the demo plays it through
## the real investigation screen by pressing the same buttons a player does: search the store and
## its surroundings, measure the bootprints, interview everybody, present evidence, link deductions,
## search the Pike house on a warrant, accuse Len and choose restitution. Prints HC_SHOT and HC_DEMO
## lines (?scene=investigation_demo).

const CASE := "res://data/cases/case_00_cash_tin.json"
var screen: InvestigationScreen


func _ready() -> void:
	GameState.reset()
	SimHost.reset()
	Settings.set_value("quality", "medium")
	GameState.mode = GameState.MODE_STORY
	Clock.set_speed(0)
	Clock.day = 0
	Clock.set_minute(7 * 60)
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	_run_case.call_deferred()


func _tap(b: Button, what: String) -> void:
	_check(b != null and is_instance_valid(b) and not b.disabled, "tap: %s" % what)
	if b != null and is_instance_valid(b) and not b.disabled:
		b.pressed.emit()
	await _frames(3)


func _choose(ob: OptionButton, text: String) -> void:
	for i in ob.item_count:
		if ob.get_item_text(i) == text:
			ob.select(i)
			return
	push_warning("no option %s" % text)


func _link(id: String, answers: Dictionary) -> void:
	var opts: Dictionary = screen.slot_options.get(id, {})
	for k: String in answers:
		_choose(opts[k] as OptionButton, str(answers[k]))
	await _tap(screen.link_buttons.get(id) as Button, "link %s" % id)


func _talk(pid: String) -> void:
	await _tap(screen.person_chips[pid] as Button, "interview %s" % pid)


func _present(pid: String, f: String) -> void:
	await _tap(screen.fact_chips.get(f) as Button, "select %s" % f)
	await _tap(screen.present_button, "present %s to %s" % [f, pid])


func _run_case() -> void:
	await _frames(5)
	rig = world.get("rig")
	hud = world.get("hud")
	for h: HouseData in DemoTown.houses():
		world.call("add_house", h)
	await _frames(2)
	SimHost.rebuild_town()
	for hid: String in ["h_hayward", "h_pike", "h_kowalski"]:
		SimHost.offer_home(hid, DemoTown.homes()[hid])
	_check(SimHost.living_count() == 10, "ten residents at home")
	Clock.day = 5
	Clock.set_minute(22 * 60 + 35)
	var trust0 := GameState.town_trust

	# Incident alert: Frank finds the window open. Time pauses.
	var inv := SimHost.open_case(CASE)
	_check(inv != null and SimHost.investigation == inv and Clock.speed == 0, "the alert opens the case and pauses time")
	screen = world.get("case_screen")
	_check(screen != null and screen.visible, "the world opens the investigation screen on the alert")
	await _frames(4)
	_check(screen.hotspots.size() == 5, "five places to search, none found yet")

	# The scene.
	await _tap(screen.hotspots["t_window"] as Button, "search the back window")
	await _tap(screen.hotspots["t_tin"] as Button, "search the counter")
	await _tap(screen.hotspots["t_prints_in"] as Button, "search the floor")
	await _tap(screen.measure_button, "measure the bootprints")
	_check(inv.knows("t_prints_in_measured"), "bootprints measured: size 10, hobnail")
	await shot("m7_01_scene")
	await _tap(screen.hotspots["t_prints_out"] as Button, "search outside the window")
	await _tap(screen.hotspots["t_mud_track"] as Button, "search the creek track")
	_check(inv.traces_found() == 5 and screen.markers.size() == 5, "all five traces found, with numbered markers")

	# Interviews.
	await _talk("r_frank")
	await _tap(screen.press_button, "press Frank")
	_check(inv.knows("rec_ledger"), "Frank hands over the credit ledger")
	await _talk("r_edna")
	_check(inv.knows("rec_exchange"), "Edna shows the exchange log")
	await _talk("r_halina")
	await _tap(screen.press_button, "press Halina")
	_check(inv.knows("st_halina_mud"), "Halina saw mud on Len's trousers")
	await _talk("r_davey")
	await _present("r_davey", "t_mud_track")
	await _tap(screen.press_button, "press Davey")
	_check(inv.knows("st_davey_saw_dad"), "Davey saw his dad on the track")
	await _talk("r_agnes")
	await _tap(screen.press_button, "press Agnes")
	await _present("r_agnes", "rec_exchange")
	_check(int(inv.people["r_agnes"]["composure"]) == 60, "the exchange log catches Agnes out (composure 60)")
	await shot("m7_02_interview")
	await _present("r_agnes", "t_prints_in_measured")
	_check(inv.knows("st_agnes_saw_len"), "Agnes breaks: she saw Len")
	await _talk("r_len")
	await _present("r_len", "st_halina_mud")
	await _present("r_len", "st_agnes_saw_len")
	await _present("r_len", "rec_ledger")
	_check(bool(inv.people["r_len"]["confessed"]), "Len confesses at composure 0")
	await shot("m7_03_confession")

	# The case board.
	await _link("d_entry", {"entry": "back window"})
	await _link("d_size", {"size": "10", "sole": "hobnail"})
	await _link("d_agnes_awake", {"person": "Agnes Doyle", "time": "10:40 pm"})
	await _link("d_len_out", {"from": "8:50 pm", "to": "9:35 pm"})
	await _link("d_motive", {"motive": "refused credit and in debt"})
	_check(inv.proven.size() == 5, "five deductions proven")

	# The warrant, then the accusation.
	_check(not bool(inv.requirements()["means"]), "means isn't proven until the boots are found")
	for i in screen.warrant_choice.item_count:
		if str(screen.warrant_choice.get_item_metadata(i)) == "h_pike":
			screen.warrant_choice.select(i)
	await _tap(screen.warrant_button, "search the Pike house")
	_check(inv.knows("t_tin_woodpile"), "the tin is under the Pikes' woodpile")
	await _tap(screen.accuse_button, "open the accusation")
	for i in screen.accuse_choice.item_count:
		if str(screen.accuse_choice.get_item_metadata(i)) == "r_len":
			screen.accuse_choice.select(i)
	await shot("m7_04_accusation")
	await _tap(screen.accuse_confirm, "accuse Len Pike")
	_check(bool(inv.outcome["right"]) and bool(inv.outcome["complete"]), "right person, all four requirements proven")
	await _tap(screen.resolution_buttons["restitution"] as Button, "choose restitution")
	_check(inv.closed() and SimHost.case_done("case_00_cash_tin"), "the case is closed")
	_check(GameState.town_trust == trust0 + 6, "Town Trust +6 (%d)" % GameState.town_trust)
	_check(SimHost.is_unlocked("footpaths") and SimHost.is_unlocked("street_lamps"), "footpaths and street lamps unlocked")
	await shot("m7_05_closed")
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
