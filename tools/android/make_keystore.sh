#!/usr/bin/env bash
# Makes the release signing key for the Android app, once. Android only installs an update over an
# older version when both are signed with the SAME key, so keep a backup of the keystore file and its
# password somewhere safe (not in git). Usage: bash tools/android/make_keystore.sh [out_dir]
set -euo pipefail
OUT="${1:-tools/cache/android}"
mkdir -p "$OUT"
KS="$OUT/hollow-creek-release.keystore"
if [[ -e "$KS" ]]; then echo "Already exists: $KS (not overwriting)"; exit 0; fi
PASS="$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(18))')"
keytool -genkeypair -v -keystore "$KS" -alias hollowcreek -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" -dname "CN=Josh Makes Games, O=Josh Makes Games, C=AU" >/dev/null 2>&1
printf '%s\n' "$PASS" > "$OUT/keystore_password.txt"
chmod 600 "$KS" "$OUT/keystore_password.txt"
echo "Keystore: $KS"
echo "Password file: $OUT/keystore_password.txt"
