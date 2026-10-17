#!/usr/bin/env python3
# .config/theme/bin/theme-thumbs.py
"""Render one preview thumbnail per theme preset into ~/.cache/theme/theme-thumbs/.

Uses only stdlib (tomllib) + ImageMagick `convert` (already required for the
wallpaper-picker cache). A thumbnail is regenerated only when its preset toml
(or default.toml, the overlay base) is newer than the png.

Layout (360x500, portrait to match the picker tiles):
  header bar (bg_panel) with danger/ok/accent dots
  accent + highlight pills, fg/fg_dim/fg_muted text lines
  terminal mock card (bg_card, theme border, term0-6 blocks)
  bottom swatch row (accent, highlight, danger, ok, border_strong, fg)
"""
import os
import subprocess
import sys
import tomllib
from pathlib import Path

HOME = Path.home()
ROOT = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "theme"
THEMES = ROOT / "themes"
OUT = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "theme" / "theme-thumbs"

W, H = 360, 500


def load_toml(p):
    with open(p, "rb") as f:
        return tomllib.load(f)


def merged(colors):
    base = dict(load_toml(THEMES / "default.toml")["colors"])
    base.update(colors)
    return {k: v.lower() for k, v in base.items()}


def draws(c):
    """ImageMagick -draw primitives for the preview card."""
    d = [
        # header bar + window dots
        f"fill {c['bg_panel']} rectangle 0,0 {W},84",
        f"fill {c['danger']} circle 36,42 48,42",
        f"fill {c['ok']} circle 68,42 80,42",
        f"fill {c['accent']} circle 100,42 112,42",
        # accent / highlight pills
        f"fill {c['accent']} roundrectangle 28,120 260,164 18,18",
        f"fill {c['highlight']} roundrectangle 28,178 200,206 14,14",
        # text lines
        f"fill {c['fg']} rectangle 28,232 332,246",
        f"fill {c['fg_dim']} rectangle 28,258 280,270",
        f"fill {c['fg_muted']} rectangle 28,280 300,290",
        # terminal mock card (border set via -strokewidth, as `strokewidth`
        # is not a valid -draw primitive)
        "@STROKE2@",
        f"stroke {c['border']} fill {c['bg_card']}"
        f" roundrectangle 28,312 332,432 10,10",
        "@STROKE1@",
        "stroke none",
    ]
    terms = [c[f"term{i}"] for i in range(1, 7)]
    for row in range(2):
        y0, y1 = 328 + row * 32, 352 + row * 32
        for col in range(3):
            x0 = 44 + col * 92
            d.append(f"fill {terms[row * 3 + col]} rectangle {x0},{y0} {x0 + 76},{y1}")
    d.append(f"fill {c['selection_bg']} rectangle 44,392 120,416")
    d.append(f"fill {c['fg']} rectangle 132,398 288,410")
    # bottom swatches
    for i, key in enumerate(["accent", "highlight", "danger", "ok", "border_strong", "fg"]):
        x0 = 28 + i * 52
        d.append(f"fill {c[key]} rectangle {x0},448 {x0 + 44},484")
    return d


def render(name, colors):
    out = OUT / f"{name}.png"
    srcs = [THEMES / f"{name}.toml", THEMES / "default.toml"]
    if out.is_file() and all(out.stat().st_mtime >= s.stat().st_mtime for s in srcs):
        return False
    cmd = ["convert", "-size", f"{W}x{H}", f"xc:{colors['bg']}"]
    for prim in draws(colors):
        if prim == "@STROKE2@":
            cmd += ["-strokewidth", "2"]
        elif prim == "@STROKE1@":
            cmd += ["-strokewidth", "1"]
        else:
            cmd += ["-draw", prim]
    cmd += ["-strip", str(out)]
    subprocess.run(cmd, check=True, stdin=subprocess.DEVNULL,
                   capture_output=True, timeout=60)
    return True


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    names = sorted(p.stem for p in THEMES.glob("*.toml"))
    done, skipped = 0, 0
    for name in names:
        try:
            colors = merged(load_toml(THEMES / f"{name}.toml").get("colors", {}))
            if render(name, colors):
                done += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"theme-thumbs: {name}: {e}", file=sys.stderr)
    print(f"theme-thumbs: rendered {done}, up-to-date {skipped} in {OUT}")


if __name__ == "__main__":
    main()
