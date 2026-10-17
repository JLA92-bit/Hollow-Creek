extends Node
## Versioned JSON saves in user:// (IndexedDB on the web), plus save codes for export and import.

const SAVE_VERSION := 1
const DIR := "user://saves"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func build_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"game_version": GameState.version(),
		"game": GameState.to_dict(),
		"clock": Clock.to_dict(),
		"sim": SimHost.snapshot(),
	}


func apply_save(data: Dictionary) -> bool:
	var migrated := migrate(data)
	if migrated.is_empty():
		return false
	GameState.from_dict(migrated.get("game", {}))
	Clock.from_dict(migrated.get("clock", {}))
	SimHost.restore(migrated.get("sim", {}))
	return true


## Upgrades older saves in place. Returns an empty dictionary when the save can't be read.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", 0))
	if v < 1 or v > SAVE_VERSION:
		return {}
	return data


func save_slot(slot: String) -> Error:
	var f := FileAccess.open("%s/%s.json" % [DIR, slot], FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(build_save()))
	f.close()
	EventBus.save_completed.emit(slot)
	return OK


func load_slot(slot: String) -> bool:
	var path := "%s/%s.json" % [DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var ok := apply_save(parsed as Dictionary)
	if ok:
		EventBus.load_completed.emit(slot)
	return ok


## Compressed, base64 text that players can copy out of the browser and paste back in.
static func encode_code(data: Dictionary) -> String:
	var raw := JSON.stringify(data).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return "HC%d:%d:%s" % [SAVE_VERSION, raw.size(), Marshalls.raw_to_base64(packed)]


static func decode_code(code: String) -> Dictionary:
	var parts := code.strip_edges().split(":", true, 2)
	if parts.size() != 3 or not parts[0].begins_with("HC"):
		return {}
	var packed := Marshalls.base64_to_raw(parts[2])
	var raw := packed.decompress(int(parts[1]), FileAccess.COMPRESSION_DEFLATE)
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}
