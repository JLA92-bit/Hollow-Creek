"""Shared helpers for the asset fetch scripts. Standard library plus Pillow and NumPy only."""
import hashlib
import json
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / "tools" / "cache"
MANIFEST = ROOT / "data" / "asset_manifest.json"
CREDITS_JSON = ROOT / "data" / "asset_credits.json"
UA = {"User-Agent": "HollowCreek-asset-fetch/1.0 (Godot game; contact via GitHub)"}


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text())


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def md5(path: Path) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: Path, expected_md5: str | None = None) -> Path:
    """Downloads to dest unless it already exists with the right checksum."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and (expected_md5 is None or md5(dest) == expected_md5):
        return dest
    tmp = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=300) as r, open(tmp, "wb") as f:
        while chunk := r.read(1 << 20):
            f.write(chunk)
    if expected_md5 and md5(tmp) != expected_md5:
        tmp.unlink()
        raise RuntimeError(f"Checksum mismatch for {url}")
    tmp.replace(dest)
    return dest


# Basis Universal in Godot 4.7 is UASTC only: about 2.2 MB per 1k texture even with RDO, which
# breaks the 40 MB first-download budget. Lossy WebP is about 0.3 MB. See docs/DECISIONS.md (17).
LOSSY_QUALITY = 0.82


def texture_import(normal_map: bool = False, size_limit: int = 1024) -> str:
    """A Godot .import file for a 3D texture: lossy WebP in the pack, mipmapped, size capped."""
    return "\n".join([
        "[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", "",
        "compress/mode=1",
        f"compress/lossy_quality={LOSSY_QUALITY if not normal_map else 0.9}",
        f"compress/normal_map={1 if normal_map else 2}",
        "compress/channel_pack=0",
        "mipmaps/generate=true",
        "mipmaps/limit=-1",
        f"roughness/mode=0",
        "process/fix_alpha_border=true",
        "process/premult_alpha=false",
        "process/normal_map_invert_y=false",
        f"process/size_limit={size_limit}",
        "detect_3d/compress_to=0",
        "",
    ])


def array_import(slices: int, normal_map: bool = False) -> str:
    return "\n".join([
        "[remap]", "", 'importer="2d_array_texture"', 'type="CompressedTexture2DArray"', "", "[params]", "",
        "compress/mode=1",
        f"compress/lossy_quality={0.9 if normal_map else LOSSY_QUALITY}",
        "compress/channel_pack=0",
        "mipmaps/generate=true",
        "mipmaps/limit=-1",
        "slices/horizontal=1",
        f"slices/vertical={slices}",
        "",
    ])


def hdr_import() -> str:
    # Keeps HDR range. VRAM Uncompressed stores it as RGBE9995 (4 bytes a pixel).
    return "\n".join([
        "[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", "",
        "compress/mode=3",
        "compress/hdr_compression=0",
        "mipmaps/generate=true",
        "mipmaps/limit=-1",
        "process/hdr_as_srgb=false",
        "process/hdr_clamp_exposure=false",
        "process/size_limit=0",
        "detect_3d/compress_to=0",
        "",
    ])


def write_if_changed(path: Path, text: str) -> None:
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


def record_credit(key: str, entry: dict) -> None:
    data = json.loads(CREDITS_JSON.read_text()) if CREDITS_JSON.exists() else {}
    data[key] = entry
    CREDITS_JSON.write_text(json.dumps(dict(sorted(data.items())), indent=2) + "\n")


def log(msg: str) -> None:
    print(msg, flush=True)
    sys.stdout.flush()
