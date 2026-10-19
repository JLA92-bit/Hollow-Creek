extends SceneTree
## Writes the shipped house templates (data/houses/templates/*.json) from the demo town's houses:
##   tools/bin/godot --headless --path . -s tools/make_templates.gd
## Each file is {name, rooms, code} like a blueprint library entry, so the library can place it.

func _init() -> void:
	var specs := [
		["general_store", "General store (shop, exchange, kitchen and two bedrooms)", DemoTown.store()],
		["cottage_2br", "Two-bedroom cottage", DemoTown.cottage("template", "Two-bedroom cottage", Vector2i.ZERO, 2)],
		["cottage_3br", "Three-bedroom family house", DemoTown.cottage("template", "Three-bedroom family house", Vector2i.ZERO, 3)]]
	for s: Array in specs:
		var h: HouseData = s[2]
		h.origin = Vector2i.ZERO
		h.id = ""
		h.name = str(s[1])
		var rooms := 0
		for l in h.levels():
			rooms += h.rooms(l).size()
		var f := FileAccess.open("res://data/houses/templates/%s.json" % s[0], FileAccess.WRITE)
		f.store_string(JSON.stringify({"name": s[1], "rooms": rooms, "template": true, "code": ShareCode.encode(h)}, "  "))
		f.close()
		print("wrote ", s[0], " rooms=", rooms)
	quit()
