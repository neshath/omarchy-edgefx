#!/usr/bin/env bash
# Recompile every shaders/*.frag into shaders/*.frag.qsb (Qt 6 RHI).
# Only needed by contributors who edit shader sources; end users never run this.
set -euo pipefail
cd "$(dirname "$0")/.."
QSB="$(command -v qsb || command -v qsb6 || true)"
[ -x "$QSB" ] || QSB=/usr/lib/qt6/bin/qsb
[ -x "$QSB" ] || { echo "qsb not found (provide the Qt 6 shader tools: qt6-shadertools / qt6-shader-baker)" >&2; exit 1; }
for f in shaders/*.frag; do
  "$QSB" --qt6 -o "$f.qsb" "$f"
  echo "compiled $f.qsb"
done
