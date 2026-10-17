#!/usr/bin/env bash
# Cycle focus only between workspaces that have windows open (occupied).
# Usage: workspace-cycle.sh next|prev
# Empty / persistent-empty workspaces (windows == 0) are skipped.
set -euo pipefail

DIR="${1:-next}"
[[ "$DIR" == "next" || "$DIR" == "prev" ]] || { echo "usage: $0 next|prev" >&2; exit 1; }

command -v hyprctl >/dev/null || exit 0
command -v jq >/dev/null || exit 0

OCCUPIED=$(hyprctl workspaces -j 2>/dev/null | jq -r '[.[] | select(.windows > 0 and .id > 0) | .id] | sort | .[]' 2>/dev/null || true)
[[ -z "$OCCUPIED" ]] && exit 0

mapfile -t IDS <<<"$OCCUPIED"
[[ ${#IDS[@]} -lt 2 ]] && { hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = ${IDS[0]} }))" >/dev/null 2>&1 || true; exit 0; }

ACTIVE=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)

# Find active index in occupied list (-1 if on an empty workspace).
IDX=-1
for i in "${!IDS[@]}"; do
	[[ "${IDS[$i]}" == "$ACTIVE" ]] && { IDX=$i; break; }
done

if [[ $IDX -ge 0 ]]; then
	if [[ "$DIR" == "next" ]]; then
		NEXT_IDX=$(( (IDX + 1) % ${#IDS[@]} ))
	else
		NEXT_IDX=$(( (IDX - 1 + ${#IDS[@]}) % ${#IDS[@]} ))
	fi
	TARGET="${IDS[$NEXT_IDX]}"
else
	# On an empty workspace: jump to nearest occupied in that direction, wrap around.
	if [[ "$DIR" == "next" ]]; then
		TARGET=""
		for id in "${IDS[@]}"; do
			if [[ "$id" -gt "$ACTIVE" ]]; then TARGET="$id"; break; fi
		done
		[[ -z "$TARGET" ]] && TARGET="${IDS[0]}"
	else
		TARGET=""
		for (( i=${#IDS[@]}-1; i>=0; i-- )); do
			if [[ "${IDS[$i]}" -lt "$ACTIVE" ]]; then TARGET="${IDS[$i]}"; break; fi
		done
		[[ -z "$TARGET" ]] && TARGET="${IDS[${#IDS[@]}-1]}"
	fi
fi

hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $TARGET }))" >/dev/null
