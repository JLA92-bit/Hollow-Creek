class_name Pulse
extends RefCounted
## Makes a control flash amber so the player can see which button to press next. With Reduce motion on
## it is simply held amber.

const AMBER := Color(1.0, 0.78, 0.2)


## Starts the flashing; keep the returned tween (or null) and give it to `stop`.
static func start(c: Control, owner_node: Node) -> Tween:
	c.modulate = AMBER
	if bool(Settings.get_value("reduce_motion")):
		return null
	var tw := owner_node.create_tween().set_loops()
	tw.tween_property(c, "modulate", Color.WHITE, 0.45)
	tw.tween_property(c, "modulate", AMBER, 0.45)
	return tw


static func stop(c: Control, tw: Tween) -> void:
	if tw != null:
		tw.kill()
	if is_instance_valid(c):
		c.modulate = Color.WHITE
