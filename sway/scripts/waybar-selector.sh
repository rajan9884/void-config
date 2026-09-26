#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Waybar Style Selector
# ──────────────────────────────────────────────

WAYBAR_THEMES_DIR="$HOME/.config/waybar/themes"

# 1. List available styles
CHOICE=$(ls "$WAYBAR_THEMES_DIR" | sort | rofi -dmenu -i -p "  Waybar Style" -theme ~/.config/rofi/active-scripts.rasi)

[ -z "$CHOICE" ] && exit 0

# 2. Apply the selected waybar style
ln -sf "$WAYBAR_THEMES_DIR/$CHOICE/config.jsonc" "$HOME/.config/waybar/config.jsonc"
ln -sf "$WAYBAR_THEMES_DIR/$CHOICE/style.css" "$HOME/.config/waybar/style.css"

# 3. Restart Waybar (explicit -c/-s: bare `waybar` ignores config.jsonc
# and falls back to the built-in default config)
pkill -x waybar 2>/dev/null; pkill -x .waybar-wrapped 2>/dev/null
sleep 0.3
setsid waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1 < /dev/null &

notify-send "  Waybar Updated" "Style: $CHOICE applied" -i preferences-desktop-theme
