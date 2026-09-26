#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Dynamic Theme Switcher (awww + matugen) — sway/Void port of swww-all.sh
#   Usage: sway-wall.sh /path/to/wallpaper.jpg
# ──────────────────────────────────────────────
set -euo pipefail

WALLPAPER="${1:-}"
[ -z "$WALLPAPER" ] && { echo "Usage: sway-wall.sh /path/to/wallpaper.jpg" >&2; exit 1; }
[ -f "$WALLPAPER" ] || { echo "Not found: $WALLPAPER" >&2; exit 1; }

# 1. Set wallpaper. Prefer awww-daemon when it is up (it paints over the
#    sway background, so the swaymsg fallback MUST only run when the
#    daemon is down — otherwise the new wallpaper would be hidden
#    behind awww's layer and appear "stuck" while matugen still recolors.
if awww query >/dev/null 2>&1; then
    if ! awww img "$WALLPAPER" --transition-type grow --transition-duration 1.5; then
        notify-send "Wallpaper Error" "awww failed to set $(basename "$WALLPAPER")" -u critical
        exit 1
    fi
else
    setsid awww-daemon >/dev/null 2>&1 < /dev/null &
    sleep 0.5
    if awww query >/dev/null 2>&1; then
        awww img "$WALLPAPER" --transition-type grow --transition-duration 1.5 || \
            { notify-send "Wallpaper Error" "awww failed to set $(basename "$WALLPAPER")" -u critical; exit 1; }
    else
        swaymsg output "*" bg "$WALLPAPER" fill || \
            { notify-send "Wallpaper Error" "Could not set $(basename "$WALLPAPER")" -u critical; exit 1; }
    fi
fi

# 1.5 Record current wallpaper + stage lock-screen background.
printf '%s' "$WALLPAPER" > ~/.cache/current-wallpaper
(magick "$WALLPAPER" ~/.cache/swaylock-bg.jpg 2>/dev/null || cp -p "$WALLPAPER" ~/.cache/swaylock-bg.jpg 2>/dev/null) & disown 2>/dev/null || true

# 2. Extract colors with matugen (updates waybar, rofi, kitty, sway, mako, …)
matugen image "$WALLPAPER" --type scheme-content -c ~/.config/matugen/config.toml --source-color-index 0

# 2.5 Bump unpacked Chromium theme version so the next launch picks up colors
THEME_MANIFEST="$HOME/.config/helium-theme/manifest.json"
if [ -f "$THEME_MANIFEST" ]; then
    CUR_VER=$(grep -o '"version": "[^"]*"' "$THEME_MANIFEST" | head -1 | cut -d'"' -f4)
    CUR_MAJ=$(echo "$CUR_VER" | cut -sd. -f1); [ -z "$CUR_MAJ" ] && CUR_MAJ=1
    CUR_MIN=$(echo "$CUR_VER" | cut -sd. -f2); [ -z "$CUR_MIN" ] && CUR_MIN=0
    CUR_PAT=$(echo "$CUR_VER" | cut -sd. -f3)
    case "$CUR_PAT" in ''|*[!0-9]*) CUR_PAT=0 ;; esac
    if [ "$CUR_PAT" -ge 65535 ] 2>/dev/null; then
        CUR_MIN=$((CUR_MIN + 1)); CUR_PAT=0
        [ "$CUR_MIN" -ge 65535 ] && { CUR_MAJ=$((CUR_MAJ + 1)); CUR_MIN=0; }
    fi
    NEW_VERSION="$CUR_MAJ.$CUR_MIN.$((CUR_PAT + 1))"
    sed -i -E "s/\"version\": \"[^\"]+\"/\"version\": \"$NEW_VERSION\"/" "$THEME_MANIFEST"
    rm -f "$HOME/.config/helium-theme/Cached Theme.pak"
fi

# 3. Reload sway (picks up generated ~/.config/sway/colors) + restart waybar
swaymsg reload 2>/dev/null || true
pkill -x waybar 2>/dev/null; pkill -x .waybar-wrapped 2>/dev/null || true
sleep 0.5
setsid waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css >/dev/null 2>&1 < /dev/null &

# 4. Reload kitty
killall -SIGUSR1 kitty 2>/dev/null || true

# 5. Reload mako with new colors
makoctl reload 2>/dev/null || { pkill -x mako 2>/dev/null; setsid mako >/dev/null 2>&1 < /dev/null & }

# 6. GTK apps read css at launch — restart nautilus only if a window is open
if swaymsg -t get_tree 2>/dev/null | grep -Fq '"app_id": "org.gnome.Nautilus"'; then
    pkill -x nautilus 2>/dev/null || true
    (nautilus --new-window >/dev/null 2>&1 &) || true
fi

# 7. Nudges for apps that need a restart
pgrep -x nvim >/dev/null 2>&1 && notify-send "Neovim Theme Updated" "Restart nvim to apply new colors" || true
pywalfox update 2>/dev/null || true
if pgrep -x chromium >/dev/null 2>&1 || pgrep -x brave >/dev/null 2>&1 || pgrep -x helium >/dev/null 2>&1; then
    notify-send "Browser Theme Updated" "Restart Chromium/Brave to apply new colors" -i "$WALLPAPER"
fi

# 8. Done
notify-send "Theme Updated" "Colors extracted from $(basename "$WALLPAPER")" -i "$WALLPAPER"
