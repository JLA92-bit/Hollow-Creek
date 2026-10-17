class_name GardenBuilder
extends RefCounted
## Meshes for a house's garden: plants as leaf cards, procedural outbuildings and outdoor items, and
## fences with gates. Uses the house's mesh builder for materials and its ground height function, so
## everything sits on the ground in house-local space.

const PLANT_DIR := "res://assets/models/garden/%s.png"

static var _leaf_mats: Dictionary = {}

var b: HouseMeshBuilder


func _init(p_builder: HouseMeshBuilder) -> void:
	b = p_builder


func build(kit: MeshKit) -> void:
	var h := b.house
	for it: Dictionary in h.garden:
		var d := GardenOps.item_def(str(it["kind"]))
		if d.is_empty():
			continue
		var at := Vector3(float(it["x"]), _g(float(it["x"]), float(it["z"])), float(it["z"]))
		var yaw := deg_to_rad(float(it.get("rot", 0.0)))
		match str(d["category"]):
			"plants":
				_plant(kit, str(it["kind"]), d, at, yaw, hash(str(it.get("id", ""))))
			"outbuildings":
				_outbuilding(kit, str(it["kind"]), d, at, yaw)
			"items":
				_item(kit, str(it["kind"]), at, yaw)
	_fences(kit)


func _g(x: float, z: float) -> float:
	return float(b.ground_fn.call(x, z))


## A transform for a local offset (x right, z forward) from an item's centre, turned by yaw.
func _at(c: Vector3, yaw: float, off: Vector3) -> Vector3:
	return c + Basis(Vector3.UP, -yaw) * off


func _box(kit: MeshKit, mat: String, c: Vector3, yaw: float, off: Vector3, size: Vector3) -> void:
	kit.box(mat, Transform3D(Basis(Vector3.UP, -yaw), _at(c, yaw, off)), size)


func _leaf(tex: String) -> String:
	var key := "garden_leaf:" + tex
	if not b.mats.has(key):
		if not _leaf_mats.has(tex):
			var mat := ShaderMaterial.new()
			mat.shader = load("res://shaders/foliage.gdshader") as Shader
			mat.set_shader_parameter("leaf_tex", load(PLANT_DIR % tex))
			mat.set_shader_parameter("sway_scale", 0.02)
			mat.set_shader_parameter("translucency", 0.25)
			mat.set_shader_parameter("alpha_cut", 0.5)
			_leaf_mats[tex] = mat
		b.mats[key] = _leaf_mats[tex]
	return key


## Crossed upright cards, normals leaning out from the middle so the clump shades like a bush.
func _cards(kit: MeshKit, mat: String, c: Vector3, w: float, ht: float, n: int, seed_value: int) -> void:
	var rng := SimRng.new(seed_value & 0x7fffffff)
	for i in n:
		var yaw := PI * i / n + rng.randf_range(-0.2, 0.2)
		var right := Vector3(cos(yaw), 0, sin(yaw)) * w * 0.5
		var mid := c + Vector3(0, ht * 0.5, 0)
		var up := Vector3(0, ht * 0.5, 0)
		var nn := Vector3(0, 0.6, 0) + Vector3(-sin(yaw), 0, cos(yaw)) * 0.4
		kit.quad_n(mat, mid - right - up, mid + right - up, mid + right + up, mid - right + up,
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), nn.normalized())


func _plant(kit: MeshKit, kind: String, d: Dictionary, c: Vector3, yaw: float, seed_value: int) -> void:
	var sz: Array = d["size"]
	var ht := float(d.get("height", 1.0))
	var leaf := _leaf(str(d["tex"]))
	match kind:
		"box_hedge":
			var w := float(sz[0])
			var dp := float(sz[1])
			_box(kit, b.m("trim_paint", Color("#2E4426")), c, yaw, Vector3(0, ht * 0.45, 0), Vector3(w - 0.1, ht * 0.9, dp - 0.1))
			var corners := [Vector3(-w, 0, -dp), Vector3(w, 0, -dp), Vector3(w, 0, dp), Vector3(-w, 0, dp)]
			for i in 4:
				var p0 := _at(c, yaw, (corners[i] as Vector3) * 0.5)
				var p1 := _at(c, yaw, (corners[(i + 1) % 4] as Vector3) * 0.5)
				var n := (Basis(Vector3.UP, -yaw) * ((corners[i] + corners[(i + 1) % 4]) as Vector3)).normalized()
				kit.quad_n(leaf, p0 + n * 0.03, p1 + n * 0.03, p1 + n * 0.03 + Vector3(0, ht, 0), p0 + n * 0.03 + Vector3(0, ht, 0),
					Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), n)
			var t0 := _at(c, yaw, Vector3(-w, 0, -dp) * 0.5)
			var t1 := _at(c, yaw, Vector3(w, 0, -dp) * 0.5)
			var t2 := _at(c, yaw, Vector3(w, 0, dp) * 0.5)
			var t3 := _at(c, yaw, Vector3(-w, 0, dp) * 0.5)
			var up := Vector3(0, ht + 0.02, 0)
			kit.quad_n(leaf, t3 + up, t2 + up, t1 + up, t0 + up, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector3.UP)
		"vegie_bed":
			var w2 := float(sz[0])
			var d2 := float(sz[1])
			var edge := b.m("decking")
			for side: float in [-1.0, 1.0]:
				_box(kit, edge, c, yaw, Vector3(0, 0.1, side * d2 * 0.5), Vector3(w2, 0.2, 0.05))
				_box(kit, edge, c, yaw, Vector3(side * w2 * 0.5, 0.1, 0), Vector3(0.05, 0.2, d2))
			var soil := b.m("trim_paint", Color("#4A3628"))
			_box(kit, soil, c, yaw, Vector3(0, 0.08, 0), Vector3(w2 - 0.06, 0.16, d2 - 0.06))
			for row in 3:
				var z := (row - 1) * d2 * 0.3
				var a := _at(c, yaw, Vector3(-w2 * 0.45, 0.12, z))
				var bb := _at(c, yaw, Vector3(w2 * 0.45, 0.12, z))
				kit.quad_n(leaf, a, bb, bb + Vector3(0, ht, 0), a + Vector3(0, ht, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector3(0, 0.7, -0.7).normalized())
				kit.quad_n(leaf, bb, a, a + Vector3(0, ht, 0), bb + Vector3(0, ht, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector3(0, 0.7, 0.7).normalized())
		_:
			if bool(d.get("tree", false)):
				var bark := b.m("bark_gum", Color("#8A7A66"))
				var crown_h := ht * 0.72
				kit.cylinder(bark, c, ht - crown_h * 0.6, 0.07, 0.05, 7)
				_cards(kit, leaf, c + Vector3(0, ht - crown_h, 0), float(sz[0]), crown_h, 4, seed_value)
				var top := c + Vector3(0, ht - crown_h * 0.5, 0)
				var flat := float(sz[0]) * 0.45
				kit.quad_n(leaf, top + Vector3(-flat, 0, -flat), top + Vector3(flat, 0, -flat), top + Vector3(flat, 0, flat), top + Vector3(-flat, 0, flat),
					Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector3.UP)
			else:
				_cards(kit, leaf, c, float(sz[0]) * 1.1, ht, 3, seed_value)


# --- Outbuildings --------------------------------------------------------------------------------

func _outbuilding(kit: MeshKit, kind: String, d: Dictionary, c: Vector3, yaw: float) -> void:
	var sz: Array = d["size"]
	var w := float(sz[0])
	var dp := float(sz[1])
	var wb := b.m("weatherboard", b.cladding_tint)
	var iron := b.m("corrugated_iron")
	var trim := b.m("trim_paint", b.trim_ext)
	var timber := b.m("decking")
	var brick := b.m("brick_red")
	match kind:
		"dunny":
			_shed(kit, c, yaw, w, dp, 2.0, 2.2, wb, iron, trim, true)
			_box(kit, b.m("trim_paint", Color("#1C1C1C")), c, yaw, Vector3(0, 1.75, -dp * 0.5 - 0.05), Vector3(0.16, 0.08, 0.01))
		"woodshed":
			var back := 2.0
			var front := 2.3
			for sx: float in [-1.0, 1.0]:
				_box(kit, iron, c, yaw, Vector3(sx * w * 0.5, back * 0.5, 0), Vector3(0.03, back, dp))
				_box(kit, timber, c, yaw, Vector3(sx * (w * 0.5 - 0.05), front * 0.5, -dp * 0.5 + 0.05), Vector3(0.1, front, 0.1))
			_box(kit, iron, c, yaw, Vector3(0, back * 0.5, dp * 0.5), Vector3(w, back, 0.03))
			_mono_roof(kit, c, yaw, w + 0.3, dp + 0.4, back, front, iron)
			for row in 4:
				for i in 8:
					var lc := _at(c, yaw, Vector3(-w * 0.4 + i * w * 0.8 / 7.0, 0.12 + row * 0.2, dp * 0.15))
					kit.frustum(b.m("bark_gum", Color("#9A8068")), lc + Basis(Vector3.UP, -yaw) * Vector3(0, 0, -0.4), lc + Basis(Vector3.UP, -yaw) * Vector3(0, 0, 0.4), 0.1, 0.1, 6, 1.0, Color.WHITE, true)
		"wash_house":
			_shed(kit, c, yaw, w, dp, 2.4, 2.4, wb, iron, trim, true)
			_box(kit, brick, c, yaw, Vector3(w * 0.3, 1.9, dp * 0.3), Vector3(0.4, 1.8, 0.4))
			_box(kit, brick, c, yaw, Vector3(w * 0.3, 2.9, dp * 0.3), Vector3(0.4, 0.8, 0.4))
		"chook_pen":
			var wire := b._lace_mat("lattice", "#9AA0A2")
			var posts := [Vector3(-w, 0, -dp), Vector3(w, 0, -dp), Vector3(w, 0, dp), Vector3(-w, 0, dp)]
			for i in 4:
				var p0 := _at(c, yaw, (posts[i] as Vector3) * 0.5)
				var p1 := _at(c, yaw, (posts[(i + 1) % 4] as Vector3) * 0.5)
				kit.box(timber, Transform3D(Basis(), p0 + Vector3(0, 0.8, 0)), Vector3(0.08, 1.6, 0.08))
				var l := p0.distance_to(p1)
				b.face_uv(kit, wire, p0, p1, p1 + Vector3(0, 1.5, 0), p0 + Vector3(0, 1.5, 0), (p1 - p0).cross(Vector3.UP).normalized(),
					Vector2(0, 1.5 / 0.15), Vector2(l / 0.15, 1.5 / 0.15), Vector2(l / 0.15, 0), Vector2(0, 0))
			_shed(kit, _at(c, yaw, Vector3(w * 0.25, 0, dp * 0.2)), yaw, 1.2, 1.0, 1.2, 1.4, wb, iron, trim, false)
		"water_tank":
			for sx: float in [-1.0, 1.0]:
				for sz2: float in [-1.0, 1.0]:
					_box(kit, timber, c, yaw, Vector3(sx * 0.7, 0.5, sz2 * 0.7), Vector3(0.12, 1.0, 0.12))
			_box(kit, timber, c, yaw, Vector3(0, 1.02, 0), Vector3(w * 0.95, 0.08, dp * 0.95))
			kit.cylinder(iron, c + Vector3(0, 1.06, 0), 1.8, 0.9, 0.9, 20, 1.0, Color.WHITE, false)
			kit.frustum(iron, c + Vector3(0, 2.86, 0), c + Vector3(0, 3.1, 0), 0.92, 0.12, 20, 1.0, Color.WHITE, true)
			kit.cylinder(b.m("chrome", Color("#A9B0B2")), _at(c, yaw, Vector3(0.85, 1.2, 0)), 0.1, 0.03, 0.03, 6)


## A little weatherboard shed with a skillion roof and a ledged door on its front (-z) face.
func _shed(kit: MeshKit, c: Vector3, yaw: float, w: float, dp: float, back: float, front: float, wall: String, iron: String, trim: String, door: bool) -> void:
	_box(kit, b.m("stump"), c, yaw, Vector3(0, 0.05, 0), Vector3(w, 0.1, dp))
	for sx: float in [-1.0, 1.0]:
		_box(kit, wall, c, yaw, Vector3(sx * (w * 0.5 - 0.03), back * 0.5, 0), Vector3(0.06, back, dp))
	_box(kit, wall, c, yaw, Vector3(0, back * 0.5, dp * 0.5 - 0.03), Vector3(w, back, 0.06))
	_box(kit, wall, c, yaw, Vector3(0, back * 0.5, -dp * 0.5 + 0.03), Vector3(w, back, 0.06))
	if door:
		_box(kit, trim, c, yaw, Vector3(0, 0.95, -dp * 0.5 - 0.01), Vector3(minf(0.75, w - 0.3), 1.85, 0.04))
	_mono_roof(kit, c, yaw, w + 0.25, dp + 0.3, back, front, iron)


## A skillion: high at the front (-z), low at the back.
func _mono_roof(kit: MeshKit, c: Vector3, yaw: float, w: float, dp: float, back: float, front: float, iron: String) -> void:
	var a := _at(c, yaw, Vector3(-w * 0.5, front + 0.04, -dp * 0.5))
	var bb := _at(c, yaw, Vector3(w * 0.5, front + 0.04, -dp * 0.5))
	var cc := _at(c, yaw, Vector3(w * 0.5, back + 0.04, dp * 0.5))
	var d := _at(c, yaw, Vector3(-w * 0.5, back + 0.04, dp * 0.5))
	var n := (bb - a).cross(d - a).normalized()
	if n.y < 0.0:
		n = -n
	b.face_uv(kit, iron, a, bb, cc, d, n, Vector2(0, 0), Vector2(w, 0), Vector2(w, dp), Vector2(0, dp))
	b.face_uv(kit, iron, a - Vector3(0, 0.01, 0), bb - Vector3(0, 0.01, 0), cc - Vector3(0, 0.01, 0), d - Vector3(0, 0.01, 0), -n, Vector2(0, 0), Vector2(w, 0), Vector2(w, dp), Vector2(0, dp))


# --- Outdoor items -------------------------------------------------------------------------------

func _item(kit: MeshKit, kind: String, c: Vector3, yaw: float) -> void:
	var metal := b.m("chrome", Color("#A9B0B2"))
	var timber := b.m("decking")
	var concrete := b.m("concrete")
	var paint := b.m("trim_paint", b.trim_ext)
	match kind:
		"hills_hoist":
			kit.cylinder(metal, c, 2.1, 0.035, 0.03, 8)
			var hub := c + Vector3(0, 2.0, 0)
			for i in 4:
				var a := yaw + PI * 0.25 + i * PI * 0.5
				var tip := hub + Vector3(cos(a) * 1.3, 0.25, sin(a) * 1.3)
				kit.beam(metal, hub, tip, 0.025, 0.025)
			for ring in 4:
				var r := 0.45 + ring * 0.28
				for i2 in 4:
					var a0 := yaw + PI * 0.25 + i2 * PI * 0.5
					var a1 := a0 + PI * 0.5
					var y := 2.0 + 0.25 * r / 1.3
					kit.beam(metal, hub + Vector3(cos(a0) * r, y - 2.0, sin(a0) * r), hub + Vector3(cos(a1) * r, y - 2.0, sin(a1) * r), 0.008, 0.008)
		"letterbox":
			_box(kit, timber, c, yaw, Vector3(0, 0.55, 0), Vector3(0.09, 1.1, 0.09))
			_box(kit, paint, c, yaw, Vector3(0, 1.2, 0), Vector3(0.36, 0.26, 0.26))
			_box(kit, paint, c, yaw, Vector3(0, 1.35, 0), Vector3(0.4, 0.04, 0.3))
		"garden_bench":
			for sx: float in [-0.6, 0.6]:
				_box(kit, paint, c, yaw, Vector3(sx, 0.22, 0), Vector3(0.06, 0.44, 0.4))
			for i in 3:
				_box(kit, timber, c, yaw, Vector3(0, 0.45, -0.13 + i * 0.13), Vector3(1.4, 0.03, 0.1))
			_box(kit, timber, c, yaw, Vector3(0, 0.8, 0.2), Vector3(1.4, 0.12, 0.03))
			_box(kit, timber, c, yaw, Vector3(0, 0.62, 0.2), Vector3(1.4, 0.1, 0.03))
		"birdbath":
			kit.frustum(concrete, c, c + Vector3(0, 0.75, 0), 0.16, 0.08, 10, 1.0, Color.WHITE, true)
			kit.frustum(concrete, c + Vector3(0, 0.72, 0), c + Vector3(0, 0.86, 0), 0.08, 0.32, 14, 1.0, Color.WHITE, true)
			kit.cylinder(b.m("trim_paint", Color("#7E9AA6")), c + Vector3(0, 0.84, 0), 0.025, 0.27, 0.27, 14)
		"wheelbarrow":
			_box(kit, b.m("decking"), c, yaw, Vector3(0.1, 0.45, 0), Vector3(0.8, 0.25, 0.55))
			for sz: float in [-0.22, 0.22]:
				kit.beam(timber, _at(c, yaw, Vector3(-0.6, 0.55, sz)), _at(c, yaw, Vector3(0.55, 0.32, sz)), 0.04, 0.04)
				kit.beam(timber, _at(c, yaw, Vector3(-0.2, 0.32, sz)), _at(c, yaw, Vector3(-0.2, 0.0, sz)), 0.04, 0.04)
			var axle := _at(c, yaw, Vector3(0.6, 0.18, 0))
			var side := Basis(Vector3.UP, -yaw) * Vector3(0, 0, 0.04)
			kit.frustum(b.m("trim_paint", Color("#2A2A2A")), axle - side, axle + side, 0.18, 0.18, 12, 1.0, Color.WHITE, true)
		"woodpile":
			for row in 3:
				for i in 6 - row:
					var lc := _at(c, yaw, Vector3(-0.55 + i * 0.22 + row * 0.11, 0.1 + row * 0.18, 0))
					var axis := Basis(Vector3.UP, -yaw) * Vector3(0, 0, 0.38)
					kit.frustum(b.m("bark_gum", Color("#9A8068")), lc - axis, lc + axis, 0.1, 0.1, 6, 1.0, Color.WHITE, true)


# --- Fences --------------------------------------------------------------------------------------

func _fences(kit: MeshKit) -> void:
	var h := b.house
	var defs: Dictionary = GardenOps.catalogue()["fences"]
	var posts: Dictionary = {}
	for k: String in h.fences:
		var f: Dictionary = h.fences[k]
		var type := str(f["type"])
		var d: Dictionary = defs.get(type, defs["picket"])
		var pts := HouseData.edge_points(k)
		var a := Vector3(pts[0].x, 0, pts[0].y)
		var c := Vector3(pts[1].x, 0, pts[1].y)
		a.y = _g(a.x, a.z)
		c.y = _g(c.x, c.z)
		var ht := float(d["height"])
		var col := b.m("trim_paint", HouseMeshBuilder._paint(str(d["colour"])))
		if bool(f.get("gate", false)):
			_gate(kit, a, c, minf(ht, 1.2), b.m("trim_paint", HouseMeshBuilder._paint("white" if type == "picket" else "#8C7A60")))
		else:
			match type:
				"picket":
					_rails(kit, a, c, [0.25, 0.75], col)
					for i in 8:
						var p := a.lerp(c, (i + 0.5) / 8.0)
						kit.box(col, Transform3D(Basis(Vector3.UP, atan2(-(c - a).z, (c - a).x)), p + Vector3(0, ht * 0.5, 0)), Vector3(0.07, ht, 0.02))
				"paling":
					_rails(kit, a, c, [0.3, 1.3], b.m("trim_paint", Color("#6E6252")))
					var dir := (c - a)
					var n := Vector3(-dir.z, 0, dir.x).normalized()
					b.face_uv(kit, col, a + n * 0.03, c + n * 0.03, c + n * 0.03 + Vector3(0, ht, 0), a + n * 0.03 + Vector3(0, ht, 0), n,
						Vector2(0, ht), Vector2(1, ht), Vector2(1, 0), Vector2(0, 0))
					b.face_uv(kit, col, c + n * 0.01, a + n * 0.01, a + n * 0.01 + Vector3(0, ht, 0), c + n * 0.01 + Vector3(0, ht, 0), -n,
						Vector2(0, ht), Vector2(1, ht), Vector2(1, 0), Vector2(0, 0))
				"post_wire":
					for y: float in [0.35, 0.7, 1.0]:
						kit.beam(b.m("chrome", Color("#8A8E8E")), a + Vector3(0, y, 0), c + Vector3(0, y, 0), 0.006, 0.006)
				"corrugated":
					var dir2 := (c - a)
					var n2 := Vector3(-dir2.z, 0, dir2.x).normalized()
					var iron := b.m("corrugated_iron_old")
					b.face_uv(kit, iron, a, c, c + Vector3(0, ht, 0), a + Vector3(0, ht, 0), n2, Vector2(0, ht), Vector2(1, ht), Vector2(1, 0), Vector2(0, 0))
					b.face_uv(kit, iron, c, a, a + Vector3(0, ht, 0), c + Vector3(0, ht, 0), -n2, Vector2(0, ht), Vector2(1, ht), Vector2(1, 0), Vector2(0, 0))
				"hedge":
					var leaf := _leaf("hedge")
					var dir3 := (c - a)
					var n3 := Vector3(-dir3.z, 0, dir3.x).normalized()
					var dark := b.m("trim_paint", Color("#2E4426"))
					kit.beam(dark, a + Vector3(0, ht * 0.45, 0), c + Vector3(0, ht * 0.45, 0), 0.5, ht * 0.9)
					for sd: float in [1.0, -1.0]:
						var o := n3 * 0.3 * sd
						kit.quad_n(leaf, a + o, c + o, c + o + Vector3(0, ht, 0), a + o + Vector3(0, ht, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), n3 * sd)
						kit.quad_n(leaf, c + o, a + o, a + o + Vector3(0, ht, 0), c + o + Vector3(0, ht, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), n3 * sd)
					kit.quad_n(leaf, a - n3 * 0.3 + Vector3(0, ht, 0), c - n3 * 0.3 + Vector3(0, ht, 0), c + n3 * 0.3 + Vector3(0, ht, 0), a + n3 * 0.3 + Vector3(0, ht, 0),
						Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector3.UP)
		if type != "hedge":
			for p2: Vector3 in [a, c]:
				posts[HouseData.tile_key(roundi(p2.x), roundi(p2.z))] = [p2, ht, type]
	for key: String in posts:
		var e: Array = posts[key]
		var p3: Vector3 = e[0]
		var pt := b.m("trim_paint", Color("#F2EFE6")) if str(e[2]) == "picket" else b.m("decking")
		kit.box(pt, Transform3D(Basis(), p3 + Vector3(0, (float(e[1]) + 0.08) * 0.5, 0)), Vector3(0.09, float(e[1]) + 0.08, 0.09))


func _rails(kit: MeshKit, a: Vector3, c: Vector3, heights: Array, mat: String) -> void:
	for y: float in heights:
		kit.beam(mat, a + Vector3(0, y, 0), c + Vector3(0, y, 0), 0.04, 0.07)


## A ledged and braced timber gate across one metre, hung closed.
func _gate(kit: MeshKit, a: Vector3, c: Vector3, ht: float, mat: String) -> void:
	var y0 := maxf(a.y, c.y) + 0.06
	var a2 := Vector3(a.x, y0, a.z).lerp(Vector3(c.x, y0, c.z), 0.05)
	var c2 := Vector3(a.x, y0, a.z).lerp(Vector3(c.x, y0, c.z), 0.95)
	for y: float in [0.1, ht - 0.12]:
		kit.beam(mat, a2 + Vector3(0, y, 0), c2 + Vector3(0, y, 0), 0.05, 0.1)
	kit.beam(mat, a2 + Vector3(0, 0.1, 0), c2 + Vector3(0, ht - 0.12, 0), 0.05, 0.08)
	for i in 6:
		var p := a2.lerp(c2, (i + 0.5) / 6.0)
		kit.box(mat, Transform3D(Basis(Vector3.UP, atan2(-(c2 - a2).z, (c2 - a2).x)), p + Vector3(0, ht * 0.5, 0)), Vector3(0.08, ht, 0.025))
