"""Generates the alpha-cut verandah textures: cast iron lace frieze and brackets, timber fretwork,
a lace balustrade panel and diagonal lattice. White where there's metal or timber, transparent
elsewhere; the material tints them with the trim colour.

Usage: python3 tools/textures/make_lace.py
Writes assets/materials/lace/{lace_frieze,lace_bracket,fret_frieze,fret_bracket,lace_rail,lattice}.png
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "materials" / "lace"
SS = 4


def new(w, h):
    return Image.new("L", (w * SS, h * SS), 0)


def save(img, w, h, name):
    img = img.resize((w, h), Image.LANCZOS)
    rgba = Image.merge("RGBA", (Image.new("L", (w, h), 255),) * 3 + (img,))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.png"
    rgba.save(path, optimize=True)
    Path(str(path) + ".import").write_text("\n".join([
        "[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", "",
        "compress/mode=0", "mipmaps/generate=true", "process/size_limit=0", "detect_3d/compress_to=0", ""]))


def ring(d, cx, cy, r, w):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=255, width=w)


def scroll(d, cx, cy, r, w, turns=1.6, flip=1):
    pts = []
    for i in range(80):
        t = i / 79 * turns * 2 * math.pi
        rr = r * (1 - i / 95)
        pts.append((cx + flip * rr * math.cos(t), cy + rr * math.sin(t)))
    d.line(pts, fill=255, width=w, joint="curve")


def lace_frieze():
    # 0.6 m by 0.25 m repeat: top and bottom bars, a row of rings with scrolls between.
    w, h = 384, 160
    img = new(w, h)
    d = ImageDraw.Draw(img)
    W, H = w * SS, h * SS
    bar = 7 * SS
    d.rectangle([0, 0, W, bar], fill=255)
    d.rectangle([0, H - bar, W, H], fill=255)
    for ox in (-W, 0, W):
        for i in range(2):
            cx = ox + W * (0.25 + 0.5 * i)
            ring(d, cx, H * 0.5, H * 0.3, 5 * SS)
            ring(d, cx, H * 0.5, H * 0.12, 4 * SS)
            for a in range(8):
                t = a / 8 * 2 * math.pi
                d.line([(cx + math.cos(t) * H * 0.12, H * 0.5 + math.sin(t) * H * 0.12),
                        (cx + math.cos(t) * H * 0.3, H * 0.5 + math.sin(t) * H * 0.3)], fill=255, width=3 * SS)
            sx = cx + W * 0.25
            scroll(d, sx - H * 0.16, H * 0.3, H * 0.14, 4 * SS, flip=1)
            scroll(d, sx + H * 0.16, H * 0.7, H * 0.14, 4 * SS, flip=-1)
            d.line([(sx, bar), (sx, H - bar)], fill=255, width=4 * SS)
    save(img, w, h, "lace_frieze")


def lace_bracket():
    # A quarter fan of lace filling the triangle under the beam (post on the left, beam on top).
    s = 256
    img = new(s, s)
    d = ImageDraw.Draw(img)
    S = s * SS
    b = 6 * SS
    d.line([(0, b / 2), (S, b / 2)], fill=255, width=b)
    d.line([(b / 2, 0), (b / 2, S)], fill=255, width=b)
    d.line([(0, S), (S, 0)], fill=255, width=b)
    for r in (0.3, 0.55, 0.8):
        d.arc([-S * r, -S * r, S * r, S * r], 0, 90, fill=255, width=4 * SS)
    for a in range(1, 6):
        t = a / 6 * math.pi / 2
        d.line([(0, 0), (math.cos(t) * S * 0.7, math.sin(t) * S * 0.7)], fill=255, width=3 * SS)
    for a in range(3):
        t = (a + 0.5) / 3 * math.pi / 2
        ring(d, math.cos(t) * S * 0.43, math.sin(t) * S * 0.43, S * 0.07, 3 * SS)
    # Cut away everything below the diagonal.
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon([(0, 0), (S, 0), (0, S)], fill=255)
    img = Image.composite(img, Image.new("L", img.size, 0), mask)
    save(img, s, s, "lace_bracket")


def fret_frieze():
    # Timber fretwork: a solid board with cut-out ovals and drops.
    w, h = 384, 160
    img = new(w, h)
    d = ImageDraw.Draw(img)
    W, H = w * SS, h * SS
    d.rectangle([0, 0, W, H * 0.62], fill=255)
    for ox in (-W, 0, W):
        for i in range(4):
            cx = ox + W * (0.125 + 0.25 * i)
            d.ellipse([cx - H * 0.13, H * 0.14, cx + H * 0.13, H * 0.46], fill=0)
            # Scalloped drops below the board.
            d.pieslice([cx - H * 0.2, H * 0.42, cx + H * 0.2, H * 0.82], 0, 180, fill=255)
            d.ellipse([cx - H * 0.05, H * 0.58, cx + H * 0.05, H * 0.68], fill=0)
    save(img, w, h, "fret_frieze")


def fret_bracket():
    s = 256
    img = new(s, s)
    d = ImageDraw.Draw(img)
    S = s * SS
    d.polygon([(0, 0), (S, 0), (0, S)], fill=255)
    d.ellipse([S * 0.12, S * 0.12, S * 0.42, S * 0.42], fill=0)
    d.ellipse([S * 0.5, S * 0.06, S * 0.66, S * 0.22], fill=0)
    d.ellipse([S * 0.06, S * 0.5, S * 0.22, S * 0.66], fill=0)
    d.pieslice([S * 0.3, S * 0.3, S * 1.3, S * 1.3], 180, 270, fill=0)
    save(img, s, s, "fret_bracket")


def lace_rail():
    # Balustrade panel, 0.6 m by 0.9 m: rails top and bottom with a lattice of rings.
    w, h = 256, 384
    img = new(w, h)
    d = ImageDraw.Draw(img)
    W, H = w * SS, h * SS
    bar = 8 * SS
    d.rectangle([0, 0, W, bar], fill=255)
    d.rectangle([0, H - bar, W, H], fill=255)
    for ox in (-W, 0, W):
        for j in range(4):
            cy = H * (0.14 + 0.24 * j)
            for i in range(2):
                cx = ox + W * (0.25 + 0.5 * i)
                ring(d, cx, cy, W * 0.2, 4 * SS)
                ring(d, cx, cy, W * 0.07, 3 * SS)
        d.line([(ox, 0), (ox, H)], fill=255, width=5 * SS)
        d.line([(ox + W * 0.5, 0), (ox + W * 0.5, H)], fill=255, width=3 * SS)
    save(img, w, h, "lace_rail")


def lattice():
    # Diagonal slats every half tile both ways, so the tile wraps cleanly.
    s = 256
    img = new(s, s)
    d = ImageDraw.Draw(img)
    S = s * SS
    w = 16 * SS
    for k in range(-4, 6):
        c = k * S / 2
        d.line([(c, 0), (c + S, S)], fill=255, width=w)
        d.line([(c, 0), (c - S, S)], fill=255, width=w)
    save(img, s, s, "lattice")


if __name__ == "__main__":
    lace_frieze()
    lace_bracket()
    fret_frieze()
    fret_bracket()
    lace_rail()
    lattice()
    print("lace textures written to", OUT)
