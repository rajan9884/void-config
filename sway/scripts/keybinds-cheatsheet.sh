#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Keybindings Cheatsheet (sway/Void port)
#   Parses `# > <description>` marker lines directly above
#   bindsym/bindswitch lines in ~/.config/sway/config
#   (trailing `#` comments can't be used: sway stores
#   bindsym commands verbatim, so `# ...` would leak
#   into e.g. workspace names) and pipes
#   `KEYS → description` through rofi -dmenu.
# ──────────────────────────────────────────────
set -euo pipefail
CFG="$HOME/.config/sway/config"
THEME="$HOME/.config/rofi/active-picker.rasi"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
pending=""
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*\>[[:space:]]*(.*)$ ]]; then
        pending="${BASH_REMATCH[1]}"
        pending="$(echo "$pending" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        continue
    fi
    if [[ "$line" =~ ^[[:space:]]*bind(sym|switch)[[:space:]]+(.*)$ ]]; then
        rest="${BASH_REMATCH[2]}"
        desc="$pending"; pending=""
        [ -z "$desc" ] && continue
        # strip bindsym flags, keep only the key combo (first token)
        combo="$(echo "$rest" | sed -e 's/--[^[:space:]]*[[:space:]]*//g' -e 's/^[[:space:]]*//' | awk '{print $1}')"
        combo="${combo//\$mod/SUPER}"; combo="${combo//\$left/h}"
        combo="${combo//\$right/l}"; combo="${combo//\$up/k}"; combo="${combo//\$down/j}"
        printf '%-28s %s\n' "$combo" "$desc" >> "$TMP"
        continue
    fi
    # any other non-blank line breaks the marker association
    # (blank lines are tolerated)
    [[ "$line" =~ ^[[:space:]]*$ ]] || pending=""
done < "$CFG"
sort -u "$TMP" | rofi -dmenu -i -p "Keybindings" -theme "$THEME" \
    -matching fuzzy -sorting-method fzf -sort -no-fixed-num-lines >/dev/null || true
