extends Node
## The Android app's update check. A short while after the game starts (and again whenever the app is
## reopened, at most every six hours) it reads version.json from the test site. When that names a newer
## version it offers a card with the release notes and a Download button, which opens the new APK in
## the browser; Android then asks the player to confirm the install. Other platforms do nothing: the
## web build updates itself and desktop builds are run from the project.

signal update_available(info: Dictionary)

const CONFIG := "res://data/update.json"
const FIRST_CHECK_DELAY := 4.0
const RECHECK_SECONDS := 6 * 3600

var info: Dictionary = {}   ## the newer release, once one is found: version, apk (absolute address), notes
var _last_check := 0
var _card: CanvasLayer


func _ready() -> void:
	if not OS.has_feature("android"):
		return
	get_tree().create_timer(FIRST_CHECK_DELAY).timeout.connect(check)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and OS.has_feature("android"):
		if int(Time.get_unix_time_from_system()) - _last_check > RECHECK_SECONDS:
			check()


## Fetches version.json and, if it names a newer version than this one, emits update_available.
func check() -> void:
	var url := _version_url()
	if url == "":
		return
	_last_check = int(Time.get_unix_time_from_system())
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		_on_version_json(url, body.get_string_from_utf8()))
	# A changing query keeps phones and proxies from handing back an old copy.
	if req.request("%s?t=%d" % [url, _last_check]) != OK:
		req.queue_free()


func _on_version_json(url: String, body: String) -> void:
	var found := newer_release(body, GameState.version(), url)
	if found.is_empty() or str(found["version"]) == str(Settings.get_value("update_dismissed")):
		return
	info = found
	update_available.emit(found)
	_show_card(found)


func _version_url() -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return str((parsed as Dictionary).get("version_url", "")) if parsed is Dictionary else ""


# --- Rules (static, so they can be tested without a network) ------------------------------------

## "0.10.2" becomes [0, 10, 2]. Anything that isn't dotted numbers gives an empty array.
static func parse_version(v: String) -> Array[int]:
	var out: Array[int] = []
	for part in v.strip_edges().trim_prefix("v").split(".", false):
		if not part.is_valid_int():
			return [] as Array[int]
		out.append(int(part))
	return out


static func is_newer(remote: String, local: String) -> bool:
	var r := parse_version(remote)
	var l := parse_version(local)
	if r.is_empty() or l.is_empty():
		return false
	for i in maxi(r.size(), l.size()):
		var a := r[i] if i < r.size() else 0
		var b := l[i] if i < l.size() else 0
		if a != b:
			return a > b
	return false


## The release in a version.json body if it is newer than `local`, with its apk made absolute against
## the address version.json came from. Empty when it isn't newer or the file makes no sense.
static func newer_release(body: String, local: String, from_url: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(body) != OK or not json.data is Dictionary:
		return {}
	var d: Dictionary = json.data
	var version := str(d.get("version", ""))
	var apk := str(d.get("apk", ""))
	if apk == "" or not is_newer(version, local):
		return {}
	if not apk.begins_with("https://"):
		apk = from_url.get_base_dir().path_join(apk)
	if not apk.begins_with("https://"):
		return {}
	return {"version": version, "apk": apk, "notes": str(d.get("notes", ""))}


# --- The card -------------------------------------------------------------------------------------

func _show_card(release: Dictionary) -> void:
	if _card != null:
		return
	_card = CanvasLayer.new()
	_card.layer = 90
	add_child(_card)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(460, 0)
	panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = "Update available"
	box.add_child(title)
	box.add_child(_para("Hollow Creek %s is ready. You have %s." % [release["version"], GameState.version()]))
	if str(release["notes"]) != "":
		box.add_child(_para(str(release["notes"])))
	box.add_child(_para("Download opens the new version. Your saved game stays on this phone."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var later := Button.new()
	later.text = "Later"
	later.custom_minimum_size = Vector2(120, 48)
	later.pressed.connect(func() -> void:
		Settings.set_value("update_dismissed", str(release["version"]))
		_close())
	row.add_child(later)
	var get_it := Button.new()
	get_it.text = "Download"
	get_it.theme_type_variation = &"PrimaryButton"
	get_it.custom_minimum_size = Vector2(160, 48)
	get_it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_it.pressed.connect(func() -> void:
		OS.shell_open(str(release["apk"]))
		_close())
	row.add_child(get_it)


func _para(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	return l


func _close() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
