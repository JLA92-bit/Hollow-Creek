extends Node
## Background content packs (data/packs.json): extra resources downloaded after the game starts, so
## the first download stays small. On the web a pack is fetched over HTTP (packs/<name>.pck, next
## to index.html), saved in user:// and mounted; everywhere else the files are already in the
## project, so every pack counts as loaded. Callers ask `is_loaded()` and listen for `pack_loaded`.

signal pack_loaded(name: String)
signal pack_failed(name: String)

const PATH := "res://data/packs.json"

var packs: Dictionary = {}
var _loading: Dictionary = {}   ## name -> HTTPRequest


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		for k: String in parsed:
			if not k.begins_with("_"):
				packs[k] = parsed[k]


func is_loaded(name: String) -> bool:
	return packs.has(name) and ResourceLoader.exists(str((packs[name] as Dictionary)["marker"]))


## Starts loading a pack if it isn't there. Emits pack_loaded(name) when it is (at once if it already is).
func request(name: String) -> void:
	if not packs.has(name):
		pack_failed.emit(name)
		return
	if is_loaded(name):
		pack_loaded.emit.call_deferred(name)
		return
	if _loading.has(name):
		return
	if not OS.has_feature("web"):
		pack_failed.emit.call_deferred(name)   # a desktop build without the files can't fetch them
		return
	var req := HTTPRequest.new()
	add_child(req)
	_loading[name] = req
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void: _done(name, result, code, body))
	var err := req.request(_url(str((packs[name] as Dictionary)["file"])))
	if err != OK:
		_loading.erase(name)
		req.queue_free()
		pack_failed.emit(name)


## Packs sit next to index.html; HTTPRequest wants an absolute address, so ask the page where it is.
func _url(file: String) -> String:
	if OS.has_feature("web"):
		var abs: Variant = JavaScriptBridge.eval("new URL('%s', document.baseURI).href" % file)
		if abs != null and str(abs) != "":
			return str(abs)
	return file


## How much of a pack has downloaded, 0 to 1 (1 once loaded).
func progress(name: String) -> float:
	if is_loaded(name):
		return 1.0
	var req: HTTPRequest = _loading.get(name)
	if req == null:
		return 0.0
	var total := req.get_body_size()
	return float(req.get_downloaded_bytes()) / float(total) if total > 0 else 0.0


func _done(name: String, result: int, code: int, body: PackedByteArray) -> void:
	var req: HTTPRequest = _loading.get(name)
	_loading.erase(name)
	if req != null:
		req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		push_warning("Pack %s: download failed (result %d, status %d)" % [name, result, code])
		pack_failed.emit(name)
		return
	var path := "user://pack_%s.pck" % name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		pack_failed.emit(name)
		return
	f.store_buffer(body)
	f.close()
	if ProjectSettings.load_resource_pack(path):
		pack_loaded.emit(name)
	else:
		pack_failed.emit(name)
