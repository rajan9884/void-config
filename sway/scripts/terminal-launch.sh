#!/usr/bin/env bash
# Open a new terminal in the working directory of the currently focused
# window (sway/Void port of terminal-launch.sh — uses swaymsg, not hyprctl).
set -eo pipefail
dir="$HOME"
pid=$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | objects | select(.focused == true) | .pid // empty' 2>/dev/null | head -n 1)
if [[ -n "${pid:-}" ]] && [[ "$pid" =~ ^[0-9]+$ ]]; then
    declare -A seen=()
    queue=("$pid")
    while ((${#queue[@]})); do
        cur=${queue[0]}
        queue=("${queue[@]:1}")
        [[ -n "${seen[$cur]:-}" ]] && continue
        seen[$cur]=1
        for c in $(pgrep -P "$cur" 2>/dev/null || true); do
            queue+=("$c")
            comm=$(ps -o comm= -p "$c" 2>/dev/null || true)
            case "$comm" in
                zsh|bash|fish)
                    cwd=$(readlink -f "/proc/$c/cwd" 2>/dev/null || true)
                    [[ -n "$cwd" && -d "$cwd" ]] && dir="$cwd"
                    ;;
            esac
        done
    done
    if [[ "$dir" == "$HOME" ]]; then
        cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)
        [[ -n "$cwd" && -d "$cwd" ]] && dir="$cwd"
    fi
fi
exec kitty --directory "$dir"
