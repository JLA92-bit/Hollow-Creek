extends "res://scenes/resident_ui/residents_demo.gd"
## The main screens at a phone's landscape size (run with --viewport 844x390): the prologue card,
## the Roads panel, the Lights panel, the interview screen and settings. Prints HC_SHOT and HC_DEMO
## lines (?scene=phone_demo). It checks that nothing important is pushed off screen or too small to tap.

const MIN_TAP := 38.0   ## screen pixels (a UI pixel is about 0.9 of one on a 390 px tall phone)


func _ready() -> void:
	GameState.reset()
	SimHost.reset()
	Settings.set_value("quality", "low")
	GameState.mode = GameState.MODE_STORY
	SimHost.begin_prologue()
	Clock.set_speed(0)
	Clock.day = 0
	Clock.set_minute(9 * 60)
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	_run_phone.call_deferred()


## Every visible button under a node must be fully on screen and at least MIN_TAP tall.
func _audit(root: Node, label: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	var px := float(get_window().size.y) / vp.y   # screen pixels per UI pixel
	var bad := 0
	var worst := ""
	for c in root.find_children("*", "BaseButton", true, false):
		var b := c as BaseButton
		if not b.is_visible_in_tree() or b.disabled and false:
			continue
		var r := b.get_global_rect()
		if r.size.y * px < MIN_TAP or r.size.x * px < MIN_TAP:
			bad += 1
			worst = "%s %s" % [b.text if b is Button else b.name, str(r.size * px)]
		var in_scroll := false
		var anc := b.get_parent()
		while anc != null:
			if anc is ScrollContainer:
				in_scroll = true
			anc = anc.get_parent()
		if not in_scroll and (r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > vp.x + 1.0 or r.end.y > vp.y + 1.0):
			bad += 1
			worst = "%s is off screen at %s" % [b.text if b is Button else b.name, str(r)]
	_check(bad == 0, "%s: every button is on screen and at least %d screen px (%.2f px per UI px; %s)" % [label, int(MIN_TAP), px, worst if worst != "" else "ok"])


func _run_phone() -> void:
	await _frames(8)
	rig = world.get("rig")
	hud = world.get("hud")
	var grid: WorldGrid = world.get("slice").grid
	await look(Vector3(40.0, grid.height_at(40, 36), 36.0), 150.0, 55.0, 55.0)
	await _frames(6)
	var card: PrologueHud
	for c in world.get_children():
		if c is PrologueHud:
			card = c
	_check(card != null, "the prologue card is up")
	card.call("_refresh")
	await shot("ph_01_prologue")
	_audit(card, "prologue card")
	_audit(hud, "HUD")
	card.continue_button.pressed.emit()
	await _frames(3)
	world.call("open_roads")
	await _frames(4)
	await shot("ph_02_roads")
	_audit(world.get("road"), "Roads panel")
	world.get("road").close()
	# Open the investigation screen on the authored case.
	SimHost.begin_prologue()
	SimHost.prologue = null
	var inv := SimHost.open_case("res://data/cases/case_00_cash_tin.json")
	await _frames(8)
	var screen: InvestigationScreen = world.get("case_screen")
	_check(screen != null and screen.visible, "the case screen opens")
	await shot("ph_03_case")
	_audit(screen, "case screen")
	screen.pick_person("r_agnes")
	await _frames(4)
	await shot("ph_04_interview")
	_check(inv != null, "case open")
	# Settings.
	var s := SettingsScreen.new()
	add_child(s)
	await _frames(6)
	await shot("ph_05_settings")
	_audit(s, "settings")
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks.size() - failures, "/", checks.size())
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
