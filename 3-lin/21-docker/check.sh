#!/bin/bash
# 3/21 — ověření. Části odpovídají krokům zadání 1:1 — proto se začíná
# dvojkou: Krok 1 je jen prohlídka.
#
# Všechno běží na stanici, takže tu není `na_serveru` ani `LAB_KONTEJNER`.
# Kotvou nemůže být nic „schovaného" — žák je na svém stroji root přes
# sudo. Kotvy jsou proto ŽIVÉ HODNOTY: ID kontejneru, které vzniklo při
# jeho běhu, a odpověď služby přes zveřejněný port.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"

FORMULAR="$DOCKER_DIR/formular.txt"
JMENO="web-$ZAK2"
WEB="$DOCKER_DIR/web"

overi_docker || exit 1
if ! command -v curl >/dev/null 2>&1; then
  echo; echo "  Na stanici není curl. Řekněte o tom vyučujícímu."; echo; exit 1
fi
precti_kod_docker || {
  echo; echo "  Kód stránky se na stanici nenašel. Spusťte ./start.sh"; echo; exit 1; }

ID="$(kontejner_id "$JMENO")"

krok 2 "Kontejner běží"
if [ -n "$ID" ]; then
  uspech "kontejner $JMENO běží"
else
  # Rozlišit „neexistuje" od „existuje zastavený" — jinak žák hledá
  # chybu v příkazu, který proběhl správně, jen kontejner spadl.
  if docker ps -a --filter "name=^${JMENO}$" --format '{{.ID}}' 2>/dev/null | grep -q .; then
    chyba "kontejner $JMENO existuje, ale neběží"
    poznamka "docker logs $JMENO řekne, proč skončil"
  else
    chyba "kontejner $JMENO neexistuje"
  fi
fi
# Obraz musí být ten z cache, ne stažený z internetu.
if [ -n "$ID" ]; then
  # Porovnává se ID obrazu, ne jeho jméno. `docker.io/library/nginx:alpine`
  # je tentýž obraz a je to běžný zápis — vytknout ho by znamenalo obvinit
  # poctivého žáka z toho, že něco stáhl.
  OBRAZ_ID="$(docker inspect -f '{{.Image}}' "$ID" 2>/dev/null)"
  CHTENY_ID="$(docker image inspect -f '{{.Id}}' nginx:alpine 2>/dev/null)"
  if [ -n "$OBRAZ_ID" ] && [ "$OBRAZ_ID" = "$CHTENY_ID" ]; then
    uspech "kontejner běží z obrazu nginx:alpine"
  elif [ -z "$OBRAZ_ID" ]; then
    chyba "obraz kontejneru se nepodařilo zjistit"
  else
    chyba "kontejner neběží z obrazu nginx:alpine"
    poznamka "obrazy jsou v cache stanice — docker images ukáže, které tam jsou"
  fi
fi

krok 3 "Port a svazek"
if [ -z "$ID" ]; then
  chyba "bez běžícího kontejneru není co ověřovat"
else
  # Zveřejněný port se čte z Dockeru, ne z curlu — curl by uspěl i tehdy,
  # kdyby na tom portu poslouchalo něco jiného.
  MAPOVANI="$(docker port "$ID" 80/tcp 2>/dev/null | head -1)"
  case "$MAPOVANI" in
    *":$DOCKER_PORT") uspech "port 80 z kontejneru je zveřejněný na $DOCKER_PORT" ;;
    '')               chyba "port 80 z kontejneru není zveřejněný"
                      poznamka "publikuje se přepínačem -p pri spuštění, dodatečně to nejde" ;;
    *)                chyba "port 80 je zveřejněný jinam než na $DOCKER_PORT ($MAPOVANI)" ;;
  esac
  # Svazek: adresář ze stanice musí být připojený dovnitř. Ověřuje se
  # z konfigurace kontejneru, ne podle toho, že stránka odpovídá —
  # obsah by mohl být zapečený v obrazu.
  # Ptáme se na CÍL, ne jen na zdroj: `-v $WEB:/mnt:ro` by jinak prošlo
  # a spadlo by až na tom, že web nic nevrací.
  KAM="$(docker inspect -f \
    '{{range .Mounts}}{{if eq .Destination "/usr/share/nginx/html"}}{{.Source}}:{{.RW}}{{end}}{{end}}' \
    "$ID" 2>/dev/null)"
  case "$KAM" in
    "$WEB:false") uspech "adresář s podklady je připojený jen ke čtení" ;;
    "$WEB:true")  uspech "adresář s podklady je připojený do kontejneru"
                  chyba "je připojený i pro zápis"
                  poznamka "web podklady jen čte — přípona :ro to omezí" ;;
    '')           chyba "na /usr/share/nginx/html není připojený žádný adresář"
                  poznamka "připojuje se přepínačem -v, taky jen při spuštění" ;;
    *)            chyba "na /usr/share/nginx/html je připojený jiný adresář než $WEB" ;;
  esac
fi

krok 4 "Web odpovídá"
if ! krok_aktivni 4; then :
else
ODPOVED="$(curl -s -m 8 -w '\n%{http_code}' "http://localhost:$DOCKER_PORT/" 2>/dev/null)"
STAV_KOD="$(printf '%s' "$ODPOVED" | tail -n1)"
OBSAH="$(printf '%s' "$ODPOVED" | sed '$d')"
if [ "$STAV_KOD" = "200" ]; then
  uspech "na portu $DOCKER_PORT odpovídá web stavem 200"
else
  chyba "na portu $DOCKER_PORT web neodpovídá"
  poznamka "docker ps ukáže, jestli kontejner běží a co má zveřejněné"
fi
# Tohle je ten důkaz: kód se přes HTTP objeví jedině tehdy, když funguje
# port I svazek naráz. Zapečený obraz ho neobsahuje.
if printf '%s' "$OBSAH" | grep -qF "$DOCKER_KOD"; then
  uspech "stránka vrací obsah z připojeného adresáře"
else
  chyba "stránka nevrací obsah z připojeného adresáře"
  poznamka "dostáváte nejspíš výchozí stránku nginxu — zkontrolujte cestu ve svazku"
fi

fi

krok 5 "Formulář"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je připravený" \
  "chybí ~/netlab/docker/formular.txt — spusťte ./start.sh, doplní ho"
# ID vzniklo při spuštění kontejneru a nikde se nevypisuje. Model ho
# nevymyslí, soused má jiné a po `docker rm` se změní i tomu, kdo ho měl.
ODP_ID="$(_zaznam "$FORMULAR" id-kontejneru | tr -d ' ' | tr 'A-Z' 'a-z')"
if [ -z "$ID" ]; then
  chyba "kontejner neběží, takže se ID nedá porovnat"
elif [ -z "$ODP_ID" ]; then
  chyba "ve formuláři chybí ID kontejneru"
else
  # `docker ps` zkracuje na 12 znaků; uznáváme i plné ID.
  PLNE="$(docker inspect -f '{{.Id}}' "$ID" 2>/dev/null)"
  case "$PLNE" in
    "$ODP_ID"*) uspech "ID kontejneru ve formuláři sedí" ;;
    *)          chyba "ID kontejneru ve formuláři nesedí (máte '$ODP_ID')"
                poznamka "je ve sloupci CONTAINER ID výpisu docker ps" ;;
  esac
fi
ODP_PORT="$(_zaznam "$FORMULAR" port-uvnitr | grep -oE '[0-9]+' | tail -1)"
if [ "$ODP_PORT" = "80" ]; then
  uspech "port uvnitř kontejneru ve formuláři sedí"
elif [ "$ODP_PORT" = "$DOCKER_PORT" ]; then
  chyba "ve formuláři je port ze stanice, ne ten z kontejneru"
  poznamka "mapování se čte zleva doprava: -p <stanice>:<kontejner>"
else
  chyba "port uvnitř kontejneru ve formuláři nesedí (máte '${ODP_PORT:-nic}')"
fi

vypis_souhrn
