#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   Volume control with QML OSD (quickshell VolumeOsd).
#   pactl makes the change (exact 5% steps, 150% ceiling);
#   VolumeOsd shows itself automatically via Pipewire.
#   Mic / failure feedback goes through the generic
#   bottom OSD: qs ipc call sysosd notify "Title|frac|Text"
# ──────────────────────────────────────────────
ACTION="$1"
SINK="@DEFAULT_SINK@"
MAX=150

run_timeout() { timeout 3 "$@" 2>/dev/null; }

sysosd() { timeout 2 qs ipc call sysosd notify "$1|$2|$3" >/dev/null 2>&1 || true; }

case "$ACTION" in
    up)
        run_timeout pactl set-sink-volume "$SINK" +5% \
        || run_timeout wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ;;
    down)
        run_timeout pactl set-sink-volume "$SINK" -5% \
        || run_timeout wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    mute-toggle)
        run_timeout pactl set-sink-mute "$SINK" toggle \
        || run_timeout wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    mic-toggle)
        run_timeout pactl set-source-mute @DEFAULT_SOURCE@ toggle \
        || run_timeout wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if run_timeout pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes \
            || run_timeout wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -qi '\[MUTED\]'; then
            sysosd "Mic" 0 "Muted"
        else
            sysosd "Mic" 1 "On"
        fi
        exit 0 ;;
esac

PCT=$(run_timeout pactl get-sink-volume "$SINK" | grep -oP '\d+(?=%)' | head -1)
# Fallback: wpctl reports "Volume: 0.75" (fraction) or "0.75 [MUTED]".
if [[ -z "$PCT" ]]; then
    FRAC_RAW=$(run_timeout wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -oP '\d+\.\d+' | head -1)
    if [[ -n "$FRAC_RAW" ]]; then
        PCT=$(awk -v f="$FRAC_RAW" 'BEGIN{ printf "%d", f*100 }')
    fi
fi

# Audio stack unreachable: still show an OSD so the key feels alive.
# (VolumeOsd only reacts to real Pipewire changes.)
if [[ -z "$PCT" ]]; then
    sysosd "Audio" 0 "No audio"
    exit 0
fi

if [ "$PCT" -gt "$MAX" ]; then
    run_timeout pactl set-sink-volume "$SINK" "$MAX%" \
    || run_timeout wpctl set-volume @DEFAULT_AUDIO_SINK@ "$MAX%"
fi
