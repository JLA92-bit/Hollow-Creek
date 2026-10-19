extends SceneTree
## Renders one resident's interview portrait at six moods, for checking the faces by eye.
## xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 --resolution 1280x420 -s tools/previews/portrait_preview.gd -- out.png [resident_id]

var _frames := 0
var _out := "user://portrait_preview.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var rid := args[1] if args.size() > 1 else "r_len"
	var data: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/residents.json")) as Dictionary)["residents"]
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(root)
	var moods := [["calm", 100.0, 0.0, false], ["worried", 40.0, 10.0, false], ["stern", 95.0, 85.0, false], ["afraid", 30.0, 80.0, false], ["breaking", 10.0, 40.0, false], ["confessed", 0.0, 0.0, true]]
	for i in moods.size():
		var pv := PortraitView.new()
		pv.custom_minimum_size = Vector2(205, 400)
		pv.position = Vector2(i * 210 + 5, 10)
		pv.size = Vector2(205, 400)
		root.add_child(pv)
		pv.show_resident(rid, data[rid])
		pv.set_mood(float(moods[i][1]), float(moods[i][2]), bool(moods[i][3]))
		var l := Label.new()
		l.text = str(moods[i][0])
		l.position = Vector2(i * 210 + 12, 12)
		root.add_child(l)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 90:
		get_root().get_viewport().get_texture().get_image().save_png(_out)
		print("wrote ", _out)
		quit()
	return false
