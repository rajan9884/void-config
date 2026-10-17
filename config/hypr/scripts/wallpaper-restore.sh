#!/usr/bin/env bash
# Draw the wallpaper recorded by theme.py (set by the installer or the picker).
state="${XDG_STATE_HOME:-$HOME/.local/state}/theme/state.json"

img="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper",""))' "$state" 2>/dev/null)"
[[ -f "$img" ]] || exit 0

# Wait for the awww daemon to be ready (up to ~5s)
for _ in {1..20}; do
    awww query >/dev/null 2>&1 && break
    sleep 0.25
done

awww img "$img" -t none

# Keep the lock-screen background in sync (hyprlock reads it from the cache).
cp -f "$img" "$HOME/.cache/hyprlock-bg.jpg" 2>/dev/null || true

# Re-render all themed targets from the current palette and push live
# Hyprland border colors (best-effort; keeps login consistent after reboot).
python3 "$HOME/.config/theme/bin/theme.py" apply >/dev/null 2>&1 || true

# Force helium browser to pick up the new theme on next launch.
rm -f "$HOME/.config/helium-theme/Cached Theme.pak" 2>/dev/null || true
