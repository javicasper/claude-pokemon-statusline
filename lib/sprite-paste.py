#!/usr/bin/env python3
"""Glue a pre-rendered ANSI sprite onto a statusline.

Usage: <statusline-on-stdin> | sprite-paste.py <sprite.ansi> <cols> [mode]

Modes:
  left    sprite first, statusline to its right (default for this project)
  right   statusline first, sprite right-aligned at the terminal edge
  compact statusline first, sprite immediately after (no edge alignment)
"""
import re
import sys

ANSI_RE = re.compile(r"\033\[[0-9;]*m")
GAP = 2
SAFETY = 2
PAD = "⠀"  # Braille Blank: visible-width but survives Claude Code's .trim()


def vlen(s: str) -> int:
    return len(ANSI_RE.sub("", s))


def main() -> None:
    import os
    sprite_path = sys.argv[1]
    cols = int(sys.argv[2]) if len(sys.argv) > 2 else 120
    mode = sys.argv[3] if len(sys.argv) > 3 else "left"

    raw = sys.stdin.read()
    status = raw.rstrip("\n").split("\n") if raw else []
    with open(sprite_path) as f:
        sprite = f.read().rstrip("\n").split("\n")

    # Optional label (e.g. "#025 Pikachu") rendered below the sprite.
    label = os.environ.get("POKEMON_LABEL", "")
    if label:
        sprite.append(label)

    sprite_w = max((vlen(line) for line in sprite), default=0)
    edge_max = max(0, cols - sprite_w - GAP - SAFETY)

    rows = max(len(status), len(sprite))
    out = []

    if mode == "left":
        for i in range(rows):
            s = status[i] if i < len(status) else ""
            p = sprite[i] if i < len(sprite) else PAD * sprite_w
            out.append(f"{p}{PAD * GAP}{s}")
    else:
        if mode == "right":
            status_max = edge_max
        else:  # compact
            max_status_w = max((vlen(s) for s in status), default=0)
            status_max = min(max_status_w, edge_max)
        for i in range(rows):
            s = status[i] if i < len(status) else ""
            p = sprite[i] if i < len(sprite) else ""
            pad = max(0, status_max - vlen(s))
            gap = PAD * GAP if p else ""
            out.append(f"{s}{PAD * pad}{gap}{p}")

    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
