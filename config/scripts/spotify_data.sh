#!/usr/bin/env bash
# Waybar custom module for Spotify (via Soloist): short "Artist - Title"
# text, tooltip mirrors it. Click opens the eww spotify-control panel.

set -uo pipefail

# waybar runs under the uwsm-managed systemd --user session, whose PATH omits
# ~/bin (where soloist lives) — same issue spotify-soloist.service works
# around for the daemon itself.
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

json=$(soloist ctl now --json 2>/dev/null)
if [[ -z "$json" ]] || ! jq -e . <<<"$json" &>/dev/null; then
  echo '{"text":"","class":"stopped","tooltip":"Soloist is not running"}'
  exit 0
fi

status=$(jq -r '.status // "idle"' <<<"$json")
title=$(jq -r '.item.decorations.identity.name // ""' <<<"$json")
artist=$(jq -r '[.item.decorations.creators[]?.entity.decorations.identity.name] | join(", ")' <<<"$json")

class="stopped"
case "$status" in
playing) class="playing" ;;
paused) class="paused" ;;
esac

maxlen=24
display="$title"
[[ -n "$artist" ]] && display="$artist - $title"
if [[ ${#display} -gt $maxlen ]]; then
  display="${display:0:$maxlen}…"
fi
[[ -z "$display" ]] && display="Spotify"

jq -nc --arg text "$display" --arg class "$class" --arg tooltip "${artist:+$artist - }${title:-Spotify}" \
  '{text: $text, class: $class, tooltip: $tooltip}'
