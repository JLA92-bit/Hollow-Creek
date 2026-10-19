"""Head-and-shoulders portrait models with face expressions, for the interview screen
(scenes/investigation/portrait_view.gd). Each is the resident's own MPFB body, cropped at the chest,
with MPFB's face action units (brows, eyes, mouth; CC0) as glTF morph targets.

Usage: tools/cache/blender-venv/bin/python tools/characters/make_portraits.py [resident_id ...]
Writes assets/characters/<name>_portrait.glb (shipped in the characters pack).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_agnes as base  # noqa: E402
import make_residents as res  # noqa: E402


def main():
    data = json.loads((base.ROOT / "data" / "residents.json").read_text())
    ids = sys.argv[1:] or list(data["residents"])
    for rid in ids:
        r = data["residents"][rid]
        name = rid.replace("r_", "")
        if rid == "r_agnes":
            base.build(0, name=name, animations="none", portrait=True)
        else:
            base.build(0, name=name, macros=res.macros_for(r), skirt=r["sex"] == "f", animations="none", portrait=True,
                       bun="bun" in r.get("appearance", "") or "plait" in r.get("appearance", ""))


if __name__ == "__main__":
    main()
