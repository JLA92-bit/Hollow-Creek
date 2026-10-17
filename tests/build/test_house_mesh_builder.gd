extends GutTest

var _house: HouseData


func before_all() -> void:
	_house = HouseData.load_file("res://data/houses/agnes_cottage.json")


func _walls_mesh(h: HouseData, cut_all: bool, level: int = 0) -> ArrayMesh:
	var b := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	b.build_walls(kit, level, func(_k: String) -> bool: return cut_all)
	return kit.commit(b.mats)


func _surface_names(mesh: ArrayMesh) -> Array[String]:
	var out: Array[String] = []
	for i in mesh.get_surface_count():
		out.append(mesh.surface_get_name(i))
	return out


func test_walls_have_cladding_lining_and_glass() -> void:
	var names := _surface_names(_walls_mesh(_house, false))
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("weatherboard")), "weatherboard outside")
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("plaster")), "plaster inside")
	assert_gte(names.filter(func(n: String) -> bool: return n.begins_with("glass:")).size(), 5, "glass per room with windows")


func test_cutaway_lowers_walls_and_hides_joinery() -> void:
	var up := _walls_mesh(_house, false)
	var down := _walls_mesh(_house, true)
	assert_almost_eq(up.get_aabb().end.y, _house.floor_y() + _house.wall_height(), 0.05, "full walls reach the plate")
	# With every wall cut, the tallest thing left is the stove's flue pipe, a fixture.
	assert_lt(down.get_aabb().end.y, _house.floor_y() + 1.65, "cut walls are much lower")
	assert_false(_surface_names(down).any(func(n: String) -> bool: return n.begins_with("glass:")), "no glass in cut walls")


func test_roof_sits_above_the_walls() -> void:
	var b := HouseMeshBuilder.new(_house)
	var kit := MeshKit.new()
	b.build_roof(kit)
	var roof := kit.commit(b.mats)
	assert_gt(roof.get_aabb().end.y, _house.floor_y() + _house.wall_height() + 1.5, "ridge well above the wall plate")
	assert_lt(roof.get_aabb().position.x, -0.4, "eaves overhang the walls")


func test_stumps_reach_the_ground_on_a_slope() -> void:
	var b := HouseMeshBuilder.new(_house, func(x: float, _z: float) -> float: return -0.05 * x)
	var kit := MeshKit.new()
	b.build_structure(kit, 0)
	assert_lt(kit.commit(b.mats).get_aabb().position.y, -0.6, "stumps run down to the lower ground")


func _shop() -> HouseData:
	var h := HouseData.new()
	BuildOps.add_room(h, 0, Rect2i(0, 0, 6, 5), {"name": "Shop", "height": 3.0})
	BuildOps.add_storey(h, 1)
	BuildOps.add_room(h, 1, Rect2i(0, 0, 6, 5), {"name": "Residence"})
	BuildOps.add_stairs(h, 0, {"kind": "straight", "x": 0, "y": 4, "dir": "N"})
	h.roof = {"type": "hip", "pitch": 28, "overhang": 0.45, "material": "corrugated_iron"}
	return h


func test_upper_storey_sits_on_the_lower_one() -> void:
	var h := _shop()
	var up := _walls_mesh(h, false, 1)
	assert_almost_eq(up.get_aabb().position.y, h.floor_y() + h.level_base(1) - HouseMeshBuilder.FLOOR_THICKNESS, 0.05)
	var b := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	b.build_roof(kit)
	assert_gt(kit.commit(b.mats).get_aabb().end.y, h.floor_y() + h.level_base(1) + h.storey_height(1), "roof on top of the first floor")


func test_stairwell_has_no_floor_upstairs() -> void:
	var h := _shop()
	var b := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	b.build_structure(kit, 1)
	var mesh := kit.commit(b.mats)
	# Count floor quads: 30 tiles minus the stairwell.
	var floor_tris := 0
	for i in mesh.get_surface_count():
		if mesh.surface_get_name(i) == "floor_boards":
			floor_tris += mesh.surface_get_array_index_len(i) / 3
	var wells := h.stairwell_tiles(1).size()
	assert_eq(floor_tris, (30 - wells) * 2)


func test_quarter_floors_and_diagonal_walls_build() -> void:
	var h := HouseData.new()
	BuildOps.add_room(h, 0, Rect2i(0, 0, 4, 4))
	BuildOps.add_wall(h, 0, Vector2i(0, 0), Vector2i(4, 4))
	BuildOps.add_wall(h, 0, Vector2i(0, 6), Vector2i(4, 6), "half")
	BuildOps.paint_floor(h, 0, [Vector2i(1, 1)] as Array[Vector2i], "lino_checks", [1, 2])
	var mesh := _walls_mesh(h, false)
	assert_gt(mesh.get_surface_count(), 0)
	var b := HouseMeshBuilder.new(h)
	var kit := MeshKit.new()
	b.build_structure(kit, 0)
	assert_true(_surface_names(kit.commit(b.mats)).has("lino_checks"))


func test_chunked_build_covers_every_wall() -> void:
	var h := HouseData.new()
	BuildOps.add_room(h, 0, Rect2i(-3, -3, 14, 12))
	var whole := _walls_mesh(h, false)
	var total := 0
	var b := HouseMeshBuilder.new(h)
	var chunks: Dictionary = {}
	for k: String in h.walls(0):
		chunks[HouseMeshBuilder.edge_chunk(k)] = true
	chunks[Vector2i.ZERO] = true
	for c: Vector2i in chunks:
		var kit := MeshKit.new()
		b.build_walls(kit, 0, func(_k: String) -> bool: return false, c)
		if kit.has_geometry():
			var m := kit.commit(b.mats)
			for i in m.get_surface_count():
				total += m.surface_get_array_index_len(i)
	var whole_total := 0
	for i2 in whole.get_surface_count():
		whole_total += whole.surface_get_array_index_len(i2)
	assert_eq(total, whole_total, "chunks add up to the whole")
	assert_gt(chunks.size(), 1)
