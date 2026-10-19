"""Writes version.json for the Android app's update check, next to the APK.
Usage: python3 -I tools/make_version_json.py out_dir "What's new in this version"
The version comes from project.godot (application/config/version); the APK is hollow-creek.apk."""
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
version = re.search(r'config/version="([^"]+)"', (root / "project.godot").read_text()).group(1)
out = pathlib.Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
notes = sys.argv[2] if len(sys.argv) > 2 else ""
(out / "version.json").write_text(json.dumps({"version": version, "apk": "hollow-creek.apk", "notes": notes}, indent=2) + "\n")
print(f"version.json: {version}")
