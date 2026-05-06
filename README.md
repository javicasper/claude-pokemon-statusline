# claude-pokemon-statusline

Pokémon animados en el statusline de Claude Code, sin tocar tu statusline actual.

Funciona con **cualquier statusline** que tengas configurado: el instalador renombra tu `statusLine.command` actual a `command_wrapped` y mete un wrapper que (1) lo ejecuta tal cual con el mismo input JSON, (2) coge la salida y le pega un sprite ANSI animado al lado.

Si no tenías statusline configurado, el wrapper imprime el nombre del modelo (el aspecto por defecto de Claude Code) y le pega el sprite.

## Cómo funciona

- **Sprites**: GIFs animados black-white de [PokeAPI/sprites](https://github.com/PokeAPI/sprites), generaciones 1-5 (649 Pokémon). Se descargan bajo demanda a `~/.claude/sprites-pokemon/cache/<id>/`.
- **Render**: cada frame del GIF → arte ANSI con caracteres `▀` (half-block, foreground = pixel superior, background = pixel inferior, truecolor RGB).
- **Animación**: el wrapper elige el frame actual con `now_ms / 250` (4 fps). Como Claude Code repinta el statusline en cada keystroke, la animación avanza sola sin proceso de fondo.
- **Rotación**: en modo `rotate`, el Pokémon cambia cada minuto (`epoch_min % 649 + 1`, ciclo completo en ~11 horas). En modo `fixed`, siempre el mismo.

## Instalación

Requisitos: `python3` con [Pillow](https://pillow.readthedocs.io/), `jq`, `curl`.

```bash
git clone https://github.com/<usuario>/claude-pokemon-statusline.git
cd claude-pokemon-statusline
bash install.sh
```

El instalador es interactivo y pregunta:
1. **Posición**: izquierda / derecha / compact
2. **Selección**: rotar los 649 (Gen 1-5) / fijo (eliges ID)
3. **Ancho** del sprite (default 22)

### Modo no interactivo

```bash
bash install.sh --position=left --selection=rotate --width=22 --yes
bash install.sh --position=right --selection=fixed --pokemon=25 --width=24 --yes
```

## Desinstalación

```bash
bash uninstall.sh
```

Restaura tu `statusLine.command` original (el que tenías antes de instalar) y opcionalmente borra `~/.claude/pokemon-statusline/` y la caché de sprites.

## Estructura

```
.
├── install.sh              # interactivo, también acepta flags
├── uninstall.sh
└── lib/
    ├── statusline-wrap.sh  # ejecuta el statusline original y pega el sprite
    ├── pokemon-rotate.sh   # descarga + renderiza el sprite del minuto
    ├── sprite-render.py    # GIF → ANSI half-block
    └── sprite-paste.py     # pega el sprite al statusline (left/right/compact)
```

## Configuración después de instalar

El instalador escribe esto en `~/.claude/settings.json`:

```jsonc
{
  "statusLine": {
    "type": "command",
    "command": "/home/<user>/.claude/pokemon-statusline/statusline-wrap.sh",
    "command_wrapped": "<tu comando original aquí>"
  },
  "pokemonStatusline": {
    "position": "left",       // "left" | "right" | "compact"
    "selection": "rotate",    // "rotate" | "fixed"
    "pokemon": "",            // ID 1-649 si selection=fixed
    "width": 22
  }
}
```

Puedes editar `pokemonStatusline` a mano y aplicará al instante (no hace falta reinstalar).

## Compatibilidad

- Linux y macOS (bash + coreutils + python3 + jq + curl).
- Terminales con soporte de truecolor y caracteres unicode half-block (`▀`/`▄`). Casi todos los modernos.
- El padding usa `⠀` (Braille Blank, U+2800) porque sobrevive al `.trim()` que aplica Claude Code antes de imprimir.

## Para agentes de Claude Code

Si quieres que un agente de Claude Code instale esto en el equipo de otra persona, mírale a `AGENT_INSTRUCTIONS.txt`.

## Créditos

- Sprites: [PokeAPI/sprites](https://github.com/PokeAPI/sprites) (animaciones black-white de Gen 5).
