"""Models the 1950s props Poly Haven doesn't have, with headless Blender (bpy), and exports each as
glTF binary to assets/models/props/<name>.glb.

Every prop is built from simple solids, measured from period pieces, with its origin at floor level
in the middle of its footprint and its front facing the viewer (+Z in Godot). Faces are grouped into
named material slots ("timber", "enamel", "chrome", "fabric" and so on). The game swaps each slot for
a library material, which is how the Design tool recolours them (data/catalogue.json lists the slots
and their default materials).

Usage: bash tools/props/setup_blender.sh, then
       tools/cache/blender-venv/bin/python tools/props/make_props.py [name ...]
"""
import math
import sys
from pathlib import Path

import bpy  # noqa: I001  (bpy must load before bmesh and mathutils)
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models" / "props"

# Preview colours only: the game replaces every slot with a library material.
PREVIEW = {
    "timber": (0.45, 0.28, 0.16), "iron": (0.08, 0.08, 0.08), "nickel": (0.8, 0.8, 0.78), "chrome": (0.85, 0.86, 0.88),
    "enamel": (0.93, 0.9, 0.82), "fabric": (0.5, 0.35, 0.3), "bakelite": (0.25, 0.14, 0.08), "laminex": (0.85, 0.3, 0.3),
    "vinyl": (0.75, 0.15, 0.15), "brass": (0.75, 0.6, 0.3), "marble": (0.9, 0.9, 0.88), "china": (0.95, 0.95, 0.95),
    "glass": (0.95, 0.92, 0.8), "mattress": (0.9, 0.88, 0.8), "blanket": (0.75, 0.8, 0.9), "mirror": (0.7, 0.75, 0.8),
}


class Prop:
    """Accumulates solids into one mesh with material slots, front towards Blender -Y."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.slots: list[str] = []

    def _slot(self, slot: str) -> int:
        if slot not in self.slots:
            self.slots.append(slot)
        return self.slots.index(slot)

    def _merge(self, tmp: bmesh.types.BMesh, slot: str, smooth: bool) -> None:
        idx = self._slot(slot)
        for f in tmp.faces:
            f.material_index = idx
            f.smooth = smooth
        mesh = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        self.bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)

    def box(self, slot: str, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, rot_z: float = 0.0) -> None:
        """An axis-aligned box from corners (x left-right, y back(+)-front(-), z up)."""
        tmp = bmesh.new()
        m = Matrix.Translation(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)) @ Matrix.Rotation(rot_z, 4, "Z") \
            @ Matrix.Diagonal((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0), 1))
        bmesh.ops.create_cube(tmp, size=1.0, matrix=m)
        self._merge(tmp, slot, False)

    def cyl(self, slot: str, base: tuple, height: float, r0: float, r1: float | None = None, seg: int = 16,
            axis: str = "Z", caps: bool = True) -> None:
        """A cylinder or cone standing on base, along an axis."""
        tmp = bmesh.new()
        rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        d = {"Z": Vector((0, 0, 1)), "X": Vector((1, 0, 0)), "Y": Vector((0, -1, 0))}[axis]
        centre = Vector(base) + d * (height / 2)
        bmesh.ops.create_cone(tmp, cap_ends=caps, segments=seg, radius1=r0, radius2=r0 if r1 is None else r1,
                              depth=height, matrix=Matrix.Translation(centre) @ rot)
        self._merge(tmp, slot, True)

    def sphere(self, slot: str, c: tuple, r: float, scale: tuple = (1, 1, 1), seg: int = 16) -> None:
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg, v_segments=max(6, seg // 2), radius=r,
                                  matrix=Matrix.Translation(c) @ Matrix.Diagonal((*scale, 1)))
        self._merge(tmp, slot, True)

    def rail(self, slot: str, a: tuple, b: tuple, r: float, seg: int = 10) -> None:
        """A round bar from a to b."""
        av, bv = Vector(a), Vector(b)
        d = bv - av
        tmp = bmesh.new()
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=d.length,
                              matrix=Matrix.Translation(av + d / 2) @ rot)
        self._merge(tmp, slot, True)

    def finish(self) -> Path:
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for s in self.slots:
            mat = bpy.data.materials.get(s) or bpy.data.materials.new(s)
            mat.diffuse_color = (*PREVIEW.get(s, (0.7, 0.7, 0.7)), 1.0)
            mesh.materials.append(mat)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
        OUT.mkdir(parents=True, exist_ok=True)
        path = OUT / f"{self.name}.glb"
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
                                  export_materials="EXPORT", export_yup=True)
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(mesh)
        print(f"wrote {path.relative_to(ROOT)} slots={self.slots}")
        return path


# --- The props ----------------------------------------------------------------------------------
# Front is -Y. Dimensions in metres.

def wood_stove() -> Prop:
    p = Prop("wood_stove")
    w, d, h = 0.9, 0.55, 0.78
    p.box("iron", -w / 2, w / 2, -d / 2, d / 2, 0.08, h)
    for x in (-w / 2 + 0.05, w / 2 - 0.05):
        for y in (-d / 2 + 0.05, d / 2 - 0.05):
            p.cyl("iron", (x, y, 0), 0.08, 0.035, 0.025, 8)
    p.box("iron", -w / 2 - 0.02, w / 2 + 0.02, -d / 2 - 0.02, d / 2 + 0.02, h, h + 0.03)
    for x in (-0.22, 0.18):
        p.cyl("iron", (x, -0.02, h + 0.03), 0.012, 0.11, None, 20)
    p.box("iron", 0.02, 0.4, -d / 2 - 0.02, -d / 2, 0.2, 0.62)  # oven door
    p.box("iron", -0.4, -0.06, -d / 2 - 0.02, -d / 2, 0.42, 0.62)  # firebox door
    p.rail("nickel", (0.06, -d / 2 - 0.05, 0.56), (0.36, -d / 2 - 0.05, 0.56), 0.008)
    p.rail("nickel", (-w / 2, -d / 2 - 0.07, h - 0.06), (w / 2, -d / 2 - 0.07, h - 0.06), 0.01)
    p.cyl("nickel", (-0.23, -d / 2 - 0.03, 0.52), 0.03, 0.02, None, 10, "Y")
    p.cyl("iron", (0.3, 0.15, h + 0.03), 1.4, 0.065, None, 14)  # flue
    return p


def icebox() -> Prop:
    p = Prop("icebox")
    w, d, h = 0.75, 0.55, 1.3
    p.box("enamel", -w / 2, w / 2, -d / 2, d / 2, 0.1, h)
    for x in (-w / 2 + 0.04, w / 2 - 0.04):
        for y in (-d / 2 + 0.04, d / 2 - 0.04):
            p.box("chrome", x - 0.02, x + 0.02, y - 0.02, y + 0.02, 0, 0.1)
    p.box("enamel", -w / 2 + 0.03, w / 2 - 0.03, -d / 2 - 0.02, -d / 2, 0.62, h - 0.04)  # ice door
    p.box("enamel", -w / 2 + 0.03, w / 2 - 0.03, -d / 2 - 0.02, -d / 2, 0.14, 0.58)  # food door
    for z in (0.95, 0.4):
        p.box("chrome", w / 2 - 0.14, w / 2 - 0.06, -d / 2 - 0.06, -d / 2 - 0.02, z - 0.03, z + 0.03)
    p.box("chrome", -w / 2, w / 2, -d / 2 - 0.005, d / 2, h - 0.02, h + 0.01)
    return p


def wireless_set() -> Prop:
    p = Prop("wireless_set")
    w, d, h = 0.5, 0.25, 0.32
    p.box("bakelite", -w / 2, w / 2, -d / 2, d / 2, 0, h - 0.08)
    p.cyl("bakelite", (-w / 2, 0, h - 0.08), w, 0.08, None, 20, "X")
    p.box("fabric", -w / 2 + 0.04, 0.06, -d / 2 - 0.005, -d / 2 + 0.01, 0.05, h - 0.06)
    p.box("glass", 0.1, w / 2 - 0.04, -d / 2 - 0.005, -d / 2 + 0.01, 0.12, h - 0.06)
    for x in (0.13, 0.21):
        p.cyl("chrome", (x, -d / 2, 0.06), 0.02, 0.022, None, 12, "Y")
    return p


def wall_telephone() -> Prop:
    p = Prop("wall_telephone")
    # Hangs on a wall: back at y = 0, origin at floor level under it (the game raises it to 1.3 m).
    p.box("timber", -0.12, 0.12, -0.12, 0, 0, 0.42)
    for x in (-0.06, 0.06):
        p.sphere("nickel", (x, -0.13, 0.36), 0.035, (1, 0.7, 1))
    p.box("timber", -0.1, 0.1, -0.2, -0.12, 0.05, 0.08)
    p.cyl("bakelite", (0, -0.17, 0.22), 0.06, 0.025, 0.04, 12, "Y")
    p.cyl("bakelite", (0.15, -0.06, 0.12), 0.18, 0.018, 0.022, 10)
    p.cyl("nickel", (-0.15, -0.06, 0.2), 0.03, 0.015, None, 8, "X")
    return p


def laminex_table() -> Prop:
    p = Prop("laminex_table")
    w, d, h = 1.2, 0.76, 0.76
    p.box("laminex", -w / 2, w / 2, -d / 2, d / 2, h - 0.03, h)
    p.box("chrome", -w / 2 - 0.005, w / 2 + 0.005, -d / 2 - 0.005, d / 2 + 0.005, h - 0.045, h - 0.025)
    for x in (-w / 2 + 0.06, w / 2 - 0.06):
        for y in (-d / 2 + 0.06, d / 2 - 0.06):
            p.cyl("chrome", (x, y, 0), h - 0.045, 0.019, None, 12)
    return p


def kitchen_chair() -> Prop:
    p = Prop("kitchen_chair")
    w, d, sh = 0.42, 0.42, 0.46
    p.box("vinyl", -w / 2, w / 2, -d / 2, d / 2, sh - 0.05, sh)
    p.box("vinyl", -w / 2 + 0.02, w / 2 - 0.02, d / 2 - 0.04, d / 2, 0.66, 0.86)
    for x in (-w / 2 + 0.03, w / 2 - 0.03):
        p.rail("chrome", (x, -d / 2 + 0.03, 0), (x, -d / 2 + 0.03, sh - 0.05), 0.011)
        p.rail("chrome", (x, d / 2 - 0.02, 0), (x, d / 2 - 0.02, 0.88), 0.011)
        p.rail("chrome", (x, -d / 2 + 0.03, 0.2), (x, d / 2 - 0.02, 0.2), 0.008)
    return p


def iron_bed() -> Prop:
    p = Prop("iron_bed")
    w, l = 1.4, 2.0
    for y, top in ((l / 2, 1.15), (-l / 2, 0.85)):
        for x in (-w / 2, w / 2):
            p.cyl("enamel", (x, y, 0), top, 0.022, None, 10)
            p.sphere("brass", (x, y, top + 0.02), 0.035)
        p.rail("enamel", (-w / 2, y, top - 0.05), (w / 2, y, top - 0.05), 0.016)
        p.rail("enamel", (-w / 2, y, 0.42), (w / 2, y, 0.42), 0.014)
        for i in range(1, 8):
            x = -w / 2 + w * i / 8
            p.rail("enamel", (x, y, 0.42), (x, y, top - 0.05), 0.008)
    p.box("iron", -w / 2, w / 2, -l / 2, l / 2, 0.36, 0.4)
    p.box("mattress", -w / 2 + 0.03, w / 2 - 0.03, -l / 2 + 0.03, l / 2 - 0.03, 0.4, 0.58)
    p.box("blanket", -w / 2 - 0.02, w / 2 + 0.02, -l / 2 + 0.02, l / 2 - 0.45, 0.45, 0.6)
    for x in (-0.32, 0.32):
        p.sphere("fabric", (x, l / 2 - 0.25, 0.64), 0.28, (1, 0.55, 0.22))
    return p


def wardrobe() -> Prop:
    p = Prop("wardrobe")
    w, d, h = 1.1, 0.55, 1.85
    p.box("timber", -w / 2, w / 2, -d / 2, d / 2, 0.08, h)
    p.box("timber", -w / 2 - 0.03, w / 2 + 0.03, -d / 2 - 0.03, d / 2, h, h + 0.06)
    p.box("timber", -w / 2, w / 2, -d / 2, d / 2, 0, 0.08)
    p.box("mirror", -w / 2 + 0.06, -0.03, -d / 2 - 0.012, -d / 2, 0.35, h - 0.12)
    p.box("timber", 0.03, w / 2 - 0.06, -d / 2 - 0.012, -d / 2, 0.35, h - 0.12)
    p.box("timber", -w / 2 + 0.04, w / 2 - 0.04, -d / 2 - 0.012, -d / 2, 0.12, 0.3)
    for x in (-0.04, 0.04):
        p.cyl("brass", (x, -d / 2, 1.0), 0.03, 0.012, None, 8, "Y")
    return p


def chest_of_drawers() -> Prop:
    p = Prop("chest_of_drawers")
    w, d, h = 0.9, 0.45, 0.95
    p.box("timber", -w / 2, w / 2, -d / 2, d / 2, 0.06, h)
    p.box("timber", -w / 2 - 0.02, w / 2 + 0.02, -d / 2 - 0.02, d / 2, h, h + 0.025)
    for i in range(4):
        z0 = 0.09 + i * 0.21
        p.box("timber", -w / 2 + 0.03, w / 2 - 0.03, -d / 2 - 0.012, -d / 2, z0, z0 + 0.19)
        for x in (-0.22, 0.22):
            p.box("brass", x - 0.05, x + 0.05, -d / 2 - 0.03, -d / 2 - 0.012, z0 + 0.09, z0 + 0.11)
    for x in (-w / 2 + 0.04, w / 2 - 0.04):
        for y in (-d / 2 + 0.04, d / 2 - 0.04):
            p.cyl("timber", (x, y, 0), 0.06, 0.025, 0.02, 8)
    return p


def washstand() -> Prop:
    p = Prop("washstand")
    w, d, h = 0.9, 0.45, 0.78
    p.box("timber", -w / 2, w / 2, -d / 2, d / 2, 0.2, h - 0.03)
    for x in (-w / 2 + 0.03, w / 2 - 0.03):
        for y in (-d / 2 + 0.03, d / 2 - 0.03):
            p.box("timber", x - 0.025, x + 0.025, y - 0.025, y + 0.025, 0, 0.2)
    p.box("marble", -w / 2 - 0.02, w / 2 + 0.02, -d / 2 - 0.02, d / 2, h - 0.03, h)
    p.box("marble", -w / 2, w / 2, d / 2 - 0.03, d / 2, h, h + 0.22)
    p.cyl("china", (0.05, -0.02, h), 0.11, 0.1, 0.2, 20)
    p.cyl("china", (-0.25, 0.04, h), 0.26, 0.08, 0.06, 16)
    p.cyl("china", (-0.25, 0.04, h + 0.2), 0.08, 0.06, 0.075, 16)
    return p


def clawfoot_bath() -> Prop:
    p = Prop("clawfoot_bath")
    w, l = 0.75, 1.65
    p.sphere("enamel", (0, 0, 0.42), 1.0, (w / 2, l / 2, 0.3), 24)
    p.box("enamel", -w / 2 + 0.02, w / 2 - 0.02, -l / 2 + 0.05, l / 2 - 0.05, 0.36, 0.6)
    p.cyl("enamel", (0, -l / 2 + w / 2, 0.36), 0.24, w / 2 - 0.02, None, 20)
    p.cyl("enamel", (0, l / 2 - w / 2, 0.36), 0.24, w / 2 - 0.02, None, 20)
    p.box("china", -w / 2 + 0.05, w / 2 - 0.05, -l / 2 + 0.1, l / 2 - 0.1, 0.59, 0.605)
    for x in (-w / 2 + 0.08, w / 2 - 0.08):
        for y in (-l / 2 + 0.2, l / 2 - 0.2):
            p.cyl("iron", (x, y, 0), 0.2, 0.05, 0.03, 10)
            p.sphere("iron", (x, y, 0.03), 0.045)
    for x in (-0.08, 0.08):
        p.cyl("chrome", (x, l / 2 - 0.05, 0.6), 0.12, 0.012, None, 8)
        p.cyl("chrome", (x, l / 2 - 0.05, 0.72), 0.03, 0.03, None, 10)
    return p


def settee() -> Prop:
    p = Prop("settee")
    w, d = 1.8, 0.82
    p.box("fabric", -w / 2, w / 2, -d / 2, d / 2, 0.12, 0.42)
    p.box("fabric", -w / 2, w / 2, d / 2 - 0.2, d / 2, 0.42, 0.85)
    for x in (-w / 2, w / 2 - 0.16):
        p.box("fabric", x, x + 0.16, -d / 2, d / 2, 0.42, 0.62)
    for i in range(3):
        x0 = -w / 2 + 0.16 + i * (w - 0.32) / 3
        p.box("fabric", x0 + 0.01, x0 + (w - 0.32) / 3 - 0.01, -d / 2 + 0.02, d / 2 - 0.2, 0.42, 0.52)
    for x in (-w / 2 + 0.08, w / 2 - 0.08):
        for y in (-d / 2 + 0.08, d / 2 - 0.08):
            p.cyl("timber", (x, y, 0), 0.12, 0.025, 0.035, 8)
    return p


def kitchen_sink() -> Prop:
    p = Prop("kitchen_sink")
    w, d, h = 1.5, 0.55, 0.9
    p.box("timber", -w / 2, w / 2, -d / 2 + 0.03, d / 2, 0.08, h - 0.04)
    p.box("timber", -w / 2 + 0.02, -0.02, -d / 2, -d / 2 + 0.03, 0.12, h - 0.08)
    p.box("timber", 0.02, w / 2 - 0.02, -d / 2, -d / 2 + 0.03, 0.12, h - 0.08)
    p.box("enamel", -w / 2, -0.05, -d / 2, d / 2, h - 0.04, h)
    p.box("enamel", -w / 2 + 0.06, -0.11, -d / 2 + 0.06, d / 2 - 0.06, h - 0.002, h + 0.001)
    p.box("timber", -0.05, w / 2, -d / 2, d / 2, h - 0.04, h - 0.01)
    for i in range(8):
        x = 0.0 + i * 0.09
        p.box("timber", x, x + 0.02, -d / 2, d / 2, h - 0.01, h)
    p.box("enamel", -w / 2, w / 2, d / 2 - 0.02, d / 2, h, h + 0.3)
    for x in (-0.55, -0.3):
        p.cyl("chrome", (x, d / 2 - 0.05, h + 0.1), 0.12, 0.012, None, 8)
        p.rail("chrome", (x, d / 2 - 0.05, h + 0.21), (x, d / 2 - 0.2, h + 0.18), 0.01)
        p.cyl("chrome", (x, d / 2 - 0.05, h + 0.2), 0.04, 0.025, None, 8)
    return p


def pendant_light() -> Prop:
    p = Prop("pendant_light")
    # Hangs from the ceiling: origin at the ceiling, everything below it.
    p.cyl("brass", (0, 0, -0.04), 0.04, 0.05, None, 12)
    p.cyl("fabric", (0, 0, -0.75), 0.71, 0.006, None, 6)
    p.cyl("glass", (0, 0, -0.95), 0.2, 0.22, 0.06, 24)
    p.sphere("glass", (0, 0, -0.95), 0.18, (1, 1, 0.35), 20)
    return p


def standard_lamp() -> Prop:
    p = Prop("standard_lamp")
    p.cyl("brass", (0, 0, 0), 0.04, 0.16, 0.12, 20)
    p.cyl("brass", (0, 0, 0.04), 1.3, 0.016, None, 10)
    p.cyl("fabric", (0, 0, 1.22), 0.32, 0.25, 0.14, 24, caps=False)
    p.cyl("glass", (0, 0, 1.3), 0.12, 0.05, None, 12)
    return p


def candle() -> Prop:
    p = Prop("candle")
    p.cyl("enamel", (0, 0, 0), 0.02, 0.07, 0.06, 16)
    p.cyl("enamel", (0, 0, 0.02), 0.03, 0.02, None, 10)
    p.cyl("glass", (0, 0, 0.03), 0.14, 0.012, None, 10)
    p.rail("enamel", (0.06, 0, 0.012), (0.1, 0, 0.04), 0.006)
    return p


PROPS = {f.__name__: f for f in [wood_stove, icebox, wireless_set, wall_telephone, laminex_table, kitchen_chair, iron_bed,
                                  wardrobe, chest_of_drawers, washstand, clawfoot_bath, settee, kitchen_sink, pendant_light,
                                  standard_lamp, candle]}


def main(names: list[str]) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for n in names or PROPS:
        PROPS[n]().finish()


if __name__ == "__main__":
    main(sys.argv[1:])
