#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Keyboard-backlight control with QML OSD (quickshell SysOsd).
#   `cycle` wraps max → off (brightnessctl has no wrap for kbd).
# ──────────────────────────────────────────────
ACTION="$1"
DEV="*kbd*"

sysosd() { timeout 2 qs ipc call sysosd notify "$1|$2|$3" >/dev/null 2>&1 || true; }

case "$ACTION" in
    up) brightnessctl --device="$DEV" set 1+ >/dev/null 2>&1 ;;
    down) brightnessctl --device="$DEV" set 1- >/dev/null 2>&1 ;;
    cycle)
        LEVEL=$(brightnessctl --device="$DEV" get 2>/dev/null)
        MAX=$(brightnessctl --device="$DEV" max 2>/dev/null)
        if [[ "$LEVEL" =~ ^[0-9]+$ && "$MAX" =~ ^[0-9]+$ ]] && ((MAX > 0)) && ((LEVEL >= MAX)); then
            brightnessctl --device="$DEV" set 0 >/dev/null 2>&1
        else
            brightnessctl --device="$DEV" set 1+ >/dev/null 2>&1
        fi
        ;;
esac

LEVEL=$(brightnessctl --device="$DEV" get 2>/dev/null)
KBMAX=$(brightnessctl --device="$DEV" max 2>/dev/null)
if [[ "$LEVEL" =~ ^[0-9]+$ && "$KBMAX" =~ ^[0-9]+$ ]] && ((KBMAX > 0)); then
    KBPCT=$(( LEVEL * 100 / KBMAX ))
    (( KBPCT > 100 )) && KBPCT=100
    KBFRAC=$(awk -v l="$LEVEL" -v m="$KBMAX" 'BEGIN{ f=(m>0)?l/m:0; if (f>1) f=1; if (f<0) f=0; printf "%.2f", f }')
    if (( KBPCT > 0 )); then
        sysosd "Keyboard" "$KBFRAC" "$KBPCT%"
    else
        sysosd "Keyboard" 0 "Off"
    fi
else
    sysosd "Keyboard" 0 "No keyboard"
fi
