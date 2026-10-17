"""Generates tileable 1950s wallpaper pattern masks. Red = motif, green = accent (leaves, fine lines).
The wallpaper shader colours them with a colourway (ground, motif, accent), so one mask gives many papers.

Usage: python3 tools/textures/make_wallpapers.py
Writes assets/materials/wallpaper/{floral,stripe,sprig,plaid,trellis}.png (512 px tiles, about 0.53 m).
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "materials" / "wallpaper"
S = 512
SS = 2


def canvas():
    return Image.new("RGB", (S * SS, S * SS), (0, 0, 0))


def tile_draw(draw_fn, img):
    # Draw each element at the 9 wrapped offsets so the pattern tiles seamlessly.
    d = ImageDraw.Draw(img)
    W = S * SS
    for ox in (-W, 0, W):
        for oy in (-W, 0, W):
            draw_fn(d, ox, oy)


def finish(img, name):
    img = img.resize((S, S), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.png"
    img.save(path, optimize=True)
    Path(str(path) + ".import").write_text("\n".join([
        "[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", "",
        "compress/mode=0", "mipmaps/generate=true", "process/size_limit=0", "detect_3d/compress_to=0", ""]))
    print("wrote", path.relative_to(ROOT))


def rose(d, cx, cy, r, ox, oy):
    for k in range(5):
        a = k / 5 * math.tau
        px = cx + math.cos(a) * r * 0.45 + ox
        py = cy + math.sin(a) * r * 0.45 + oy
        d.ellipse([px - r * 0.55, py - r * 0.55, px + r * 0.55, py + r * 0.55], fill=(255, 0, 0))
    d.ellipse([cx - r * 0.3 + ox, cy - r * 0.3 + oy, cx + r * 0.3 + ox, cy + r * 0.3 + oy], fill=(150, 0, 0))


def leaf(d, cx, cy, length, ang, ox, oy):
    pts = []
    for i in range(9):
        t = i / 8
        w = math.sin(math.pi * t) * length * 0.28
        x = t * length
        pts.append((x, w))
    pts += [(x, -w) for x, w in reversed(pts)]
    c, s = math.cos(ang), math.sin(ang)
    d.polygon([(cx + x * c - y * s + ox, cy + x * s + y * c + oy) for x, y in pts], fill=(0, 255, 0))


def floral():
    rnd = random.Random(1)
    img = canvas()
    W = S * SS
    spots = [(0.25, 0.25), (0.75, 0.75), (0.75, 0.2), (0.25, 0.7)]

    def draw(d, ox, oy):
        for i, (fx, fy) in enumerate(spots):
            cx, cy = fx * W, fy * W
            r = W * (0.07 if i < 2 else 0.045)
            for k in range(3):
                leaf(d, cx, cy, r * 2.2, k * 2.1 + i, ox, oy)
            rose(d, cx, cy, r, ox, oy)
    tile_draw(draw, img)
    finish(img, "floral")


def stripe():
    img = canvas()
    W = S * SS
    d = ImageDraw.Draw(img)
    # Regency stripe: a broad band, two fine lines.
    d.rectangle([W * 0.1, 0, W * 0.38, W], fill=(255, 0, 0))
    for x in (0.5, 0.56, 0.9):
        d.rectangle([W * x, 0, W * x + W * 0.012, W], fill=(0, 255, 0))
    finish(img, "stripe")


def sprig():
    img = canvas()
    W = S * SS
    rnd = random.Random(7)
    pts = [((i % 4 + (0.5 if (i // 4) % 2 else 0)) / 4, (i // 4) / 4) for i in range(16)]

    def draw(d, ox, oy):
        for (fx, fy) in pts:
            cx, cy = fx * W + W / 8, fy * W + W / 8
            leaf(d, cx, cy, W * 0.05, -0.9, ox, oy)
            leaf(d, cx, cy, W * 0.05, -2.3, ox, oy)
            d.ellipse([cx - W * 0.012 + ox, cy - W * 0.03 + oy, cx + W * 0.012 + ox, cy - W * 0.006 + oy], fill=(255, 0, 0))
    tile_draw(draw, img)
    finish(img, "sprig")


def plaid():
    W = S * SS
    a = np.zeros((W, W, 3), dtype=np.float32)
    x = np.arange(W) / W
    bands = ((x > 0.1) & (x < 0.3)).astype(np.float32)
    fine = ((np.abs(x - 0.62) < 0.012) | (np.abs(x - 0.68) < 0.012)).astype(np.float32)
    a[..., 0] = np.clip(bands[None, :] * 0.6 + bands[:, None] * 0.6, 0, 1)
    a[..., 1] = np.clip(fine[None, :] + fine[:, None], 0, 1)
    finish(Image.fromarray((a * 255).astype(np.uint8)), "plaid")


def trellis():
    img = canvas()
    W = S * SS

    def draw(d, ox, oy):
        for k in range(-1, 3):
            d.line([(k * W / 2 + ox, oy), (k * W / 2 + W / 2 + ox, W / 2 + oy), (k * W / 2 + ox, W + oy)], fill=(0, 255, 0), width=int(W * 0.012))
            d.line([(k * W / 2 + W / 2 + ox, oy), (k * W / 2 + ox, W / 2 + oy), (k * W / 2 + W / 2 + ox, W + oy)], fill=(0, 255, 0), width=int(W * 0.012))
        for (fx, fy) in [(0.0, 0.0), (0.5, 0.5)]:
            r = W * 0.035
            d.ellipse([fx * W - r + ox, fy * W - r + oy, fx * W + r + ox, fy * W + r + oy], fill=(255, 0, 0))
    tile_draw(draw, img)
    finish(img, "trellis")


if __name__ == "__main__":
    floral()
    stripe()
    sprig()
    plaid()
    trellis()
