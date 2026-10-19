extends Node
## Shows the turn-your-phone cover on a portrait window and saves a screenshot.
## HC_FORCE_GATE=1 xvfb-run -a tools/bin/godot --path . --resolution 390x844 res://tools/previews/gate_check.tscn -- out.png

func _ready() -> void:
	for i in 30:
		await get_tree().process_frame
	var gate := get_tree().root.get_node("OrientationGate")
	print("HC_CHECK gate visible=", gate._cover.visible, " cover=", gate._cover.get_global_rect(), " viewport=", get_viewport().get_visible_rect().size)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
