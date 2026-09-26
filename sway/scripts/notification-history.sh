#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Notification history in rofi (mako — Void port of notification-history.sh)
# ──────────────────────────────────────────────
set -euo pipefail
THEME="$HOME/.config/rofi/active-picker.rasi"
LIST="$(makoctl list 2>/dev/null || true)"
[ -z "$LIST" ] && { notify-send "Notifications" "No notification history" -u low; exit 0; }
printf '%s\n' "$LIST" | rofi -dmenu -i -p "Notifications" -theme "$THEME" >/dev/null || true
