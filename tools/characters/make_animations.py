"""Writes assets/characters/animations.glb: one body (Agnes, LOD1) carrying the whole retargeted
Quaternius library. The game loads its animations once and adds them to every resident, so the
resident models themselves carry none (see make_residents.py, animations="none").

Usage: tools/cache/blender-venv/bin/python tools/characters/make_animations.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_agnes as base  # noqa: E402

if __name__ == "__main__":
    base.build(1, name="animations", animations="ual")
