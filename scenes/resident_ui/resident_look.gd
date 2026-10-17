class_name ResidentLook
extends RefCounted
## How a placeholder mannequin looks for a resident: which build (trousers or dress), height and
## breadth, and colours for its skin, hair, top, bottom and shoes, read from the appearance line in
## data/residents.json ("grey hair in a bun", "flannel shirt", "floral dress"...). Deterministic.

const HAIR := {"grey": "#99938A", "white": "#E4E0D8", "auburn": "#7A3A22", "fair": "#C9A86A", "dark": "#2E221A", "balding": "#8E7A66",
	"black": "#1C1814", "brown": "#5A3E2A", "red": "#8A3A1E"}
const TOPS := {"flannel": "#8E3B2F", "white shirt": "#EEEAE0", "cardigan": "#4A5468", "floral": "#C98A8E", "gingham": "#7E9CC4",
	"jacket": "#5A5446", "shirtsleeves": "#DCD6C6", "apron": "#E8E2D0", "dress": "#A87A6E", "work jacket": "#4E5A52"}
const BOTTOMS := {"dress": "#A87A6E", "floral": "#C98A8E", "gingham": "#7E9CC4", "braces": "#3E3A34", "apron": "#5A4E44"}
const SKIN := ["#E8C4A8", "#E0B898", "#D8AE8C", "#ECCAB0"]


static func for_resident(rid: String, d: Dictionary) -> Dictionary:
	var text := str(d.get("appearance", "")).to_lower()
	var female := str(d.get("sex", "m")) == "f"
	var h := absi(hash(rid))
	var look := {"model": str(d.get("model", "mannequin_f" if female else "mannequin_m")), "height": float(d.get("height", 1.62 if female else 1.76)),
		"build": float(d.get("build", 0.5)), "skin": SKIN[h % SKIN.size()], "shoes": "#2A1E16"}
	look["hair"] = _first(text, HAIR, "#5A3E2A")
	look["top"] = _first(text, TOPS, ["#7A8A9A", "#8A7A6A", "#6A7A5E", "#9A8A7A"][h % 4])
	look["bottom"] = _first(text, BOTTOMS, look["top"] if female else ["#3E4248", "#4A4038", "#3A3E3A"][h % 3])
	# Stockings under a dress, trouser legs otherwise (the MPFB models have a separate legs slot).
	look["legs"] = "#C9A48A" if female else look["bottom"]
	if int(d.get("age", 30)) >= 60 and not text.contains("hair"):
		look["hair"] = HAIR["grey"]
	return look


static func _first(text: String, table: Dictionary, fallback: Variant) -> String:
	var best := ""
	var best_at := 1 << 30
	for k: String in table:
		var at := text.find(k)
		if at >= 0 and (at < best_at or (at == best_at and k.length() > best.length())):
			best = k
			best_at = at
	return str(table[best]) if best != "" else str(fallback)


static var _mats: Dictionary = {}


## Puts a look on an instanced mannequin: slot colours, height and breadth.
static func apply(n: Node3D, look: Dictionary) -> void:
	var s := float(look["height"]) / 1.76
	var w := lerpf(0.88, 1.18, float(look["build"]))
	n.scale = Vector3(s * w, s, s * w)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var slot := m.resource_name if m else ""
			if not look.has(slot):
				continue
			var key := "%s:%s" % [slot, look[slot]]
			if not _mats.has(key):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(str(look[slot]))
				mat.roughness = 0.45 if slot == "skin" else (0.6 if slot == "shoes" else 0.9)
				_mats[key] = mat
			mi.set_surface_override_material(i, _mats[key])
