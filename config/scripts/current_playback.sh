#!/usr/bin/env bash
# Output current media playback as Waybar custom module JSON: text, alt, tooltip, class, percentage

if ! playerctl status &>/dev/null; then
  echo '{"text":"","alt":"stopped","tooltip":"","class":"stopped","percentage":0}'
  exit 0
fi

status=$(playerctl status 2>/dev/null)
position=$(playerctl position 2>/dev/null || echo "0")
title=$(playerctl metadata xesam:title 2>/dev/null)
artist=$(playerctl metadata xesam:artist 2>/dev/null)
length_us=$(playerctl metadata mpris:length 2>/dev/null)

# mpris:length is in microseconds; convert to seconds
track_length=0
if [[ -n "$length_us" && "$length_us" =~ ^[0-9]+$ ]]; then
  track_length=$(( length_us / 1000000 ))
fi

# class / alt: status for waybar (playing, paused, stopped)
case "$status" in
  Playing) class="playing" ;;
  Paused)  class="paused" ;;
  *)       class="stopped" ;;
esac
alt="$class"

# text: short display (e.g. "Title - Artist")
if [[ -n "$title" && -n "$artist" ]]; then
  # Truncate title if too long (e.g. >40 chars for display)
  maxlen=20
  t_display="$title"
  if [[ ${#title} -gt $maxlen ]]; then
    t_display="${title:0:$maxlen}…"
  fi
  text="$artist | $t_display"
elif [[ -n "$title" ]]; then
  text="$title"
elif [[ -n "$artist" ]]; then
  text="$artist"
else
  text="$status"
fi

if [[ "$track_length" -gt 0 ]]; then
  pos_min=$(( ${position%%.*} / 60 ))
  pos_sec=$(( ${position%%.*} % 60 ))
  len_min=$(( track_length / 60 ))
  len_sec=$(( track_length % 60 ))
  text="${text} | ${pos_min}:$(printf '%02d' $pos_sec)/${len_min}:$(printf '%02d' $len_sec)"
fi

# percentage: 0–100 progress (integer)
percentage=0
if [[ "$track_length" -gt 0 ]]; then
  percentage=$(awk "BEGIN { printf \"%.0f\", ($position / $track_length) * 100 }")
  [[ "$percentage" -gt 100 ]] && percentage=100
  [[ "$percentage" -lt 0 ]] && percentage=0
fi

# Build JSON (jq for safe escaping; fallback to manual)
if command -v jq &>/dev/null; then
  jq -n -c \
    --arg text "${text:-}" \
    --arg alt "${alt:-stopped}" \
    --arg class "${class:-stopped}" \
    --argjson percentage "$percentage" \
    '{text: $text, alt: $alt, class: $class, percentage: $percentage}'
else
  escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'; }
  printf '{"text":"%s","alt":"%s","class":"%s","percentage":%s}\n' \
    "$(escape "$text")" \
    "$(escape "$alt")" \
    "$(escape "$class")" \
    "$percentage"
fi
