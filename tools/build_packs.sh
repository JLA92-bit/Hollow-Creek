#!/usr/bin/env bash
# Builds the background content packs listed in data/packs.json into build/web/packs/.
# Run after the main web export. Usage: bash tools/build_packs.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web/packs
python3 -I - <<'PY' | while IFS='|' read -r preset file; do
import json
for name, p in json.load(open("data/packs.json")).items():
    if not name.startswith("_"):
        print(f"{p['preset']}|{p['file']}")
PY
  echo "packing $preset -> build/web/$file"
  tools/bin/godot --headless --path . --export-pack "$preset" "build/web/$file" 2>&1 | grep -i -E "error|saved" | grep -v "error.wav" || true
  ls -l "build/web/$file" | awk '{print "  " $5 " bytes"}'
done
