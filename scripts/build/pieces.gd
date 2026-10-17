class_name Pieces
extends RefCounted
## Structural pieces from data/pieces.json: names, costs and defaults.

const PATH := "res://data/pieces.json"

static var _data: Dictionary = {}


static func all() -> Dictionary:
	if _data.is_empty():
		_data = (JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary)["pieces"]
	return _data


static func get_piece(id: String) -> Dictionary:
	return all().get(id, {})


static func cost(id: String) -> int:
	return int(get_piece(id).get("cost", 0))


static func of_category(cat: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in all():
		if str(all()[k].get("category", "")) == cat:
			out.append(k)
	return out
