#!/usr/bin/env bash
# Open a new terminal in the working directory of the currently focused
# window (sway/Void port of terminal-launch.sh — uses swaymsg, not hyprctl).
# Fast path: one swaymsg + one jq + one ps snapshot, zero forks per process
# (the old pgrep/ps-per-node BFS cost ~170ms before kitty even started).
set -u
dir="$HOME"
pid="$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | objects | select(.focused == true) | .pid // empty' 2>/dev/null | head -n 1 || true)"
if [[ -n "${pid:-}" ]] && [[ "$pid" =~ ^[0-9]+$ ]]; then
    # Build parent->children map + comm table from a single ps snapshot.
    declare -A kids=() comms=()
    while read -r p pp c; do
        [[ "$p" =~ ^[0-9]+$ ]] || continue
        comms[$p]="$c"
        kids[$pp]="${kids[$pp]:-} $p"
    done < <(ps -eo pid=,ppid=,comm= 2>/dev/null || true)
    # BFS from the focused pid; newest shell descendant wins (outermost loop
    # order), falling back to the focused pid's own cwd.
    declare -A seen=()
    queue=("$pid")
    while ((${#queue[@]})); do
        cur=${queue[0]}
        queue=("${queue[@]:1}")
        [[ -n "${seen[$cur]:-}" ]] && continue
        seen[$cur]=1
        # shellcheck disable=SC2086
        for c in ${kids[$cur]:-}; do
            queue+=("$c")
            case "${comms[$c]:-}" in
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
# Prefer the login kitty daemon (~100ms remote open); fall back to a cold
# launch if it isn't up yet (slow once, still opens). The fallback carries
# the listener flags so it becomes the new anchor — a taken socket is
# ignored harmlessly, so this is safe when a daemon is already up.
SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kitty.sock"
if [[ -S "$SOCK" ]] && kitty @ --to "unix:$SOCK" launch --type=os-window --cwd="$dir" >/dev/null 2>&1; then
    exit 0
fi
exec kitty -o allow_remote_control=yes --listen-on "unix:$SOCK" --directory "$dir"
