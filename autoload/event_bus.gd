extends Node
## Global signals. Systems talk through these rather than holding references to each other.

signal game_started(mode: String)
signal time_changed(day: int, minute: int)
signal speed_changed(speed: int)
signal settings_changed(key: String, value: Variant)
signal save_completed(slot: String)
signal load_completed(slot: String)
signal toast_requested(text: String)
