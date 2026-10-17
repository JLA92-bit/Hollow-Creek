class_name WorldGrid
extends RefCounted
## The logical grid: the source of truth for the town (docs/BUILDING.md). 1 tile is 1 metre.
## x runs east, y runs south. In 3D, x is X and y is Z. Walls, doors and windows live on tile edges.

enum Dir { N, E, S, W }

var width: int
var height: int
var ground: PackedByteArray
var wet: PackedByteArray      ## 0 to 255 for 0 to 1
var light: PackedByteArray    ## 0 to 255 for 0 to 1
var heights: PackedFloat32Array  ## Terrain height at tile corners, (width + 1) x (height + 1)
var occupant: Dictionary = {}    ## tile index -> object id
var edges: Dictionary = {}       ## edge key -> piece Dictionary
var objects: Array[Dictionary] = []  ## trees, rocks, landmarks: {id, kind, x, y, ...}


func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h
	ground = PackedByteArray()
	ground.resize(w * h)
	wet = PackedByteArray()
	wet.resize(w * h)
	light = PackedByteArray()
	light.resize(w * h)
	heights = PackedFloat32Array()
	heights.resize((w + 1) * (h + 1))


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func idx(x: int, y: int) -> int:
	return y * width + x


func get_ground(x: int, y: int) -> Ground.Type:
	return ground[idx(x, y)] as Ground.Type


func set_ground(x: int, y: int, t: Ground.Type) -> void:
	ground[idx(x, y)] = t


func get_wet(x: int, y: int) -> float:
	return wet[idx(x, y)] / 255.0


func set_wet(x: int, y: int, v: float) -> void:
	wet[idx(x, y)] = int(round(clampf(v, 0.0, 1.0) * 255.0))


func get_light(x: int, y: int) -> float:
	return light[idx(x, y)] / 255.0


func set_light(x: int, y: int, v: float) -> void:
	light[idx(x, y)] = int(round(clampf(v, 0.0, 1.0) * 255.0))


func corner_height(cx: int, cy: int) -> float:
	cx = clampi(cx, 0, width)
	cy = clampi(cy, 0, height)
	return heights[cy * (width + 1) + cx]


func set_corner_height(cx: int, cy: int, h: float) -> void:
	heights[cy * (width + 1) + cx] = h


## Bilinear terrain height at a world position (metres).
func height_at(px: float, pz: float) -> float:
	var x0 := clampi(floori(px), 0, width - 1)
	var z0 := clampi(floori(pz), 0, height - 1)
	var fx := clampf(px - x0, 0.0, 1.0)
	var fz := clampf(pz - z0, 0.0, 1.0)
	var a := lerpf(corner_height(x0, z0), corner_height(x0 + 1, z0), fx)
	var b := lerpf(corner_height(x0, z0 + 1), corner_height(x0 + 1, z0 + 1), fx)
	return lerpf(a, b, fz)


## Every edge has one canonical key: the north or west side of a tile.
## The south side of (x, y) is the north side of (x, y + 1); the east side is the west side of (x + 1, y).
static func edge_key(x: int, y: int, side: Dir) -> String:
	match side:
		Dir.S:
			return "%d,%d,N" % [x, y + 1]
		Dir.E:
			return "%d,%d,W" % [x + 1, y]
		Dir.N:
			return "%d,%d,N" % [x, y]
		_:
			return "%d,%d,W" % [x, y]


func set_edge(x: int, y: int, side: Dir, piece: Dictionary) -> void:
	edges[edge_key(x, y, side)] = piece


func get_edge(x: int, y: int, side: Dir) -> Dictionary:
	return edges.get(edge_key(x, y, side), {})


func clear_edge(x: int, y: int, side: Dir) -> void:
	edges.erase(edge_key(x, y, side))


func add_object(obj: Dictionary) -> void:
	objects.append(obj)
	if obj.get("blocks", false):
		occupant[idx(int(obj["x"]), int(obj["y"]))] = str(obj["id"])


func count_ground(t: Ground.Type) -> int:
	return ground.count(t)


func to_dict() -> Dictionary:
	var occ := {}
	for k: int in occupant:
		occ[str(k)] = occupant[k]
	return {
		"width": width,
		"height": height,
		"ground": Marshalls.raw_to_base64(ground.compress(FileAccess.COMPRESSION_DEFLATE)),
		"wet": Marshalls.raw_to_base64(wet.compress(FileAccess.COMPRESSION_DEFLATE)),
		"light": Marshalls.raw_to_base64(light.compress(FileAccess.COMPRESSION_DEFLATE)),
		"heights": Marshalls.raw_to_base64(heights.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE)),
		"occupant": occ,
		"edges": edges.duplicate(true),
		"objects": objects.duplicate(true),
	}


static func from_dict(d: Dictionary) -> WorldGrid:
	var w := int(d.get("width", 0))
	var h := int(d.get("height", 0))
	var g := WorldGrid.new(w, h)
	g.ground = Marshalls.base64_to_raw(str(d["ground"])).decompress(w * h, FileAccess.COMPRESSION_DEFLATE)
	g.wet = Marshalls.base64_to_raw(str(d["wet"])).decompress(w * h, FileAccess.COMPRESSION_DEFLATE)
	g.light = Marshalls.base64_to_raw(str(d["light"])).decompress(w * h, FileAccess.COMPRESSION_DEFLATE)
	g.heights = Marshalls.base64_to_raw(str(d["heights"])).decompress((w + 1) * (h + 1) * 4, FileAccess.COMPRESSION_DEFLATE).to_float32_array()
	var occ: Dictionary = d.get("occupant", {})
	for k: String in occ:
		g.occupant[int(k)] = str(occ[k])
	g.edges = (d.get("edges", {}) as Dictionary).duplicate(true)
	for o: Variant in d.get("objects", []):
		g.objects.append((o as Dictionary).duplicate(true))
	return g
