"""Fetches ambientCG materials listed under "ambientcg" in data/asset_manifest.json.

Usage: python3 tools/assets/fetch_ambientcg.py

ambientCG's API is on ambientcg.com, but its zips are served from acg-download.struffelproductions.com,
which may be blocked in some environments. When a download fails, the script looks for the same zip
in assets/incoming/ (where Josh drops manual downloads), and otherwise lists what's missing.
Entry format: {"id": "WoodSiding008", "as": "weatherboard_alt", "res": "1K-JPG", "size_m": 2.0}
"""
import os
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from common import CACHE, ROOT, download, load_manifest, log, record_credit, texture_import, write_if_changed  # noqa: E402

MAPS = {"Color": "albedo", "NormalGL": "normal", "Roughness": "roughness", "AmbientOcclusion": "ao", "Metalness": "metal"}


def extract(zpath: Path, m: dict) -> None:
    out_dir = ROOT / "assets" / "materials" / m["as"]
    out_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zpath) as z:
        for name in z.namelist():
            for key, ours in MAPS.items():
                if name.endswith(f"_{key}.jpg"):
                    dest = out_dir / f"{m['as']}_{ours}.jpg"
                    dest.write_bytes(z.read(name))
                    write_if_changed(Path(str(dest) + ".import"), texture_import(normal_map=(ours == "normal")))
    record_credit(f"ambientcg:{m['id']}", {
        "name": m["id"], "authors": ["ambientCG (Lennart Demes)"],
        "source": f"https://ambientcg.com/view?id={m['id']}", "licence": "CC0",
        "kind": "texture", "used_as": m.get("use", m["as"]),
    })


def main() -> None:
    mats = load_manifest().get("ambientcg", {}).get("materials", [])
    missing = []
    for m in mats:
        fname = f"{m['id']}_{m.get('res', '1K-JPG')}.zip"
        incoming = ROOT / "assets" / "incoming" / fname
        try:
            z = download(f"https://ambientcg.com/get?file={fname}", CACHE / "ambientcg" / fname)
        except Exception as e:  # blocked host, offline, etc.
            if incoming.exists():
                z = incoming
            else:
                missing.append((m, str(e)))
                continue
        extract(z, m)
        log(f"  ambientCG {m['id']} -> assets/materials/{m['as']}")
    if missing:
        log("Missing (add to docs/ASSET_REQUESTS.md or drop the zips in assets/incoming/):")
        for m, err in missing:
            log(f"  https://ambientcg.com/get?file={m['id']}_{m.get('res', '1K-JPG')}.zip  ({err[:60]})")
    log(f"ambientCG: {len(mats) - len(missing)} of {len(mats)} materials ready.")


if __name__ == "__main__":
    main()
