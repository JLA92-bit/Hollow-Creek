#!/usr/bin/env bash
# MPFB 2 (MakeHuman for Blender) for the character pipeline: headless Blender plus the MPFB source
# from GitHub, packaged as a Blender extension. The base mesh, targets and rigs it ships are CC0;
# the add-on code is GPL and isn't shipped. Idempotent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$ROOT/tools/props/setup_blender.sh"
CACHE="$ROOT/tools/cache"
if [ ! -d "$CACHE/mpfb2" ]; then
  git clone -q --depth 1 https://github.com/makehumancommunity/mpfb2.git "$CACHE/mpfb2"
fi
if [ ! -f "$CACHE/mpfb.zip" ]; then
  (cd "$CACHE/mpfb2/src" && zip -qr "$CACHE/mpfb.zip" mpfb)
fi
echo "MPFB ready: $CACHE/mpfb.zip ($(git -C "$CACHE/mpfb2" rev-parse --short HEAD))"
