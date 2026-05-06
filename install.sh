#!/usr/bin/env bash
# Pokemon Statusline installer.
#
# Interactive by default (asks position/selection/width).
# For non-interactive use (e.g., from a Claude Code agent):
#   ./install.sh --position=left --selection=rotate --width=22
#   ./install.sh --position=right --selection=fixed --pokemon=25 --width=24
# Flags:
#   --position=left|right|compact    sprite placement (default: left)
#   --selection=rotate|fixed         rotate Gen 1-5 every minute, or pick one
#   --pokemon=<id>                   1..649, only used with --selection=fixed
#   --width=<n>                      sprite width in chars (default: 22)
#   --yes                            skip confirmation prompt
set -euo pipefail

B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; D=$'\033[2m'; N=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
INSTALL_DIR="$HOME/.claude/pokemon-statusline"
SETTINGS="$HOME/.claude/settings.json"

# --- Parse flags ---
POSITION=""
SELECTION=""
FIXED_ID=""
WIDTH=""
SKIP_CONFIRM=false
INTERACTIVE=true

for arg in "$@"; do
  case "$arg" in
    --position=*) POSITION="${arg#*=}"; INTERACTIVE=false ;;
    --selection=*) SELECTION="${arg#*=}"; INTERACTIVE=false ;;
    --pokemon=*) FIXED_ID="${arg#*=}" ;;
    --width=*) WIDTH="${arg#*=}" ;;
    --yes|-y) SKIP_CONFIRM=true ;;
    -h|--help)
      awk 'NR==1 { next } /^#/ { sub(/^#[[:space:]]?/,""); print; next } { exit }' "$0"
      exit 0 ;;
    *) echo "${R}Unknown argument: $arg${N}"; exit 1 ;;
  esac
done

echo "${B}Pokemon Statusline para Claude Code${N}"
echo

# --- Dependency check ---
missing=()
command -v python3 >/dev/null 2>&1 || missing+=("python3")
command -v jq      >/dev/null 2>&1 || missing+=("jq")
command -v curl    >/dev/null 2>&1 || missing+=("curl")
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import PIL' 2>/dev/null || missing+=("python3-pillow (pip install --user pillow)")
fi
if [ "${#missing[@]}" -gt 0 ]; then
  echo "${R}Faltan dependencias:${N}"
  for m in "${missing[@]}"; do echo "  - $m"; done
  echo
  echo "Instálalas y vuelve a ejecutar."
  exit 1
fi

# --- Interactive prompts (only if flags not supplied) ---
if $INTERACTIVE; then
  if [ -z "$POSITION" ]; then
    echo "${B}1. Posición del Pokémon${N}"
    echo "  ${C}1${N}) izquierda  — sprite a la izquierda, statusline a su derecha"
    echo "  ${C}2${N}) derecha    — statusline a la izquierda, sprite alineado al borde derecho"
    echo "  ${C}3${N}) compact    — sprite justo a la derecha del statusline (sin alineación al borde)"
    read -rp "Elige [1]: " p
    case "${p:-1}" in
      2) POSITION="right" ;;
      3) POSITION="compact" ;;
      *) POSITION="left" ;;
    esac
    echo
  fi

  if [ -z "$SELECTION" ]; then
    echo "${B}2. Qué Pokémon mostrar${N}"
    echo "  ${C}1${N}) rotar — un Pokémon distinto cada minuto (Gen 1-5, 649 en total)"
    echo "  ${C}2${N}) fijo  — uno concreto (eliges el ID)"
    read -rp "Elige [1]: " s
    case "${s:-1}" in
      2)
        SELECTION="fixed"
        echo "  ${D}Algunos IDs:  1=Bulbasaur  4=Charmander  7=Squirtle  25=Pikachu  39=Jigglypuff  133=Eevee  150=Mewtwo${N}"
        read -rp "ID del Pokémon (1-649) [25]: " FIXED_ID
        FIXED_ID="${FIXED_ID:-25}"
        ;;
      *) SELECTION="rotate" ;;
    esac
    echo
  fi

  if [ -z "$WIDTH" ]; then
    echo "${B}3. Tamaño del sprite${N} ${D}(en columnas; 18 = compacto, 22 = recomendado, 26 = grande)${N}"
    read -rp "Ancho [22]: " WIDTH
    WIDTH="${WIDTH:-22}"
    echo
  fi
fi

# --- Validate / fill defaults ---
POSITION="${POSITION:-left}"
SELECTION="${SELECTION:-rotate}"
WIDTH="${WIDTH:-22}"
case "$POSITION" in
  left|right|compact) ;;
  *) echo "${R}position inválida: $POSITION${N}"; exit 1 ;;
esac
case "$SELECTION" in
  rotate) FIXED_ID="" ;;
  fixed)
    FIXED_ID="${FIXED_ID:-25}"
    case "$FIXED_ID" in
      ''|*[!0-9]*) echo "${R}pokemon ID inválido: $FIXED_ID${N}"; exit 1 ;;
    esac
    if [ "$FIXED_ID" -lt 1 ] || [ "$FIXED_ID" -gt 649 ]; then
      echo "${R}pokemon ID fuera de rango (1-649): $FIXED_ID${N}"; exit 1
    fi
    ;;
  *) echo "${R}selection inválida: $SELECTION${N}"; exit 1 ;;
esac
case "$WIDTH" in
  ''|*[!0-9]*) echo "${R}width inválido: $WIDTH${N}"; exit 1 ;;
esac
if [ "$WIDTH" -lt 8 ] || [ "$WIDTH" -gt 40 ]; then
  echo "${R}width fuera de rango razonable (8-40): $WIDTH${N}"; exit 1
fi

# --- Summary + confirm ---
echo "${B}Resumen:${N}"
echo "  Posición:   $POSITION"
echo "  Selección:  $SELECTION${FIXED_ID:+ (#$FIXED_ID)}"
echo "  Ancho:      $WIDTH"
echo "  Instala en: $INSTALL_DIR"
echo "  Settings:   $SETTINGS"
echo

if ! $SKIP_CONFIRM; then
  read -rp "¿Proceder? [Y/n]: " confirm
  case "${confirm:-y}" in
    [nN]*) echo "Cancelado."; exit 0 ;;
  esac
fi

# --- Copy files ---
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/lib/sprite-render.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/lib/sprite-paste.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/lib/pokemon-rotate.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/lib/statusline-wrap.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/"*.sh "$INSTALL_DIR/"*.py
echo "${G}✓${N} Archivos copiados a $INSTALL_DIR"

# --- Backup + patch settings.json ---
mkdir -p "$(dirname "$SETTINGS")"
if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.pre-pokemon.$(date +%Y%m%d-%H%M%S).bak"
  cp "$SETTINGS" "$BACKUP"
  echo "${G}✓${N} Backup en $BACKUP"
else
  echo '{}' > "$SETTINGS"
fi

CURRENT_CMD=$(jq -r '.statusLine.command // empty' "$SETTINGS")
ALREADY_WRAPPED=$(jq -r '.statusLine.command_wrapped // empty' "$SETTINGS")
WRAP_CMD="$INSTALL_DIR/statusline-wrap.sh"

TMP=$(mktemp)
if [ -n "$ALREADY_WRAPPED" ]; then
  # Already wrapped — just update the pokemon config.
  jq \
    --arg pos "$POSITION" \
    --arg sel "$SELECTION" \
    --arg fix "$FIXED_ID" \
    --argjson w "$WIDTH" \
    '.pokemonStatusline = {position:$pos, selection:$sel, pokemon:$fix, width:$w}' \
    "$SETTINGS" > "$TMP"
  echo "${Y}!${N} Ya estaba wrapeado: solo actualizo configuración."
elif [ -n "$CURRENT_CMD" ] && [ "$CURRENT_CMD" != "$WRAP_CMD" ]; then
  jq \
    --arg wrap "$WRAP_CMD" \
    --arg orig "$CURRENT_CMD" \
    --arg pos "$POSITION" \
    --arg sel "$SELECTION" \
    --arg fix "$FIXED_ID" \
    --argjson w "$WIDTH" \
    '.statusLine.command_wrapped = $orig
     | .statusLine.command = $wrap
     | .statusLine.type = (.statusLine.type // "command")
     | .pokemonStatusline = {position:$pos, selection:$sel, pokemon:$fix, width:$w}' \
    "$SETTINGS" > "$TMP"
  echo "${G}✓${N} Wrapeado statusline existente (preservado en command_wrapped)"
else
  jq \
    --arg wrap "$WRAP_CMD" \
    --arg pos "$POSITION" \
    --arg sel "$SELECTION" \
    --arg fix "$FIXED_ID" \
    --argjson w "$WIDTH" \
    '.statusLine = {type:"command", command:$wrap}
     | .pokemonStatusline = {position:$pos, selection:$sel, pokemon:$fix, width:$w}' \
    "$SETTINGS" > "$TMP"
  echo "${G}✓${N} Statusline configurado (no había uno previo)"
fi
mv "$TMP" "$SETTINGS"

# --- Pre-warm sprite ---
echo "${G}✓${N} Descargando sprite inicial..."
if [ "$SELECTION" = "fixed" ]; then
  bash "$INSTALL_DIR/pokemon-rotate.sh" "$WIDTH" "$FIXED_ID" \
    || echo "${Y}!${N} Falló la descarga (se reintentará en runtime)"
else
  bash "$INSTALL_DIR/pokemon-rotate.sh" "$WIDTH" \
    || echo "${Y}!${N} Falló la descarga (se reintentará en runtime)"
fi

echo
echo "${G}${B}✓ Instalado.${N}"
echo "  Abre Claude Code (o reinicia la sesión actual) para verlo."
echo "  Desinstalar: ${C}bash $SCRIPT_DIR/uninstall.sh${N}"
