"""Generates foliage card textures, a macro noise map and a water normal map. Deterministic (seeded).

Usage: python3 tools/textures/make_foliage.py
Outputs (with Godot .import files):
  assets/models/foliage/gum_leaves.png    eucalypt leaf clusters (RGBA)
  assets/models/foliage/shrub_leaves.png  small-leaved bush (RGBA)
  assets/models/foliage/grass_tuft.png    dry grass tuft (RGBA)
  assets/materials/noise/macro_noise.png  three octaves of tileable value noise (RGB)
  assets/materials/noise/water_normal.png tileable ripple normal map
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SS = 2  # supersampling for clean alpha edges


def card_import(normal: bool = False, lossless: bool = False) -> str:
    return "\n".join([
        "[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", "",
        f"compress/mode={0 if lossless else 1}", "compress/lossy_quality=0.85",
        f"compress/normal_map={1 if normal else 2}", "mipmaps/generate=true",
        "process/fix_alpha_border=true", "process/premult_alpha=false", "process/size_limit=0",
        "detect_3d/compress_to=0", "",
    ])


def save(img: Image.Image, path: Path, normal: bool = False, lossless: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    Path(str(path) + ".import").write_text(card_import(normal, lossless))
    print("wrote", path.relative_to(ROOT))


def leaf_polygon(cx, cy, length, width, angle, curve):
    """A lanceolate (gum-leaf) outline: narrow, pointed, gently sickle-shaped."""
    pts_l, pts_r = [], []
    steps = 14
    for i in range(steps + 1):
        t = i / steps
        w = width * math.sin(math.pi * t) ** 0.85 * (1.0 - 0.35 * t)
        bend = curve * length * (t ** 2)
        along = t * length
        for sign, pts in ((1, pts_l), (-1, pts_r)):
            x = along
            y = sign * w * 0.5 + bend
            pts.append((cx + x * math.cos(angle) - y * math.sin(angle), cy + x * math.sin(angle) + y * math.cos(angle)))
    return pts_l + pts_r[::-1]


def gum_leaves(size=1024, seed=7):
    rnd = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Several drooping clusters hanging from twigs across the card.
    clusters = [(rnd.uniform(0.1, 0.9) * S, rnd.uniform(0.05, 0.62) * S) for _ in range(20)]
    for (bx, by) in clusters:
        twig_len = rnd.uniform(0.12, 0.25) * S
        twig_ang = math.radians(rnd.uniform(60, 120))  # mostly downward
        tx = bx + math.cos(twig_ang) * twig_len
        ty = by + math.sin(twig_ang) * twig_len
        d.line([(bx, by), (tx, ty)], fill=(92, 70, 52, 255), width=int(4 * SS))
        for _ in range(rnd.randint(14, 22)):
            t = rnd.uniform(0.1, 1.0)
            px = bx + (tx - bx) * t
            py = by + (ty - by) * t
            ang = math.radians(rnd.uniform(55, 125))  # leaves hang down
            length = rnd.uniform(0.09, 0.16) * S
            width = length * rnd.uniform(0.16, 0.24)
            base = np.array([rnd.uniform(96, 128), rnd.uniform(112, 138), rnd.uniform(84, 104)])
            if rnd.random() < 0.18:
                base += np.array([24, 18, -8])  # some olive and yellowing leaves
            if rnd.random() < 0.25:
                base += np.array([-8, 0, 14])  # some blue-grey juvenile leaves
            shade = rnd.uniform(0.75, 1.1)
            col = tuple(int(np.clip(c * shade, 0, 255)) for c in base) + (255,)
            poly = leaf_polygon(px, py, length, width, ang, rnd.uniform(-0.12, 0.12))
            d.polygon(poly, fill=col)
            # Midrib.
            mx = px + math.cos(ang) * length * 0.85
            my = py + math.sin(ang) * length * 0.85
            d.line([(px, py), (mx, my)], fill=tuple(int(c * 1.12) for c in col[:3]) + (255,), width=max(1, SS))
    img = img.resize((size, size), Image.LANCZOS)
    return img


def shrub_leaves(size=512, seed=11):
    rnd = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(420):
        r = rnd.uniform(0, 0.46) * S
        a = rnd.uniform(0, math.tau)
        cx = S / 2 + math.cos(a) * r
        cy = S / 2 + math.sin(a) * r * 0.9
        length = rnd.uniform(0.035, 0.06) * S
        ang = rnd.uniform(0, math.tau)
        g = rnd.uniform(0.7, 1.1)
        col = (int(78 * g), int(98 * g), int(58 * g), 255)
        d.polygon(leaf_polygon(cx, cy, length, length * 0.4, ang, 0.05), fill=col)
    return img.resize((size, size), Image.LANCZOS)


def grass_tuft(size=512, seed=3):
    rnd = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(140):
        x0 = S / 2 + rnd.uniform(-0.18, 0.18) * S
        h = rnd.uniform(0.45, 0.95) * S
        lean = rnd.uniform(-0.35, 0.35) * S
        w = rnd.uniform(3, 7) * SS
        straw = rnd.random()
        col = (int(196 - 40 * straw), int(176 - 40 * straw), int(118 - 40 * straw), 255) if rnd.random() < 0.85 else (122, 128, 78, 255)
        pts = []
        for i in range(10):
            t = i / 9
            pts.append((x0 + lean * t * t, S - 2 - h * t))
        for i in range(len(pts) - 1):
            ww = max(1, int(w * (1 - i / len(pts))))
            d.line([pts[i], pts[i + 1]], fill=col, width=ww)
    return img.resize((size, size), Image.LANCZOS)


def value_noise(size, cells, rng):
    g = rng.random((cells, cells))
    x = np.linspace(0, cells, size, endpoint=False)
    xi = np.floor(x).astype(int)
    xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    x0, x1 = xi % cells, (xi + 1) % cells
    a = g[np.ix_(x0, x0)]
    b = g[np.ix_(x0, x1)]
    c = g[np.ix_(x1, x0)]
    dd = g[np.ix_(x1, x1)]
    fx = xf[None, :]
    fy = xf[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + dd * fx) * fy


def fbm(size, base, octaves, rng):
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(size, base * 2 ** o, rng) * amp
        total += amp
        amp *= 0.5
    return out / total


def macro_noise(size=512, seed=5):
    rng = np.random.default_rng(seed)
    chans = [fbm(size, 4, 4, rng), fbm(size, 8, 4, rng), fbm(size, 16, 3, rng)]
    arr = np.stack([(c - c.min()) / (c.max() - c.min()) for c in chans], axis=-1)
    return Image.fromarray((arr * 255).astype(np.uint8), "RGB")


def water_normal(size=512, seed=9):
    rng = np.random.default_rng(seed)
    h = fbm(size, 8, 5, rng)
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 6.0
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 6.0
    n = np.stack([-gx, -gy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def main():
    save(gum_leaves(), ROOT / "assets/models/foliage/gum_leaves.png")
    save(shrub_leaves(), ROOT / "assets/models/foliage/shrub_leaves.png")
    save(grass_tuft(), ROOT / "assets/models/foliage/grass_tuft.png")
    save(macro_noise(), ROOT / "assets/materials/noise/macro_noise.png", lossless=True)
    save(water_normal(), ROOT / "assets/materials/noise/water_normal.png", normal=True, lossless=True)


if __name__ == "__main__":
    main()
