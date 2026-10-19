extends Node
## Background packs in the browser: the music pack isn't in the first download, so it has to be
## fetched and mounted at run time. Prints HC_DEMO lines (?scene=packs_demo).

var failures := 0
var checks := 0


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("HC_DEMO ", "PASS " if ok else "FAIL ", text)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var web := OS.has_feature("web")
	var was_there := ContentPacks.is_loaded("music")
	_check(was_there != web, "the music pack is %s at start (%s)" % ["absent" if web else "present", "web build" if web else "desktop"])
	var t0 := Time.get_ticks_msec()
	if not was_there:
		var st := {"done": false, "ok": true}   # a lambda captures plain variables by value, so share a Dictionary
		ContentPacks.pack_loaded.connect(func(_n: String) -> void: st["done"] = true)
		ContentPacks.pack_failed.connect(func(_n: String) -> void:
			st["done"] = true
			st["ok"] = false)
		ContentPacks.request("music")
		var guard := 0
		while not bool(st["done"]) and guard < 3000:
			await get_tree().process_frame
			guard += 1
		_check(bool(st["ok"]) and bool(st["done"]), "the pack downloaded and mounted in %d ms" % (Time.get_ticks_msec() - t0))
	_check(ContentPacks.is_loaded("music"), "the pack's marker resource now exists")
	var s := load("res://assets/audio/music/music_dance.ogg") as AudioStreamOggVorbis
	_check(s != null and s.get_length() > 20.0, "the dance music loads (%.0f s)" % (s.get_length() if s else 0.0))
	_check(ContentPacks.progress("music") == 1.0, "progress reads 1 once loaded")
	print("HC_DEMO_RESULT ", "PASS" if failures == 0 else "FAIL", " ", checks - failures, "/", checks)
	print("HC_DONE")
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)
