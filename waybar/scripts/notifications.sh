#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Notification count for Waybar (mako — Void port)
# ──────────────────────────────────────────────
set -euo pipefail
count="$(makoctl list 2>/dev/null | grep -c '^Notification ' || echo 0)"
count="${count//[^0-9]/}"
[ -z "$count" ] && count=0
if ((count > 0)); then
    jq -cn --argjson n "$count" '{text: ("󰂚 " + ($n | tostring)), tooltip: "Notifications (click to dismiss all)", class: "has-notifications"}'
else
    jq -cn '{text: "󰂚", tooltip: "No notifications", class: "no-notifications"}'
fi
