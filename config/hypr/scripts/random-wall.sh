#!/usr/bin/env bash
# Random wallpaper (theme edition): pick from ~/.local/share/wallpapers or
# ~/Pictures/Wallpapers, set via awww, re-theme via theme.py.
# Same flow as quickshell hyprquickpaper commands.sh.
set -euo pipefail
WALL_DIRS=()
for _d in "$HOME/.local/share/wallpapers" "$HOME/Pictures/Wallpapers"; do
    [ -d "$_d" ] && WALL_DIRS+=("$_d")
done
if ((${#WALL_DIRS[@]})); then
    CURRENT="$(python3 -c 'import json; print(json.load(open("'"$HOME"'/.local/state/theme/state.json")).get("wallpaper",""))' 2>/dev/null || true)"
    CANDIDATES=$(find "${WALL_DIRS[@]}" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null || true)
    if [ -n "$CURRENT" ]; then
        FILTERED=$(printf '%s\n' "$CANDIDATES" | grep -Fxv "$CURRENT" || true)
        [ -n "$FILTERED" ] && CANDIDATES="$FILTERED"
    fi
    SELECTED_WALL=$(printf '%s\n' "$CANDIDATES" | shuf -n 1 || true)
fi
if [ -n "${SELECTED_WALL:-}" ]; then
    awww img "$SELECTED_WALL" -t random --transition-duration 1
    mkdir -p "$HOME/.cache/theme"
    setsid -f python3 "$HOME/.config/theme/bin/theme.py" wallpaper "$SELECTED_WALL" \
        >>"$HOME/.cache/theme/theme.log" 2>&1
else
    notify-send "Wallpaper Error" "No images found in ${WALL_DIRS[*]:-~/.local/share/wallpapers}" -u critical
fi
