"""Retargets the Quaternius Universal Animation Library (CC0) onto the MPFB "game_engine" rig.

Both skeletons have the same bones (Unreal-style), but the library rests in a T-pose and MPFB in an
A-pose, so a plain copy would drop the arms through the legs. Each bone is first given the library's
world-space rotation change from rest, applied to MPFB's own rest, then swung so that it points the
way the library's bone points (this fixes the arms and keeps the twist of spine, head and hips). The
pelvis keeps the library's movement, scaled to this body. Rotation only elsewhere, so the same
animations suit every resident whatever their proportions.

Used by make_agnes.build(..., animations=True); not run on its own.
"""
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
UAL = ROOT / "assets" / "incoming" / "animations" / "ual" / "Universal Animation Library[Standard]" / "Unreal-Godot" / "UAL1_Standard.glb"

# Our name -> the library's action. Loops are marked in scenes/resident_ui/character_anims.gd.
ACTIONS = {
    "idle": "Idle_Loop", "walk": "Walk_Loop", "walk_formal": "Walk_Formal_Loop", "jog": "Jog_Fwd_Loop",
    "talk": "Idle_Talking_Loop", "sit": "Sitting_Idle_Loop", "sit_talk": "Sitting_Talking_Loop",
    "sit_down": "Sitting_Enter", "stand_up": "Sitting_Exit", "crouch": "Crouch_Idle_Loop", "sneak": "Crouch_Fwd_Loop",
    "interact": "Interact", "pickup": "PickUp_Table", "dance": "Dance_Loop", "push": "Push_Loop",
    "kneel_fix": "Fixing_Kneeling", "torch": "Idle_Torch_Loop", "flinch": "Hit_Chest",
}
Y = Vector((0.0, 1.0, 0.0))


def _swing(a: Vector, b: Vector) -> Quaternion:
    return a.normalized().rotation_difference(b.normalized())


def retarget(rig, fps: int = 30) -> list:
    """Adds the ACTIONS to `rig` as NLA tracks. Returns their names."""
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(UAL))
    src = next(o for o in bpy.data.objects if o.type == "ARMATURE" and o.name not in before)
    low_s = {b.name.lower(): b.name for b in src.data.bones}
    bones = [b for b in rig.data.bones if b.name.lower() in low_s]
    mt, ms = rig.matrix_world, src.matrix_world
    rest_t = {b.name: (mt @ b.matrix_local).to_quaternion() for b in rig.data.bones}
    rest_s = {n: (ms @ src.data.bones[n].matrix_local).to_quaternion() for n in low_s.values()}
    pelvis_t = next(b for b in rig.data.bones if b.name.lower() == "pelvis")
    pelvis_s = src.data.bones[low_s["pelvis"]]
    ratio = (mt @ pelvis_t.head_local).z / max(1e-6, (ms @ pelvis_s.head_local).z)
    bpy.context.scene.render.fps = fps
    rig.animation_data_create()
    done = []
    for ours, theirs in ACTIONS.items():
        act_s = bpy.data.actions.get(theirs)
        if act_s is None:
            print("missing action", theirs)
            continue
        src.animation_data_create()
        src.animation_data.action = act_s
        start, end = int(act_s.frame_range[0]), int(act_s.frame_range[1])
        act = bpy.data.actions.new(ours)
        rig.animation_data.action = act
        frames = list(range(start, end + 1, 1 if end - start < 14 else 2))   # every second frame: 15 keys a second is plenty
        if frames[-1] != end:
            frames.append(end)
        for f in frames:
            bpy.context.scene.frame_set(f)
            pose_world: dict = {}
            for b in bones:
                sn = low_s[b.name.lower()]
                rp_s = (ms @ src.pose.bones[sn].matrix).to_quaternion()
                delta = rp_s @ rest_s[sn].inverted()
                rp_t = delta @ rest_t[b.name]
                # Swing so the bone points where the library's bone points (the arms, mostly).
                want = rp_s @ Y
                have = rp_t @ Y
                rp_t = _swing(have, want) @ rp_t
                pose_world[b.name] = rp_t
                pb = rig.pose.bones[b.name]
                parent_rest = rest_t[b.parent.name] if b.parent else Quaternion()
                parent_pose = pose_world.get(b.parent.name, parent_rest) if b.parent else Quaternion()
                q = rest_t[b.name].inverted() @ parent_rest @ parent_pose.inverted() @ rp_t
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
                if b.name.lower() == "pelvis":
                    d = (ms @ src.pose.bones[sn].matrix).translation - (ms @ pelvis_s.matrix_local).translation
                    pb.location = rest_t[b.name].inverted() @ (d * ratio)
                    pb.keyframe_insert("location", frame=f)
        act.use_fake_user = True
        track = rig.animation_data.nla_tracks.new()
        track.name = ours
        track.strips.new(ours, start, act)
        done.append(ours)
    rig.animation_data.action = None
    # The library's own armature and meshes are no longer needed.
    for o in [o for o in bpy.data.objects if o.name not in before and o != rig]:
        if o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)
    return done
