class_name Catalogue
extends RefCounted
## The Buy mode catalogue (data/catalogue.json): items, search and filters, model paths, material
## slots and light colours. Plain class; the view applies slots to instanced models.

const PATH := "res://data/catalogue.json"
const MODELS := "res://assets/models/%s"
## Library material categories the Design tool offers for a slot.
const DESIGN_CATEGORIES: Array[String] = ["timber", "metal", "fabric", "plastic", "ceramic", "glass"]

static var _data: Dictionary = {}
static var _by_model: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary
		for id: String in _data["items"]:
			_by_model[str(_data["items"][id]["model"])] = id
	return _data


static func items() -> Dictionary:
	return data()["items"]


static func item(id: String) -> Dictionary:
	return items().get(id, {})


## The catalogue id for a placed object (older saves only stored the model).
static func id_of(o: Dictionary) -> String:
	if o.has("item"):
		return str(o["item"])
	data()
	return str(_by_model.get(str(o.get("model", "")), ""))


static func model_path(model: String) -> String:
	if model.begins_with("props/"):
		return (MODELS % model) + ".glb"
	return MODELS % ("%s/%s.gltf" % [model, model])


## Items matching a search: words in the name or note, a room, a function, a top price, a style tag.
## Empty filters match everything. Sorted by name.
static func search(query: String = "", room: String = "", function: String = "", max_price: int = 0, tag: String = "") -> Array[String]:
	var out: Array[String] = []
	var words := query.to_lower().split(" ", false)
	for id: String in items():
		var it: Dictionary = items()[id]
		if room != "" and not ((it.get("rooms", []) as Array).has(room) or (it.get("rooms", []) as Array).has("any")):
			continue
		if function != "" and str(it.get("function", "")) != function:
			continue
		if max_price > 0 and int(it.get("price", 0)) > max_price:
			continue
		if tag != "" and not (it.get("tags", []) as Array).has(tag):
			continue
		var text := ("%s %s %s" % [it.get("name", ""), it.get("note", ""), id]).to_lower()
		var ok := true
		for w in words:
			if not text.contains(w):
				ok = false
		if ok:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return str(items()[a]["name"]) < str(items()[b]["name"]))
	return out


## A slot's material and colour on a placed object: the object's own choice, else the default.
static func slot_value(o: Dictionary, slot: String) -> Dictionary:
	var it := item(id_of(o))
	var d: Dictionary = (it.get("slots", {}) as Dictionary).get(slot, {"mat": "", "colour": "#FFFFFF"})
	var own: Dictionary = (o.get("slots", {}) as Dictionary).get(slot, {})
	var v := d.duplicate()
	v.merge(own, true)
	return v


## Library materials the Design tool offers, grouped by category: {category: [id, ...]}.
static func design_materials() -> Dictionary:
	var out: Dictionary = {}
	var mats: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json")) as Dictionary)["materials"]
	for id: String in mats:
		var cat := str(mats[id].get("category", ""))
		if cat in DESIGN_CATEGORIES:
			if not out.has(cat):
				out[cat] = []
			(out[cat] as Array).append(id)
	return out


## Colour of a black-body light at a colour temperature (Kelvin), for lamps and candles.
static func kelvin_colour(k: float) -> Color:
	var t := clampf(k, 1000.0, 10000.0) / 100.0
	var r := 1.0 if t <= 66.0 else clampf(1.292936 * pow(t - 60.0, -0.1332047592), 0.0, 1.0)
	var g := clampf(0.39008158 * log(t) - 0.63184144, 0.0, 1.0) if t <= 66.0 else clampf(1.129890861 * pow(t - 60.0, -0.0755148492), 0.0, 1.0)
	var b := 1.0 if t >= 66.0 else (0.0 if t <= 19.0 else clampf(0.543206789 * log(t - 10.0) - 1.19625409, 0.0, 1.0))
	return Color(r, g, b)


## The light a placed object gives, with the object's own brightness and colour temperature:
## {kind, energy, range, kelvin, at} or {}.
static func light_of(o: Dictionary) -> Dictionary:
	# M1 houses light their lamps from HouseData.lights; only Buy mode objects light themselves.
	if not o.has("item"):
		return {}
	var it := item(id_of(o))
	if not it.has("light"):
		return {}
	var l: Dictionary = (it["light"] as Dictionary).duplicate()
	if o.get("light") is Dictionary:
		l.merge(o["light"], true)
	return l
