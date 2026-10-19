extends Node
## Top-level state of the current game: mode, money, Town Trust.

const MODE_STORY := "story"
const MODE_SANDBOX := "sandbox"

var mode: String = MODE_STORY
var money: int = 1500
var town_trust: int = 50
var seed_value: int = 1952
## Houses the player has built: id -> HouseData.to_dict(). Landmarks come from the map, not here.
var houses: Dictionary = {}
## Story-mode building projects: house id -> Construction project.
var construction: Dictionary = {}
## Roads and paths the player has laid: "x,y" -> "dirt" | "gravel" | "footpath" (scripts/build/road_ops.gd).
var roads: Dictionary = {}
## Street lamps the player has put up: [[x, y], ...] (scripts/build/lamp_ops.gd).
var lamps: Array = []
## Building crews in the town (docs/GAME_DESIGN.md: two to start).
var crews: int = 2
## Each home's history card: house id -> [{day, text}] (HomeLife.record).
var history: Dictionary = {}


## The autosave slot for this kind of game: story and sandbox saves are kept apart.
func save_slot() -> String:
	return "sandbox" if mode == MODE_SANDBOX else "autosave"


func is_sandbox() -> bool:
	return mode == MODE_SANDBOX


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func to_dict() -> Dictionary:
	return {"mode": mode, "money": money, "town_trust": town_trust, "seed": seed_value, "houses": houses.duplicate(true),
		"construction": construction.duplicate(true), "crews": crews, "history": history.duplicate(true), "roads": roads.duplicate(), "lamps": lamps.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	mode = str(d.get("mode", MODE_STORY))
	money = int(d.get("money", 1500))
	town_trust = int(d.get("town_trust", 50))
	seed_value = int(d.get("seed", 1952))
	houses = (d.get("houses", {}) as Dictionary).duplicate(true)
	construction = (d.get("construction", {}) as Dictionary).duplicate(true)
	crews = int(d.get("crews", 2))
	history = (d.get("history", {}) as Dictionary).duplicate(true)
	roads = (d.get("roads", {}) as Dictionary).duplicate()
	lamps = (d.get("lamps", []) as Array).duplicate(true)


func reset() -> void:
	mode = MODE_STORY
	money = 1500
	town_trust = 50
	houses.clear()
	construction.clear()
	history.clear()
	roads.clear()
	lamps.clear()
	crews = 2
