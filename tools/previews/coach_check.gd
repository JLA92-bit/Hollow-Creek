extends Node
## The first prologue steps as a new player sees them: the road step (flashing Roads button, camera over
## the yellow dots), the Roads panel, and the wrong-mode warning from Build mode. Saves three screenshots.
## xvfb-run -a tools/bin/godot --path . --resolution 1280x720 res://tools/previews/coach_check.tscn -- /tmp/coach

func _ready() -> void:
	GameState.reset()
	SimHost.reset()
	GameState.mode = GameState.MODE_STORY
	SimHost.begin_prologue()
	Clock.set_speed(0)
	Settings.set_value("quality", "low")
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(world)
	await _frames(20)
	SimHost.prologue.acknowledge()
	SimHost.refresh_story()
	await _frames(60)
	_shot("1_road_step")
	world.call("open_roads")
	await _frames(40)
	_shot("2_roads_panel")
	(world.get("road") as RoadMode).close()
	world.call("enter_build_mode")
	await _frames(60)
	_shot("3_wrong_mode")
	print("HC_COACH step=", SimHost.prologue.current_id())
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	var base := args[0] if args.size() > 0 else "/tmp/coach"
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [base, name])
