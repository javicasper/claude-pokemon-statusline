#!/usr/bin/env python3
"""Convert PNG/GIF → ANSI half-block art for terminal statusline.

Static:   sprite-render.py <input.png> [width=16]              → stdout
          sprite-render.py <input.png> <width> <out_prefix>    → out_prefix.ansi
Animated: sprite-render.py <input.gif> <width> <out_prefix>    → out_prefix-N.ansi
"""
import glob
import os
import sys
from PIL import Image

ESC = "\033["
RESET = ESC + "0m"
TRANSPARENT = "⠀"  # Braille Blank — visible-width but survives terminal trim
DEFAULT_GIF_FRAMES = 0  # 0 = use all frames in the GIF (BW pokemon: ~50-85)

# Quadrant block characters (2×2 sub-pixels per cell, 16 patterns).
# bits: top-left=8, top-right=4, bottom-left=2, bottom-right=1.
QC = {
    0b0000: " ",  0b0001: "▗",  0b0010: "▖",  0b0011: "▄",
    0b0100: "▝",  0b0101: "▐",  0b0110: "▞",  0b0111: "▟",
    0b1000: "▘",  0b1001: "▚",  0b1010: "▌",  0b1011: "▙",
    0b1100: "▀",  0b1101: "▜",  0b1110: "▛",  0b1111: "█",
}


def sextant_char(bits):
    """Map a 6-bit pattern (bit order: TL=1, TR=2, ML=4, MR=8, BL=16, BR=32)
    to the corresponding Unicode "Symbols for Legacy Computing" sextant char.
    Special-cases 0/21/42/63 which collide with pre-existing block chars."""
    if bits == 0:  return " "
    if bits == 21: return "▌"
    if bits == 42: return "▐"
    if bits == 63: return "█"
    pos = bits - 1
    if bits > 21: pos -= 1
    if bits > 42: pos -= 1
    return chr(0x1FB00 + pos)


def _luma(p):
    return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]


def _quadrant_cell(pixels):
    """Render a 2×2 RGBA block as a single colored quadrant character."""
    visible = [p[3] > 32 for p in pixels]
    if not any(visible):
        return TRANSPARENT
    vis = [p for p, v in zip(pixels, visible) if v]
    uniq = {p[:3] for p in vis}
    if len(uniq) == 1:
        bits = sum(b << i for i, b in zip([3, 2, 1, 0], visible))
        r, g, b = vis[0][:3]
        return f"{ESC}38;2;{r};{g};{b}m{QC.get(bits, ' ')}{RESET}"
    # 2-color quantization by luma.
    sp = sorted(vis, key=_luma)
    dark, bright = sp[0][:3], sp[-1][:3]
    classes = []
    for p, v in zip(pixels, visible):
        if not v:
            classes.append(None)
            continue
        d_fg = sum((a - b) ** 2 for a, b in zip(p[:3], bright))
        d_bg = sum((a - b) ** 2 for a, b in zip(p[:3], dark))
        classes.append(1 if d_fg < d_bg else 0)
    bits = 0
    for i, c in enumerate(classes):
        if c == 1:
            bits |= 1 << (3 - i)
    fr, fg, fb = bright
    has_bg = any(c == 0 for c in classes)
    has_tr = any(c is None for c in classes)
    if has_bg and not has_tr:
        br, bgg, bbb = dark
        return f"{ESC}38;2;{fr};{fg};{fb};48;2;{br};{bgg};{bbb}m{QC.get(bits, ' ')}{RESET}"
    return f"{ESC}38;2;{fr};{fg};{fb}m{QC.get(bits, ' ')}{RESET}"


def _sextant_cell(pixels):
    """Render a 2×3 RGBA block (6 sub-pixels) as a single colored sextant char.
    pixels order: TL, TR, ML, MR, BL, BR."""
    visible = [p[3] > 32 for p in pixels]
    if not any(visible):
        return TRANSPARENT
    vis = [p for p, v in zip(pixels, visible) if v]
    uniq = {p[:3] for p in vis}
    if len(uniq) == 1:
        bits = sum((1 << i) for i, v in enumerate(visible) if v)
        r, g, b = vis[0][:3]
        return f"{ESC}38;2;{r};{g};{b}m{sextant_char(bits)}{RESET}"
    sp = sorted(vis, key=_luma)
    dark, bright = sp[0][:3], sp[-1][:3]
    classes = []
    for p, v in zip(pixels, visible):
        if not v:
            classes.append(None); continue
        d_fg = sum((a - b) ** 2 for a, b in zip(p[:3], bright))
        d_bg = sum((a - b) ** 2 for a, b in zip(p[:3], dark))
        classes.append(1 if d_fg < d_bg else 0)
    bits = 0
    for i, c in enumerate(classes):
        if c == 1:
            bits |= 1 << i
    fr, fg, fb = bright
    has_bg = any(c == 0 for c in classes)
    has_tr = any(c is None for c in classes)
    if has_bg and not has_tr:
        br, bgg, bbb = dark
        return f"{ESC}38;2;{fr};{fg};{fb};48;2;{br};{bgg};{bbb}m{sextant_char(bits)}{RESET}"
    return f"{ESC}38;2;{fr};{fg};{fb}m{sextant_char(bits)}{RESET}"


def _frame_to_sextant(img, width, bbox=None):
    img = img.convert("RGBA")
    if bbox is None:
        bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    # Each cell = 2 px wide × 3 px tall.
    img.thumbnail((width * 2, width * 12), Image.LANCZOS)
    w, h = img.size
    nw = w + (w % 2)
    nh = h + ((3 - h % 3) % 3)
    if (nw, nh) != (w, h):
        pad = Image.new("RGBA", (nw, nh), (0, 0, 0, 0))
        pad.paste(img, (0, 0))
        img, w, h = pad, nw, nh
    px = img.load()
    lines = []
    for y in range(0, h, 3):
        out = []
        for x in range(0, w, 2):
            out.append(_sextant_cell([
                px[x, y],     px[x + 1, y],
                px[x, y + 1], px[x + 1, y + 1],
                px[x, y + 2], px[x + 1, y + 2],
            ]))
        lines.append("".join(out))
    return lines


def _frame_to_quadrant(img, width, bbox=None):
    img = img.convert("RGBA")
    if bbox is None:
        bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    # Each cell = 2×2 pixels, so target image width = width * 2.
    img.thumbnail((width * 2, width * 8), Image.LANCZOS)
    w, h = img.size
    nw, nh = w + (w % 2), h + (h % 2)
    if (nw, nh) != (w, h):
        pad = Image.new("RGBA", (nw, nh), (0, 0, 0, 0))
        pad.paste(img, (0, 0))
        img, w, h = pad, nw, nh
    px = img.load()
    lines = []
    for y in range(0, h, 2):
        out = []
        for x in range(0, w, 2):
            out.append(_quadrant_cell(
                [px[x, y], px[x + 1, y], px[x, y + 1], px[x + 1, y + 1]]
            ))
        lines.append("".join(out))
    return lines


def _frame_to_ansi(img, width, bbox=None):
    img = img.convert("RGBA")
    if bbox is None:
        bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    if width > 0:
        img.thumbnail((width, width * 4), Image.LANCZOS)
    # width <= 0: render at native sprite resolution (zero pixel loss).
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


def render_gif(path, width, frame_count=DEFAULT_GIF_FRAMES, mode="halfblock"):
    img = Image.open(path)
    n = getattr(img, "n_frames", 1)
    limit = n if frame_count <= 0 else min(frame_count, n)

    # Some GIFs report more frames than they can actually seek to.
    real_indices = []
    for i in range(limit):
        try:
            img.seek(i)
        except EOFError:
            break
        real_indices.append(i)

    union = None
    for i in real_indices:
        try:
            img.seek(i)
        except EOFError:
            continue
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
    if mode == "quadrant":
        render_one = _frame_to_quadrant
    elif mode == "sextant":
        render_one = _frame_to_sextant
    else:
        render_one = _frame_to_ansi
    frames = []
    for i in real_indices:
        try:
            img.seek(i)
        except EOFError:
            continue
        frames.append(render_one(img, width, bbox=bbox))
    return frames


def main():
    src = sys.argv[1]
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    out_prefix = sys.argv[3] if len(sys.argv) > 3 else None
    mode = sys.argv[4] if len(sys.argv) > 4 else "halfblock"

    is_gif = src.lower().endswith(".gif")

    if is_gif:
        if not out_prefix:
            sys.exit("GIF mode requires <out_prefix> as 3rd arg")
        frames = render_gif(src, width, mode=mode)
        # Wipe stale frame files from a prior render at this prefix
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
