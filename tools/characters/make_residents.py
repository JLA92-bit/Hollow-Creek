"""Builds every resident through the MPFB pipeline (docs/RESIDENTS.md), each to their own age, sex,
height and build from data/residents.json. Women get the dress (skirt helper), men trousers (tights
helper). Same skeleton, slots and animations as Agnes, so ResidentLook colours them the same way.

Usage: bash tools/characters/setup_mpfb.sh, then
       tools/cache/blender-venv/bin/python tools/characters/make_residents.py [resident_id ...]
Writes assets/characters/<name>.glb and <name>_lod1.glb, and sets "model" in data/residents.json.
These ship in the background "characters" pack (data/packs.json), not the first download.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_agnes as base  # noqa: E402

ROOT = base.ROOT
DATA = ROOT / "data" / "residents.json"


def mpfb_age(years: float) -> float:
    """MPFB's age scale: 0.1875 is 11, 0.5 is 25, 1.0 is 90."""
    if years <= 25:
        return 0.1875 + max(0.0, years - 11) / 14.0 * (0.5 - 0.1875)
    return 0.5 + (years - 25) / 65.0 * 0.5


def macros_for(r: dict) -> dict:
    female = r["sex"] == "f"
    build = float(r.get("build", 0.5))
    height = float(r.get("height", 1.62 if female else 1.76))
    return {"gender": 0.0 if female else 1.0, "age": round(mpfb_age(float(r["age"])), 3), "muscle": round(0.3 + 0.35 * build + (0.0 if female else 0.1), 3),
            "weight": round(0.3 + 0.45 * build, 3), "proportions": 0.55, "height": round(min(1.0, max(0.0, (height - 1.5) / 0.45)), 3),
            "cupsize": 0.45, "firmness": 0.4, "race": {"asian": 0.0, "caucasian": 1.0, "african": 0.0}}


def main():
    data = json.loads(DATA.read_text())
    ids = sys.argv[1:] or list(data["residents"])
    for rid in ids:
        r = data["residents"][rid]
        name = rid.replace("r_", "")
        macros = macros_for(r)
        print(rid, macros)
        for lod in (0, 1):
            if rid == "r_agnes":
                base.build(lod, name=name, animations="none")   # her own macros, skirt and bun
            else:
                base.build(lod, name=name, macros=macros, skirt=r["sex"] == "f", animations="none", bun="bun" in r.get("appearance", "") or "plait" in r.get("appearance", ""))
        r["model"] = name
    # Keep the file's own formatting where possible: only the "model" values change.
    text = DATA.read_text()
    for rid in ids:
        r = data["residents"][rid]
        marker = f'"{rid}": {{'
        i = text.index(marker)
        j = text.index('"sex"', i)
        if '"model"' not in text[i:text.index("}", text.index('"secrets"', i))]:
            text = text[:j] + f'"model": "{r["model"]}", ' + text[j:]
    DATA.write_text(text)


if __name__ == "__main__":
    main()
