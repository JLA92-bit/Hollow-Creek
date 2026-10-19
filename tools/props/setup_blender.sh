#!/usr/bin/env bash
# Headless Blender (bpy) for the prop scripts, in a git-ignored venv. Idempotent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VENV="$ROOT/tools/cache/blender-venv"
mkdir -p "$ROOT/tools/cache" && touch "$ROOT/tools/cache/.gdignore"   # Godot must not scan the Python venv
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
fi
if ! "$VENV/bin/python" -c "import bpy" 2>/dev/null; then
  "$VENV/bin/pip" install -q bpy
fi
"$VENV/bin/python" -c "import bpy; print('Blender', bpy.app.version_string)"
