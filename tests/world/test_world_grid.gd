extends GutTest


func test_edge_keys_are_canonical() -> void:
	assert_eq(WorldGrid.edge_key(3, 4, WorldGrid.Dir.S), WorldGrid.edge_key(3, 5, WorldGrid.Dir.N))
	assert_eq(WorldGrid.edge_key(3, 4, WorldGrid.Dir.E), WorldGrid.edge_key(4, 4, WorldGrid.Dir.W))
	assert_ne(WorldGrid.edge_key(3, 4, WorldGrid.Dir.N), WorldGrid.edge_key(3, 4, WorldGrid.Dir.W))


func test_edges_shared_between_neighbours() -> void:
	var g := WorldGrid.new(8, 8)
	g.set_edge(2, 2, WorldGrid.Dir.E, {"piece": "wall_weatherboard"})
	assert_eq(g.get_edge(3, 2, WorldGrid.Dir.W)["piece"], "wall_weatherboard")
	g.clear_edge(3, 2, WorldGrid.Dir.W)
	assert_true(g.get_edge(2, 2, WorldGrid.Dir.E).is_empty())


func test_save_round_trip() -> void:
	var g := WorldGrid.new(12, 9)
	g.set_ground(3, 4, Ground.Type.MUD)
	g.set_wet(3, 4, 0.75)
	g.set_light(5, 5, 0.4)
	g.set_corner_height(2, 2, 1.25)
	g.set_edge(1, 1, WorldGrid.Dir.N, {"piece": "fence_picket"})
	g.add_object({"id": "tree_1", "kind": "gum", "x": 6.5, "y": 2.5, "blocks": true})
	var back := WorldGrid.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())) as Dictionary)
	assert_eq(back.width, 12)
	assert_eq(back.get_ground(3, 4), Ground.Type.MUD)
	assert_almost_eq(back.get_wet(3, 4), 0.75, 0.01)
	assert_almost_eq(back.get_light(5, 5), 0.4, 0.01)
	assert_almost_eq(back.corner_height(2, 2), 1.25, 0.0001)
	assert_eq(back.get_edge(1, 1, WorldGrid.Dir.N)["piece"], "fence_picket")
	assert_eq(back.occupant.get(back.idx(6, 2)), "tree_1")
	assert_eq(back.objects.size(), 1)


func test_height_interpolates() -> void:
	var g := WorldGrid.new(2, 2)
	g.set_corner_height(1, 0, 2.0)
	g.set_corner_height(1, 1, 2.0)
	assert_almost_eq(g.height_at(0.5, 0.0), 1.0, 0.001)


func test_print_clarity_rules() -> void:
	assert_eq(Ground.print_clarity(Ground.Type.MUD, false), 1.0)
	assert_eq(Ground.print_clarity(Ground.Type.GRASS, false), 0.0)
	assert_eq(Ground.print_clarity(Ground.Type.GRASS, true), 0.5)
	assert_eq(Ground.print_clarity(Ground.Type.GRAVEL, true), 0.0)
	assert_eq(Ground.print_clarity(Ground.Type.DIRT, true), 1.0)
