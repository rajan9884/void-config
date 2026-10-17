#!/usr/bin/env python3
# .config/theme/bin/foot-live.py
"""Push the active theme palette to all running foot instances.

Foot only reads colors.ini at startup (SIGUSR1/2 just switch between the
already-loaded [colors-dark]/[colors-light] sections), so rewriting the file
alone never recolors open terminals. Foot understands xterm-style OSC
sequences, so broadcast the new fg/bg + 16 palette colors + selection to
every owned pty. New instances already pick up colors.ini; this covers the
running ones so no reopen is needed. Never raises; failures only warn.
"""
import json
import os
import sys
from pathlib import Path

HOME = Path.home()
PALETTE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "theme" / "palette.json"


def warn(msg):
    print(f"foot-live: warning: {msg}", file=sys.stderr)


def load_palette():
    try:
        return json.loads(PALETTE.read_text())
    except Exception as e:
        warn(f"could not read {PALETTE}: {e}")
        return {}


def build_sequences(pal):
    """OSC 10 (fg), 11 (bg), 4 (indexed 0-15). BEL-terminated for max compat."""
    seqs = []
    fg = pal.get("fg")
    bg = pal.get("bg")
    if isinstance(fg, str) and fg.startswith("#"):
        seqs.append(f"\033]10;{fg}\a")
    if isinstance(bg, str) and bg.startswith("#"):
        seqs.append(f"\033]11;{bg}\a")
    for i in range(16):
        c = pal.get(f"term{i}")
        if isinstance(c, str) and c.startswith("#"):
            seqs.append(f"\033]4;{i};{c}\a")
    # Selection colors (foot honors these OSCs; ignored elsewhere, harmless).
    sel_bg = pal.get("selection_bg")
    sel_fg = pal.get("selection_fg")
    if isinstance(sel_bg, str) and sel_bg.startswith("#"):
        seqs.append(f"\033]17;{sel_bg}\a")
    if isinstance(sel_fg, str) and sel_fg.startswith("#"):
        seqs.append(f"\033]19;{sel_fg}\a")
    return "".join(seqs)


def owned_ptys():
    """All /dev/pts/N nodes we can write to (foot's shells among them).

    Targeting only foot's exact ptys via /proc is fragile (foot holds the
    master side); OSC 4/10/11 are xterm-standard, so any other owned
    terminal receiving them just themes along too.
    """
    pts_dir = Path("/dev/pts")
    found = []
    try:
        for child in pts_dir.iterdir():
            if not child.name.isdigit():
                continue
            try:
                if os.access(child, os.W_OK):
                    found.append(child)
            except OSError:
                continue
    except OSError as e:
        warn(f"could not list /dev/pts: {e}")
    return found


def main():
    pal = load_palette()
    if not pal:
        return
    data = build_sequences(pal)
    if not data:
        warn("palette had no usable colors; nothing sent")
        return
    encoded = data.encode()
    sent, skipped = 0, 0
    for pts in owned_ptys():
        try:
            with open(pts, "wb") as f:
                f.write(encoded)
            sent += 1
        except OSError:
            skipped += 1
    print(f"foot-live: updated {sent} pty(s){f' ({skipped} skipped)' if skipped else ''}")


if __name__ == "__main__":
    main()
