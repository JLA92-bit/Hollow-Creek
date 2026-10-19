class_name PrologueGuides
extends Node3D
## The prologue's marks in the world: the dotted ghost path to follow when laying the road, and the
## outline of the store plot. Shown only on the steps that need them.

var grid: WorldGrid
var _road: MultiMeshInstance3D
var _plot: MeshInstance3D
var _mat: StandardMaterial3D
var _built := false


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color("#FFD166")
	_mat.no_depth_test = false
	_mat.render_priority = 8
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _process(_delta: float) -> void:
	var p := SimHost.prologue
	if p == null or grid == null:
		visible = false
		return
	if not _built:
		_build(p)
	visible = true
	var id := p.current_id()
	_road.visible = id == "road"
	_plot.visible = id == "store"


func _build(p: Prologue) -> void:
	_built = true
	var pts: Array = p.data["road"]["points"]
	var spots: Array[Vector3] = []
	for i in range(pts.size() - 1):
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var n := int(a.distance_to(b) / 1.6)
		for s in n:
			var q := a.lerp(b, float(s) / float(maxi(1, n)))
			spots.append(Vector3(q.x + 0.5, grid.height_at(q.x, q.y) + 0.12, q.y + 0.5))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.05, 0.7)
	mesh.material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
	_road = MultiMeshInstance3D.new()
	_road.multimesh = mm
	add_child(_road)
	# The plot: a loop of thin boxes round its edge.
	var rect := Rect2i()
	var slice: MapSlice = SimHost.get("_world").get("slice") if SimHost.get("_world") else null
	if slice != null:
		for l: Dictionary in slice.data["landmarks"]:
			if str(l["id"]) == str(p.data["store_plot"]):
				var r: Array = l["rect"]
				rect = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _mat)
	for c: Vector2 in [Vector2(rect.position), Vector2(rect.end.x, rect.position.y), Vector2(rect.end), Vector2(rect.position.x, rect.end.y), Vector2(rect.position)]:
		im.surface_add_vertex(Vector3(c.x, grid.height_at(c.x, c.y) + 0.3, c.y))
	im.surface_end()
	_plot = MeshInstance3D.new()
	_plot.mesh = im
	add_child(_plot)
