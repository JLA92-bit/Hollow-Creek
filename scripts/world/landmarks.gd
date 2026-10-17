class_name Landmarks
extends Node3D
## Fixed landmarks the player doesn't build: the railway siding, the timber mill, and the store
## plot's survey pegs. Simple procedural structures with real materials.

var slice: MapSlice
var _kit_mats: Dictionary = {}


func setup(p_slice: MapSlice) -> void:
	slice = p_slice
	for l: Dictionary in slice.data["landmarks"]:
		match str(l["kind"]):
			"siding":
				_siding(l)
			"mill":
				_mill(l)
			"plot":
				_plot(l)


func _m(id: String, tint: Variant = null) -> String:
	var key := id if tint == null else "%s#%s" % [id, (tint as Color).to_html(false)]
	if not _kit_mats.has(key):
		_kit_mats[key] = MaterialLibrary.get_material(id, tint)
	return key


func _commit(kit: MeshKit, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = kit.commit(_kit_mats)
	add_child(mi)
	return mi


func _h(x: float, z: float) -> float:
	return slice.grid.height_at(x, z)


func _siding(l: Dictionary) -> void:
	var r: Array = l["rect"]
	var kit := MeshKit.new()
	var rail_x := float(r[0]) + 2.0
	var z0 := -2.0
	var z1 := float(slice.grid.height) + 2.0
	var sleeper := _m("stump", Color("#6E655A"))
	var steel := _m("rail_steel")
	var z := z0
	while z < z1:
		var y := _h(rail_x, clampf(z, 0, slice.grid.height))
		kit.box(sleeper, Transform3D(Basis(), Vector3(rail_x, y + 0.05, z)), Vector3(2.4, 0.12, 0.22))
		z += 0.65
	for side: float in [-0.72, 0.72]:
		var prev := Vector3(rail_x + side, _h(rail_x, 0) + 0.17, z0)
		var zz := z0 + 4.0
		while zz <= z1 + 0.01:
			var p := Vector3(rail_x + side, _h(rail_x, clampf(zz, 0, slice.grid.height)) + 0.17, zz)
			kit.beam(steel, prev, p, 0.07, 0.12)
			prev = p
			zz += 4.0
	# Timber platform with a goods shed.
	var px0 := rail_x + 1.5
	var px1 := float(r[0]) + float(r[2])
	var pz0 := float(r[1]) + 2.0
	var pz1 := float(r[1]) + float(r[3]) - 2.0
	var base := _h((px0 + px1) * 0.5, (pz0 + pz1) * 0.5)
	var top := base + 0.95
	kit.box(_m("decking"), Transform3D(Basis(), Vector3((px0 + px1) * 0.5, top - 0.03, (pz0 + pz1) * 0.5)), Vector3(px1 - px0, 0.06, pz1 - pz0))
	kit.box(_m("stump", Color("#7B7166")), Transform3D(Basis(), Vector3(px0 + 0.05, base + 0.45, (pz0 + pz1) * 0.5)), Vector3(0.1, 1.0, pz1 - pz0))
	var zz2 := pz0 + 0.3
	while zz2 < pz1:
		kit.box(_m("stump"), Transform3D(Basis(), Vector3(px1 - 0.3, base + 0.45, zz2)), Vector3(0.15, 1.0, 0.15))
		zz2 += 1.8
	var shed_z0 := pz0 + 1.0
	var shed_z1 := shed_z0 + 4.0
	var sx0 := px0 + 0.8
	var sx1 := px1 - 0.4
	var iron := _m("corrugated_iron_old")
	var wall_h := 2.7
	for pair: Array in [[Vector3(sx0, top, shed_z0), Vector3(sx1, top, shed_z0), Vector3(0, 0, -1)],
			[Vector3(sx1, top, shed_z1), Vector3(sx0, top, shed_z1), Vector3(0, 0, 1)],
			[Vector3(sx1, top, shed_z0), Vector3(sx1, top, shed_z1), Vector3(1, 0, 0)]]:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		_wall_quad(kit, iron, a, b, wall_h, pair[2])
	# Skillion roof sloping towards the track.
	var ra := Vector3(sx1 + 0.3, top + wall_h + 0.35, shed_z0 - 0.3)
	var rb := Vector3(sx1 + 0.3, top + wall_h + 0.35, shed_z1 + 0.3)
	var rc := Vector3(sx0 - 0.6, top + wall_h - 0.1, shed_z1 + 0.3)
	var rd := Vector3(sx0 - 0.6, top + wall_h - 0.1, shed_z0 - 0.3)
	_roof_quad(kit, iron, ra, rb, rc, rd)
	for zp: float in [shed_z0, shed_z1]:
		kit.box(_m("stump"), Transform3D(Basis(), Vector3(sx0 - 0.5, top + (wall_h - 0.1) * 0.5, zp)), Vector3(0.12, wall_h - 0.1, 0.12))
	# A few crates.
	for i in 3:
		kit.box(_m("decking", Color("#A88A66")), Transform3D(Basis(Vector3.UP, 0.2 * i), Vector3(px0 + 0.8 + 0.7 * i, top + 0.3, pz1 - 1.2)), Vector3(0.6, 0.6, 0.6))
	_commit(kit, "Siding")
	# Station sign.
	var board := MeshKit.new()
	var sign_z := pz1 - 0.6
	board.box(_m("trim_paint", Color("#F7F3E8")), Transform3D(Basis(), Vector3(px0 + 0.4, top + 1.6, sign_z)), Vector3(0.06, 0.45, 2.4))
	for dz: float in [-1.0, 1.0]:
		board.box(_m("trim_paint", Color("#2F4A35")), Transform3D(Basis(), Vector3(px0 + 0.4, top + 0.7, sign_z + dz)), Vector3(0.08, 1.6, 0.08))
	_commit(board, "SidingSign")
	var label := Label3D.new()
	label.text = "HOLLOW CREEK"
	label.font = load("res://assets/fonts/Fraunces.ttf") as Font
	label.font_size = 48
	label.pixel_size = 0.0045
	label.modulate = Color("#2F4A35")
	label.outline_size = 0
	label.shaded = true
	label.double_sided = true
	label.position = Vector3(px0 + 0.36, top + 1.6, sign_z)
	label.rotation = Vector3(0, -PI * 0.5, 0)
	add_child(label)


func _mill(l: Dictionary) -> void:
	var r: Array = l["rect"]
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := x0 + float(r[2])
	var z1 := z0 + float(r[3])
	var y := _h((x0 + x1) * 0.5, (z0 + z1) * 0.5) - 0.1
	var kit := MeshKit.new()
	var iron := _m("corrugated_iron_old")
	var wall_h := 5.0
	# Three closed sides, open to the yard (south) between posts.
	_wall_quad(kit, iron, Vector3(x0, y, z0), Vector3(x1, y, z0), wall_h, Vector3(0, 0, -1))
	_wall_quad(kit, iron, Vector3(x0, y, z1), Vector3(x0, y, z0), wall_h, Vector3(-1, 0, 0))
	_wall_quad(kit, iron, Vector3(x1, y, z0), Vector3(x1, y, z1), wall_h, Vector3(1, 0, 0))
	_wall_quad(kit, iron, Vector3(x1, y + 3.4, z1), Vector3(x0, y + 3.4, z1), wall_h - 3.4, Vector3(0, 0, 1))
	var post := _m("stump", Color("#857A6C"))
	var px := x0
	while px <= x1 + 0.01:
		kit.box(post, Transform3D(Basis(), Vector3(px, y + 1.7, z1)), Vector3(0.22, 3.4, 0.22))
		px += (x1 - x0) / 5.0
	# Gable roof along x.
	var rise := (z1 - z0) * 0.5 * tan(deg_to_rad(18.0))
	var eave := y + wall_h
	var o := 0.5
	var ridge := Vector2((z0 + z1) * 0.5, eave + rise)
	_roof_quad(kit, iron, Vector3(x0 - o, eave - 0.16, z0 - o), Vector3(x1 + o, eave - 0.16, z0 - o), Vector3(x1 + o, ridge.y, ridge.x), Vector3(x0 - o, ridge.y, ridge.x))
	_roof_quad(kit, iron, Vector3(x1 + o, eave - 0.16, z1 + o), Vector3(x0 - o, eave - 0.16, z1 + o), Vector3(x0 - o, ridge.y, ridge.x), Vector3(x1 + o, ridge.y, ridge.x))
	for gx: float in [x0, x1]:
		var n := Vector3(-1, 0, 0) if gx == x0 else Vector3(1, 0, 0)
		var a := Vector3(gx, eave, z0)
		var b := Vector3(gx, eave, z1)
		var c := Vector3(gx, ridge.y, ridge.x)
		if (b - a).cross(c - a).dot(n) < 0:
			kit.tri(iron, a, c, b, Vector2(a.z, -a.y), Vector2(c.z, -c.y), Vector2(b.z, -b.y))
		else:
			kit.tri(iron, a, b, c, Vector2(a.z, -a.y), Vector2(b.z, -b.y), Vector2(c.z, -c.y))
	# Boiler chimney stack.
	kit.cylinder(_m("cast_iron", Color("#5A4636")), Vector3(x1 - 2.0, y, z0 + 2.0), 13.0, 0.45, 0.38, 12)
	# Sawn timber stacks and log piles in the yard.
	var yard_z := z1 + 2.5
	var rng := SimRng.new(77)
	for i in 4:
		var cx := x0 + 3.0 + i * 4.5
		var hs := rng.randf_range(0.8, 1.4)
		kit.box(_m("decking", Color("#E2C9A2")), Transform3D(Basis(), Vector3(cx, _h(cx, yard_z) + hs * 0.5, yard_z)), Vector3(3.2, hs, 1.1))
	var bark := _m("bark_gum", Color("#8C7A66"))
	for row in 3:
		for j in 6 - row:
			var lz := yard_z + 3.5
			var lx := x0 + 6.0 + j * 0.62 + row * 0.31
			var ly := _h(lx, lz) + 0.3 + row * 0.52
			kit.frustum(bark, Vector3(x0 + 2.0, ly, lz + j * 0.0) + Vector3(0, 0, 0) + Vector3(lx - x0 - 2.0, 0, 0) - Vector3(0, 0, 2.6), Vector3(lx, ly, lz + 2.6), 0.3, 0.28, 10, 1.0, Color.WHITE, true)
	_commit(kit, "Mill")


func _plot(l: Dictionary) -> void:
	# Survey pegs and string line marking the store plot.
	var r: Array = l["rect"]
	var kit := MeshKit.new()
	var corners := [Vector2(float(r[0]), float(r[1])), Vector2(float(r[0]) + float(r[2]), float(r[1])),
		Vector2(float(r[0]) + float(r[2]), float(r[1]) + float(r[3])), Vector2(float(r[0]), float(r[1]) + float(r[3]))]
	var peg := _m("stump", Color("#B39B7C"))
	var string := _m("trim_paint", Color("#F7F3E8"))
	for i in 4:
		var c: Vector2 = corners[i]
		var n: Vector2 = corners[(i + 1) % 4]
		kit.box(peg, Transform3D(Basis(), Vector3(c.x, _h(c.x, c.y) + 0.3, c.y)), Vector3(0.05, 0.6, 0.05))
		kit.beam(string, Vector3(c.x, _h(c.x, c.y) + 0.5, c.y), Vector3(n.x, _h(n.x, n.y) + 0.5, n.y), 0.008)
	_commit(kit, "StorePlot")


func _wall_quad(kit: MeshKit, mat: String, a: Vector3, b: Vector3, h: float, n: Vector3) -> void:
	var c := b + Vector3(0, h, 0)
	var d := a + Vector3(0, h, 0)
	if (b - a).cross(d - a).dot(n) < 0.0:
		kit.quad_auto(mat, b, a, d, c)
	else:
		kit.quad_auto(mat, a, b, c, d)
	# Inside face too, so the open front shows a lined interior.
	if (b - a).cross(d - a).dot(-n) < 0.0:
		kit.quad_auto(mat, b, a, d, c)
	else:
		kit.quad_auto(mat, a, b, c, d)


func _roof_quad(kit: MeshKit, mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a, b along the eave; corrugations run down the slope. Two-sided.
	var ua := Vector2(0, 0)
	var ub := Vector2(a.distance_to(b), 0)
	var uc := Vector2(a.distance_to(b), b.distance_to(c))
	var ud := Vector2(0, a.distance_to(d))
	if (b - a).cross(d - a).y > 0.0:
		kit.quad(mat, a, b, c, d, ua, ub, uc, ud)
		kit.quad(mat, b, a, d, c, ub, ua, ud, uc)
	else:
		kit.quad(mat, b, a, d, c, ub, ua, ud, uc)
		kit.quad(mat, a, b, c, d, ua, ub, uc, ud)
