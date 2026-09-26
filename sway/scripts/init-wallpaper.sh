#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Ensure wallpaper is displayed on sway start
# ──────────────────────────────────────────────
WALL_DIR="$HOME/.local/share/wallpapers/Wallpaper"
for i in {1..30}; do
    awww query >/dev/null 2>&1 && break
    sleep 0.1
done
if awww query 2>/dev/null | grep -q "image:"; then exit 0; fi
awww restore 2>/dev/null || true
if ! awww query 2>/dev/null | grep -q "image:"; then
    if [ -s "$HOME/.cache/current-wallpaper" ] && [ -f "$(<"$HOME/.cache/current-wallpaper")" ]; then
        "$HOME/.config/sway/scripts/sway-wall.sh" "$(<"$HOME/.cache/current-wallpaper")"
    else
        WALL=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -n 1)
        if [ -n "${WALL:-}" ]; then
            "$HOME/.config/sway/scripts/sway-wall.sh" "$WALL"
        else
            "$HOME/.config/sway/scripts/random-wall.sh"
        fi
    fi
fi
