#!/usr/bin/env python3
"""Convert PNG/GIF -> ANSI half-block art for terminal statusline.

Static:   sprite-render.py <input.png> [width=16]              -> stdout
          sprite-render.py <input.png> <width> <out_prefix>    -> out_prefix.ansi
Animated: sprite-render.py <input.gif> <width> <out_prefix>    -> out_prefix-N.ansi
"""
import glob
import os
import sys
from PIL import Image

ESC = "\033["
RESET = ESC + "0m"
TRANSPARENT = "⠀"  # Braille Blank: visible-width but survives terminal trim
DEFAULT_GIF_FRAMES = 0  # 0 = use all frames; BW GIFs typically have ~50-85


def _frame_to_ansi(img, width, bbox=None):
    img = img.convert("RGBA")
    if bbox is None:
        bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img.thumbnail((width, width * 4), Image.LANCZOS)
    w, h = img.size
    if h % 2:
        padded = Image.new("RGBA", (w, h + 1), (0, 0, 0, 0))
        padded.paste(img, (0, 0))
        img, h = padded, h + 1

    px = img.load()
    lines = []
    for y in range(0, h, 2):
        out = []
        for x in range(w):
            tr, tg, tb, ta = px[x, y]
            br, bgc, bbc, ba = px[x, y + 1]
            top, bot = ta > 32, ba > 32
            if not top and not bot:
                out.append(TRANSPARENT)
            elif top and not bot:
                out.append(f"{ESC}38;2;{tr};{tg};{tb}m▀{RESET}")
            elif bot and not top:
                out.append(f"{ESC}38;2;{br};{bgc};{bbc}m▄{RESET}")
            else:
                out.append(f"{ESC}38;2;{tr};{tg};{tb};48;2;{br};{bgc};{bbc}m▀{RESET}")
        lines.append("".join(out))
    return lines


def render_static(path, width):
    img = Image.open(path)
    if getattr(img, "n_frames", 1) > 1:
        img.seek(0)
    return _frame_to_ansi(img, width)


def render_gif(path, width, frame_count=DEFAULT_GIF_FRAMES):
    img = Image.open(path)
    n = getattr(img, "n_frames", 1)
    limit = n if frame_count <= 0 else min(frame_count, n)
    indices = list(range(limit))

    union = None
    for i in indices:
        img.seek(i)
        bb = img.convert("RGBA").getbbox()
        if bb:
            if union is None:
                union = list(bb)
            else:
                union[0] = min(union[0], bb[0])
                union[1] = min(union[1], bb[1])
                union[2] = max(union[2], bb[2])
                union[3] = max(union[3], bb[3])

    bbox = tuple(union) if union else None
    frames = []
    for i in indices:
        img.seek(i)
        frames.append(_frame_to_ansi(img, width, bbox=bbox))
    return frames


def main():
    src = sys.argv[1]
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    out_prefix = sys.argv[3] if len(sys.argv) > 3 else None

    is_gif = src.lower().endswith(".gif")

    if is_gif:
        if not out_prefix:
            sys.exit("GIF mode requires <out_prefix> as 3rd arg")
        frames = render_gif(src, width)
        for old in glob.glob(f"{out_prefix}-*.ansi"):
            os.remove(old)
        for i, lines in enumerate(frames):
            with open(f"{out_prefix}-{i}.ansi", "w") as f:
                f.write("\n".join(lines))
        print(f"Wrote {len(frames)} frames to {out_prefix}-N.ansi")
    else:
        lines = render_static(src, width)
        if out_prefix:
            with open(f"{out_prefix}.ansi", "w") as f:
                f.write("\n".join(lines))
        else:
            for line in lines:
                print(line)


if __name__ == "__main__":
    main()
