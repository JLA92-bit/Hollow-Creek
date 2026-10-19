"""The MPFB character pipeline (docs/ASSET_SOURCES.md), proven on one resident: Agnes Doyle.

MakeHuman for Blender (MPFB 2, CC0 base mesh, targets and rigs) builds a 67-year-old woman of
Agnes's height and build, with the light "game engine" skeleton. The skirt helper becomes her dress;
the body is split into material slots by which bone moves it (skin, hair, top, bottom, legs, shoes),
so the game colours her like the mannequins. Decimated to under 10,000 triangles (LOD0) and 3,000
(LOD1), with the same idle, walk and sit animations as the placeholders.

Usage: bash tools/characters/setup_mpfb.sh, then
       tools/cache/blender-venv/bin/python tools/characters/make_agnes.py
Writes assets/characters/agnes.glb and agnes_lod1.glb.
"""
import importlib
import math
import sys
from pathlib import Path

import bpy  # noqa: I001
import addon_utils
from mathutils import Quaternion, Vector
Vector = Vector  # noqa: PLW0127  (used in annotations below)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "characters"
MPFB_ZIP = ROOT / "tools" / "cache" / "mpfb.zip"
FPS = 24
SLOTS = ["skin", "hair", "top", "bottom", "legs", "shoes"]
# Agnes (docs/RESIDENTS.md): 67, small and upright. MPFB age 0.5 is 25 and 1.0 is 90.
MACROS = {"gender": 0.0, "age": 0.84, "muscle": 0.42, "weight": 0.45, "proportions": 0.55, "height": 0.28, "cupsize": 0.45, "firmness": 0.35,
          "race": {"asian": 0.0, "caucasian": 1.0, "african": 0.0}}


MPFB_MOD = ""


def mpfb():
    global MPFB_MOD
    mods = [m.__name__ for m in addon_utils.modules() if m.__name__.endswith(".mpfb")]
    if not mods:
        bpy.ops.extensions.package_install_files(repo="user_default", filepath=str(MPFB_ZIP), enable_on_install=True)
        mods = [m.__name__ for m in addon_utils.modules() if m.__name__.endswith(".mpfb")]
    addon_utils.enable(mods[0], default_set=True)
    MPFB_MOD = mods[0]
    return importlib.import_module(mods[0] + ".services.humanservice").HumanService


def region(bone: str) -> str:
    if bone.startswith(("head", "neck")):
        return "skin"
    if bone.startswith(("hand", "thumb", "index", "middle", "ring", "pinky")):
        return "skin"
    if bone.startswith(("spine", "clavicle", "upperarm", "lowerarm")):
        return "top"
    if bone.startswith(("pelvis", "thigh", "Root")):
        return "bottom"
    if bone.startswith("calf"):
        return "legs"
    return "shoes"


# MPFB rigs rest in an A-pose; these bones are turned to hang straight down in every pose.
HANG = ("upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r")


def delta(rig, bone, angles, memo):
    """How far a bone turns from its rest in armature space: the swings (degrees about world X, which
    is forward and back) of it and its ancestors, after the arms have been lowered from the A-pose."""
    if bone in memo:
        return memo[bone]
    b = rig.data.bones[bone]
    if bone not in angles and bone not in HANG:
        d = delta(rig, b.parent.name, angles, memo) if b.parent else Quaternion()
    else:
        cum = 0.0
        x = b
        while x:
            cum += angles.get(x.name, 0.0)
            x = x.parent
        lower = Quaternion()
        if bone in HANG:
            v = b.tail_local - b.head_local
            lower = v.rotation_difference(Vector((0.1 if v.x > 0 else -0.1, 0.0, -1.0)))
        d = Quaternion((1, 0, 0), math.radians(cum)) @ lower
    memo[bone] = d
    return d


def make_action(rig, name, frames, poses):
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    for f in frames:
        angles = {k: v[0] for k, v in poses(f).items() if k in rig.pose.bones}
        memo = {}
        for bone in set(angles) | set(HANG):
            b = rig.data.bones[bone]
            rest = b.matrix_local.to_quaternion()
            parent = delta(rig, b.parent.name, angles, memo) if b.parent else Quaternion()
            pb = rig.pose.bones[bone]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = rest.inverted() @ parent.inverted() @ delta(rig, bone, angles, memo) @ rest
            pb.keyframe_insert("rotation_quaternion", frame=f)
    act.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(frames[0]), act)
    rig.animation_data.action = None


def walk(f):
    t = (f - 1) / 24.0 * 2 * math.pi
    s, c = math.sin(t), math.cos(t)
    return {"thigh_l": (-22 * s,), "thigh_r": (22 * s,), "calf_l": (max(0.0, 35 * -c) if s < 0 else 6,), "calf_r": (max(0.0, 35 * c) if s > 0 else 6,),
            "upperarm_l": (16 * s,), "upperarm_r": (-16 * s,), "lowerarm_l": (-10,), "lowerarm_r": (-10,), "spine_02": (2,)}


def idle(f):
    t = (f - 1) / 96.0 * 2 * math.pi
    return {"spine_03": (1.2 * math.sin(t),), "head": (2 * math.sin(t * 0.5 + 1),), "upperarm_l": (2 * math.sin(t),), "upperarm_r": (2 * math.sin(t + 0.5),)}


def sit(f):
    return {"thigh_l": (-85,), "thigh_r": (-85,), "calf_l": (85,), "calf_r": (85,), "upperarm_l": (-20,), "upperarm_r": (-20,),
            "lowerarm_l": (-40,), "lowerarm_r": (-40,)}


EXPR_DIR = ROOT / "tools" / "cache" / "mpfb2" / "src" / "mpfb" / "data" / "targets" / "expression" / "units" / "caucasian"
EXPRESSION_KEYS = ["eyebrows-left-up", "eyebrows-right-up", "eyebrows-left-down", "eyebrows-right-down", "eyebrows-left-inner-up", "eyebrows-right-inner-up",
                   "eyebrows-left-extern-up", "eyebrows-right-extern-up", "eye-left-opened-up", "eye-right-opened-up", "eye-left-closure", "eye-right-closure",
                   "eye-left-slit", "eye-right-slit", "mouth-open", "mouth-compression", "mouth-corner-puller", "mouth-elevation", "mouth-depression",
                   "mouth-depression-retraction", "mouth-pursing", "mouth-upward-retraction"]
PORTRAIT_FROM = 1.30   # metres: the portrait keeps everything above the chest


def _eyelid_centre(body, key: str) -> Vector:
    """The middle of an eye: the centre of the vertices the eyelid-closing shape key moves."""
    kb = body.data.shape_keys.key_blocks
    ref = kb["Basis"] if "Basis" in kb else kb[0]
    moved = [i for i, v in enumerate(kb[key].data) if (v.co - ref.data[i].co).length > 0.0008]
    pts = [Vector(body.data.vertices[i].co) for i in moved]
    return sum(pts, Vector()) / max(1, len(pts))


def _eye_material(name: str, colour):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = colour
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.25
    return mat


def _add_eyes(body, eyes: dict) -> None:
    """A white eyeball and a dark iris in each socket, joined to the head (they stay put when the lids move)."""
    white = _eye_material("eye_white", (0.92, 0.91, 0.88, 1.0))
    iris = _eye_material("iris", (0.16, 0.2, 0.24, 1.0))
    objs = []
    for c in eyes.values():
        for radius, mat, dy in ((0.0115, white, 0.0), (0.0062, iris, -0.0098)):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, radius=radius, location=(c.x, c.y + 0.0105 + dy, c.z))
            o = bpy.context.active_object
            o.data.materials.append(mat)
            objs.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()


def _export_portrait(body, rig, name: str) -> Path:
    """Exports the cropped head-and-shoulders mesh with its shape keys, no skeleton."""
    for mod in list(body.modifiers):
        if mod.type == "ARMATURE":
            body.modifiers.remove(mod)
    body.parent = None
    bpy.data.objects.remove(rig, do_unlink=True)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}_portrait.glb"
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_animations=False, export_yup=True,
                              export_skins=False, export_materials="EXPORT", export_morph=True, export_morph_normal=False)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"wrote {path.relative_to(ROOT)} ({tris} triangles, {len(body.data.shape_keys.key_blocks) - 1 if body.data.shape_keys else 0} shape keys)")
    return path


def build(lod: int, name: str = "agnes", macros: dict = MACROS, skirt: bool = True, bun: bool = True, animations: str = "own", portrait: bool = False) -> Path:
    """One resident as a GLB. `skirt` makes the dress (women); without it the tights helper is trousers. `bun` adds the hair bun."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    hs = mpfb()
    body = hs.create_human(macro_detail_dict=macros)
    rig = hs.add_builtin_rig(body, "game_engine")
    # Bake the targets into the mesh, then keep the body and the skirt helper and drop the rest.
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    if body.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for mod in list(body.modifiers):
        if mod.type == "MASK":
            body.modifiers.remove(mod)
    # Scaled to the mannequins' 1.76 m, so ResidentLook sizes every model the same way (height / 1.76).
    body_group = body.vertex_groups["body"].index
    top = max(v.co.z for v in body.data.vertices if any(g.group == body_group for g in v.groups))
    k = 1.76 / top
    bpy.ops.object.select_all(action="DESELECT")
    rig.scale = (k, k, k)  # the body is parented to the rig and scales with it
    for o in (rig, body):
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = body
    head = rig.data.bones["head"].head_local
    top = 1.76
    # The clothes are MPFB's tights helper (a smooth shell over the body) and its skirt helper; the
    # body itself shows only where skin and shoes do (head, neck, hands, feet).
    group = {g: body.vertex_groups[g].index for g in ("body", "helper-tights", "helper-skirt") if g in body.vertex_groups}
    bones = {g.index: g.name for g in body.vertex_groups if g.name in rig.data.bones}
    for s in SLOTS:
        mat = bpy.data.materials.new(s)
        body.data.materials.append(mat)
    skirt_top = max((v.co.z for v in body.data.vertices if any(g.group == group.get("helper-skirt", -2) for g in v.groups)), default=0.0)
    vert_slot = {}
    drop = []
    for v in body.data.vertices:
        groups = {g.group: g.weight for g in v.groups}
        part = next((name for name, i in group.items() if i in groups), "")
        if part == "helper-skirt":
            if skirt:
                vert_slot[v.index] = "bottom"
            else:
                drop.append(v.index)
            continue
        bone_w = [(w, bones[g]) for g, w in groups.items() if g in bones]
        bone = max(bone_w)[1] if bone_w else "pelvis"
        slot = region(bone)
        # Hair: the top and back of the head.
        if bone.startswith("head") and (v.co.z > top - 0.085 or (v.co.z > head.z + 0.3 * (top - head.z) and v.co.y > head.y + 0.03)):
            slot = "hair"
        if part == "helper-tights" and bone.startswith("neck"):
            slot = "top"  # a high collar, closing the gap to the neck
        if part == "helper-tights" and slot == "top" and v.co.z < skirt_top - 0.02:
            slot = "bottom"  # tucked in under the skirt
        clothed = slot in ("top", "bottom", "legs")
        if part == "" or (part == "body" and clothed) or (part == "helper-tights" and not clothed):
            drop.append(v.index)
            continue
        vert_slot[v.index] = slot
    for p in body.data.polygons:
        slots = [vert_slot.get(i) for i in p.vertices]
        slots = [s for s in slots if s]
        if slots:
            p.material_index = SLOTS.index(max(set(slots), key=slots.count))
    # Soften the clothed torso so the shell reads as a cardigan rather than a body.
    soft = body.vertex_groups.new(name="soften")
    soft.add([i for i, sl in vert_slot.items() if sl == "top"], 1.0, "REPLACE")
    sm = body.modifiers.new("soften", "SMOOTH")
    sm.vertex_group = "soften"
    sm.factor = 0.8
    sm.iterations = 12
    bpy.ops.object.modifier_move_to_index(modifier="soften", index=0)
    bpy.ops.object.modifier_apply(modifier="soften")
    body.vertex_groups.remove(body.vertex_groups["soften"])
    if portrait:
        # A head-and-shoulders model with the face's action units as shape keys (portrait_view.gd mixes
        # them into expressions). The targets are offsets by vertex index, so they go on before any
        # vertex is deleted.
        ts = importlib.import_module(MPFB_MOD + ".services.targetservice").TargetService
        for key in EXPRESSION_KEYS:
            ts.load_target(body, str(EXPR_DIR / f"{key}.target.gz"), weight=0.0, name=key)
        drop.extend(v.index for v in body.data.vertices if v.co.z < PORTRAIT_FROM and v.index not in set(drop))
        eyes = {side: _eyelid_centre(body, f"eye-{side}-closure") for side in ("left", "right")}
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in drop], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    if bun:
        # A bun at the back of the head.
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.055, location=(0, head.y + 0.1, head.z + 0.6 * (top - head.z)))
        bun_obj = bpy.context.active_object
        bun_obj.data.materials.append(bpy.data.materials["hair"])
        bun_obj.vertex_groups.new(name="head").add(list(range(len(bun_obj.data.vertices))), 1.0, "REPLACE")
        bpy.ops.object.select_all(action="DESELECT")
        bun_obj.select_set(True)
        body.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()
    if portrait:
        _add_eyes(body, eyes)
        return _export_portrait(body, rig, name)
    # Down to the triangle budget: under 10,000 at LOD0 and 3,000 at LOD1.
    tris_now = sum(len(p.vertices) - 2 for p in body.data.polygons)
    target = 300 if name == "animations" else (9000 if lod == 0 else 2800)   # the animation carrier only needs a skinned body
    dec = body.modifiers.new("decimate", "DECIMATE")
    dec.ratio = min(1.0, target / tris_now)
    bpy.ops.object.modifier_move_to_index(modifier="decimate", index=0)
    bpy.ops.object.modifier_apply(modifier="decimate")
    # "own": the hand-keyed idle, walk and sit. "ual": the retargeted Quaternius library (animations.glb).
    # "none": no animations; the game adds the shared set from animations.glb at run time.
    if animations == "own":
        make_action(rig, "idle", list(range(1, 98, 8)), idle)
        make_action(rig, "walk", list(range(1, 26, 2)), walk)
        make_action(rig, "sit", [1, 10], sit)
    elif animations == "ual":
        import retarget_ual
        print("retargeted", retarget_ual.retarget(rig))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (f"{name}.glb" if lod == 0 else f"{name}_lod1.glb")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_animations=animations != "none",
                              export_animation_mode="NLA_TRACKS", export_yup=True, export_skins=True, export_materials="EXPORT",
                              export_morph=False)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    top = max(v.co.z for v in body.data.vertices)
    faces = {body.data.materials[i].name: sum(1 for p in body.data.polygons if p.material_index == i) for i in range(len(body.data.materials))}
    print(f"wrote {path.relative_to(ROOT)} ({tris} triangles, faces per slot {faces}, {len(rig.data.bones)} bones, rest height {top:.2f} m)")
    return path


if __name__ == "__main__":
    build(0, animations="none")
    build(1, animations="none")
