"""Rewrites the generated asset section of CREDITS.md from data/asset_credits.json."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
START, END = "<!-- assets:start -->", "<!-- assets:end -->"


def main() -> None:
    data = json.loads((ROOT / "data" / "asset_credits.json").read_text())
    rows = ["| Asset | Authors | Source | Licence | Used as |", "|---|---|---|---|---|"]
    for key, e in data.items():
        rows.append(f"| {e['name']} ({e['kind']}) | {', '.join(e['authors'])} | {e['source']} | {e['licence']} | {e['used_as']} |")
    block = "\n".join([START, *rows, END])
    credits = (ROOT / "CREDITS.md").read_text()
    if START in credits:
        pre, rest = credits.split(START, 1)
        post = rest.split(END, 1)[1]
        credits = pre + block + post
    else:
        credits = credits.rstrip() + "\n\n## Materials, models and skies (generated)\n\n" + block + "\n"
    (ROOT / "CREDITS.md").write_text(credits)
    print(f"CREDITS.md: {len(data)} assets")


if __name__ == "__main__":
    main()
