"""Fetches the Poly Haven textures, HDRIs and models listed in data/asset_manifest.json.

Usage: python3 tools/assets/fetch_polyhaven.py [--only id1,id2] [--kind textures|hdris|models]

Textures become assets/materials/<as>/<as>_albedo.jpg, _normal.jpg and _orm.jpg (Poly Haven's
"arm" map is already packed as occlusion, roughness, metallic, which is Godot's ORM order).
Ground layers marked with "array" are stacked into one Texture2DArray per map so the terrain
shader uses two samplers instead of eight. Every texture gets a .import file (lossy WebP, size capped; see common.py).
"""
import argparse
import io
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from common import (CACHE, ROOT, array_import, download, get_json, hdr_import, load_manifest, log,  # noqa: E402
                    record_credit, texture_import, write_if_changed)

API = "https://api.polyhaven.com"
PH_CACHE = CACHE / "polyhaven"


def credit(asset_id: str, kind: str, used_as: str) -> None:
    info = get_json(f"{API}/info/{asset_id}")
    record_credit(f"polyhaven:{asset_id}", {
        "name": info.get("name", asset_id),
        "authors": sorted(info.get("authors", {}).keys()),
        "source": f"https://polyhaven.com/a/{asset_id}",
        "licence": "CC0",
        "kind": kind,
        "used_as": used_as,
    })


def neutralise(img: Image.Image, target: float) -> Image.Image:
    """Desaturates and lifts an albedo so a paint colour multiplies cleanly over it."""
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    lum = a @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    lum = lum / max(float(lum.mean()), 1e-3) * target
    # Keep the grain but soften the contrast so paint reads as paint, not stained timber.
    lum = target + (lum - target) * 0.55
    out = np.clip(np.stack([lum, lum, lum], axis=-1), 0, 1)
    return Image.fromarray((out * 255).astype(np.uint8))


def fetch_texture(t: dict) -> dict[str, Path]:
    files = get_json(f"{API}/files/{t['id']}")
    res = t.get("res", "1k")
    maps = {"albedo": "Diffuse", "normal": "nor_gl", "orm": "arm"}
    # Ground layers only feed the texture arrays, so they stay in the git-ignored cache.
    out_dir = (CACHE / "layers" / t["as"]) if "array" in t else (ROOT / "assets" / "materials" / t["as"])
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: dict[str, Path] = {}
    for ours, theirs in maps.items():
        entry = files[theirs][res]["jpg"]
        cached = download(entry["url"], PH_CACHE / t["id"] / Path(entry["url"]).name, entry["md5"])
        dest = out_dir / f"{t['as']}_{ours}.jpg"
        if ours == "albedo" and "neutral" in t:
            neutralise(Image.open(cached), float(t["neutral"])).save(dest, quality=92)
        else:
            dest.write_bytes(cached.read_bytes())
        paths[ours] = dest
        if "array" not in t:
            # Normal and ORM maps can be imported smaller ("detail_limit") to save download size.
            limit = 1024 if ours == "albedo" else int(t.get("detail_limit", 1024))
            write_if_changed(Path(str(dest) + ".import"), texture_import(normal_map=(ours == "normal"), size_limit=limit))
        elif dest.with_suffix(".jpg.import").exists():
            dest.with_suffix(".jpg.import").unlink()
    credit(t["id"], "texture", t.get("use", t["as"]))
    log(f"  texture {t['id']} -> {out_dir}")
    return paths


def build_arrays(textures: list[dict], layer_paths: dict[str, dict[str, Path]]) -> None:
    groups: dict[str, list[dict]] = {}
    for t in textures:
        if "array" in t:
            groups.setdefault(t["array"], []).append(t)
    for name, members in groups.items():
        members.sort(key=lambda m: m["slot"])
        out_dir = ROOT / "assets" / "materials" / f"{name}_array"
        out_dir.mkdir(parents=True, exist_ok=True)
        for kind in ("albedo", "normal", "orm"):
            imgs = [Image.open(layer_paths[m["as"]][kind]).convert("RGB").resize((1024, 1024)) for m in members]
            sheet = Image.new("RGB", (1024, 1024 * len(imgs)))
            for i, im in enumerate(imgs):
                sheet.paste(im, (0, 1024 * i))
            dest = out_dir / f"{name}_{kind}_array.jpg"
            sheet.save(dest, quality=93)
            write_if_changed(Path(str(dest) + ".import"), array_import(len(imgs), normal_map=(kind == "normal")))
        log(f"  array {name}: {[m['as'] for m in members]}")


def fetch_hdri(h: dict) -> None:
    files = get_json(f"{API}/files/{h['id']}")
    entry = files["hdri"][h.get("res", "1k")]["hdr"]
    dest = ROOT / "assets" / "hdri" / f"{h['as']}.hdr"
    cached = download(entry["url"], PH_CACHE / h["id"] / Path(entry["url"]).name, entry["md5"])
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(cached.read_bytes())
    write_if_changed(Path(str(dest) + ".import"), hdr_import())
    credit(h["id"], "hdri", h["as"])
    log(f"  hdri {h['id']} -> {dest.relative_to(ROOT)}")


def fetch_model(m: dict) -> None:
    files = get_json(f"{API}/files/{m['id']}")
    entry = files["gltf"][m.get("res", "1k")]["gltf"]
    out_dir = ROOT / "assets" / "models" / m["id"]
    gltf = download(entry["url"], out_dir / f"{m['id']}.gltf", entry["md5"])
    for rel, inc in entry.get("include", {}).items():
        dest = download(inc["url"], out_dir / rel, inc["md5"])
        if dest.suffix.lower() in (".jpg", ".png"):
            write_if_changed(Path(str(dest) + ".import"), texture_import(normal_map="_nor" in dest.name, size_limit=int(m.get("tex_limit", 512))))
    credit(m["id"], "model", m.get("use", m["id"]))
    log(f"  model {m['id']} -> {out_dir.relative_to(ROOT)} ({gltf.stat().st_size // 1024} KB gltf)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="comma-separated Poly Haven ids")
    ap.add_argument("--kind", default="", choices=["", "textures", "hdris", "models"])
    args = ap.parse_args()
    only = {s for s in args.only.split(",") if s}
    ph = load_manifest()["polyhaven"]

    def wanted(item: dict, kind: str) -> bool:
        return (not args.kind or args.kind == kind) and (not only or item["id"] in only)

    layer_paths: dict[str, dict[str, Path]] = {}
    for t in ph.get("textures", []):
        if wanted(t, "textures") or ("array" in t and (not args.kind or args.kind == "textures")):
            layer_paths[t["as"]] = fetch_texture(t)
    if any("array" in t for t in ph.get("textures", [])) and (not args.kind or args.kind == "textures"):
        build_arrays(ph["textures"], layer_paths)
    for h in ph.get("hdris", []):
        if wanted(h, "hdris"):
            fetch_hdri(h)
    for m in ph.get("models", []):
        if wanted(m, "models"):
            fetch_model(m)
    log("Poly Haven fetch complete. Run tools/assets/write_credits.py, then import in Godot.")


if __name__ == "__main__":
    main()
