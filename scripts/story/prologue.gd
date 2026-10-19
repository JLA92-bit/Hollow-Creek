class_name Prologue
extends RefCounted
## The guided opening (docs/CASE_00_CASH_TIN.md): arrive, lay the road, build the store and three
## houses, approve the families, live the first week, solve The Cash Tin. A plain class: the host
## gives it a context each minute and it works out which steps are done. Steps finish in order.
##
## Context keys: road (bool), store {door, window, exchange: bool}, houses (int), families (int),
## day, minute, case_open (bool), case_done (bool). "ack" steps wait for acknowledge().

const PATH := "res://data/prologue.json"

var data: Dictionary
var step: int = 0                   ## index of the current step
var finished := false
var _acked: Dictionary = {}         ## step id -> true when the player pressed Continue
var _store: Dictionary = {}         ## the last store checklist, for the HUD


func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary


func steps() -> Array:
	return data["steps"]


func current() -> Dictionary:
	var s := steps()
	return s[step] if step < s.size() else {}


func current_id() -> String:
	return str(current().get("id", ""))


func is_locked(feature: String) -> bool:
	return not finished and (data["locked"] as Array).has(feature) and not _done("solve")


func _done(id: String) -> bool:
	var s := steps()
	for i in s.size():
		if str(s[i]["id"]) == id:
			return step > i or finished
	return false


## The player pressed Continue on an acknowledgement step.
func acknowledge() -> void:
	_acked[current_id()] = true


## The things the current step still needs, as [{text, done}], for the HUD.
func checklist() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match current_id():
		"store":
			for k: String in ["door", "window", "exchange"]:
				out.append({"text": {"door": "A front door onto the road", "window": "A back window facing the creek", "exchange": "A room for the exchange"}[k],
					"done": bool(_store.get(k, false))})
		"houses":
			out.append({"text": "Three houses built and furnished", "done": false})
	return out


## Works out which steps are now done. Returns the ids of the steps completed by this call.
func update(ctx: Dictionary) -> Array[String]:
	var done: Array[String] = []
	_store = ctx.get("store", {})
	while not finished and step < steps().size():
		var s: Dictionary = current()
		if not _met(str(s["check"]), s, ctx):
			break
		done.append(str(s["id"]))
		step += 1
		if step >= steps().size():
			finished = true
	return done


func _met(check: String, s: Dictionary, ctx: Dictionary) -> bool:
	match check:
		"ack":
			return bool(_acked.get(str(s["id"]), false))
		"road":
			return bool(ctx.get("road", false))
		"store":
			var st: Dictionary = ctx.get("store", {})
			return bool(st.get("door", false)) and bool(st.get("window", false)) and bool(st.get("exchange", false))
		"houses":
			return int(ctx.get("houses", 0)) >= 3
		"families":
			return int(ctx.get("families", 0)) >= 3
		"dance":
			var d: Dictionary = data["welcome_dance"]
			return int(ctx.get("day", 0)) * 1440 + int(ctx.get("minute", 0)) >= int(d["day"]) * 1440 + int(d["from"])
		"case_open":
			return bool(ctx.get("case_open", false)) or bool(ctx.get("case_done", false))
		"case_done":
			return bool(ctx.get("case_done", false))
	return false


func snapshot() -> Dictionary:
	return {"step": step, "finished": finished, "acked": _acked.duplicate()}


func restore(d: Dictionary) -> void:
	step = int(d.get("step", 0))
	finished = bool(d.get("finished", false))
	_acked = (d.get("acked", {}) as Dictionary).duplicate()
