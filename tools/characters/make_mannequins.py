"""Placeholder people for the simulation (M5): realistic-proportion mannequins with a simple
skeleton and walk, idle and sit animations, made with headless Blender (bpy). Two builds: trousers
(mannequin_m) and a dress (mannequin_f). Each part is skinned rigidly to one bone, and faces are in
material slots the game colours per resident: skin, hair, top, bottom, shoes.

Usage: bash tools/props/setup_blender.sh, then
       tools/cache/blender-venv/bin/python tools/characters/make_mannequins.py
Writes assets/characters/mannequin_m.glb and mannequin_f.glb (about 1.75 m; the game scales them).
"""
import math
from pathlib import Path

import bpy  # noqa: I001  (bpy must load before bmesh and mathutils)
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "characters"
FPS = 24

# Joint positions for a 1.75 m adult in metres (x to the person's left, z up, front is -Y).
J = {
    "hips": (0, 0, 0.98), "spine": (0, 0, 1.08), "chest": (0, 0, 1.28), "neck": (0, 0, 1.47), "head": (0, 0, 1.56), "head_top": (0, 0, 1.76),
    "shoulder.L": (0.18, 0, 1.42), "elbow.L": (0.21, 0.01, 1.14), "wrist.L": (0.22, -0.02, 0.88), "hand_end.L": (0.22, -0.03, 0.78),
    "hip.L": (0.095, 0, 0.94), "knee.L": (0.1, -0.01, 0.52), "ankle.L": (0.1, 0.01, 0.08), "toe.L": (0.1, -0.13, 0.02),
}
for k in list(J):
    if k.endswith(".L"):
        x, y, z = J[k]
        J[k[:-2] + ".R"] = (-x, y, z)

BONES = [
    # name, head joint, tail joint, parent
    ("hips", "hips", "spine", None), ("spine", "spine", "chest", "hips"), ("chest", "chest", "neck", "spine"),
    ("neck", "neck", "head", "chest"), ("head", "head", "head_top", "neck"),
]
for s in ("L", "R"):
    BONES += [
        (f"upper_arm.{s}", f"shoulder.{s}", f"elbow.{s}", "chest"), (f"forearm.{s}", f"elbow.{s}", f"wrist.{s}", f"upper_arm.{s}"),
        (f"hand.{s}", f"wrist.{s}", f"hand_end.{s}", f"forearm.{s}"),
        (f"thigh.{s}", f"hip.{s}", f"knee.{s}", "hips"), (f"shin.{s}", f"knee.{s}", f"ankle.{s}", f"thigh.{s}"),
        (f"foot.{s}", f"ankle.{s}", f"toe.{s}", f"shin.{s}"),
    ]

SLOTS = ["skin", "hair", "top", "bottom", "shoes"]
PREVIEW = {"skin": (0.85, 0.66, 0.55), "hair": (0.3, 0.2, 0.12), "top": (0.7, 0.68, 0.6), "bottom": (0.25, 0.25, 0.3), "shoes": (0.12, 0.08, 0.06)}


class Body:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.groups = {}  # vertex index range -> bone
        self.deform = self.bm.verts.layers.deform.verify()

    def _merge(self, tmp, slot, bone, smooth=True):
        for f in tmp.faces:
            f.material_index = SLOTS.index(slot)
            f.smooth = smooth
        mesh = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        start = len(self.bm.verts)
        self.bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        self.bm.verts.ensure_lookup_table()
        for i in range(start, len(self.bm.verts)):
            self.groups[i] = bone

    def limb(self, slot, bone, a, b, r0, r1=None, seg=12):
        """A tapered capsule-ish cylinder from joint a to joint b."""
        av, bv = Vector(J[a] if isinstance(a, str) else a), Vector(J[b] if isinstance(b, str) else b)
        d = bv - av
        tmp = bmesh.new()
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=seg, radius1=r0, radius2=r0 if r1 is None else r1, depth=d.length,
                              matrix=Matrix.Translation(av + d / 2) @ rot)
        self._merge(tmp, slot, bone)

    def ball(self, slot, bone, c, r, scale=(1, 1, 1), seg=14):
        tmp = bmesh.new()
        c = Vector(J[c] if isinstance(c, str) else c)
        bmesh.ops.create_uvsphere(tmp, u_segments=seg, v_segments=max(6, seg // 2), radius=r, matrix=Matrix.Translation(c) @ Matrix.Diagonal((*scale, 1)))
        self._merge(tmp, slot, bone)

    def box(self, slot, bone, c, size):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0, matrix=Matrix.Translation(c) @ Matrix.Diagonal((*size, 1)))
        self._merge(tmp, slot, bone, False)


def build_body(dress: bool) -> Body:
    b = Body("mannequin_f" if dress else "mannequin_m")
    # Head, hair, neck.
    b.ball("skin", "head", (0, -0.005, 1.66), 0.1, (0.86, 1.0, 1.12), 18)
    b.ball("hair", "head", (0, 0.015, 1.7), 0.104, (0.9, 1.0, 0.95) if not dress else (0.96, 1.05, 1.0), 18)
    if dress:
        b.ball("hair", "head", (0, 0.09, 1.66), 0.055)  # a bun
    b.ball("skin", "head", (0, -0.075, 1.645), 0.022, (0.8, 1, 1.2), 8)  # nose
    b.limb("skin", "neck", (0, 0, 1.44), (0, 0, 1.57), 0.05, 0.045, 10)
    # Torso.
    shoulders = 0.17 if not dress else 0.155
    b.ball("top", "chest", (0, 0, 1.33), 0.2, (shoulders / 0.2 * 1.05, 0.62, 0.75), 18)
    b.limb("top", "spine", (0, 0, 1.06), (0, 0, 1.3), 0.15 if not dress else 0.13, 0.17 if not dress else 0.15, 16)
    b.ball("bottom", "hips", (0, 0, 1.0), 0.16, (1.0 if not dress else 1.08, 0.72, 0.6), 16)
    for s, sx in (("L", 1), ("R", -1)):
        b.ball("top", f"upper_arm.{s}", f"shoulder.{s}", 0.055)
        b.limb("top", f"upper_arm.{s}", f"shoulder.{s}", f"elbow.{s}", 0.046, 0.038)
        b.limb("top" if not dress else "skin", f"forearm.{s}", f"elbow.{s}", f"wrist.{s}", 0.036, 0.03)
        b.ball("skin", f"hand.{s}", (0.22 * sx, -0.025, 0.83), 0.04, (0.6, 0.9, 1.4), 10)
        b.limb("bottom" if not dress else "skin", f"thigh.{s}", f"hip.{s}", f"knee.{s}", 0.075, 0.055)
        b.limb("bottom" if not dress else "skin", f"shin.{s}", f"knee.{s}", f"ankle.{s}", 0.05, 0.036)
        b.box("shoes", f"foot.{s}", (0.1 * sx, -0.04, 0.04), (0.09, 0.25, 0.08))
    if dress:
        # A skirt on the hips, to just below the knee.
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=False, segments=20, radius1=0.17, radius2=0.25, depth=0.5,
                              matrix=Matrix.Translation((0, 0, 0.72)) @ Matrix.Rotation(math.pi, 4, "X"))
        b._merge(tmp, "bottom", "hips")
    return b


def build_armature(name):
    arm = bpy.data.armatures.new(name + "_rig")
    obj = bpy.data.objects.new(name + "_rig", arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent in BONES:
        eb = arm.edit_bones.new(bname)
        eb.head = J[head]
        eb.tail = J[tail]
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def key(pb, frame, rx=0.0, ry=0.0, rz=0.0, loc=None):
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    pb.keyframe_insert("rotation_euler", frame=frame)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame)


def make_action(rig, name, frames, poses):
    """poses(frame) -> {bone: (rx, ry, rz[, loc])}, keyed at each listed frame."""
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    for f in frames:
        for bone, v in poses(f).items():
            pb = rig.pose.bones[bone]
            key(pb, f, v[0], v[1], v[2], v[3] if len(v) > 3 else None)
    act.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(frames[0]), act)
    rig.animation_data.action = None
    return act


def walk(f):
    t = (f - 1) / 24.0 * 2 * math.pi
    s = math.sin(t)
    c = math.cos(t)
    return {
        "thigh.L": (-25 * s, 0, 0), "thigh.R": (25 * s, 0, 0),
        "shin.L": (max(0.0, 40 * -c) if s < 0 else 8, 0, 0), "shin.R": (max(0.0, 40 * c) if s > 0 else 8, 0, 0),
        "foot.L": (8 * s, 0, 0), "foot.R": (-8 * s, 0, 0),
        "upper_arm.L": (20 * s, 0, 0), "upper_arm.R": (-20 * s, 0, 0),
        "forearm.L": (-12 - 6 * s, 0, 0), "forearm.R": (-12 + 6 * s, 0, 0),
        "hips": (0, 0, 4 * s, (0, 0, 0.02 * abs(c))), "chest": (2, 0, -6 * s),
    }


def idle(f):
    t = (f - 1) / 96.0 * 2 * math.pi
    return {"chest": (1.5 * math.sin(t), 0, 0.8 * math.sin(t * 0.5)), "head": (2 * math.sin(t * 0.5 + 1), 3 * math.sin(t * 0.25), 0),
            "upper_arm.L": (2 * math.sin(t), 0, -3), "upper_arm.R": (2 * math.sin(t + 0.5), 0, 3), "hips": (0, 0, 0, (0, 0, 0))}


def sit(f):
    return {"thigh.L": (-85, 0, 3), "thigh.R": (-85, 0, -3), "shin.L": (85, 0, 0), "shin.R": (85, 0, 0),
            "upper_arm.L": (-25, 0, -5), "upper_arm.R": (-25, 0, 5), "forearm.L": (-40, 0, 0), "forearm.R": (-40, 0, 0),
            "hips": (0, 0, 0, (0, 0, -0.5)), "chest": (-4, 0, 0)}


def build(dress: bool) -> Path:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    body = build_body(dress)
    rig = build_armature(body.name)
    mesh = bpy.data.meshes.new(body.name)
    body.bm.to_mesh(mesh)
    body.bm.free()
    obj = bpy.data.objects.new(body.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for s in SLOTS:
        mat = bpy.data.materials.new(s)
        mat.diffuse_color = (*PREVIEW[s], 1.0)
        mesh.materials.append(mat)
    groups = {bn: obj.vertex_groups.new(name=bn) for bn, *_ in BONES}
    by_bone = {}
    for vi, bone in body.groups.items():
        by_bone.setdefault(bone, []).append(vi)
    for bone, vis in by_bone.items():
        groups[bone].add(vis, 1.0, "REPLACE")
    obj.parent = rig
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    make_action(rig, "idle", list(range(1, 98, 8)), idle)
    make_action(rig, "walk", list(range(1, 26, 2)), walk)
    make_action(rig, "sit", [1, 10], sit)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{body.name}.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_yup=True, export_skins=True, export_materials="EXPORT")
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    print(f"wrote {path.relative_to(ROOT)} ({tris} triangles)")
    return path


if __name__ == "__main__":
    build(False)
    build(True)
