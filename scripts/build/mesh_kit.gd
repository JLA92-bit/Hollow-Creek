class_name MeshKit
extends RefCounted
## Collects geometry per material id and turns it into one ArrayMesh with a surface per material.
## Used by the procedural architecture, landmarks and plants. UVs are in metres unless stated.

var _tools: Dictionary = {}  ## material id -> SurfaceTool


func _st(mat: String) -> SurfaceTool:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	return _tools[mat]


func has_geometry() -> bool:
	return not _tools.is_empty()


func materials() -> Array:
	return _tools.keys()


## One quad from four corners (counter-clockwise when seen from the front) with explicit UVs.
func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, color: Color = Color.WHITE) -> void:
	var st := _st(mat)
	var n := (b - a).cross(d - a).normalized()
	if n.is_zero_approx():
		n = (c - b).cross(a - b).normalized()
	# Godot treats clockwise triangles as front faces, so emit in reverse of the counter-clockwise corners.
	for v: Array in [[a, ua], [c, uc], [b, ub], [a, ua], [d, ud], [c, uc]]:
		st.set_color(color)
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## A quad whose UVs come from world-space metres projected onto its own plane.
## u runs along a -> b, v runs down from the top edge (so weatherboard and corrugations line up).
func quad_auto(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_scale: float = 1.0, u_origin: float = 0.0, color: Color = Color.WHITE) -> void:
	var u_axis := (b - a).normalized()
	var ua := u_origin + 0.0
	var ub := u_origin + a.distance_to(b)
	# a and b are bottom, c and d are top. V is height from a reference of 0 at y = 0, flipped.
	quad(mat, a, b, c, d,
		Vector2(ua, -a.y) * uv_scale, Vector2(ub, -b.y) * uv_scale,
		Vector2(u_origin + u_axis.dot(c - a), -c.y) * uv_scale, Vector2(u_origin + u_axis.dot(d - a), -d.y) * uv_scale, color)


## A triangle with corners counter-clockwise when seen from the front.
func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, color: Color = Color.WHITE) -> void:
	var st := _st(mat)
	var n := (b - a).cross(c - a).normalized()
	for v: Array in [[a, ua], [c, uc], [b, ub]]:
		st.set_color(color)
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## An axis-aligned box (in the given transform) with metre UVs on every face.
func box(mat: String, xf: Transform3D, size: Vector3, uv_scale: float = 1.0, color: Color = Color.WHITE, skip_bottom: bool = false) -> void:
	var h := size * 0.5
	var p := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var w: Array[Vector3] = []
	for v: Vector3 in p:
		w.append(xf * v)
	var sx := size.x * uv_scale
	var sy := size.y * uv_scale
	var sz := size.z * uv_scale
	# Front (+z), back (-z), right (+x), left (-x), top, bottom.
	quad(mat, w[4], w[5], w[6], w[7], Vector2(0, sy), Vector2(sx, sy), Vector2(sx, 0), Vector2(0, 0), color)
	quad(mat, w[1], w[0], w[3], w[2], Vector2(0, sy), Vector2(sx, sy), Vector2(sx, 0), Vector2(0, 0), color)
	quad(mat, w[5], w[1], w[2], w[6], Vector2(0, sy), Vector2(sz, sy), Vector2(sz, 0), Vector2(0, 0), color)
	quad(mat, w[0], w[4], w[7], w[3], Vector2(0, sy), Vector2(sz, sy), Vector2(sz, 0), Vector2(0, 0), color)
	quad(mat, w[7], w[6], w[2], w[3], Vector2(0, 0), Vector2(sx, 0), Vector2(sx, sz), Vector2(0, sz), color)
	if not skip_bottom:
		quad(mat, w[0], w[1], w[5], w[4], Vector2(0, 0), Vector2(sx, 0), Vector2(sx, sz), Vector2(0, sz), color)


## A box between two points with a square or rectangular cross-section (posts, rails, rafters).
func beam(mat: String, from: Vector3, to: Vector3, width: float, depth: float = -1.0, uv_scale: float = 1.0, color: Color = Color.WHITE) -> void:
	if depth < 0.0:
		depth = width
	var dir := to - from
	var length := dir.length()
	if length < 0.0001:
		return
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var basis := Basis.looking_at(dir.normalized(), up)
	box(mat, Transform3D(basis, (from + to) * 0.5), Vector3(width, depth, length), uv_scale, color)


## A capped cylinder along +y from base, tapering from r0 to r1.
func cylinder(mat: String, base: Vector3, height: float, r0: float, r1: float, sides: int = 8, uv_scale: float = 1.0, color: Color = Color.WHITE, cap: bool = true) -> void:
	frustum(mat, base, base + Vector3(0, height, 0), r0, r1, sides, uv_scale, color, cap)


## A tapered tube between two arbitrary points (trunks and branches).
func frustum(mat: String, a: Vector3, b: Vector3, r0: float, r1: float, sides: int = 8, uv_scale: float = 1.0, color: Color = Color.WHITE, cap: bool = false, v_offset: float = 0.0) -> void:
	var st := _st(mat)
	var axis := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u := axis.cross(ref).normalized()
	var w := axis.cross(u).normalized()
	var length := a.distance_to(b)
	var circ := TAU * maxf(r0, r1)
	for i in sides:
		var t0 := TAU * i / sides
		var t1 := TAU * (i + 1) / sides
		var d0 := u * cos(t0) + w * sin(t0)
		var d1 := u * cos(t1) + w * sin(t1)
		var p00 := a + d0 * r0
		var p01 := a + d1 * r0
		var p10 := b + d0 * r1
		var p11 := b + d1 * r1
		var u0 := float(i) / sides * circ * uv_scale
		var u1 := float(i + 1) / sides * circ * uv_scale
		var v0 := v_offset * uv_scale
		var v1 := (v_offset + length) * uv_scale
		for v: Array in [[p00, d0, Vector2(u0, v0)], [p10, d0, Vector2(u0, v1)], [p11, d1, Vector2(u1, v1)],
				[p00, d0, Vector2(u0, v0)], [p11, d1, Vector2(u1, v1)], [p01, d1, Vector2(u1, v0)]]:
			st.set_color(color)
			st.set_normal(v[1])
			st.set_uv(v[2])
			st.add_vertex(v[0])
	if cap:
		for i in sides:
			var t0 := TAU * i / sides
			var t1 := TAU * (i + 1) / sides
			var q0 := b + (u * cos(t0) + w * sin(t0)) * r1
			var q1 := b + (u * cos(t1) + w * sin(t1)) * r1
			tri(mat, b, q0, q1, Vector2(0.5, 0.5), Vector2(0.5 + cos(t0) * 0.5, 0.5 + sin(t0) * 0.5), Vector2(0.5 + cos(t1) * 0.5, 0.5 + sin(t1) * 0.5), color)


## Builds the ArrayMesh. Materials are looked up in the given dictionary (id -> Material).
func commit(mats: Dictionary, generate_tangents: bool = true) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var keys := _tools.keys()
	keys.sort()
	for k: String in keys:
		var st: SurfaceTool = _tools[k]
		st.index()
		if generate_tangents:
			st.generate_tangents()
		st.commit(mesh)
		var m: Material = mats.get(k)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		mesh.surface_set_name(mesh.get_surface_count() - 1, k)
	return mesh


## A quad with one shared normal on every vertex (foliage cards, soft volumes).
func quad_n(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, n: Vector3, color: Color = Color.WHITE) -> void:
	var st := _st(mat)
	for v: Array in [[a, ua], [c, uc], [b, ub], [a, ua], [d, ud], [c, uc]]:
		st.set_color(color)
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])
