class_name AudioDirector
extends Node
## The sound of the valley: birds by day and crickets by night, crossfaded over the dusk and dawn
## hours; rain when it rains; and during the welcome dance, the band from the mill shed, fading
## with distance from it. Also plays one-shot story cues (a trace found, the alert, a case solved).
## Everything is our own synthesis (tools/audio/make_world_audio.py).

const DIR := "res://assets/audio/world/"
const MUSIC_DIR := "res://assets/audio/music/"
const SILENT := -60.0
const MILL_HEARD_M := 70.0

var world: Node3D
var day_player: AudioStreamPlayer
var night_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_next := 0
var _cues: Dictionary = {}

static var instance: AudioDirector


func _ready() -> void:
	instance = self
	day_player = _loop(DIR + "ambience_day.ogg")
	night_player = _loop(DIR + "ambience_night.ogg")
	rain_player = _loop(DIR + "rain.ogg")
	_start_music()
	if music_player == null:
		ContentPacks.pack_loaded.connect(func(n: String) -> void: _start_music() if n == "music" else null)
		ContentPacks.request("music")
	for name in ["search", "found", "alert", "phone", "solved", "knock"]:
		_cues[name] = load(DIR + name + ".ogg")
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_cue_players.append(p)
	SimHost.case_opened.connect(func(_i: Investigation) -> void: cue("alert"))
	SimHost.case_closed.connect(func(_r: Dictionary) -> void: cue("solved"))


func _start_music() -> void:
	if music_player == null and ResourceLoader.exists(MUSIC_DIR + "music_dance.ogg"):
		music_player = _loop(MUSIC_DIR + "music_dance.ogg")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := load(path) as AudioStreamOggVorbis
	if s != null:
		s.loop = true
	p.stream = s
	p.volume_db = SILENT
	p.autoplay = false
	add_child(p)
	p.play()
	return p


## 0 at night, 1 by day, easing across the hour either side of sunrise (6 am) and sunset (6:30 pm).
static func daylight(minute: float) -> float:
	var up := clampf((minute - 5.5 * 60.0) / 60.0, 0.0, 1.0)
	var down := clampf((19.0 * 60.0 - minute) / 60.0, 0.0, 1.0)
	return minf(up, down)


static func db_for(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001)) if linear > 0.001 else SILENT


## Is the band playing? (The prologue's welcome dance: Saturday 7:30 to 11 pm.)
static func dance_on() -> bool:
	var n: Dictionary = SimHost.night
	if n.is_empty() or int(n.get("anchor", -1)) < 0:
		return false
	var at := int(n["anchor"]) * 1440 + CashTinNight.DANCE_FROM
	var now := Clock.day * 1440 + Clock.minute
	return now >= at and now < int(n["anchor"]) * 1440 + 23 * 60


func _process(_delta: float) -> void:
	var d := daylight(Clock.minute_f())
	var rain_i := 0.0
	var rain_node: Node = world.get("rain") if world else null
	if rain_node != null:
		rain_i = clampf(float(rain_node.get("intensity")), 0.0, 1.0)
	day_player.volume_db = db_for(d * (1.0 - 0.6 * rain_i) * 0.5)
	night_player.volume_db = db_for((1.0 - d) * (1.0 - 0.6 * rain_i) * 0.45)
	rain_player.volume_db = db_for(rain_i * 0.8)
	if music_player != null:
		var vol := 0.0
		if dance_on() and world != null and SimHost.sim != null and SimHost.sim.town != null:
			var mill: Array = SimHost.sim.town.landmark_tiles.get("lm_mill", [])
			var rig: Node = world.get("rig")
			if not mill.is_empty() and rig != null:
				var f: Vector3 = rig.get("focus")
				var dist := Vector2(f.x, f.z).distance_to(Vector2(float(mill[1]), float(mill[2])))
				vol = clampf(1.0 - dist / MILL_HEARD_M, 0.0, 1.0) * 0.6
		music_player.volume_db = db_for(vol)


## A one-shot sound: "search", "found", "alert", "phone", "solved" or "knock".
func cue(name: String) -> void:
	if not _cues.has(name):
		return
	var p := _cue_players[_cue_next]
	_cue_next = (_cue_next + 1) % _cue_players.size()
	p.stream = _cues[name]
	p.volume_db = -3.0
	p.play()


static func play_cue(name: String) -> void:
	if instance != null:
		instance.cue(name)
