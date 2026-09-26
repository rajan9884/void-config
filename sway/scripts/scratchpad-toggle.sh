#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   scratchpad-toggle — run a scratchpad command, then dim the
#   background while a scratchpad window is visible.
#   (Arch gets this free via Hyprland dim_inactive on the special
#   workspace; sway needs the bump explicitly.)
#   Usage: scratchpad-toggle.sh <sway command...>
#   e.g.   scratchpad-toggle.sh scratchpad show
#          scratchpad-toggle.sh '[con_mark="music"] scratchpad show'
#          scratchpad-toggle.sh move scratchpad
#          scratchpad-toggle.sh 'mark music; move scratchpad'
# ──────────────────────────────────────────────
set -u
swaymsg "$*" >/dev/null 2>&1 || true
sleep 0.2
# A scratchpad window keeps scratchpad_state=fresh even while shown; it
# only differs by visible. Count shown ones across all workspaces.
VISIBLE=$(swaymsg -t get_tree 2>/dev/null | jq '[.. | objects | select(.scratchpad_state != null and .scratchpad_state != "none" and .visible == true)] | length' 2>/dev/null || echo 0)
[[ "$VISIBLE" =~ ^[0-9]+$ ]] || VISIBLE=0
if [ "$VISIBLE" -gt 0 ]; then
    # Scratchpad up: strong dim so it stands out from the workspace.
    [ -f /tmp/swayfx-off ] || swaymsg default_dim_inactive 0.4 >/dev/null 2>&1 || true
else
    # Nothing shown: back to the config default (or 0 when fx are off).
    if [ -f /tmp/swayfx-off ]; then
        swaymsg default_dim_inactive 0.0 >/dev/null 2>&1 || true
    else
        swaymsg default_dim_inactive 0.12 >/dev/null 2>&1 || true
    fi
fi
