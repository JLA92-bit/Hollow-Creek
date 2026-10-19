#!/usr/bin/env bash
# Builds the signed Android APK into build/android/hollow-creek.apk and the version.json beside it.
# Needs: Godot Android templates (WITH_ANDROID=1 bash tools/setup_godot.sh), a JDK, the Android SDK
# (ANDROID_SDK_ROOT) and the release keystore (bash tools/android/make_keystore.sh).
# Usage: bash tools/build_apk.sh ["what's new"]
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
KS="${HC_KEYSTORE:-tools/cache/android/hollow-creek-release.keystore}"
PASSFILE="${HC_KEYSTORE_PASSWORD_FILE:-tools/cache/android/keystore_password.txt}"
[[ -d "$SDK/build-tools" ]] || { echo "No Android SDK at $SDK (set ANDROID_SDK_ROOT)"; exit 1; }
[[ -f "$KS" ]] || { echo "No keystore at $KS (run tools/android/make_keystore.sh)"; exit 1; }
PASS="${HC_KEYSTORE_PASSWORD:-$(cat "$PASSFILE")}"
VERSION="$(python3 -I -c "import re;print(re.search(r'config/version=\"([^\"]+)\"',open('project.godot').read()).group(1))")"
# version code: 0.0.1 -> 1, 0.1.0 -> 100, 1.2.3 -> 10203 (must go up with every release)
CODE="$(python3 -I -c "a=[int(x) for x in '$VERSION'.split('.')]+[0,0,0];print(a[0]*10000+a[1]*100+a[2])")"
python3 -I - "$VERSION" "$CODE" <<'PY'
import re, sys
v, c = sys.argv[1], sys.argv[2]
s = open("export_presets.cfg").read()
s = re.sub(r'(\[preset\.3\.options\][\s\S]*?version/code=)\d+', r'\g<1>' + c, s, count=1)
s = re.sub(r'(\[preset\.3\.options\][\s\S]*?version/name=)"[^"]*"', r'\g<1>"' + v + '"', s, count=1)
open("export_presets.cfg", "w").write(s)
PY
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/$KS"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="hollowcreek"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS"
# Godot reads the SDK and JDK locations from its editor settings
mkdir -p "$HOME/.config/godot"
SETTINGS="$HOME/.config/godot/editor_settings-4.7.tres"
python3 -I - "$SETTINGS" "$SDK" "$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")" <<'PY'
import os, re, sys
path, sdk, jdk = sys.argv[1:4]
text = open(path).read() if os.path.exists(path) else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
for key, val in (("export/android/android_sdk_path", sdk), ("export/android/java_sdk_path", jdk)):
    line = f'{key} = "{val}"'
    text = re.sub(rf'^{re.escape(key)} = .*$', line, text, flags=re.M) if re.search(rf'^{re.escape(key)} = ', text, re.M) else text.rstrip("\n") + "\n" + line + "\n"
open(path, "w").write(text)
PY
mkdir -p build/android
tools/bin/godot --headless --path . --import >/dev/null 2>&1 || true
tools/bin/godot --headless --path . --export-release "Android" build/android/hollow-creek.apk
python3 -I tools/make_version_json.py build/android "${1:-}"
ls -l build/android
