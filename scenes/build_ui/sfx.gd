class_name Sfx
extends Node
## A small pool of players for UI sounds (assets/audio/ui/*.wav).

const NAMES: Array[String] = ["click", "tick", "place", "remove", "error", "undo", "storey"]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load("res://assets/audio/ui/%s.wav" % n)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)


func play(name: String, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(float(Settings.get_value("master_volume")), 0.001))
	p.play()
