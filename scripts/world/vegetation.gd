class_name Vegetation
extends Node3D
## Trees, shrubs and grass tufts from the map, drawn as MultiMeshes (one per mesh variant).

const VARIANTS := 4

var _tufts: MultiMeshInstance3D
## Trees that hide when they stand between the camera and what it looks at: [{mm, i, xf, p}].
var _trees: Array[Dictionary] = []


func setup(slice: MapSlice, skirt_height: Callable = Callable()) -> void:
	var grid := slice.grid
	# Trees, grouped by kind and variant.
	var groups: Dictionary = {}
	for o in grid.objects:
		var kind := str(o["kind"])
		if not EucalyptBuilder.KINDS.has(kind):
			continue
		var key := "%s_%d" % [kind, int(o["variant"]) % VARIANTS]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(o)
	var keys := groups.keys()
	keys.sort()
	# Backdrop bush on the hills around the valley: visual only, no shadows, never hidden.
	var backdrop: Dictionary = {}
	if skirt_height.is_valid():
		var rng := SimRng.new(4242)
		var made := 0
		while made < 420:
			var bx := rng.randf_range(-170.0, grid.width + 170.0)
			var bz := rng.randf_range(-170.0, grid.height + 170.0)
			if Rect2(-4, -4, grid.width + 8, grid.height + 8).has_point(Vector2(bx, bz)):
				continue
			var bkey := "%s_%d" % ["gum" if rng.chance(0.75) else "red_gum", rng.randi_range(0, VARIANTS - 1)]
			if not backdrop.has(bkey):
				backdrop[bkey] = []
			(backdrop[bkey] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)),
				Vector3(bx, float(skirt_height.call(bx, bz)) - 0.2, bz)))
			made += 1
	for key: String in keys:
		var parts := key.rsplit("_", true, 1)
		var mesh := EucalyptBuilder.build(parts[0], hash(key) & 0x7fffffff)
		var far_mesh := EucalyptBuilder.build(parts[0], hash(key) & 0x7fffffff, 1)
		var list: Array = groups[key]
		var xforms: Array[Transform3D] = []
		for o: Dictionary in list:
			var x := float(o["x"])
			var z := float(o["y"])
			var s := float(o["scale"])
			xforms.append(Transform3D(Basis(Vector3.UP, float(o["rot"])).scaled(Vector3.ONE * s), Vector3(x, grid.height_at(x, z), z)))
		var mmi := _add_multimesh("Trees_" + key, mesh, xforms, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		if backdrop.has(key):
			var bx_list: Array[Transform3D] = []
			for bxf: Transform3D in backdrop[key]:
				bx_list.append(bxf)
			_add_multimesh("Bush_" + key, far_mesh, bx_list, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for i in xforms.size():
			_trees.append({"mm": mmi.multimesh, "i": i, "xf": xforms[i], "p": Vector2(xforms[i].origin.x, xforms[i].origin.z), "hidden": false})
	# Shrubs.
	var shrub_mesh := _card_cluster_mesh("res://assets/models/foliage/shrub_leaves.png", 6, 1.3, 0.85, 0.6)
	var sx: Array[Transform3D] = []
	for s2 in slice.shrubs:
		var px := float(s2["x"])
		var pz := float(s2["y"])
		sx.append(Transform3D(Basis(Vector3.UP, float(s2["rot"])).scaled(Vector3.ONE * float(s2["scale"])), Vector3(px, grid.height_at(px, pz) - 0.05, pz)))
	_add_multimesh("Shrubs", shrub_mesh, sx, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	# Grass tufts.
	var tuft_mesh := _card_cluster_mesh("res://assets/models/foliage/grass_tuft.png", 2, 0.7, 0.5, 0.0, true)
	var tx: Array[Transform3D] = []
	for t in slice.tufts:
		var qx := float(t["x"])
		var qz := float(t["y"])
		tx.append(Transform3D(Basis(Vector3.UP, float(t["rot"])).scaled(Vector3.ONE * float(t["scale"])), Vector3(qx, grid.height_at(qx, qz) - 0.02, qz)))
	_tufts = _add_multimesh("Tufts", tuft_mesh, tx, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_tufts.visibility_range_end = 60.0


func _add_multimesh(n: String, mesh: Mesh, xforms: Array[Transform3D], shadows: GeometryInstance3D.ShadowCastingSetting) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.cast_shadow = shadows
	add_child(mmi)
	return mmi


## A small clump of crossed cards with upward-leaning normals (bushes and grass).
func _card_cluster_mesh(tex_path: String, cards: int, width: float, height: float, scatter: float, grass: bool = false) -> ArrayMesh:
	var kit := MeshKit.new()
	var rng := SimRng.new(hash(tex_path) & 0xffff)
	for i in cards:
		var yaw := PI * i / cards + rng.randf_range(-0.2, 0.2)
		var off := Vector3(rng.randf_range(-scatter, scatter), 0, rng.randf_range(-scatter, scatter)) * 0.5
		var right := Vector3(cos(yaw), 0, sin(yaw)) * width * 0.5
		var c := off + Vector3(0, height * 0.5, 0)
		var up := Vector3(0, height * 0.5, 0)
		var n := Vector3.UP if grass else (c + Vector3(0, -height * 0.2, 0)).normalized()
		if n.is_zero_approx():
			n = Vector3.UP
		var shade := rng.randf_range(0.85, 1.05)
		kit.quad_n("leaves", c - right - up, c + right - up, c + right + up, c - right + up,
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), n, Color(shade, shade, shade))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/foliage.gdshader") as Shader
	mat.set_shader_parameter("leaf_tex", load(tex_path))
	mat.set_shader_parameter("sway_scale", 0.12 if grass else 0.03)
	mat.set_shader_parameter("translucency", 0.12 if grass else 0.3)
	mat.set_shader_parameter("tint", Color(0.82, 0.8, 0.72) if grass else Color.WHITE)
	# A higher cut-off makes distant cards thin out instead of turning into solid squares as the
	# mipmapped alpha averages out.
	mat.set_shader_parameter("alpha_cut", 0.62 if grass else 0.55)
	return kit.commit({"leaves": mat}, false)


func set_detail(on: bool) -> void:
	if _tufts:
		_tufts.visible = on


## Hides trees whose trunks stand close to the line from the camera to its focus point, the way
## life sims fade walls and trees out of the way. Cheap: about 160 point-to-segment checks.
func update_occlusion(cam: Vector3, focus: Vector3) -> void:
	var a := Vector2(cam.x, cam.z)
	var b := Vector2(focus.x, focus.z)
	for t in _trees:
		var p: Vector2 = t["p"]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var along := a.distance_to(q) / maxf(a.distance_to(b), 0.001)
		var hide := p.distance_to(q) < 3.2 and along < 0.92 and cam.y < (t["xf"] as Transform3D).origin.y + 16.0
		if hide != t["hidden"]:
			t["hidden"] = hide
			var xf: Transform3D = t["xf"]
			(t["mm"] as MultiMesh).set_instance_transform(int(t["i"]), xf.scaled_local(Vector3.ONE * 0.0001) if hide else xf)
