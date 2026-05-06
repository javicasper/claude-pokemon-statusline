#!/usr/bin/env bash
# Pick a Pokemon (by minute, or fixed via $2), fetch+render frames, point
# ~/.claude/sprites-pokemon/current at the chosen folder.
# Usage: pokemon-rotate.sh [width] [fixed_id]
set -euo pipefail

WIDTH="${1:-30}"
FIXED_ID="${2:-}"
MODE="${3:-halfblock}"  # halfblock=1×2, quadrant=2×2, sextant=2×3 px per cell
TOTAL=649  # PokeAPI BW animated covers Gen 1-5 (IDs 1..649)
SPRITES_DIR="$HOME/.claude/sprites-pokemon"
CACHE="$SPRITES_DIR/cache"
CURRENT="$SPRITES_DIR/current"
URL_BASE="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated"
INSTALL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

mkdir -p "$CACHE"

if [ -n "$FIXED_ID" ]; then
  ID="$FIXED_ID"
else
  ID=$(( ($(date +%s) / 60) % TOTAL + 1 ))
fi

DIR="$CACHE/$ID"

if [ ! -f "$DIR/frame-0.ansi" ]; then
  mkdir -p "$DIR"
  GIF="$DIR/sprite.gif"
  if [ ! -f "$GIF" ]; then
    curl -fsSL --max-time 10 -o "$GIF" "$URL_BASE/$ID.gif" || exit 1
  fi
  python3 "$INSTALL_DIR/sprite-render.py" "$GIF" "$WIDTH" "$DIR/frame" "$MODE" >/dev/null || exit 1
fi

if [ -z "$FIXED_ID" ]; then
  ln -sfn "$DIR" "$CURRENT"
fi
