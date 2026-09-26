#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Universal clipboard for sway (port of the Hyprland Lua helper).
#   Usage: universal-clipboard.sh copy|paste|cut
#   Terminals get ctrl+insert / shift+insert, everyone else ctrl+c/v/x.
#   Uses wtype so the injected keys reach the focused surface.
# ──────────────────────────────────────────────
set -euo pipefail
ACTION="${1:-copy}"
APP=$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | objects | select(.focused == true) | (.app_id // .window_properties.class // "")' 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')
is_term=0
case "$APP" in
    kitty|foot|alacritty|wezterm|ghostty|rio|konsole|*terminal*|*console*|xterm|urxvt|st) is_term=1 ;;
esac
case "$ACTION" in
    copy)  if ((is_term)); then wtype -M ctrl -k Insert -m ctrl; else wtype -M ctrl c -m ctrl; fi ;;
    paste) if ((is_term)); then wtype -M shift -k Insert -m shift; else wtype -M ctrl v -m ctrl; fi ;;
    cut)   wtype -M ctrl x -m ctrl ;;
esac
