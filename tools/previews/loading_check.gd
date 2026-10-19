extends Node
## Opens the world behind the loading screen and prints each step the bar reports, then whether the
## cover came down. xvfb-run -a tools/bin/godot --path . --resolution 1280x720 res://tools/previews/loading_check.tscn -- shot.png

func _ready() -> void:
	GameState.reset()
	SimHost.reset()
	GameState.mode = GameState.MODE_STORY
	SimHost.begin_prologue()
	Clock.set_speed(0)
	LoadingScreen.show_loading("Starting a new game")
	await get_tree().process_frame
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		get_viewport().get_texture().get_image().save_png(args[0])
	var t0 := Time.get_ticks_msec()
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	var steps: Array = []
	var bar := LoadingScreen.get("_bar") as ProgressBar
	var msg := LoadingScreen.get("_message") as Label
	var last := ""
	add_child(world)
	var frames := 0
	while LoadingScreen.is_showing() and frames < 2000:
		if msg.text != last:
			last = msg.text
			steps.append("%d ms  %.0f%%  %s" % [Time.get_ticks_msec() - t0, bar.value * 100.0, last])
		await get_tree().process_frame
		frames += 1
	for s in steps:
		print("HC_LOAD ", s)
	print("HC_LOAD cover hidden=", not LoadingScreen.is_showing(), " after ", Time.get_ticks_msec() - t0, " ms, ", frames, " frames")
	get_tree().quit(0 if not LoadingScreen.is_showing() else 1)
