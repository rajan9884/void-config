#!/usr/bin/env bash
# Caffeine toggle (Hyprland): kills/starts hypridle to suspend/resume
# auto-dim, lock, screen-off and suspend. Sway is gone; no dispatch needed.
exec "$HOME/.config/hypr/scripts/idle-toggle.sh" "$@"
