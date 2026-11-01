#!/usr/bin/env bash
set -euo pipefail
socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
if [[ ! -S "$socket" ]]; then
  echo "Hyprland event socket not found: $socket" >&2
  exit 1
fi
command -v socat >/dev/null || { echo 'socat is required' >&2; exit 1; }
socat -U - UNIX-CONNECT:"$socket" | while IFS= read -r event; do
  case "$event" in
    workspace\>*|workspacev2\>*|activewindow\>*|activewindowv2\>*) omarchy-shell edgefx pulse >/dev/null 2>&1 || true ;;
  esac
done
