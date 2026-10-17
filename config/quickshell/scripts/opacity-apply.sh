#!/bin/sh
# Apply global transparency everywhere at once.
# Port of the rofi-era scripts/opacity.sh (whose qmlscene rework could never
# return a selection and is gone) — this one is called by quickshell's
# OpacityMenu, so it only mutates files, it never has to reply.
#
#   usage: opacity-apply.sh <pct>     (40..100; 0 is normalized to 100 upstream)
#
#   1) first `opacity = ".* override"` window rule in hypr/rules.lua
#   2) quickshell Theme.qml bgAlpha — its write makes quickshell hot-reload
#      the config
#   3) state files of surfaces storing their own opacity
#      (bar-state bgOpacity, powermenu panelOpacity/itemOpacity, mediaosd
#      bgOpacity) — kept AFTER the Theme write on purpose: quickshell's
#      FileView save-back can resurrect an old value when its config hot
#      reload races this script; writing them last lets the watcher pick
#      up the final value instead.
#   4) hyprctl reload for the rules change
#
set -u
PCT="${1:-100}"
case "$PCT" in ''|*[!0-9]*) echo "opacity-apply: bad percent '$PCT'" >&2; exit 1 ;; esac
[ "$PCT" -lt 40 ] && PCT=40
[ "$PCT" -gt 100 ] && PCT=100
# Two values (inactive + active) so FOCUSED windows follow SUPER+O as well.
if [ "$PCT" -eq 100 ]; then OPACITY="1.0 1.0"; else OPACITY="0.$PCT 0.$PCT"; fi
FACTOR="1.0"
[ "$PCT" -lt 100 ] && FACTOR="0.$PCT"

# 1) Hyprland global window rule (first match only, like the old script)
sed -i --follow-symlinks \
  "0,/opacity = \".* override\"/s//opacity = \"$OPACITY override\"/" \
  "$HOME/.config/hypr/rules.lua"
echo "rules rc=$?"

# 2) quickshell Theme.qml bgAlpha (single real; triggers shell hot reload).
#    No backref here: "\1$FACTOR" would let sed read "\1<digit>" as a
#    higher group reference and corrupt the line.
sed -i --follow-symlinks -E \
  "s/^([[:space:]]*property real bgAlpha: )[0-9.].*/\1$FACTOR/" \
  "$HOME/.config/quickshell/Theme.qml"
echo "theme rc=$?"

# 3) saved state of surfaces with their own stored opacity (AFTER 2, see above)
python3 - "$PCT" "$FACTOR" <<'PYEOF'
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

# 4) Hyprland reload so rules.lua takes effect live
sleep 0.3
hyprctl reload >/dev/null 2>&1
echo "reload rc=$?"
