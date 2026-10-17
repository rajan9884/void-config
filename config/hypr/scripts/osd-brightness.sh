#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Brightness control with QML OSD (quickshell SysOsd).
#   brightnessctl makes the change (exact 5% steps, backlight
#   class only); SysOsd renders the bottom bar + percentage.
# ──────────────────────────────────────────────
ACTION="$1"

sysosd() { timeout 2 qs ipc call sysosd notify "$1|$2|$3" >/dev/null 2>&1 || true; }

case "$ACTION" in
    up) brightnessctl -c backlight set 5%+ >/dev/null 2>&1 ;;
    down) brightnessctl -c backlight set 5%- >/dev/null 2>&1 ;;
    max) brightnessctl -c backlight set 100% >/dev/null 2>&1 ;;
    min) brightnessctl -c backlight set 1% >/dev/null 2>&1 ;;
esac

INFO=$(brightnessctl -c backlight -m 2>/dev/null | head -1)
if [[ -z "$INFO" ]]; then
    sysosd "Brightness" 0 "No backlight"
    exit 0
fi
CUR=$(printf '%s' "$INFO" | cut -d, -f3)
MAXV=$(printf '%s' "$INFO" | cut -d, -f5)
PCT=$(printf '%s' "$INFO" | cut -d, -f4 | tr -d '%')
[[ "$CUR" =~ ^[0-9]+$ ]] || CUR=0
[[ "$MAXV" =~ ^[0-9]+$ && "$MAXV" != "0" ]] || MAXV=100
[[ "$PCT" =~ ^[0-9]+$ ]] || PCT=0
FRAC=$(awk -v c="$CUR" -v m="$MAXV" 'BEGIN{ f=(m>0)?c/m:0; if (f>1) f=1; if (f<0) f=0; printf "%.2f", f }')

sysosd "Brightness" "$FRAC" "$PCT%"
# Persist raw value for login restore (see hypr autostart backlight-restore).
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}" 2>/dev/null
printf '%s\n' "$CUR" > "${XDG_STATE_HOME:-$HOME/.local/state}/backlight" 2>/dev/null || true
