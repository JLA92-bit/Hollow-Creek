extends SceneTree
## Times each world build step headlessly. Run: tools/bin/godot --headless --path . -s tools/debug_build_steps.gd


func _t(label: String, start: int) -> int:
	print("%-14s %6d ms" % [label, Time.get_ticks_msec() - start])
	return Time.get_ticks_msec()


func _initialize() -> void:
	var t := Time.get_ticks_msec()
	var slice := MapSlice.load_default()
	t = _t("map slice", t)
	var terrain := TerrainView.new()
	root.add_child(terrain)
	terrain.setup(slice.grid)
	t = _t("terrain", t)
	var creek := CreekView.new()
	root.add_child(creek)
	creek.setup(slice)
	t = _t("creek", t)
	var veg := Vegetation.new()
	root.add_child(veg)
	veg.setup(slice)
	t = _t("vegetation", t)
	var lm := Landmarks.new()
	root.add_child(lm)
	lm.setup(slice)
	t = _t("landmarks", t)
	var h := HouseData.load_file("res://data/houses/agnes_cottage.json")
	var hv := HouseView.new()
	root.add_child(hv)
	hv.setup(h, func(_x: float, _z: float) -> float: return 0.0)
	t = _t("house", t)
	hv.set_view(HouseView.WALLS_CUTAWAY, Vector3(0.3, 0, 0.9))
	t = _t("cutaway", t)
	quit()
