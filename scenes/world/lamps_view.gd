class_name LampsView
extends Node3D
## The street lamps standing in the valley (GameState.lamps): a pole each, and from dusk to dawn a
## warm glow, a bright bulb and a light that fades out with distance from the camera.

const MODEL := "res://assets/models/props/street_lamp.glb"
const GLOW := Color("#FFD9A0")

var grid: WorldGrid
var world: Node3D
var _bulb_mat: StandardMaterial3D
var _lamps: Array[Dictionary] = []   ## {node, light}
var _sig := ""
var _scene: PackedScene


func _ready() -> void:
	_scene = load(MODEL) as PackedScene
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = Color("#FFF3D0")
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = GLOW
	_bulb_mat.emission_energy_multiplier = 0.0


func refresh() -> void:
	var sig := JSON.stringify(GameState.lamps)
	if sig == _sig:
		return
	_sig = sig
	for l in _lamps:
		(l["node"] as Node).queue_free()
	_lamps.clear()
	for p: Array in GameState.lamps:
		var n := _scene.instantiate() as Node3D
		n.position = Vector3(float(p[0]), grid.height_at(float(p[0]), float(p[1])), float(p[1]))
		n.rotation.y = fmod(float(p[0]) * 12.9898 + float(p[1]) * 78.233, TAU)   # a little variety
		add_child(n)
		_dress(n)
		var light := OmniLight3D.new()
		light.position = Vector3(0.6, 3.7, 0.0)
		light.light_color = GLOW
		light.omni_range = LampOps.REACH + 2.0
		light.light_energy = 0.0
		light.distance_fade_enabled = true
		light.distance_fade_begin = 28.0
		light.distance_fade_length = 14.0
		n.add_child(light)
		_lamps.append({"node": n, "light": light})


## Slot colours: timber pole, black iron arm, cream enamel shade, glowing glass.
func _dress(n: Node) -> void:
	var cols := {"timber": Color("#5B4630"), "iron": Color("#1E1E1E"), "enamel": Color("#E8E2D0")}
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var slot := mi.mesh.surface_get_material(i).resource_name if mi.mesh.surface_get_material(i) else ""
			if slot == "glass":
				mi.set_surface_override_material(i, _bulb_mat)
			elif cols.has(slot):
				var m := StandardMaterial3D.new()
				m.albedo_color = cols[slot]
				m.roughness = 0.8
				mi.set_surface_override_material(i, m)


func _process(_delta: float) -> void:
	var night := 1.0 - AudioDirector.daylight(Clock.minute_f())
	_bulb_mat.emission_energy_multiplier = night * 3.0
	for l in _lamps:
		(l["light"] as OmniLight3D).light_energy = night * 1.1
