class_name Blueprints
extends RefCounted
## The blueprint library: saved designs in user://blueprints, each a small JSON file holding a name,
## the date it was saved and its share code. Imported codes land here too.

const DIR := "user://blueprints"


static func _safe(name: String) -> String:
	var out := ""
	for ch in name.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	return out.strip_edges().substr(0, 40) if out != "" else "house"


## Saves a design and returns its file name.
static func save(name: String, h: HouseData) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var base := _safe(name)
	var file := "%s.json" % base
	var n := 2
	while FileAccess.file_exists("%s/%s" % [DIR, file]):
		file = "%s_%d.json" % [base, n]
		n += 1
	var f := FileAccess.open("%s/%s" % [DIR, file], FileAccess.WRITE)
	if f == null:
		return ""
	var rooms := 0
	for l in h.levels():
		rooms += h.rooms(l).size()
	f.store_string(JSON.stringify({"name": name, "saved": Time.get_date_string_from_system(), "rooms": rooms,
		"code": ShareCode.encode(h)}))
	f.close()
	return file


## Every blueprint, newest name first: [{file, name, saved, rooms, code}].
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for file in d.get_files():
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, file]))
		if parsed is Dictionary and (parsed as Dictionary).has("code"):
			var e := (parsed as Dictionary).duplicate()
			e["file"] = file
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return out


static func load_design(file: String) -> HouseData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, file]))
	if not parsed is Dictionary:
		return null
	return ShareCode.decode(str((parsed as Dictionary).get("code", "")))


static func remove(file: String) -> bool:
	return DirAccess.remove_absolute("%s/%s" % [DIR, file]) == OK
