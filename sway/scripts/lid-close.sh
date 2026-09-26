#!/usr/bin/env bash
# Lock the screen when the laptop lid closes (also wired via bindswitch).
set -euo pipefail
pidof swaylock >/dev/null 2>&1 || exec swaylock -f
