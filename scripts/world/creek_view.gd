class_name CreekView
extends MeshInstance3D
## The creek's water surface: a ribbon along the resampled creek line at the local water level.

var material: ShaderMaterial


func setup(slice: MapSlice) -> void:
	var c: Dictionary = slice.data["creek"]
	var half := float(c["water_width"]) * 0.5 + 1.1
	var pts := slice.creek_points
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	var rows: Array[Array] = []
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var tangent := (next - prev).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var y := slice.creek_levels[i]
		var l := pts[i] + normal * half
		var r := pts[i] - normal * half
		rows.append([Vector3(l.x, y, l.y), Vector3(r.x, y, r.y), dist])
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var quad := [[a[0], Vector2(a[2], 0)], [a[1], Vector2(a[2], 1)], [b[1], Vector2(b[2], 1)],
			[a[0], Vector2(a[2], 0)], [b[1], Vector2(b[2], 1)], [b[0], Vector2(b[2], 0)]]
		# Keep the ribbon facing up whichever way the creek bends.
		var up := ((a[1] as Vector3) - (a[0] as Vector3)).cross((b[1] as Vector3) - (a[0] as Vector3)).y > 0.0
		var order := [0, 1, 2, 3, 4, 5] if not up else [0, 2, 1, 3, 5, 4]
		for k: int in order:
			st.set_normal(Vector3.UP)
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	st.generate_tangents()
	mesh = st.commit()
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/water.gdshader") as Shader
	material.set_shader_parameter("ripple", load("res://assets/materials/noise/water_normal.png"))
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_rain(v: float) -> void:
	material.set_shader_parameter("rain", v)
