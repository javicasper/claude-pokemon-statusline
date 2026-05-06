#!/usr/bin/env bash
# Restore the original statusLine.command and remove pokemonStatusline config.
# Optionally deletes the install dir and sprite cache.
set -euo pipefail

B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'

SETTINGS="$HOME/.claude/settings.json"
INSTALL_DIR="$HOME/.claude/pokemon-statusline"
SPRITES_DIR="$HOME/.claude/sprites-pokemon"

if ! command -v jq >/dev/null 2>&1; then
  echo "Necesito jq para editar settings.json"; exit 1
fi

if [ ! -f "$SETTINGS" ]; then
  echo "${Y}No existe $SETTINGS — nada que desinstalar.${N}"
else
  WRAPPED=$(jq -r '.statusLine.command_wrapped // empty' "$SETTINGS")
  TMP=$(mktemp)
  if [ -n "$WRAPPED" ]; then
    jq --arg orig "$WRAPPED" \
      '.statusLine.command = $orig
       | del(.statusLine.command_wrapped)
       | del(.pokemonStatusline)' \
      "$SETTINGS" > "$TMP"
    echo "${G}✓${N} Statusline original restaurado"
  else
    # We added the statusline ourselves, or there's nothing wrapped.
    CMD=$(jq -r '.statusLine.command // empty' "$SETTINGS")
    if [[ "$CMD" == "$INSTALL_DIR/"* ]]; then
      jq 'del(.statusLine) | del(.pokemonStatusline)' "$SETTINGS" > "$TMP"
      echo "${G}✓${N} Eliminado statusline (no había uno previo)"
    else
      jq 'del(.pokemonStatusline)' "$SETTINGS" > "$TMP"
      echo "${Y}!${N} El statusline actual no es nuestro — solo elimino .pokemonStatusline"
    fi
  fi
  mv "$TMP" "$SETTINGS"
fi

read -rp "¿Borrar también $INSTALL_DIR y la caché de sprites $SPRITES_DIR? [y/N]: " del
case "${del:-n}" in
  [yY]*)
    rm -rf "$INSTALL_DIR" "$SPRITES_DIR"
    rm -f "$HOME/.claude/.pokemon-last-rotate"
    echo "${G}✓${N} Borrados."
    ;;
  *) echo "(Conservados — bórralos a mano si quieres)" ;;
esac

echo
echo "${G}${B}✓ Desinstalado.${N} Reinicia Claude Code para ver el cambio."
