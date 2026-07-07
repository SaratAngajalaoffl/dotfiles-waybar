#!/usr/bin/env bash
# Output Waybar custom module JSON: text = connected count, tooltip = table (device | battery)

# Collect connected devices: MAC and name
get_connected() {
  bluetoothctl devices 2>/dev/null | while read -r _ mac _ rest; do
    [[ -z "$mac" ]] && continue
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    grep -q "Connected: yes" <<< "$info" || continue
    name=$(grep "Name:" <<< "$info" | cut -d' ' -f2-)
    [[ -z "$name" ]] && name="$mac"
    echo "$mac $name"
  done
}

# Get battery percentage for device (BlueZ Battery1 over D-Bus, or from bluetoothctl info)
get_battery() {
  local mac="$1"
  local info="$2"
  local battery

  # Try bluetoothctl info (some BlueZ versions expose Battery Percentage)
  battery=$(grep "Battery Percentage:" <<< "$info" | sed -n 's/.*Battery Percentage: *\([0-9]*\).*/\1/p')
  if [[ -n "$battery" ]]; then
    echo "$battery"
    return
  fi

  # Try D-Bus org.bluez.Battery1 (requires bluetoothd -E on some systems)
  local path_mac="${mac//:/_}"
  battery=$(dbus-send --print-reply=literal --system --dest=org.bluez \
    "/org/bluez/hci0/dev_${path_mac}" org.freedesktop.DBus.Properties.Get \
    string:"org.bluez.Battery1" string:"Percentage" 2>/dev/null | awk '{print $NF}')
  if [[ -n "$battery" && "$battery" =~ ^[0-9]+$ ]]; then
    echo "$battery"
    return
  fi

  echo "—"
}

# Build table rows for tooltip
count=0
rows=""
while read -r mac name; do
  [[ -z "$mac" ]] && continue
  info=$(bluetoothctl info "$mac" 2>/dev/null)
  battery=$(get_battery "$mac" "$info")
  rows="$rows$name	$battery%"
  ((count++)) || true
done < <(get_connected)
# Default when no devices
text="$count"
tooltip="$rows"
if [[ -z "$rows" ]]; then
  text="0"
  tooltip="No devices connected"
fi

# Waybar custom module JSON (text + tooltip as requested; alt/class/percentage for compatibility)
if command -v jq &>/dev/null; then
  jq -n \
    --arg text "$text" \
    --arg alt "bluetooth" \
    --arg tooltip "$tooltip" \
    --arg class "bluetooth" \
    --argjson percentage 0 \
    '{text: $text, alt: $alt, tooltip: $tooltip, class: $class, percentage: $percentage}'
else
  escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'; }
  printf '{"text":"%s","alt":"bluetooth","tooltip":"%s","class":"bluetooth","percentage":0}\n' \
    "$(escape "$text")" \
    "$(escape "$tooltip")"
fi
