"""Generates leaf-card textures for garden plants: a round clump of leaves with flowers or fruit.
Deterministic (seeded), 256 px. Cards are drawn on crossed quads by scripts/build/garden_builder.gd.

Usage: python3 tools/textures/make_garden.py
Writes assets/models/garden/{rose,hydrangea,lavender,agapanthus,geranium,hedge,vegies,lemon,apple,wattle}.png
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_foliage import leaf_polygon, save  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models" / "garden"
SS = 2
S = 512 * SS


def card():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def jitter(col, rnd, amt=0.15):
    g = rnd.uniform(1 - amt, 1 + amt)
    return tuple(max(0, min(255, int(c * g))) for c in col[:3]) + (255,)


def clump(d, rnd, n, leaf, green, shape="round", spread=0.46, base=0.97, top=0.05):
    """Leaves filling a dome (round), an upright fan (upright) or a box (box)."""
    for _ in range(n):
        if shape == "box":
            cx = rnd.uniform(0.06, 0.94) * S
            cy = rnd.uniform(0.2, base) * S
        elif shape == "upright":
            t = rnd.random()
            cx = S / 2 + rnd.uniform(-1, 1) * spread * S * (0.25 + 0.75 * t)
            cy = base * S - t * (base - top) * S
        else:
            a = rnd.uniform(math.pi, math.tau)
            r = math.sqrt(rnd.random()) * spread * S
            cx = S / 2 + math.cos(a) * r
            cy = base * S + math.sin(a) * r * ((base - top) / spread)
        ang = rnd.uniform(0, math.tau)
        ln = rnd.uniform(*leaf) * S
        d.polygon(leaf_polygon(cx, cy, ln, ln * 0.45, ang, 0.05), fill=jitter(green, rnd))


def blooms(d, rnd, n, colours, radius, region=(0.15, 0.85, 0.08, 0.8), petals=0):
    for _ in range(n):
        cx = rnd.uniform(region[0], region[1]) * S
        cy = rnd.uniform(region[2], region[3]) * S
        r = rnd.uniform(*radius) * S
        col = jitter(rnd.choice(colours), rnd, 0.1)
        if petals:
            for k in range(petals):
                a = k / petals * math.tau
                px, py = cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55
                d.ellipse([px - r * 0.5, py - r * 0.5, px + r * 0.5, py + r * 0.5], fill=col)
            d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3], fill=jitter(col, rnd, 0.25))
        else:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
            d.ellipse([cx - r * 0.5, cy - r * 0.6, cx + r * 0.3, cy], fill=jitter(col, rnd, 0.2))


def stems(d, rnd, n, colour, base=0.98, height=(0.4, 0.8), lean=0.25, width=3):
    tips = []
    for _ in range(n):
        x0 = S / 2 + rnd.uniform(-0.12, 0.12) * S
        h = rnd.uniform(*height) * S
        x1 = x0 + rnd.uniform(-lean, lean) * S
        d.line([(x0, base * S), (x1, base * S - h)], fill=colour, width=width * SS)
        tips.append((x1, base * S - h))
    return tips


def rose():
    rnd = random.Random(21)
    img = card()
    d = ImageDraw.Draw(img)
    clump(d, rnd, 650, (0.03, 0.055), (62, 92, 48))
    blooms(d, rnd, 26, [(176, 32, 44), (214, 92, 120), (236, 206, 196)], (0.025, 0.04), (0.18, 0.82, 0.25, 0.8), petals=5)
    return img


def hydrangea():
    rnd = random.Random(22)
    img = card()
    d = ImageDraw.Draw(img)
    clump(d, rnd, 420, (0.06, 0.1), (58, 98, 52))
    for _ in range(9):
        cx = rnd.uniform(0.2, 0.8) * S
        cy = rnd.uniform(0.25, 0.7) * S
        col = rnd.choice([(116, 140, 206), (150, 132, 204), (206, 150, 186)])
        for _ in range(60):
            a = rnd.uniform(0, math.tau)
            r = math.sqrt(rnd.random()) * 0.075 * S
            px, py = cx + math.cos(a) * r, cy + math.sin(a) * r
            rr = 0.012 * S
            d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=jitter(col, rnd, 0.12))
    return img


def lavender():
    rnd = random.Random(23)
    img = card()
    d = ImageDraw.Draw(img)
    clump(d, rnd, 300, (0.03, 0.05), (118, 136, 112), shape="upright", spread=0.3, top=0.5)
    for (x, y) in stems(d, rnd, 60, (110, 128, 96, 255), height=(0.55, 0.85), lean=0.35, width=2):
        for k in range(7):
            r = 0.011 * S
            py = y + k * 0.012 * S
            d.ellipse([x - r, py - r, x + r, py + r], fill=jitter((122, 96, 176), rnd, 0.12))
    return img


def agapanthus():
    rnd = random.Random(24)
    img = card()
    d = ImageDraw.Draw(img)
    for _ in range(70):
        x0 = S / 2 + rnd.uniform(-0.1, 0.1) * S
        a = math.radians(rnd.uniform(-160, -20))
        ln = rnd.uniform(0.3, 0.5) * S
        pts = [(x0, 0.98 * S)]
        for i in range(1, 8):
            t = i / 7
            pts.append((x0 + math.cos(a) * ln * t, 0.98 * S + math.sin(a) * ln * t + (t * t) * 0.18 * S))
        d.line(pts, fill=jitter((56, 104, 52), rnd), width=7 * SS)
    for (x, y) in stems(d, rnd, 6, (78, 110, 64, 255), height=(0.7, 0.9), lean=0.18, width=3):
        for _ in range(40):
            a = rnd.uniform(0, math.tau)
            r = rnd.uniform(0.02, 0.07) * S
            px, py = x + math.cos(a) * r, y + math.sin(a) * r * 0.8
            rr = 0.012 * S
            d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=jitter((92, 116, 208), rnd, 0.12))
    return img


def geranium():
    rnd = random.Random(25)
    img = card()
    d = ImageDraw.Draw(img)
    clump(d, rnd, 260, (0.06, 0.09), (66, 112, 56), spread=0.4, top=0.3)
    blooms(d, rnd, 14, [(212, 30, 36), (230, 54, 60)], (0.035, 0.05), (0.2, 0.8, 0.12, 0.5), petals=6)
    return img


def hedge():
    rnd = random.Random(26)
    img = card()
    d = ImageDraw.Draw(img)
    clump(d, rnd, 3600, (0.018, 0.03), (52, 82, 40), shape="box")
    return img


def vegies():
    rnd = random.Random(27)
    img = card()
    d = ImageDraw.Draw(img)
    for row in range(3):
        y = (0.55 + row * 0.15) * S
        for i in range(6):
            cx = (0.1 + i * 0.16 + rnd.uniform(-0.02, 0.02)) * S
            col = [(86, 132, 74), (128, 156, 92), (58, 96, 60)][row]
            for _ in range(26):
                ang = rnd.uniform(math.pi * 1.05, math.pi * 1.95)
                ln = rnd.uniform(0.04, 0.08) * S
                d.polygon(leaf_polygon(cx, y, ln, ln * 0.7, ang, 0.1), fill=jitter(col, rnd))
    return img


def fruit_tree(seed, green, fruit, n_fruit, flowers=None):
    rnd = random.Random(seed)
    img = card()
    d = ImageDraw.Draw(img)
    clump(d, rnd, 900, (0.035, 0.06), green, spread=0.47, base=0.92, top=0.04)
    if flowers:
        blooms(d, rnd, 260, flowers, (0.008, 0.014), (0.08, 0.92, 0.08, 0.85))
    if fruit:
        blooms(d, rnd, n_fruit, [fruit], (0.016, 0.022), (0.15, 0.85, 0.3, 0.85))
    return img


def main():
    out = {
        "rose": rose(), "hydrangea": hydrangea(), "lavender": lavender(), "agapanthus": agapanthus(),
        "geranium": geranium(), "hedge": hedge(), "vegies": vegies(),
        "lemon": fruit_tree(31, (52, 88, 44), (236, 206, 54), 40),
        "apple": fruit_tree(32, (70, 104, 52), (176, 40, 34), 34),
        "wattle": fruit_tree(33, (86, 108, 64), None, 0, flowers=[(238, 196, 40), (246, 214, 70)]),
    }
    for name, img in out.items():
        save(img.resize((256, 256), Image.LANCZOS), OUT / f"{name}.png")


if __name__ == "__main__":
    main()
