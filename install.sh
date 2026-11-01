#!/usr/bin/env bash
set -euo pipefail
src_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
omarchy plugin validate "$src_dir"
omarchy plugin add "$src_dir" --enable
install -Dm755 "$src_dir/edgefx-events.sh" "$HOME/.local/bin/edgefx-events"
install -Dm755 "$src_dir/edgefx-audio-sync.py" "$HOME/.local/bin/edgefx-audio-sync"
printf '%s\n' 'EdgeFX installed. Try: omarchy-shell edgefx status' 'Optional event bridge: edgefx-events' 'Audio bridge: edgefx-audio-sync'
