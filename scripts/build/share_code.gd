class_name ShareCode
extends RefCounted
## Share codes: a house and its garden as compact text ("HOLLOW1:<size>:<base64 deflate>") or a
## .hollow file holding the same text. Where it stood in the town (id, origin, base height) is left
## out, so a code drops into any save, story or sandbox.

const PREFIX := "HOLLOW1"
const FILE_EXT := "hollow"
## Fields that belong to the town rather than the design.
const PLACE_FIELDS: Array[String] = ["id", "origin", "base_y", "locked"]


## The design as a plain dictionary, with numbers in canonical JSON form.
static func design(h: HouseData) -> Dictionary:
	var d := h.to_dict()
	for k in PLACE_FIELDS:
		d.erase(k)
	return JSON.parse_string(JSON.stringify(d)) as Dictionary


## A string that's equal for two identical designs (for checking a round trip).
static func fingerprint(h: HouseData) -> String:
	return JSON.stringify(design(h), "", true)


static func encode(h: HouseData) -> String:
	var raw := JSON.stringify(design(h)).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return "%s:%d:%s" % [PREFIX, raw.size(), Marshalls.raw_to_base64(packed)]


## Reads a code (spaces and line breaks are ignored, so codes survive email and chat). Returns
## null when the code is broken.
static func decode(code: String) -> HouseData:
	var clean := ""
	for ch in code:
		if ch not in [" ", "\n", "\r", "\t"]:
			clean += ch
	var parts := clean.split(":", true, 2)
	if parts.size() != 3 or parts[0] != PREFIX or not parts[1].is_valid_int():
		return null
	var size := int(parts[1])
	if size <= 0 or size > 8 * 1024 * 1024:
		return null
	if parts[2].length() % 4 != 0 or not _is_base64(parts[2]):
		return null
	var packed := Marshalls.base64_to_raw(parts[2])
	if packed.is_empty():
		return null
	var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size:
		return null
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary or not (parsed as Dictionary).has("storeys"):
		return null
	var h := HouseData.from_dict(parsed as Dictionary)
	h.id = ""
	h.origin = Vector2i.ZERO
	h.base_y = NAN
	h.locked = false
	return h


static func _is_base64(t: String) -> bool:
	var re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	return re.search(t) != null


## Copies a design into a house that already has its place in the town (id, origin).
static func apply_to(h: HouseData, src: HouseData) -> void:
	var d := design(src)
	d["id"] = h.id
	d["origin"] = [h.origin.x, h.origin.y]
	d["base_y"] = null if is_nan(h.base_y) else h.base_y
	d["locked"] = false
	var copy := HouseData.from_dict(d)
	if copy.name == "":
		copy.name = h.name
	for prop: String in ["name", "foundation", "exterior", "storeys", "roof", "verandahs", "chimneys", "fixtures", "objects",
			"lights", "garden", "fences", "ground", "terrain", "quality", "_next_id"]:
		h.set(prop, copy.get(prop))
	h.touch()


## Roughly what building the design from scratch would cost in the story.
static func estimate_cost(h: HouseData) -> int:
	var total := 0
	for l in h.levels():
		for k: String in h.walls(l):
			total += Pieces.cost("wall_half" if str((h.walls(l)[k] as Dictionary).get("kind", "full")) != "full" else "wall_weatherboard")
		for tk: String in h.floors(l):
			var fm: Variant = (h.floors(l)[tk] as Dictionary).get("m", "floor_boards")
			total += Pieces.cost(str(fm)) if fm is String else 1
		for o: Dictionary in h.openings(l):
			total += Pieces.cost(str(o.get("style", o.get("kind", ""))))
		for st: Dictionary in h.stairs(l):
			total += Pieces.cost("stairs_" + str(st.get("kind", "straight")))
	for p: Dictionary in Roofs.pieces(h):
		total += Roofs.cost(p)
	for v: Dictionary in h.verandahs:
		total += BuildOps._verandah_cost(v)
	total += h.chimneys.size() * Pieces.cost("chimney")
	for it: Dictionary in h.garden:
		total += int(GardenOps.item_def(str(it["kind"])).get("cost", 1))
	total += h.fences.size()
	return total
