class_name DemoTown
extends RefCounted
## A furnished starting town for tests, demos and previews: the general store with the Haywards'
## rooms behind it on the pegged plot, the Pikes' cottage and the Kowalskis' cottage east of it.
## Agnes's cottage comes from the map. Built with the real BuildOps and FurnitureOps.

const SITES := {"h_hayward": Vector2i(69, 45), "h_pike": Vector2i(84, 47), "h_kowalski": Vector2i(97, 47)}


static func houses() -> Array:
	return [store(), cottage("house_pike", "Pike cottage", SITES["h_pike"], 3), cottage("house_kowalski", "Kowalski cottage", SITES["h_kowalski"], 3)]


## Household -> house id, including Agnes in her cottage.
static func homes() -> Dictionary:
	return {"h_doyle": "lm_agnes_cottage", "h_hayward": "house_store", "h_pike": "house_pike", "h_kowalski": "house_kowalski"}


static func _door(h: HouseData, axis: String, x: float, z: float, style: String = "four_panel") -> void:
	BuildOps.place_opening(h, 0, {"kind": "door", "style": style, "axis": axis, "x": x, "z": z, "width": 0.82, "height": 2.05 if style != "front_door" else 2.1,
		"lock": style == "front_door", "night": {"lock": style == "front_door", "latch": false, "curtains": true}})


static func _window(h: HouseData, axis: String, x: float, z: float) -> void:
	BuildOps.place_opening(h, 0, {"kind": "window", "style": "double_hung", "axis": axis, "x": x, "z": z, "width": 0.9, "height": 1.5, "sill": 0.9,
		"night": {"lock": false, "latch": true, "curtains": true}})


static func _put(h: HouseData, item: String, x: float, z: float, rot: float = 0.0) -> void:
	var res := FurnitureOps.place(h, 0, item, Vector2(x, z), rot)
	if not res["ok"]:
		push_warning("DemoTown: %s at %.1f, %.1f: %s" % [item, x, z, res["msg"]])


## The general store: shop and exchange at the front, a kitchen and two bedrooms behind.
static func store() -> HouseData:
	var h := HouseData.new()
	h.id = "house_store"
	h.name = "General store"
	h.origin = SITES["h_hayward"]
	BuildOps.add_room(h, 0, Rect2i(0, 0, 8, 5), {"name": "Shop", "height": 3.0, "floor": "floor_boards"})
	BuildOps.add_room(h, 0, Rect2i(8, 0, 3, 5), {"name": "Exchange", "paint": "duck_egg", "height": 3.0})
	BuildOps.add_room(h, 0, Rect2i(0, 5, 5, 4), {"name": "Kitchen", "paint": "mint", "floor": "lino_checks"})
	BuildOps.add_room(h, 0, Rect2i(5, 5, 3, 4), {"name": "Bedroom", "paint": "rose"})
	BuildOps.add_room(h, 0, Rect2i(8, 5, 3, 4), {"name": "June's room", "paint": "sky"})
	_door(h, "x", 3.5, 0.0, "front_door")
	_door(h, "z", 8.0, 2.0)
	_door(h, "x", 2.0, 5.0)
	_door(h, "z", 5.0, 6.5)
	_door(h, "x", 9.0, 5.0)
	_door(h, "x", 1.0, 9.0, "ledge_brace")
	for w: Array in [["x", 0.8, 0.0], ["x", 6.0, 0.0], ["z", 0.0, 7.0], ["x", 6.0, 9.0], ["x", 9.0, 9.0], ["z", 11.0, 2.0]]:
		_window(h, w[0], w[1], w[2])
	_put(h, "wood_stove", 0.6, 6.0, 90.0)
	_put(h, "icebox", 4.5, 8.5, 180.0)
	_put(h, "laminex_table", 2.5, 7.0)
	_put(h, "kitchen_chair", 2.0, 6.3, 180.0)
	_put(h, "kitchen_chair", 3.0, 7.75)
	_put(h, "wireless_set", 2.75, 7.0)
	_put(h, "iron_bed", 6.5, 7.75)
	_put(h, "day_bed", 9.5, 7.0, 90.0)
	_put(h, "crate", 1.0, 1.0)
	_put(h, "crate", 1.0, 2.0)
	BuildOps.auto_roof(h, {"shape": "gable", "material": "roof_paint_red"})
	return h


## A cottage: living room and kitchen across the front, bedrooms behind.
static func cottage(id: String, name: String, origin: Vector2i, bedrooms: int) -> HouseData:
	var h := HouseData.new()
	h.id = id
	h.name = name
	h.origin = origin
	BuildOps.add_room(h, 0, Rect2i(0, 0, 5, 4), {"name": "Kitchen", "paint": "cream", "floor": "lino_checks"})
	BuildOps.add_room(h, 0, Rect2i(5, 0, 4, 4), {"name": "Living room", "paint": "sage"})
	BuildOps.add_room(h, 0, Rect2i(0, 4, 4, 3), {"name": "Bedroom", "paint": "rose"})
	BuildOps.add_room(h, 0, Rect2i(4, 4, 5, 3), {"name": "Second bedroom", "paint": "sky"})
	_door(h, "x", 6.0, 0.0, "front_door")
	_door(h, "z", 5.0, 1.5)
	_door(h, "x", 1.5, 4.0)
	_door(h, "x", 6.0, 4.0)
	_door(h, "z", 9.0, 5.0, "ledge_brace")
	for w: Array in [["x", 2.0, 0.0], ["z", 0.0, 1.5], ["z", 9.0, 1.5], ["x", 1.5, 7.0], ["x", 6.5, 7.0]]:
		_window(h, w[0], w[1], w[2])
	_put(h, "wood_stove", 0.6, 3.2, 90.0)
	_put(h, "icebox", 4.5, 0.6)
	_put(h, "farmhouse_table", 2.5, 2.0)
	_put(h, "kitchen_chair", 2.0, 1.2, 180.0)
	_put(h, "kitchen_chair", 3.0, 2.8)
	_put(h, "settee", 7.0, 3.5, 180.0)
	_put(h, "wireless_set", 8.5, 0.5)
	_put(h, "iron_bed", 2.0, 5.5, 90.0)
	if bedrooms >= 2:
		_put(h, "day_bed", 6.5, 6.4)
	if bedrooms >= 3:
		_put(h, "day_bed", 6.5, 4.6)
	# Garden items need the house to have a height; the world sets the real one when it's placed.
	h.base_y = 0.0
	GardenOps.place_item(h, "vegie_bed", Vector2(2.0, 9.5))
	h.base_y = NAN
	BuildOps.auto_roof(h, {"shape": "hip"})
	return h
