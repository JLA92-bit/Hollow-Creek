class_name TerrainView
extends Node3D
## Renders the WorldGrid terrain as a few chunk meshes with the splat-painted ground shader.
## The grid stays the source of truth: call rebuild() or refresh_splat() after it changes.

const CHUNK := Vector2i(48, 32)
const SKIRT := 220.0   ## metres of rising bush country drawn around the playable valley
const SKIRT_CELL := 8.0

var grid: WorldGrid
var material: ShaderMaterial
var splat_image: Image
var splat_texture: ImageTexture


func setup(p_grid: WorldGrid) -> void:
	grid = p_grid
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/ground.gdshader") as Shader
	material.set_shader_parameter("albedo_array", load("res://assets/materials/ground_array/ground_albedo_array.jpg"))
	material.set_shader_parameter("normal_array", load("res://assets/materials/ground_array/ground_normal_array.jpg"))
	material.set_shader_parameter("orm_array", load("res://assets/materials/ground_array/ground_orm_array.jpg"))
	material.set_shader_parameter("macro_noise", load("res://assets/materials/noise/macro_noise.png"))
	material.set_shader_parameter("map_size", Vector2(grid.width, grid.height))
	material.set_shader_parameter("grass_tint", Color("#C9C48F"))
	refresh_splat()
	material.set_shader_parameter("splat", splat_texture)
	rebuild()


func refresh_splat() -> void:
	if splat_image == null:
		splat_image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	for y in grid.height:
		for x in grid.width:
			var c := Ground.splat(grid.get_ground(x, y))
			c.a = grid.get_wet(x, y)
			splat_image.set_pixel(x, y, c)
	if splat_texture == null:
		splat_texture = ImageTexture.create_from_image(splat_image)
	else:
		splat_texture.update(splat_image)


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	for cy in range(0, grid.height, CHUNK.y):
		for cx in range(0, grid.width, CHUNK.x):
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cy]
			mi.mesh = _chunk_mesh(cx, cy, mini(CHUNK.x, grid.width - cx), mini(CHUNK.y, grid.height - cy))
			mi.material_override = material
			add_child(mi)
	_build_skirt()


func _chunk_mesh(ox: int, oy: int, w: int, h: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in h + 1:
		for i in w + 1:
			var x := ox + i
			var z := oy + j
			verts.append(Vector3(x, grid.corner_height(x, z), z))
			var n := Vector3(grid.corner_height(x - 1, z) - grid.corner_height(x + 1, z), 2.0,
				grid.corner_height(x, z - 1) - grid.corner_height(x, z + 1)).normalized()
			normals.append(n)
			var t := (Vector3.RIGHT - n * n.dot(Vector3.RIGHT)).normalized()
			tangents.append_array([t.x, t.y, t.z, 1.0])
			uvs.append(Vector2(x, z))
	for j in h:
		for i in w:
			var a := j * (w + 1) + i
			var b := a + 1
			var c := a + (w + 1)
			var d := c + 1
			# Clockwise from above is front-facing in Godot.
			idx.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Height outside the map: the edge height carried outwards, rising into hills around the valley.
func skirt_height(x: float, z: float) -> float:
	var cx := clampf(x, 0.0, grid.width)
	var cz := clampf(z, 0.0, grid.height)
	var d := Vector2(x - cx, z - cz).length()
	var edge := grid.height_at(cx, cz)
	var rise := smoothstep(0.0, 160.0, d) * 26.0 + sin(x * 0.031) * cos(z * 0.027) * 3.0 * smoothstep(0.0, 60.0, d)
	return edge + rise


func _build_skirt() -> void:
	var skirt_mat := material.duplicate() as ShaderMaterial
	var plain := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	plain.set_pixel(0, 0, Color(0, 0, 0, 0))
	skirt_mat.set_shader_parameter("splat", ImageTexture.create_from_image(plain))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -SKIRT
	var z0 := -SKIRT
	var nx := int((grid.width + SKIRT * 2.0) / SKIRT_CELL)
	var nz := int((grid.height + SKIRT * 2.0) / SKIRT_CELL)
	var inner := Rect2(0, 0, grid.width, grid.height)
	for j in nz:
		for i in nx:
			var a := Vector2(x0 + i * SKIRT_CELL, z0 + j * SKIRT_CELL)
			var cell := Rect2(a, Vector2(SKIRT_CELL, SKIRT_CELL))
			if inner.encloses(cell):
				continue
			var corners := [a, a + Vector2(SKIRT_CELL, 0), a + Vector2(0, SKIRT_CELL), a + Vector2(SKIRT_CELL, SKIRT_CELL)]
			var v: Array[Vector3] = []
			for c: Vector2 in corners:
				var h := skirt_height(c.x, c.y)
				# Tuck the skirt slightly under the map so the seam never shows a gap.
				if inner.grow(0.01).has_point(c):
					h -= 0.08
				v.append(Vector3(c.x, h, c.y))
			for tri: Array in [[0, 1, 2], [1, 3, 2]]:
				var p0: Vector3 = v[tri[0]]
				var p1: Vector3 = v[tri[1]]
				var p2: Vector3 = v[tri[2]]
				var n := (p2 - p0).cross(p1 - p0).normalized()
				for p: Vector3 in [p0, p1, p2]:
					st.set_normal(n)
					st.set_uv(Vector2(p.x, p.z))
					st.add_vertex(p)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Skirt"
	mi.mesh = st.commit()
	mi.material_override = skirt_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func set_rain_wetness(v: float) -> void:
	material.set_shader_parameter("rain_wetness", v)
	var skirt := get_node_or_null("Skirt") as MeshInstance3D
	if skirt:
		(skirt.material_override as ShaderMaterial).set_shader_parameter("rain_wetness", v)


func set_detail(on: bool) -> void:
	material.set_shader_parameter("detail", on)
