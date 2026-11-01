#!/usr/bin/env bash
set -euo pipefail
command -v playerctl >/dev/null || { echo 'playerctl is required' >&2; exit 1; }
command -v omarchy-shell >/dev/null || { echo 'omarchy-shell was not found; run this on Omarchy' >&2; exit 1; }
lyrics_file="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/edgefx/lyrics.txt"
last=""
while sleep 1; do
  IFS=$'\t' read -r title artist art_url < <(playerctl metadata --format '{{title}}\t{{artist}}\t{{mpris:artUrl}}' 2>/dev/null || true)
  title=${title//$'\n'/ }
  artist=${artist//$'\n'/ }
  art_url=${art_url//$'\n'/ }
  # The service uses | as its three-field separator; sanitize metadata fields.
  title=${title//|/-}
  artist=${artist//|/-}
  art_url=${art_url//|/%7C}
  payload="${title}|${artist}|${art_url}"
  if [[ "$payload" != "$last" ]]; then
    omarchy-shell edgefx setMedia "$payload" >/dev/null 2>&1 || true
    last="$payload"
  fi
  if [[ -f "$lyrics_file" ]]; then
    lyrics=$(head -c 500 "$lyrics_file" | tr '\n' ' ')
    omarchy-shell edgefx setLyrics "$lyrics" >/dev/null 2>&1 || true
  fi
done
