class_name UndoStack
extends RefCounted
## Unlimited undo and redo for the session. Each step stores a house's state before and after an edit
## (null when the house didn't exist), so any edit, however complex, reverses exactly.

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


## Records a finished edit. before and after are HouseData.to_dict() results (or null).
func push(label: String, house_id: String, before: Variant, after: Variant, cost: int = 0) -> void:
	_undo.append({"label": label, "house": house_id, "before": before, "after": after, "cost": cost})
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


## Returns {label, house, state} to restore (state null means delete the house), or {}.
func undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	var step: Dictionary = _undo.pop_back()
	_redo.append(step)
	return {"label": step["label"], "house": step["house"], "state": step["before"], "refund": int(step.get("cost", 0))}


func redo() -> Dictionary:
	if _redo.is_empty():
		return {}
	var step: Dictionary = _redo.pop_back()
	_undo.append(step)
	return {"label": step["label"], "house": step["house"], "state": step["after"], "charge": int(step.get("cost", 0))}


func size() -> int:
	return _undo.size()


func next_undo_label() -> String:
	return str(_undo.back()["label"]) if not _undo.is_empty() else ""


func next_redo_label() -> String:
	return str(_redo.back()["label"]) if not _redo.is_empty() else ""


func clear() -> void:
	_undo.clear()
	_redo.clear()
