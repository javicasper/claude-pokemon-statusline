#!/usr/bin/env bash
# Wrapper statusline: runs the user's original statusLine.command (if any),
# captures its output, and pastes an animated Pokemon sprite onto it.
#
# Reads JSON from stdin (Claude Code's statusline contract).
# Settings live in ~/.claude/settings.json under:
#   .statusLine.command          = path to this script
#   .statusLine.command_wrapped  = the user's original command (may be empty)
#   .pokemonStatusline           = { position, selection, pokemon, width }

set -uo pipefail

INSTALL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"

input=$(cat)

# --- Read config (with defaults) ---
WRAPPED=""
POSITION="left"
SELECTION="rotate"
FIXED_ID=""
WIDTH=22
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  WRAPPED=$(jq -r '.statusLine.command_wrapped // empty' "$SETTINGS" 2>/dev/null)
  POSITION=$(jq -r '.pokemonStatusline.position // "left"' "$SETTINGS" 2>/dev/null)
  SELECTION=$(jq -r '.pokemonStatusline.selection // "rotate"' "$SETTINGS" 2>/dev/null)
  FIXED_ID=$(jq -r '.pokemonStatusline.pokemon // empty' "$SETTINGS" 2>/dev/null)
  W=$(jq -r '.pokemonStatusline.width // 22' "$SETTINGS" 2>/dev/null)
  case "$W" in ''|*[!0-9]*) WIDTH=22 ;; *) WIDTH="$W" ;; esac
fi

# --- Run the user's original statusline (if any) ---
if [ -n "$WRAPPED" ]; then
  status=$(printf '%s' "$input" | bash -c "$WRAPPED")
else
  # No prior statusline: emit the model name (Claude Code's default look).
  if command -v jq >/dev/null 2>&1; then
    status=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
  else
    status="Claude"
  fi
fi

# --- Trigger sprite rotation (rotate mode, once per minute) ---
ROTATE="$INSTALL_DIR/pokemon-rotate.sh"
NOW=$(date +%s)
if [ "$SELECTION" = "rotate" ] && [ -x "$ROTATE" ]; then
  MINUTE=$(( NOW / 60 ))
  LAST_FILE="$HOME/.claude/.pokemon-last-rotate"
  LAST=$(cat "$LAST_FILE" 2>/dev/null || echo "")
  if [ "$MINUTE" != "$LAST" ]; then
    echo "$MINUTE" > "$LAST_FILE"
    ( bash "$ROTATE" "$WIDTH" </dev/null >/dev/null 2>&1 & ) >/dev/null 2>&1
  fi
fi

# --- Resolve sprite directory ---
SPRITE_DIR=""
if [ "$SELECTION" = "fixed" ] && [ -n "$FIXED_ID" ]; then
  SPRITE_DIR="$HOME/.claude/sprites-pokemon/cache/$FIXED_ID"
  # Render on first use if missing.
  if [ ! -f "$SPRITE_DIR/frame-0.ansi" ] && [ -x "$ROTATE" ]; then
    bash "$ROTATE" "$WIDTH" "$FIXED_ID" >/dev/null 2>&1 || true
  fi
else
  SPRITE_DIR="$HOME/.claude/sprites-pokemon/current"
fi

# --- Pick frame (1 fps; sync with statusLine.refreshInterval=1 so every
# --- repaint advances exactly one frame instead of jumping half a cycle) ---
NOW_MS=$(date +%s%3N)
TICK=$(( NOW_MS / 1000 ))
SPRITE=""
if [ -d "$SPRITE_DIR" ]; then
  NFRAMES=$(ls "$SPRITE_DIR"/frame-*.ansi 2>/dev/null | wc -l)
  if [ "$NFRAMES" -gt 0 ]; then
    IDX=$(( TICK % NFRAMES ))
    SPRITE="$SPRITE_DIR/frame-$IDX.ansi"
  fi
fi

# --- Terminal width ---
COLS=""
[ -n "${COLUMNS:-}" ] && COLS="$COLUMNS"
[ -z "$COLS" ] && COLS=$(stty size 2>/dev/null </dev/tty | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
case "$COLS" in
  ''|*[!0-9]*) COLS=100 ;;
  *) [ "$COLS" -lt 40 ] && COLS=100 ;;
esac

# --- Glue it together ---
PASTER="$INSTALL_DIR/sprite-paste.py"
if [ -n "$SPRITE" ] && [ -f "$SPRITE" ] && [ -f "$PASTER" ] && command -v python3 >/dev/null 2>&1; then
  printf "%s" "$status" | python3 "$PASTER" "$SPRITE" "$COLS" "$POSITION"
else
  printf "%s" "$status"
fi
