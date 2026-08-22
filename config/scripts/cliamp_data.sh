#!/usr/bin/env bash
# Waybar custom module for cliamp: text is a 5-bar mini visualizer sampled
# from cliamp's live band data, tooltip is the current track.
#
# One-shot and bounded (run on Waybar's "interval") rather than a
# continuously-streamed pipe from `cliamp visstream` - Waybar's reload flow
# (killall waybar; waybar &, used by theme-set.sh too) doesn't clean up a
# custom module's child processes, so a long-running stream here would leak
# an orphaned process on every reload.

set -uo pipefail

bars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
bars_joined="${bars[*]}"

status=$(cliamp status --json 2>/dev/null)
if [[ -z "$status" ]] || ! jq -e '.ok' <<<"$status" &>/dev/null; then
  echo '{"text":"","class":"stopped","tooltip":"cliamp is not running"}'
  exit 0
fi

state=$(jq -r '.state' <<<"$status")
title=$(jq -r '.track.title // "cliamp"' <<<"$status")

if [[ "$state" != "playing" ]]; then
  icon=""
  [[ "$state" == "paused" ]] && icon=""
  jq -nc --arg text "$icon" --arg class "$state" --arg tooltip "$title" \
    '{text: $text, class: $class, tooltip: $tooltip}'
  exit 0
fi

frame=$(timeout 1 cliamp visstream --fps 8 2>/dev/null | head -n 1)

icon=""
if [[ -n "$frame" ]] && jq -e '.ok' <<<"$frame" &>/dev/null; then
  icon=$(jq -r '.bands as $b | [
      (($b[0]+$b[1])/2), (($b[2]+$b[3])/2), (($b[4]+$b[5])/2),
      (($b[6]+$b[7])/2), (($b[8]+$b[9])/2)
    ] | .[]' <<<"$frame" |
    awk -v joined="$bars_joined" -v n="${#bars[@]}" '
      BEGIN { split(joined, b, " ") }
      { i = int($1 * (n - 1) + 0.5); if (i < 0) i = 0; if (i > n - 1) i = n - 1; printf "%s", b[i+1] }
    ')
fi
[[ -z "$icon" ]] && icon="♪"

jq -nc --arg text "$icon" --arg class "playing" --arg tooltip "$title" \
  '{text: $text, class: $class, tooltip: $tooltip}'
