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
	# Full precision so the simulation carries on exactly as it would have.
	f.store_string(JSON.stringify(build_save(), "", false, true))
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
	if parts.size() != 3 or not parts[0].begins_with("HC") or not parts[1].is_valid_int():
		return {}
	var size := int(parts[1])
	var body: String = parts[2].strip_edges()
	var b64 := RegEx.new()
	b64.compile("^[A-Za-z0-9+/]+={0,2}$")
	if size <= 0 or size > 64 * 1024 * 1024 or body.length() % 4 != 0 or b64.search(body) == null:
		return {}
	var packed := Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return {}
	var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}


# --- Slots ---------------------------------------------------------------------------------------

const MANUAL_SLOTS: Array[String] = ["slot1", "slot2", "slot3"]


## What a slot holds, for the save list: {exists, mode, day, trust, version}.
static func slot_info(slot: String) -> Dictionary:
	var path := "%s/%s.json" % [DIR, slot]
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"exists": false}
	var d := parsed as Dictionary
	var g: Dictionary = d.get("game", {})
	return {"exists": true, "mode": str(g.get("mode", "story")), "day": int((d.get("clock", {}) as Dictionary).get("day", 0)),
		"trust": int(g.get("town_trust", 50)), "version": str(d.get("game_version", ""))}


## A line for the list: "Story, day 12, Town Trust 57" or "Empty".
static func slot_label(slot: String) -> String:
	var i := slot_info(slot)
	if not bool(i["exists"]):
		return "Empty"
	return "%s, day %d, Town Trust %d" % [str(i["mode"]).capitalize(), int(i["day"]), int(i["trust"])]


func export_code() -> String:
	return encode_code(build_save())


## Loads a pasted code into the game. Returns false if it doesn't read.
func import_code(code: String) -> bool:
	var d := decode_code(code)
	if d.is_empty():
		return false
	return apply_save(d)
