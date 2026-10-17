class_name EucalyptBuilder
extends RefCounted
## Procedural eucalypts: a pale trunk that forks into a few spreading limbs, with drooping leaf
## clusters (crossed cards) at the branch tips. Leaf normals point out from the crown so it shades
## like a soft volume. Deterministic per seed.

const KINDS := {
	"gum": {"height": 13.0, "trunk_r": 0.2, "fork": [0.3, 0.42], "limbs": [2, 3], "spread": 0.55, "bark": "#EDE7DC", "leaf": "#FFFFFF", "card": 3.2},
	"red_gum": {"height": 14.5, "trunk_r": 0.38, "fork": [0.2, 0.3], "limbs": [3, 4], "spread": 0.95, "bark": "#D2C8B8", "leaf": "#E6EFE2", "card": 3.8},
}

static var _bark_mats: Dictionary = {}
static var _leaf_mat: ShaderMaterial


static func leaf_material() -> ShaderMaterial:
	if _leaf_mat == null:
		_leaf_mat = ShaderMaterial.new()
		_leaf_mat.shader = load("res://shaders/foliage.gdshader") as Shader
		_leaf_mat.set_shader_parameter("leaf_tex", load("res://assets/models/foliage/gum_leaves.png"))
		_leaf_mat.set_shader_parameter("sway_scale", 0.006)
	return _leaf_mat


static func bark_material(kind: String) -> StandardMaterial3D:
	if not _bark_mats.has(kind):
		var m := MaterialLibrary.unique("bark_gum", Color(str(KINDS[kind]["bark"])))
		m.vertex_color_use_as_albedo = true
		_bark_mats[kind] = m
	return _bark_mats[kind]


## lod 0 is the full tree; lod 1 is a cheap distant version with fewer, larger leaf cards.
static func build(kind: String, seed_value: int, lod: int = 0) -> ArrayMesh:
	var k: Dictionary = KINDS[kind]
	var rng := SimRng.new(seed_value)
	var kit := MeshKit.new()
	var h := float(k["height"]) * rng.randf_range(0.9, 1.1)
	var r0 := float(k["trunk_r"])
	var fork_t := rng.randf_range(float(k["fork"][0]), float(k["fork"][1]))
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12)).normalized()
	var fork := lean * h * fork_t
	var tips: Array[Dictionary] = []
	# Trunk in two segments with a slight kink. Rough, darker bark at the base.
	var mid := fork * 0.5 + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	kit.frustum("bark", Vector3(0, -0.3, 0), mid, r0 * 1.25, r0 * 0.95, 10, 1.0, Color(0.72, 0.68, 0.62))
	kit.frustum("bark", mid, fork, r0 * 0.95, r0 * 0.78, 10, 1.0, Color(0.95, 0.94, 0.92), false, mid.length())
	var limbs := rng.randi_range(int(k["limbs"][0]), int(k["limbs"][1]))
	var spread := float(k["spread"])
	var base_angle := rng.randf_range(0.0, TAU)
	for i in limbs:
		var ang := base_angle + TAU * i / limbs + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(ang), 0, sin(ang))
		var dir := (Vector3.UP + out * spread * rng.randf_range(0.7, 1.2)).normalized()
		var length := h * rng.randf_range(0.28, 0.38)
		var p1 := fork + dir * length * 0.55
		var bend := (dir + Vector3.UP * 0.4 + out * 0.15).normalized()
		var p2 := p1 + bend * length * 0.45
		kit.frustum("bark", fork, p1, r0 * 0.6, r0 * 0.42, 8, 1.0, Color.WHITE)
		kit.frustum("bark", p1, p2, r0 * 0.42, r0 * 0.25, 7, 1.0, Color.WHITE)
		tips.append({"p": p2, "out": out, "s": 1.0})
		# Two or three sub-branches.
		for j in rng.randi_range(2, 3):
			var from := fork.lerp(p2, rng.randf_range(0.45, 0.9))
			var sang := ang + rng.randf_range(-1.1, 1.1)
			var sout := Vector3(cos(sang), 0, sin(sang))
			var sdir := (Vector3.UP * rng.randf_range(0.4, 0.9) + sout * spread * 1.2).normalized()
			var slen := h * rng.randf_range(0.14, 0.22)
			var sp := from + sdir * slen
			kit.frustum("bark", from, sp, r0 * 0.22, r0 * 0.1, 5, 1.0, Color.WHITE)
			tips.append({"p": sp, "out": sout, "s": 0.8})
	# Crown centre for soft normals.
	var centre := Vector3.ZERO
	for t in tips:
		centre += t["p"]
	centre /= tips.size()
	centre.y -= h * 0.08
	var card := float(k["card"])
	for t in tips:
		var p: Vector3 = t["p"]
		var clusters := rng.randi_range(3, 5) if lod == 0 else 2
		for c in clusters:
			var cp := p + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.9, 0.6), rng.randf_range(-1.2, 1.2)) * float(t["s"])
			var size := card * rng.randf_range(0.75, 1.15) * float(t["s"]) * (1.0 if lod == 0 else 1.5)
			var shade := rng.randf_range(0.82, 1.08)
			var col := Color(shade, shade * rng.randf_range(0.97, 1.03), shade * rng.randf_range(0.95, 1.05))
			var cards := 3 if lod == 0 else 2
			for q in cards:
				var yaw := rng.randf_range(0.0, PI) + q * PI / cards
				var right := Vector3(cos(yaw), 0, sin(yaw)) * size * 0.5
				var tilt := rng.randf_range(-0.25, 0.25)
				var up := (Vector3.UP + right.normalized() * tilt).normalized() * size * 0.5
				_card(kit, cp, right, up, (cp - centre).normalized(), col)
	var mats := {"bark": bark_material(kind), "leaves": leaf_material()}
	return kit.commit(mats)


## A camera-agnostic card with a custom (crown) normal on every vertex.
static func _card(kit: MeshKit, c: Vector3, right: Vector3, up: Vector3, n: Vector3, col: Color) -> void:
	var a := c - right - up
	var b := c + right - up
	var cc := c + right + up
	var d := c - right + up
	kit.quad_n("leaves", a, b, cc, d, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), n, col)
