class_name CharacterAnims
extends RefCounted
## The shared animation set (assets/characters/animations.glb: the Quaternius Universal Animation
## Library retargeted onto the MPFB rig by tools/characters/retarget_ual.py). It's loaded once and
## added to every resident, so the resident models carry no animations of their own. The placeholder
## mannequins keep theirs.

const PATH := "res://assets/characters/animations.glb"
## Animations that repeat; the rest play once.
const LOOPS: Array[String] = ["idle", "walk", "walk_formal", "jog", "talk", "sit", "sit_talk", "crouch", "sneak", "interact", "dance", "push", "torch"]

static var _lib: AnimationLibrary


static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var scene := load(PATH) as PackedScene
	if scene == null:
		return _lib
	var root := scene.instantiate()
	var found := root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		var p := found[0] as AnimationPlayer
		for n in p.get_animation_list():
			var a := p.get_animation(n).duplicate() as Animation
			a.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(n) else Animation.LOOP_NONE
			_lib.add_animation(n, a)
	root.free()
	return _lib


## Gives a model the shared animations and returns its player, or its own player if it brought
## idle and walk with it (the mannequins).
static func attach(model: Node3D) -> AnimationPlayer:
	var own := model.find_children("*", "AnimationPlayer", true, false)
	if not own.is_empty():
		var p := own[0] as AnimationPlayer
		if p.has_animation("walk") and p.has_animation("idle"):
			for a in ["idle", "walk"]:
				p.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			return p
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", library())
	return player


## Which animation a resident should be playing: what they're doing, whether they're walking, how old.
static func pick(kind: String, walking: bool, pose: String, age: int) -> String:
	if walking:
		if kind == "sneak":
			return "sneak"
		return "walk_formal" if age >= 62 else "walk"
	if pose == "sit":
		return "sit"
	match kind:
		"dance":
			return "dance"
		"sneak":
			return "crouch"
		"cook", "snack", "garden", "potter", "shop", "work", "fish":
			return "interact"
	return "idle"
