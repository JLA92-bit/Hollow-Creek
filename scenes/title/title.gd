extends Control
## Title menu: continue the story autosave, start a new game, or open the Sandbox (its own save:
## unlimited money and instant building), or open settings, saves and credits.

@onready var _status: Label = %Status


func _ready() -> void:
	_start_music()
	if not ContentPacks.is_loaded("music"):
		ContentPacks.pack_loaded.connect(func(n: String) -> void: _start_music() if n == "music" else null)
		ContentPacks.request("music")
	var new_game: Button = %NewGame
	var sandbox: Button = %Sandbox
	var settings: Button = %Settings
	var has_story := FileAccess.file_exists("%s/autosave.json" % SaveSystem.DIR)
	var has_sandbox := FileAccess.file_exists("%s/sandbox.json" % SaveSystem.DIR)
	if has_story:
		var cont := Button.new()
		cont.text = "Continue"
		cont.custom_minimum_size = Vector2(0, 52)
		cont.theme_type_variation = &"PrimaryButton"
		cont.pressed.connect(func() -> void: _load("autosave"))
		new_game.get_parent().add_child(cont)
		new_game.get_parent().move_child(cont, new_game.get_index())
		new_game.theme_type_variation = &""
	new_game.text = "New game"
	new_game.pressed.connect(_new_game.bind(GameState.MODE_STORY))
	sandbox.text = "Sandbox" if not has_sandbox else "Sandbox (continue)"
	sandbox.tooltip_text = "Unlimited money and instant building, for pure designing."
	sandbox.disabled = false
	sandbox.pressed.connect(func() -> void:
		if has_sandbox:
			_load("sandbox")
		else:
			_new_game(GameState.MODE_SANDBOX))
	settings.disabled = false
	settings.pressed.connect(func() -> void:
		var s := SettingsScreen.new()
		s.loaded.connect(_open_world)
		add_child(s))
	_status.text = "Press Build (or B) to build. Right-drag or two fingers to look around, R for rain, F2 for photos."


var _music: AudioStreamPlayer


## The title theme, from the music pack (it arrives a moment after the menu on the web).
func _start_music() -> void:
	if _music != null or not ContentPacks.is_loaded("music"):
		return
	var stream := load("res://assets/audio/music/music_title.ogg") as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -8.0
	add_child(_music)
	_music.play()


## Shows the loading screen first and lets it draw, so the player sees something happening while the
## valley builds instead of a frozen title.
func _open_world() -> void:
	LoadingScreen.show_loading("Opening the valley")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")


func _load(slot: String) -> void:
	LoadingScreen.show_loading("Reading your saved game")
	await get_tree().process_frame
	await get_tree().process_frame
	if SaveSystem.load_slot(slot):
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")
	else:
		LoadingScreen.hide_loading()


func _new_game(mode: String) -> void:
	LoadingScreen.show_loading("Starting a new game")
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.reset()
	SimHost.reset()
	GameState.mode = mode
	if mode == GameState.MODE_STORY:
		SimHost.begin_prologue()
	Clock.from_dict({"day": 0, "minute": 360})
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")
