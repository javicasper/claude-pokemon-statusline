#!/usr/bin/env bash
# Manage the pinned Pokemon for the statusline animation.
#
#   ~/.claude/pokemon-set.sh                 # show current state
#   ~/.claude/pokemon-set.sh rotate          # rotate every minute (default)
#   ~/.claude/pokemon-set.sh pikachu         # pin to Pikachu (by name)
#   ~/.claude/pokemon-set.sh 25              # pin to ID 25
#   ~/.claude/pokemon-set.sh next            # advance to the next one
#   ~/.claude/pokemon-set.sh prev            # go back to the previous one
#   ~/.claude/pokemon-set.sh random          # pin to a random one
#   ~/.claude/pokemon-set.sh shuffle [secs]  # rotate randomly every N seconds (default 10)
#   ~/.claude/pokemon-set.sh list            # list all 649 names
#   ~/.claude/pokemon-set.sh list | grep -i char   # search by substring
#
# Coverage: Gen 1-5 (1..649). PokeAPI BW animated does not include Gen 6+.
set -euo pipefail

FIXED_FILE="$HOME/.claude/.pokemon-fixed"
SHUFFLE_FILE="$HOME/.claude/.pokemon-shuffle"
ROTATE="$HOME/.claude/pokemon-rotate.sh"
LAST_ROTATE_MIN="$HOME/.claude/.last-rotate-minute"
TOTAL=649

# Names indexed by id (1..649). Lowercase, hyphenated where the canonical
# name has punctuation (nidoran-f, mr-mime, ...).
NAMES=("" \
  bulbasaur ivysaur venusaur charmander charmeleon charizard squirtle wartortle \
  blastoise caterpie metapod butterfree weedle kakuna beedrill pidgey \
  pidgeotto pidgeot rattata raticate spearow fearow ekans arbok \
  pikachu raichu sandshrew sandslash nidoran-f nidorina nidoqueen nidoran-m \
  nidorino nidoking clefairy clefable vulpix ninetales jigglypuff wigglytuff \
  zubat golbat oddish gloom vileplume paras parasect venonat \
  venomoth diglett dugtrio meowth persian psyduck golduck mankey \
  primeape growlithe arcanine poliwag poliwhirl poliwrath abra kadabra \
  alakazam machop machoke machamp bellsprout weepinbell victreebel tentacool \
  tentacruel geodude graveler golem ponyta rapidash slowpoke slowbro \
  magnemite magneton farfetchd doduo dodrio seel dewgong grimer \
  muk shellder cloyster gastly haunter gengar onix drowzee \
  hypno krabby kingler voltorb electrode exeggcute exeggutor cubone \
  marowak hitmonlee hitmonchan lickitung koffing weezing rhyhorn rhydon \
  chansey tangela kangaskhan horsea seadra goldeen seaking staryu \
  starmie mr-mime scyther jynx electabuzz magmar pinsir tauros \
  magikarp gyarados lapras ditto eevee vaporeon jolteon flareon \
  porygon omanyte omastar kabuto kabutops aerodactyl snorlax articuno \
  zapdos moltres dratini dragonair dragonite mewtwo mew chikorita \
  bayleef meganium cyndaquil quilava typhlosion totodile croconaw feraligatr \
  sentret furret hoothoot noctowl ledyba ledian spinarak ariados \
  crobat chinchou lanturn pichu cleffa igglybuff togepi togetic \
  natu xatu mareep flaaffy ampharos bellossom marill azumarill \
  sudowoodo politoed hoppip skiploom jumpluff aipom sunkern sunflora \
  yanma wooper quagsire espeon umbreon murkrow slowking misdreavus \
  unown wobbuffet girafarig pineco forretress dunsparce gligar steelix \
  snubbull granbull qwilfish scizor shuckle heracross sneasel teddiursa \
  ursaring slugma magcargo swinub piloswine corsola remoraid octillery \
  delibird mantine skarmory houndour houndoom kingdra phanpy donphan \
  porygon2 stantler smeargle tyrogue hitmontop smoochum elekid magby \
  miltank blissey raikou entei suicune larvitar pupitar tyranitar \
  lugia ho-oh celebi treecko grovyle sceptile torchic combusken \
  blaziken mudkip marshtomp swampert poochyena mightyena zigzagoon linoone \
  wurmple silcoon beautifly cascoon dustox lotad lombre ludicolo \
  seedot nuzleaf shiftry taillow swellow wingull pelipper ralts \
  kirlia gardevoir surskit masquerain shroomish breloom slakoth vigoroth \
  slaking nincada ninjask shedinja whismur loudred exploud makuhita \
  hariyama azurill nosepass skitty delcatty sableye mawile aron \
  lairon aggron meditite medicham electrike manectric plusle minun \
  volbeat illumise roselia gulpin swalot carvanha sharpedo wailmer \
  wailord numel camerupt torkoal spoink grumpig spinda trapinch \
  vibrava flygon cacnea cacturne swablu altaria zangoose seviper \
  lunatone solrock barboach whiscash corphish crawdaunt baltoy claydol \
  lileep cradily anorith armaldo feebas milotic castform kecleon \
  shuppet banette duskull dusclops tropius chimecho absol wynaut \
  snorunt glalie spheal sealeo walrein clamperl huntail gorebyss \
  relicanth luvdisc bagon shelgon salamence beldum metang metagross \
  regirock regice registeel latias latios kyogre groudon rayquaza \
  jirachi deoxys turtwig grotle torterra chimchar monferno infernape \
  piplup prinplup empoleon starly staravia staraptor bidoof bibarel \
  kricketot kricketune shinx luxio luxray budew roserade cranidos \
  rampardos shieldon bastiodon burmy wormadam mothim combee vespiquen \
  pachirisu buizel floatzel cherubi cherrim shellos gastrodon ambipom \
  drifloon drifblim buneary lopunny mismagius honchkrow glameow purugly \
  chingling stunky skuntank bronzor bronzong bonsly mime-jr happiny \
  chatot spiritomb gible gabite garchomp munchlax riolu lucario \
  hippopotas hippowdon skorupi drapion croagunk toxicroak carnivine finneon \
  lumineon mantyke snover abomasnow weavile magnezone lickilicky rhyperior \
  tangrowth electivire magmortar togekiss yanmega leafeon glaceon gliscor \
  mamoswine porygon-z gallade probopass dusknoir froslass rotom uxie \
  mesprit azelf dialga palkia heatran regigigas giratina cresselia \
  phione manaphy darkrai shaymin arceus victini snivy servine \
  serperior tepig pignite emboar oshawott dewott samurott patrat \
  watchog lillipup herdier stoutland purrloin liepard pansage simisage \
  pansear simisear panpour simipour munna musharna pidove tranquill \
  unfezant blitzle zebstrika roggenrola boldore gigalith woobat swoobat \
  drilbur excadrill audino timburr gurdurr conkeldurr tympole palpitoad \
  seismitoad throh sawk sewaddle swadloon leavanny venipede whirlipede \
  scolipede cottonee whimsicott petilil lilligant basculin sandile krokorok \
  krookodile darumaka darmanitan maractus dwebble crustle scraggy scrafty \
  sigilyph yamask cofagrigus tirtouga carracosta archen archeops trubbish \
  garbodor zorua zoroark minccino cinccino gothita gothorita gothitelle \
  solosis duosion reuniclus ducklett swanna vanillite vanillish vanilluxe \
  deerling sawsbuck emolga karrablast escavalier foongus amoonguss frillish \
  jellicent alomomola joltik galvantula ferroseed ferrothorn klink klang \
  klinklang tynamo eelektrik eelektross elgyem beheeyem litwick lampent \
  chandelure axew fraxure haxorus cubchoo beartic cryogonal shelmet \
  accelgor stunfisk mienfoo mienshao druddigon golett golurk pawniard \
  bisharp bouffalant rufflet braviary vullaby mandibuzz heatmor durant \
  deino zweilous hydreigon larvesta volcarona cobalion terrakion virizion \
  tornadus thundurus reshiram zekrom landorus kyurem keldeo meloetta \
  genesect
)

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

resolve_id() {
  local arg="$1"
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    if [ "$arg" -ge 1 ] && [ "$arg" -le "$TOTAL" ]; then
      echo "$arg"; return 0
    fi
    echo "ID fuera de rango (1-$TOTAL): $arg" >&2
    return 1
  fi
  local needle
  needle=$(echo "$arg" | tr '[:upper:]' '[:lower:]' | tr -d '_ ')
  for i in "${!NAMES[@]}"; do
    [ "$i" = 0 ] && continue
    local n="${NAMES[$i]}"
    local nclean
    nclean=$(echo "$n" | tr -d '-')
    if [ "$nclean" = "${needle//-/}" ] || [ "$n" = "$needle" ]; then
      echo "$i"; return 0
    fi
  done
  echo "Pokémon no encontrado: $arg (prueba './pokemon-set.sh list')" >&2
  return 1
}

cmd="${1:-status}"

case "$cmd" in
  -h|--help|help)
    usage; exit 0 ;;
  status|"")
    if [ -f "$FIXED_FILE" ]; then
      id=$(tr -dc 0-9 < "$FIXED_FILE" 2>/dev/null)
      if [ -n "$id" ] && [ "$id" -ge 1 ] && [ "$id" -le "$TOTAL" ]; then
        echo "Modo: fijo en #${id} ${NAMES[$id]}"
        exit 0
      fi
    fi
    cur_id=$(basename "$(readlink -f "$HOME/.claude/sprites/current" 2>/dev/null)" 2>/dev/null)
    if [ -f "$SHUFFLE_FILE" ]; then
      iv=$(tr -dc 0-9 < "$SHUFFLE_FILE" 2>/dev/null); [ -z "$iv" ] || [ "$iv" = "0" ] && iv=10
      echo "Modo: shuffle cada ${iv}s (actual: #${cur_id} ${NAMES[$cur_id]:-?})"
    else
      echo "Modo: rota cada minuto en orden (actual: #${cur_id} ${NAMES[$cur_id]:-?})"
    fi
    ;;
  rotate)
    rm -f "$FIXED_FILE" "$SHUFFLE_FILE" "$LAST_ROTATE_MIN"
    bash "$ROTATE"
    cur_id=$(basename "$(readlink -f "$HOME/.claude/sprites/current")")
    echo "✓ Rotando en orden. Actual: #${cur_id} ${NAMES[$cur_id]:-?}"
    ;;
  shuffle)
    interval="${2:-10}"
    case "$interval" in ''|*[!0-9]*) echo "Intervalo inválido: $interval" >&2; exit 1 ;; esac
    [ "$interval" -lt 1 ] && interval=1
    rm -f "$FIXED_FILE" "$LAST_ROTATE_MIN"
    echo "$interval" > "$SHUFFLE_FILE"
    bash "$ROTATE"
    cur_id=$(basename "$(readlink -f "$HOME/.claude/sprites/current")")
    echo "✓ Shuffle cada ${interval}s. Actual: #${cur_id} ${NAMES[$cur_id]:-?}"
    ;;
  list)
    for i in $(seq 1 "$TOTAL"); do
      printf "%4d  %s\n" "$i" "${NAMES[$i]}"
    done
    ;;
  random)
    id=$(( (RANDOM % TOTAL) + 1 ))
    echo "$id" > "$FIXED_FILE"
    rm -f "$LAST_ROTATE_MIN"
    bash "$ROTATE"
    echo "✓ Fijado en #${id} ${NAMES[$id]}"
    ;;
  next|prev)
    # Read current id (from fixed file if present, otherwise from the
    # symlink that the rotator last pointed to).
    cur=""
    if [ -f "$FIXED_FILE" ]; then
      cur=$(tr -dc 0-9 < "$FIXED_FILE" 2>/dev/null)
    fi
    if [ -z "$cur" ]; then
      cur=$(basename "$(readlink -f "$HOME/.claude/sprites/current" 2>/dev/null)" 2>/dev/null)
    fi
    case "$cur" in ''|*[!0-9]*) cur=1 ;; esac
    if [ "$cmd" = "next" ]; then
      id=$(( cur % TOTAL + 1 ))
    else
      id=$(( cur - 1 )); [ "$id" -lt 1 ] && id="$TOTAL"
    fi
    echo "$id" > "$FIXED_FILE"
    rm -f "$LAST_ROTATE_MIN"
    bash "$ROTATE"
    echo "✓ Fijado en #${id} ${NAMES[$id]}"
    ;;
  *)
    id=$(resolve_id "$cmd") || exit 1
    echo "$id" > "$FIXED_FILE"
    rm -f "$LAST_ROTATE_MIN"
    bash "$ROTATE"
    echo "✓ Fijado en #${id} ${NAMES[$id]}"
    ;;
esac
