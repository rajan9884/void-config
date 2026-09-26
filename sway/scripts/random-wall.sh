#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Random Wallpaper Switcher (sway/Void port)
#   Picks from ~/.local/share/wallpapers/Wallpaper
# ──────────────────────────────────────────────
set -euo pipefail
WALL_DIR="$HOME/.local/share/wallpapers/Wallpaper"
SCRIPT="$HOME/.config/sway/scripts/sway-wall.sh"
SELECTED_WALL=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)
if [ -n "${SELECTED_WALL:-}" ]; then
    exec "$SCRIPT" "$SELECTED_WALL"
else
    notify-send "Wallpaper Error" "No images found in $WALL_DIR" -u critical
fi
