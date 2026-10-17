#!/usr/bin/env bash
# Installs a pinned Godot editor binary and the web export templates.
# Safe to re-run. Used by Claude Code sessions and by CI.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_STATUS="${GODOT_STATUS:-stable}"
TAG="${GODOT_VERSION}-${GODOT_STATUS}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${TAG}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${ROOT}/tools/bin"
BIN="${BIN_DIR}/godot"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_STATUS}"
WITH_ANDROID="${WITH_ANDROID:-0}"

mkdir -p "${BIN_DIR}" "${TEMPLATE_DIR}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

if [[ ! -x "${BIN}" ]] || ! "${BIN}" --version 2>/dev/null | grep -q "^${GODOT_VERSION}.${GODOT_STATUS}"; then
  echo "Downloading Godot ${TAG} editor..."
  curl -fsSL "${BASE}/Godot_v${TAG}_linux.x86_64.zip" -o "${TMP}/godot.zip"
  unzip -q -o "${TMP}/godot.zip" -d "${TMP}/godot"
  mv "${TMP}/godot/Godot_v${TAG}_linux.x86_64" "${BIN}"
  chmod +x "${BIN}"
fi
echo "Godot: $("${BIN}" --version)"

if ! ls "${TEMPLATE_DIR}"/web_nothreads_release.zip >/dev/null 2>&1 \
   || { [[ "${WITH_ANDROID}" == "1" ]] && ! ls "${TEMPLATE_DIR}"/android_release.apk >/dev/null 2>&1; }; then
  echo "Downloading export templates (large file, only the needed parts are kept)..."
  curl -fsSL "${BASE}/Godot_v${TAG}_export_templates.tpz" -o "${TMP}/templates.tpz"
  PATTERNS=("templates/version.txt" "templates/web*")
  if [[ "${WITH_ANDROID}" == "1" ]]; then PATTERNS+=("templates/android*"); fi
  unzip -q -o "${TMP}/templates.tpz" "${PATTERNS[@]}" -d "${TMP}/t"
  cp -f "${TMP}/t/templates/"* "${TEMPLATE_DIR}/"
  rm -f "${TMP}/templates.tpz"
fi
echo "Templates in ${TEMPLATE_DIR}:"
ls -1 "${TEMPLATE_DIR}"
