#!/bin/sh
# Apply global transparency everywhere at once.
# Port of the rofi-era scripts/opacity.sh (whose qmlscene rework could never
# return a selection and is gone) — this one is called by quickshell's
# OpacityMenu, so it only mutates files, it never has to reply.
#
#   usage: opacity-apply.sh <pct>     (40..100; 0 is normalized to 100 upstream)
#
#   1) first `opacity = ".* override"` window rule in hypr/rules.lua
#   2) state files of surfaces storing their own opacity
#      (bar-state bgOpacity, powermenu panel/itemOpacity, mediaosd bgOpacity)
#   3) quickshell Theme.qml bgAlpha  — its write makes quickshell hot-reload
#      the config, so it is kept LAST and hyprctl reload comes after it.
#
set -u
PCT="${1:-100}"
case "$PCT" in ''|*[!0-9]*) echo "opacity-apply: bad percent '$PCT'" >&2; exit 1 ;; esac
[ "$PCT" -lt 40 ] && PCT=40
[ "$PCT" -gt 100 ] && PCT=100
if [ "$PCT" -eq 100 ]; then OPACITY="1.0"; else OPACITY="0.$PCT"; fi

# 1) Hyprland global window rule (first match only, like the old script)
sed -i --follow-symlinks \
  "0,/opacity = \".* override\"/s//opacity = \"$OPACITY override\"/" \
  "$HOME/.config/hypr/rules.lua"
echo "rules rc=$?"

# 2) saved state of surfaces with their own stored opacity
python3 - "$PCT" "$OPACITY" <<'PYEOF'
import json, os, sys
pct = int(sys.argv[1]); opF = float(sys.argv[2])
home = os.path.expanduser("~")
def upd(rel, fn):
    p = os.path.join(home, rel)
    try:
        d = json.load(open(p))
    except Exception:
        return
    fn(d)
    json.dump(d, open(p, "w"), indent=2)
upd(".config/quickshell/state/bar-state.json", lambda d: d.update(bgOpacity=opF))
upd(".config/quickshell/state/powermenu-state.json", lambda d: d.update(panelOpacity=pct, itemOpacity=pct))
upd(".config/quickshell/state/mediaosd-state.json", lambda d: d.update(bgOpacity=pct))
print("state ok")
PYEOF
echo "state rc=$?"

# 3) quickshell Theme.qml bgAlpha (hot-reloaded by the config watcher)
sed -i --follow-symlinks -E \
  "s/(property real bgAlpha: )[0-9.]+/\\1$OPACITY/" \
  "$HOME/.config/quickshell/Theme.qml"
echo "theme rc=$?"

# 4) Hyprland reload so rules.lua takes effect live
sleep 0.3
hyprctl reload >/dev/null 2>&1
echo "reload rc=$?"
