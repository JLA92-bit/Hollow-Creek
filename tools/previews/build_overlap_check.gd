extends Node
## Enters build mode in a new prologue game and prints whether the prologue card overlaps any build
## panel, then saves a screenshot. Run under xvfb:
## xvfb-run -a -s "-screen 0 1920x1080x24" tools/bin/godot --path . --resolution 1280x720 res://tools/previews/build_overlap_check.tscn -- out.png

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.reset()
	SimHost.reset()
	GameState.mode = GameState.MODE_STORY
	SimHost.begin_prologue()
	Clock.set_speed(0)
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	for i in 20:
		await get_tree().process_frame
	world.call("enter_build_mode")
	for i in 150:
		await get_tree().process_frame
	var card: Control = null
	for hud in find_children("*", "PrologueHud", true, false):
		card = (hud as PrologueHud).get("_card") as Control
	var bp := get_tree().get_first_node_in_group(&"build_panel") as BuildPanel
	var rects := {}
	if bp != null:
		for n in ["_palette_panel", "_options_panel", "_house_panel", "_actions_panel", "_status_panel", "_stack_panel"]:
			var c := bp.get(n) as Control
			if c != null and c.is_visible_in_tree():
				rects[n] = c.get_global_rect()
	var bad := 0
	if card != null and card.visible:
		var cr := card.get_global_rect()
		print("HC_CHECK card ", cr)
		for k in rects:
			var hit: bool = cr.intersects(rects[k])
			print("HC_CHECK ", k, " ", rects[k], " overlap=", hit)
			if hit:
				bad += 1
	else:
		print("HC_CHECK no card")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		get_viewport().get_texture().get_image().save_png(args[0])
	print("HC_CHECK overlaps=", bad, " viewport=", get_viewport().get_visible_rect().size)
	get_tree().quit(1 if bad > 0 else 0)
