#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Layout indicator for Waybar (Hyprland)
#   Shows  when the focused window is in a group.
# ──────────────────────────────────────────────
set -euo pipefail
grouped="$(hyprctl activewindow -j 2>/dev/null | jq -r '(.grouped // []) | length' 2>/dev/null || echo 0)"
if [ "${grouped:-0}" -gt 0 ]; then
    printf '{"text":"","tooltip":"Grouped windows: %s","class":"grouped"}\n' "$grouped"
else
    printf '{"text":"","tooltip":"No grouped layout","class":"empty"}\n'
fi
