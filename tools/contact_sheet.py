"""Makes labelled contact sheets from look-test screenshots, one per quality preset.

Usage: python3 tools/contact_sheet.py docs/screens/m1
Writes <dir>/sheet_<preset>.png: rows are morning, midday, dusk, night; columns are exterior, interior.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TIMES = ["morning", "midday", "dusk", "night"]
VIEWS = ["exterior", "interior"]
W, H = 800, 450
PAD = 36


def main() -> None:
    d = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/screens/m1")
    font_path = Path(__file__).resolve().parents[1] / "assets/fonts/AtkinsonHyperlegible-Bold.ttf"
    font = ImageFont.truetype(str(font_path), 22)
    for q in ["low", "medium", "high"]:
        sheet = Image.new("RGB", (W * 2, (H + PAD) * 4), "white")
        draw = ImageDraw.Draw(sheet)
        found = 0
        for r, t in enumerate(TIMES):
            for c, v in enumerate(VIEWS):
                f = d / f"{t}_{v}_{q}.png"
                if not f.exists():
                    continue
                found += 1
                sheet.paste(Image.open(f).convert("RGB").resize((W, H), Image.LANCZOS), (c * W, r * (H + PAD) + PAD))
                draw.text((c * W + 12, r * (H + PAD) + 6), f"{t.capitalize()} · {v} · {q.capitalize()}", fill=(0, 41, 77), font=font)
        if found:
            out = d / f"sheet_{q}.png"
            sheet.save(out, optimize=True)
            print("wrote", out, found, "shots")


if __name__ == "__main__":
    main()
