#!/bin/bash
# Claude Code StatusLine - Converted from PowerShell to Bash
# Line 1: Model | tokens used/total | % used <full> | % remain <full> | thinking
# Line 2: Current (5h): <progressbar> | Weekly (7d): <progressbar> | Extra usage
# Line 3: Reset times

export LC_NUMERIC=C

input=$(cat)

if [ -z "$input" ]; then
  echo "Claude"
  exit 0
fi

# ANSI colors (matching oh-my-posh theme)
BLUE=$'\033[38;2;0;153;255m'
ORANGE=$'\033[38;2;255;176;85m'
GREEN=$'\033[38;2;0;160;0m'
CYAN=$'\033[38;2;46;149;153m'
RED=$'\033[38;2;255;85;85m'
YELLOW=$'\033[38;2;230;200;0m'
WHITE=$'\033[38;2;220;220;220m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# Format token counts (e.g., 50k / 200k)
format_tokens() {
  local num=$1
  if [ "$num" -ge 1000000 ]; then
    awk "BEGIN { printf \"%.1fm\", $num/1000000 }"
  elif [ "$num" -ge 1000 ]; then
    awk "BEGIN { printf \"%.0fk\", $num/1000 }"
  else
    echo "$num"
  fi
}

# Format number with commas (e.g., 123,456)
format_commas() {
  printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# Build a colored progress bar
build_bar() {
  local pct=$1
  local width=$2
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100

  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))

  # Color based on usage level
  local bar_color
  if [ "$pct" -ge 90 ]; then
    bar_color="$RED"
  elif [ "$pct" -ge 70 ]; then
    bar_color="$YELLOW"
  elif [ "$pct" -ge 50 ]; then
    bar_color="$ORANGE"
  else
    bar_color="$GREEN"
  fi

  local filled_str="" empty_str=""
  for ((i=0; i<filled; i++)); do filled_str+="●"; done
  for ((i=0; i<empty; i++)); do empty_str+="○"; done

  echo -n "${bar_color}${filled_str}${DIM}${empty_str}${RESET}"
}

# Extract values from JSON
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

current=$(( input_tokens + cache_create + cache_read ))
[ "$size" -eq 0 ] && size=200000

used_tokens=$(format_tokens "$current")
total_tokens=$(format_tokens "$size")

pct_used=$(( current * 100 / size ))
pct_remain=$(( 100 - pct_used ))

used_comma=$(format_commas "$current")
remain_comma=$(format_commas "$(( size - current ))")

# Check thinking status
thinking_on=false
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
  thinking_val=$(jq -r '.alwaysThinkingEnabled // false' "$settings_file" 2>/dev/null)
  [ "$thinking_val" = "true" ] && thinking_on=true
fi

# ===== LINE 1: Model | tokens | % used | % remain | thinking =====
line1="${BLUE}${model_name}${RESET}"
line1+=" ${DIM}|${RESET} "
line1+="${ORANGE}${used_tokens} / ${total_tokens}${RESET}"
line1+=" ${DIM}|${RESET} "
line1+="${GREEN}${pct_used}% used ${ORANGE}${used_comma}${RESET}"
line1+=" ${DIM}|${RESET} "
line1+="${CYAN}${pct_remain}% remain ${BLUE}${remain_comma}${RESET}"
line1+=" ${DIM}|${RESET} "
if $thinking_on; then
  line1+="thinking: ${ORANGE}On${RESET}"
else
  line1+="thinking: ${DIM}Off${RESET}"
fi

# ===== LINE 2 & 3: Usage limits with progress bars (cached) =====
CACHE_FILE="/tmp/claude-statusline-usage-cache.json"
CACHE_MAX_AGE=60

needs_refresh=true
usage_data=""

# Check cache
if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$cache_age" -lt "$CACHE_MAX_AGE" ]; then
    needs_refresh=false
    usage_data=$(cat "$CACHE_FILE")
  fi
fi

# Fetch fresh data if cache is stale
if $needs_refresh; then
  creds_file="$HOME/.claude/.credentials.json"
  if [ -f "$creds_file" ]; then
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
    if [ -n "$token" ]; then
      response=$(curl -sf --max-time 5 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/2.1.34" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
      if [ -n "$response" ]; then
        echo "$response" > "$CACHE_FILE"
        usage_data="$response"
      elif [ -f "$CACHE_FILE" ]; then
        usage_data=$(cat "$CACHE_FILE")
      fi
    fi
  fi
fi

# Format ISO reset time to local time
format_reset_time() {
  local iso_string="$1"
  local style="$2"
  [ -z "$iso_string" ] && return
  if [ "$style" = "time" ]; then
    date -d "$iso_string" "+%-I:%M%P" 2>/dev/null || echo ""
  elif [ "$style" = "datetime" ]; then
    date -d "$iso_string" "+%b %-d, %-I:%M%P" 2>/dev/null || echo ""
  else
    date -d "$iso_string" "+%b %-d" 2>/dev/null || echo ""
  fi
}

line2=""
line3=""
SEP=" ${DIM}|${RESET} "

if [ -n "$usage_data" ]; then
  BAR_WIDTH=10

  # ---- 5-hour (current) ----
  five_hour_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
  five_hour_reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
  five_hour_reset=$(format_reset_time "$five_hour_reset_iso" "time")

  five_hour_bar=$(build_bar "$five_hour_pct" "$BAR_WIDTH")
  col1_bar="${WHITE}current:${RESET} ${five_hour_bar} ${CYAN}${five_hour_pct}%${RESET}"
  col1_reset="${WHITE}resets ${five_hour_reset}${RESET}"

  # ---- 7-day (weekly) ----
  seven_day_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
  seven_day_reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
  seven_day_reset=$(format_reset_time "$seven_day_reset_iso" "datetime")

  seven_day_bar=$(build_bar "$seven_day_pct" "$BAR_WIDTH")
  col2_bar="${WHITE}weekly:${RESET} ${seven_day_bar} ${CYAN}${seven_day_pct}%${RESET}"
  col2_reset="${WHITE}resets ${seven_day_reset}${RESET}"

  # Assemble line 2: bars row
  line2="${col1_bar}${SEP}${col2_bar}"

  # Assemble line 3: resets row
  line3="${col1_reset}${SEP}${col2_reset}"

  # ---- Extra usage (if enabled) ----
  extra_enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // false')
  if [ "$extra_enabled" = "true" ]; then
    extra_pct=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f", $1}')
    extra_used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
    extra_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.2f", $1/100}')
    extra_bar=$(build_bar "$extra_pct" "$BAR_WIDTH")
    extra_reset=$(date -d "$(date +%Y-%m-01) +1 month" "+%b %-d" 2>/dev/null || echo "")

    line2+="${SEP}${WHITE}extra:${RESET} ${extra_bar} ${CYAN}\$${extra_used}/\$${extra_limit}${RESET}"
    line3+="${SEP}${WHITE}resets ${extra_reset}${RESET}"
  fi
fi

# Output all lines (with optional pokemon sprite glued to the right).
# Sprite source preference:
#   1. ~/.claude/sprites/current/frame-N.ansi  (rotating Pokemon — pokemon-rotate.sh)
#   2. ~/.claude/sprite-frame-N.ansi           (legacy fixed-pokemon animated)
#   3. ~/.claude/sprite.ansi                   (legacy static)

NOW=$(date +%s)

# Trigger Pokemon rotation when the time bucket changes (background, never blocks).
# Shuffle mode rotates faster: 10 s buckets (or whatever's in .pokemon-shuffle).
ROTATE="$HOME/.claude/pokemon-rotate.sh"
SHUFFLE_FILE="$HOME/.claude/.pokemon-shuffle"
if [ -x "$ROTATE" ]; then
  if [ -f "$SHUFFLE_FILE" ]; then
    INTERVAL=$(tr -dc 0-9 < "$SHUFFLE_FILE" 2>/dev/null)
    case "$INTERVAL" in ''|0) INTERVAL=10 ;; esac
    BUCKET=$(( NOW / INTERVAL ))
  else
    BUCKET=$(( NOW / 60 ))
  fi
  LAST_FILE="$HOME/.claude/.last-rotate-minute"
  LAST=$(cat "$LAST_FILE" 2>/dev/null || echo "")
  if [ "$BUCKET" != "$LAST" ]; then
    echo "$BUCKET" > "$LAST_FILE"
    ( bash "$ROTATE" </dev/null >/dev/null 2>&1 & ) >/dev/null 2>&1
  fi
fi

# 1 fps: new frame every 1000 ms. Synced with statusLine.refreshInterval=1
# so each repaint advances exactly one consecutive frame instead of jumping
# half a cycle (which produced a "stop-motion" effect when the terminal was idle).
NOW_MS=$(date +%s%3N)
TICK=$(( NOW_MS / 1000 ))

SPRITE=""
ROT_DIR="$HOME/.claude/sprites/current"
if [ -d "$ROT_DIR" ]; then
  NFRAMES=$(ls "$ROT_DIR"/frame-*.ansi 2>/dev/null | wc -l)
  if [ "$NFRAMES" -gt 0 ]; then
    IDX=$(( TICK % NFRAMES ))
    SPRITE="$ROT_DIR/frame-$IDX.ansi"
  fi
fi
if [ -z "$SPRITE" ]; then
  NFRAMES=$(ls "$HOME/.claude"/sprite-frame-*.ansi 2>/dev/null | wc -l)
  if [ "$NFRAMES" -gt 0 ]; then
    IDX=$(( TICK % NFRAMES ))
    SPRITE="$HOME/.claude/sprite-frame-$IDX.ansi"
  else
    SPRITE="$HOME/.claude/sprite.ansi"
  fi
fi
PASTER="$HOME/.claude/sprite-paste.py"

# Build the "#025 Pikachu" label that goes under the sprite, colored by the
# Pokemon's primary type. Resolve the sprite path through symlinks.
POKEMON_LABEL=""
NAMES_FILE="$HOME/.claude/pokemon-names.txt"
TYPES_FILE="$HOME/.claude/pokemon-types.txt"
if [ -n "$SPRITE" ] && [ -f "$NAMES_FILE" ]; then
  REAL_SPRITE=$(readlink -f "$SPRITE" 2>/dev/null || echo "$SPRITE")
  PKMN_ID=$(basename "$(dirname "$REAL_SPRITE")")
  if [[ "$PKMN_ID" =~ ^[0-9]+$ ]]; then
    PKMN_NAME=$(sed -n "${PKMN_ID}p" "$NAMES_FILE" 2>/dev/null)
    PKMN_TYPE=""
    [ -f "$TYPES_FILE" ] && PKMN_TYPE=$(sed -n "${PKMN_ID}p" "$TYPES_FILE" 2>/dev/null)
    # type → RGB (Bulbapedia canonical type colors).
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
      POKEMON_LABEL="${DIM}#$(printf '%03d' "$PKMN_ID") ${RESET}\033[38;2;${TC}m${PKMN_CAP}${RESET}"
      # printf %b expands the \033 escape; export the result.
      POKEMON_LABEL=$(printf '%b' "$POKEMON_LABEL")
      export POKEMON_LABEL
    fi
  fi
fi

# Detect actual terminal width — try multiple sources, conservative fallback.
COLS=""
[ -n "$COLUMNS" ] && COLS="$COLUMNS"
[ -z "$COLS" ] && COLS=$(stty size 2>/dev/null </dev/tty | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
case "$COLS" in
  ''|*[!0-9]*) COLS=100 ;;
  *) [ "$COLS" -lt 40 ] && COLS=100 ;;
esac

# Sprite alignment mode: "left" | "edge" (right edge w/ calibration) | "compact"
SPRITE_MODE="left"
COLS_CONF="$HOME/.claude/sprite-cols.conf"
if [ "$SPRITE_MODE" != "left" ] && [ -f "$COLS_CONF" ]; then
  CONF_COLS=$(tr -dc 0-9 < "$COLS_CONF" 2>/dev/null)
  if [ -n "$CONF_COLS" ] && [ "$CONF_COLS" -ge 40 ]; then
    COLS="$CONF_COLS"
    SPRITE_MODE="edge"
  fi
fi


output="$line1"
[ -n "$line2" ] && output+=$'\n'"$line2"
[ -n "$line3" ] && output+=$'\n'"$line3"

if [ -f "$SPRITE" ] && [ -f "$PASTER" ] && command -v python3 >/dev/null 2>&1; then
  printf "%s" "$output" | python3 "$PASTER" "$SPRITE" "$COLS" "$SPRITE_MODE"
else
  printf "%s" "$output"
fi
