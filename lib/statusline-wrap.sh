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
WIDTH=20
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  WRAPPED=$(jq -r '.statusLine.command_wrapped // empty' "$SETTINGS" 2>/dev/null)
  POSITION=$(jq -r '.pokemonStatusline.position // "left"' "$SETTINGS" 2>/dev/null)
  SELECTION=$(jq -r '.pokemonStatusline.selection // "rotate"' "$SETTINGS" 2>/dev/null)
  FIXED_ID=$(jq -r '.pokemonStatusline.pokemon // empty' "$SETTINGS" 2>/dev/null)
  W=$(jq -r '.pokemonStatusline.width // 22' "$SETTINGS" 2>/dev/null)
  case "$W" in ''|*[!0-9]*) WIDTH=20 ;; *) WIDTH="$W" ;; esac
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

# --- Build "#025 Pikachu" label below the sprite, colored by primary type ---
POKEMON_LABEL=""
NAMES_FILE="$INSTALL_DIR/pokemon-names.txt"
TYPES_FILE="$INSTALL_DIR/pokemon-types.txt"
if [ -n "$SPRITE" ] && [ -f "$NAMES_FILE" ]; then
  REAL_SPRITE=$(readlink -f "$SPRITE" 2>/dev/null || echo "$SPRITE")
  PKMN_ID=$(basename "$(dirname "$REAL_SPRITE")")
  case "$PKMN_ID" in
    ''|*[!0-9]*) ;;
    *)
      PKMN_NAME=$(sed -n "${PKMN_ID}p" "$NAMES_FILE" 2>/dev/null)
      PKMN_TYPE=""
      [ -f "$TYPES_FILE" ] && PKMN_TYPE=$(sed -n "${PKMN_ID}p" "$TYPES_FILE" 2>/dev/null)
      case "$PKMN_TYPE" in
        normal)   TC="168;168;120" ;;
        fire)     TC="240;128;48"  ;;
        water)    TC="104;144;240" ;;
        electric) TC="248;208;48"  ;;
        grass)    TC="120;200;80"  ;;
        ice)      TC="152;216;216" ;;
        fighting) TC="192;48;40"   ;;
        poison)   TC="160;64;160"  ;;
        ground)   TC="224;192;104" ;;
        flying)   TC="168;144;240" ;;
        psychic)  TC="248;88;136"  ;;
        bug)      TC="168;184;32"  ;;
        rock)     TC="184;160;56"  ;;
        ghost)    TC="112;88;152"  ;;
        dragon)   TC="112;56;248"  ;;
        dark)     TC="112;88;72"   ;;
        steel)    TC="184;184;208" ;;
        fairy)    TC="238;153;172" ;;
        *)        TC="220;220;220" ;;
      esac
      if [ -n "$PKMN_NAME" ]; then
        PKMN_CAP="$(printf '%s' "${PKMN_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${PKMN_NAME:1}"
        POKEMON_LABEL=$(printf '\033[2m#%03d \033[0m\033[38;2;%sm%s\033[0m' \
          "$PKMN_ID" "$TC" "$PKMN_CAP")
        export POKEMON_LABEL
      fi
      ;;
  esac
fi

# --- Glue it together ---
PASTER="$INSTALL_DIR/sprite-paste.py"
if [ -n "$SPRITE" ] && [ -f "$SPRITE" ] && [ -f "$PASTER" ] && command -v python3 >/dev/null 2>&1; then
  printf "%s" "$status" | python3 "$PASTER" "$SPRITE" "$COLS" "$POSITION"
else
  printf "%s" "$status"
fi
