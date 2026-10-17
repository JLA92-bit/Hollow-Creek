extends GutTest
## docs/HOUSE_BUILDING.md roofs: auto-roof for rectangles, L and T shapes and storeys; every shape
## covers its plan with no holes or cliffs; pitch limits; chimneys clear the roof.


func _house() -> HouseData:
	var h := HouseData.new()
	h.id = "roof_test"
	return h


func _ok(res: Dictionary) -> void:
	assert_true(res["ok"], str(res["msg"]))


func _piece(shape: String, rect: Rect2, axis: String = "x") -> Dictionary:
	return {"id": "p", "level": 0, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "shape": shape,
		"axis": axis, "pitch": 30.0, "overhang": 0.45, "material": "corrugated_iron", "joins": [], "high": "N"}


## Highest point of every tile centre of the rooms is under some roof piece.
func _covered(h: HouseData) -> bool:
	var pcs := Roofs.pieces(h)
	for l in h.levels():
		for t: Vector2i in Roofs.roof_tiles(h, l):
			var hit := false
			for p: Dictionary in pcs:
				if int(p["level"]) == l and not is_nan(Roofs.surface_y(p, 0.0, t.x + 0.5, t.y + 0.5)):
					hit = true
			if not hit:
				return false
	return true


func test_hip_heights() -> void:
	var p := _piece("hip", Rect2(0, 0, 10, 6))
	var tanp := tan(deg_to_rad(30.0))
	assert_almost_eq(Roofs.surface_y(p, 3.0, 5.0, 3.0), 3.0 + 3.0 * tanp, 0.001, "ridge over the middle")
	assert_almost_eq(Roofs.surface_y(p, 3.0, 5.0, 0.0), 3.0, 0.001, "eave height at the wall line")
	assert_almost_eq(Roofs.surface_y(p, 3.0, 0.0, 3.0), 3.0, 0.001, "hip end meets the end wall at eave height")
	assert_true(is_nan(Roofs.surface_y(p, 3.0, -1.0, 3.0)), "nothing outside the overhang")
	assert_almost_eq(Roofs.ridge_y(p, 3.0), 3.0 + 3.0 * tanp, 0.001)


func test_gable_has_two_gables_and_finials() -> void:
	var g := Roofs.geometry(_piece("gable", Rect2(0, 0, 8, 5)), 3.0)
	assert_eq((g["gable"] as Array).size(), 2)
	assert_eq((g["finials"] as Array).size(), 2)
	assert_eq((g["roof"] as Array).size(), 2, "two slopes, no hip ends")
	assert_eq((g["barge"] as Array).size(), 4)
	var p := _piece("gable", Rect2(0, 0, 8, 5))
	assert_almost_eq(Roofs.surface_y(p, 3.0, 0.1, 2.5), Roofs.ridge_y(p, 3.0), 0.001, "the ridge runs to the gable")


func test_every_shape_is_watertight() -> void:
	for shape: String in Roofs.SHAPES:
		for axis: String in ["x", "z"]:
			var p := _piece(shape, Rect2(2, 1, 9, 6), axis)
			var ey := 3.0
			var tanp := tan(deg_to_rad(Roofs.clamp_pitch(shape, 30.0)))
			var step := 0.1
			var worst := 0.0
			var x := 2.0
			while x <= 11.0:
				var z := 1.0
				while z <= 7.0:
					var y0 := Roofs.surface_y(p, ey, x, z)
					assert_false(is_nan(y0), "%s %s covers %.1f, %.1f" % [shape, axis, x, z])
					var y1 := Roofs.surface_y(p, ey, x + step, z)
					var y2 := Roofs.surface_y(p, ey, x, z + step)
					if not is_nan(y1):
						worst = maxf(worst, absf(y1 - y0))
					if not is_nan(y2):
						worst = maxf(worst, absf(y2 - y0))
					z += 0.5
				x += 0.5
			if shape != "dutch":
				# The Dutch gable's little gable is the one upright step on purpose.
				assert_true(worst <= step * tanp * 1.01 + 0.0001, "%s %s has no steps in it (%.3f)" % [shape, axis, worst])
			var g := Roofs.geometry(p, ey)
			for f: Dictionary in g["roof"]:
				assert_gt((f["n"] as Vector3).y, 0.0, "%s roof faces up" % shape)
				var pts: Array = f["pts"]
				# Every polygon is flat and on the surface.
				for q: Vector3 in pts:
					var on := Roofs.surface_y(p, ey, q.x, q.z)
					if not is_nan(on):
						assert_true(q.y <= on + 0.01, "%s polygon point sits on or under the surface" % shape)
			for f2: Dictionary in g["gable"]:
				assert_almost_eq((f2["n"] as Vector3).y, 0.0, 0.0001, "%s gables are upright" % shape)


func test_half_hip_and_dutch_profiles() -> void:
	var hh := Roofs.geometry(_piece("half_hip", Rect2(0, 0, 10, 6)), 3.0)
	assert_eq((hh["gable"] as Array).size(), 2, "half-hip keeps a gable under each hip")
	assert_eq((hh["roof"] as Array).size(), 2 * 2 + 2, "two bands per slope plus two clipped hips")
	var du := Roofs.geometry(_piece("dutch", Rect2(0, 0, 10, 6)), 3.0)
	assert_eq((du["gable"] as Array).size(), 2, "Dutch gable has a small gable above each hip")
	assert_eq((du["finials"] as Array).size(), 2)


func test_pitch_limits() -> void:
	assert_eq(Roofs.clamp_pitch("hip", 70.0), Roofs.MAX_PITCH)
	assert_eq(Roofs.clamp_pitch("gable", 2.0), Roofs.MIN_PITCH)
	assert_eq(Roofs.clamp_pitch("flat", 30.0), Roofs.FLAT_PITCH)


func test_auto_roof_rectangle() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 10, 6)))
	_ok(BuildOps.auto_roof(h, {"shape": "hip"}))
	var pcs := Roofs.pieces(h)
	assert_eq(pcs.size(), 1)
	assert_eq(str(pcs[0]["axis"]), "x", "ridge runs the long way")
	assert_true(_covered(h))


func test_auto_roof_l_shape_joins_wing_into_main() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 10, 5)))
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 5, 4, 4)))
	_ok(BuildOps.auto_roof(h, {"shape": "gable"}))
	var pcs := Roofs.pieces(h)
	assert_eq(pcs.size(), 2)
	var wing: Dictionary = pcs[1]
	assert_eq(str(wing["axis"]), "z", "the wing's ridge runs out from the main roof")
	assert_true((wing["joins"] as Array).has("N"))
	assert_lt(float(wing["rect"][1]), 5.0, "the wing reaches into the main roof")
	assert_true(_covered(h))
	# The wing's ridge is no higher than the main ridge, so it meets the main slope in valleys.
	var ey := Roofs.eave_y(h, pcs[0])
	assert_true(Roofs.ridge_y(wing, ey) <= Roofs.ridge_y(pcs[0], ey) + 0.001)


func test_auto_roof_t_shape() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 12, 5)))
	_ok(BuildOps.add_room(h, 0, Rect2i(4, 5, 4, 5)))
	_ok(BuildOps.auto_roof(h, {"shape": "hip"}))
	assert_eq(Roofs.pieces(h).size(), 2)
	assert_true(_covered(h))


func test_two_storeys_roof_both_levels() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 8, 8)))
	_ok(BuildOps.add_storey(h, 1))
	_ok(BuildOps.add_room(h, 1, Rect2i(0, 0, 8, 5)))
	_ok(BuildOps.auto_roof(h, {"shape": "hip"}))
	var pcs := Roofs.pieces(h)
	var lv := {}
	for p: Dictionary in pcs:
		lv[int(p["level"])] = p
	assert_true(lv.has(0) and lv.has(1), "the ground floor beyond the upstairs gets its own roof")
	var low: Dictionary = lv[0]
	assert_eq(str(low["shape"]), "skillion", "a strip against the upstairs wall leans on it")
	assert_eq(str(low["high"]), "N")
	assert_true((low["joins"] as Array).has("N"))
	assert_true(_covered(h))
	# The lean-to stays below the upstairs eaves.
	assert_true(Roofs.ridge_y(low, Roofs.eave_y(h, low)) < Roofs.eave_y(h, lv[1]))


func test_roof_follows_plan_until_edited() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 6, 4)))
	_ok(BuildOps.auto_roof(h, {"shape": "hip"}))
	_ok(BuildOps.add_room(h, 0, Rect2i(6, 0, 4, 4)))
	assert_eq(Roofs.rect_of(Roofs.pieces(h)[0]).size.x, 10.0, "the auto-roof grows with the plan")
	var id := str(Roofs.pieces(h)[0]["id"])
	_ok(BuildOps.update_roof_piece(h, id, {"pitch": 35.0, "material": "roof_terracotta"}))
	assert_false(bool(h.roof["follow"]))
	var p: Dictionary = Roofs.pieces(h)[0]
	assert_eq(float(p["pitch"]), 35.0)
	assert_eq(str(p["material"]), "roof_terracotta")
	_ok(BuildOps.add_room(h, 0, Rect2i(10, 0, 2, 4)))
	assert_eq(Roofs.rect_of(Roofs.pieces(h)[0]).size.x, 10.0, "hand-edited roofs stay put")


func test_manual_pieces_and_round_trip() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 6, 4)))
	var res := BuildOps.add_roof_piece(h, 0, Rect2(0, 0, 6, 4), {"shape": "dutch", "pitch": 32.0})
	_ok(res)
	assert_gt(int(res["cost"]), 0, "roofing costs money")
	_ok(BuildOps.add_roof_piece(h, 0, Rect2(6, 0, 2, 4), {"shape": "skillion", "high": "W"}))
	var copy := HouseData.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	assert_eq(Roofs.pieces(copy).size(), 2)
	assert_eq(str(Roofs.pieces(copy)[0]["shape"]), "dutch")
	_ok(BuildOps.remove_roof_piece(h, str(res["id"])))
	assert_eq(Roofs.pieces(h).size(), 1)


func test_legacy_roof_still_draws() -> void:
	var h := HouseData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/agnes_cottage.json")))
	var pcs := Roofs.pieces(h)
	assert_eq(pcs.size(), 1, "Agnes's cottage keeps its one hip roof")
	assert_eq(str(pcs[0]["shape"]), "hip")


func test_chimney_clears_the_roof() -> void:
	var h := _house()
	_ok(BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 4)))
	_ok(BuildOps.add_room(h, 0, Rect2i(4, 0, 4, 4)))
	_ok(BuildOps.auto_roof(h, {"shape": "hip"}))
	_ok(BuildOps.add_chimney(h, 0, HouseData.vkey(4, 1)))
	assert_false(BuildOps.add_chimney(h, 0, HouseData.vkey(4, 1))["ok"], "one chimney per spot")
	_ok(BuildOps.add_chimney(h, 0, HouseData.hkey(1, 0)))
	assert_true(bool(h.chimneys[1].get("outside", false)), "a chimney on an outside wall stands outside")
	assert_lt(float(h.chimneys[1]["z"]), 0.0)
	assert_eq(BuildOps.chimney_at(h, 4.0, 1.5), 0)
	var c: Dictionary = h.chimneys[0]
	var roof_y := Roofs.height_over(h, Rect2(float(c["x"]), float(c["z"]), float(c["w"]), float(c["d"])))
	assert_false(is_nan(roof_y))
	var builder := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	builder.build_roof(kit)
	assert_true(kit.has_geometry())
