#!/usr/bin/env bash
# Picks the current Pokemon based on the wall clock minute, fetches+renders
# its animated sprite if not already cached, and points the "current" symlink
# at it. Idempotent — safe to call every second.
set -euo pipefail

TOTAL=649                # cycle through gen 1-5 (PokeAPI BW covers up to 649)
WIDTH=30                 # cap at 30 cols (downsamples bigger sprites)
MAX_H=20                 # cap at 20 rows — keeps roughly-square visual aspect
MODE=sextant             # 2×3 px/cell — 6 sub-pixels, best detail per cell
SPRITES_DIR="$HOME/.claude/sprites"
CACHE="$SPRITES_DIR/cache"
CURRENT="$SPRITES_DIR/current"
URL_BASE="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated"

mkdir -p "$CACHE"

# If ~/.claude/.pokemon-fixed exists and contains a valid id, pin to it.
# Otherwise rotate by wall-clock minute. Manage via ~/.claude/pokemon-set.sh
FIXED_FILE="$HOME/.claude/.pokemon-fixed"
FIXED_ID=""
if [ -f "$FIXED_FILE" ]; then
  FIXED_ID=$(tr -dc 0-9 < "$FIXED_FILE" 2>/dev/null)
fi

SHUFFLE_FILE="$HOME/.claude/.pokemon-shuffle"
NOW_S=$(date +%s)

if [ -n "$FIXED_ID" ] && [ "$FIXED_ID" -ge 1 ] && [ "$FIXED_ID" -le "$TOTAL" ]; then
  ID="$FIXED_ID"
elif [ -f "$SHUFFLE_FILE" ]; then
  # Random rotation: hash a time bucket. The bucket size (in seconds) lives
  # in the shuffle file; default 10s. Same bucket → same Pokemon, so
  # repaints within the bucket are stable.
  INTERVAL=$(tr -dc 0-9 < "$SHUFFLE_FILE" 2>/dev/null)
  case "$INTERVAL" in ''|0) INTERVAL=10 ;; esac
  BUCKET=$(( NOW_S / INTERVAL ))
  HASH=$(printf '%s' "$BUCKET" | cksum | awk '{print $1}')
  ID=$(( HASH % TOTAL + 1 ))
else
  ID=$(( (NOW_S / 60) % TOTAL + 1 ))
fi
ID=$(( ID ))  # force decimal (avoid leading-zero octal interpretation)
DIR="$CACHE/$ID"

# If frames not yet rendered for this id, fetch + render.
if [ ! -f "$DIR/frame-0.ansi" ]; then
  mkdir -p "$DIR"
  GIF="$DIR/sprite.gif"
  if [ ! -f "$GIF" ]; then
    curl -fsSL --max-time 10 -o "$GIF" "$URL_BASE/$ID.gif" || exit 1
  fi
  python3 "$HOME/.claude/sprite-render.py" "$GIF" "$WIDTH" "$DIR/frame" "$MODE" "$MAX_H" >/dev/null || exit 1
fi

ln -sfn "$DIR" "$CURRENT"
