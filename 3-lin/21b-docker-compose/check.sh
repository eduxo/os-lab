#!/bin/bash
# 3/21b — ověření. Části odpovídají krokům zadání 1:1 — proto se začíná
# dvojkou: Krok 1 je jen prohlídka.
#
# Compose značkuje kontejnery, které vytvoří. Ptáme se proto na značky,
# ne na jména — jméno kontejneru si Compose skládá sám a záleží na verzi,
# kdežto značky jsou součástí jeho rozhraní.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/docker-lib.sh"

COMPOSE_DIR="$DOCKER_DIR/compose"
FORMULAR="$COMPOSE_DIR/formular.txt"
WEB="$DOCKER_DIR/web"
PROJEKT="netlab-$ZAK2"

overi_docker || exit 1
for n in curl; do
  command -v "$n" >/dev/null 2>&1 || {
    echo; echo "  Na stanici není $n. Řekněte o tom vyučujícímu."; echo; exit 1; }
done
if ! docker compose version >/dev/null 2>&1; then
  echo; echo "  Na stanici není plugin 'docker compose'. Spusťte ./start.sh"; echo; exit 1
fi
precti_kod_docker || {
  echo; echo "  Kód stránky se na stanici nenašel. Spusťte ./start.sh"; echo; exit 1; }

# Kontejner dané služby v daném projektu → ID (prázdné, když neběží).
sluzba_id() {  # sluzba_id JMÉNO_SLUŽBY
  docker ps --filter "label=com.docker.compose.project=$PROJEKT" \
            --filter "label=com.docker.compose.service=$1" \
            --format '{{.ID}}' 2>/dev/null | head -1
}

ID_WEB="$(sluzba_id web)"
ID_ZAP="$(sluzba_id zapisovac)"

krok 2 "Compose soubor"
SOUBOR=""
for k in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
  [ -s "$COMPOSE_DIR/$k" ] && { SOUBOR="$COMPOSE_DIR/$k"; break; }
done
if [ -z "$SOUBOR" ]; then
  chyba "v $COMPOSE_DIR není compose soubor"
  poznamka "jmenuje se compose.yaml — Compose ho hledá sám, nemusíte ho zadávat"
else
  uspech "compose soubor je na svém místě"
  # `config` je pro Compose totéž co `configtest` pro Apache: přečte
  # soubor, dosadí výchozí hodnoty a řekne, jestli mu rozumí.
  if (cd "$COMPOSE_DIR" && docker compose config >/dev/null 2>&1); then
    uspech "compose soubor je syntakticky v pořádku"
    # `--services` vypíše jména SLUŽEB, jedno na řádek. Grep odsazeného
    # klíče by prošel i svazku nebo síti, které se jmenují stejně.
    SLUZBY="$(cd "$COMPOSE_DIR" && docker compose config --services 2>/dev/null)"
    printf '%s' "$SLUZBY" | grep -qx web \
      && uspech "je v něm služba web" || chyba "chybí v něm služba web"
    printf '%s' "$SLUZBY" | grep -qx zapisovac \
      && uspech "je v něm služba zapisovac" || chyba "chybí v něm služba zapisovac"
  else
    chyba "compose soubor má chybu"
    poznamka "docker compose config ji vypíše i s místem"
  fi
fi

krok 3 "Obě služby běží"
# Nejpravděpodobnější chyba labu je zapomenuté `name:` — Compose pak
# projekt pojmenuje podle adresáře a služby běží, jen je kontrola
# nenajde. Bez téhle větve by dostal žák „služba web neběží" a šel
# číst prázdný log služby, která je v pořádku.
JINY="$(cd "$COMPOSE_DIR" 2>/dev/null && docker compose ps --format '{{.Project}}' 2>/dev/null | head -1)"
if [ -z "$ID_WEB" ] && [ -z "$ID_ZAP" ] && [ -n "$JINY" ] && [ "$JINY" != "$PROJEKT" ]; then
  chyba "služby běží, ale v projektu '$JINY' místo $PROJEKT"
  poznamka "jméno projektu se nastavuje klíčem name: na začátku souboru"
else
[ -n "$ID_WEB" ] && uspech "služba web běží" || {
  chyba "služba web neběží"
  poznamka "docker compose ps ukáže stav, docker compose logs web důvod" ; }
[ -n "$ID_ZAP" ] && uspech "služba zapisovac běží" || {
  chyba "služba zapisovac neběží"
  poznamka "docker compose logs zapisovac řekne, proč skončila" ; }
# Jméno projektu je součást zadání — bez něj by si dva žáci na jedné
# stanici přepsali svazky navzájem.
fi

krok 4 "Web a sdílený svazek"
if ! krok_aktivni 4; then :
else
ODPOVED="$(curl -s -m 8 -w '\n%{http_code}' "http://localhost:$COMPOSE_PORT/" 2>/dev/null)"
STAV_KOD="$(printf '%s' "$ODPOVED" | tail -n1)"
OBSAH="$(printf '%s' "$ODPOVED" | sed '$d')"
if [ "$STAV_KOD" = "200" ] && printf '%s' "$OBSAH" | grep -qF "$DOCKER_KOD"; then
  uspech "web na portu $COMPOSE_PORT vrací obsah z připojeného adresáře"
else
  chyba "web na portu $COMPOSE_PORT nevrací obsah z připojeného adresáře"
  poznamka "zveřejněný port a připojený adresář — obojí patří do služby web"
fi
# Tohle je jádro: soubor vzniká v JEDNÉ službě a čte ho DRUHÁ. Bez
# sdíleného pojmenovaného svazku to nejde.
ODP_STAV="$(curl -s -m 8 -w '\n%{http_code}' \
  "http://localhost:$COMPOSE_PORT/data/stav.txt" 2>/dev/null)"
KOD_STAV="$(printf '%s' "$ODP_STAV" | tail -n1)"
STAV="$(printf '%s' "$ODP_STAV" | sed '$d')"
# Bez kontroly stavového kódu by prošla i chybová stránka nginxu:
# `curl -s` u 404 vrátí tělo, takže test na neprázdnost uspěje.
if [ "$KOD_STAV" != "200" ] || [ -z "$STAV" ]; then
  chyba "přes web není vidět soubor, do kterého píše zapisovac"
  poznamka "oba kontejnery musí sáhnout na TENTÝŽ pojmenovaný svazek"
else
  uspech "přes web je vidět soubor od druhé služby"
  # Čerstvost dokládá, že zapisovac opravdu běží teď, ne že soubor
  # zbyl z dřívějška.
  POSLEDNI="$(printf '%s' "$STAV" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z' | tail -1)"
  if [ -z "$POSLEDNI" ]; then
    chyba "v souboru nejsou časové značky v očekávaném tvaru"
    poznamka "zapisovac má psát čas ve tvaru 2027-02-04T08:15:00Z"
  else
    TEDKA="$(date -u +%s 2>/dev/null)"
    ZAPIS="$(date -u -d "$(printf '%s' "$POSLEDNI" | tr 'TZ' ' ')" +%s 2>/dev/null)"
    if [ -n "$ZAPIS" ] && [ $(( TEDKA - ZAPIS )) -lt 180 ]; then
      uspech "poslední zápis je čerstvý — zapisovac běží teď"
    else
      chyba "poslední zápis je starý, zapisovac zřejmě neběží"
      poznamka "docker compose ps ukáže, jestli služba nespadla"
    fi
  fi
fi

fi

# Nejdůležitější kontrola bloku: data musí téct POJMENOVANÝM SVAZKEM.
# Bez toho by lab prošel i dvěma bind mounty do téhož adresáře na stanici —
# a „soubor vyrobila jedna služba a servíruje ho druhá" by neplatilo.
if [ -n "$ID_WEB" ] && [ -n "$ID_ZAP" ]; then
  SV_WEB="$(docker inspect -f \
    '{{range .Mounts}}{{if eq .Destination "/usr/share/nginx/html/data"}}{{.Type}}:{{.Name}}{{end}}{{end}}' \
    "$ID_WEB" 2>/dev/null)"
  SV_ZAP="$(docker inspect -f \
    '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Type}}:{{.Name}}{{end}}{{end}}' \
    "$ID_ZAP" 2>/dev/null)"
  case "$SV_WEB" in
    volume:?*) if [ "$SV_WEB" = "$SV_ZAP" ]; then
                 uspech "obě služby sáhly na tentýž pojmenovaný svazek"
               else
                 chyba "služby nesdílejí tentýž pojmenovaný svazek"
                 poznamka "web má '${SV_WEB#volume:}', zapisovac '${SV_ZAP#volume:}'"
               fi ;;
    '')        chyba "web nemá na /usr/share/nginx/html/data připojený nic" ;;
    *)         chyba "web tam má připojený adresář ze stanice, ne pojmenovaný svazek"
               poznamka "sdílet data mezi kontejnery umí pojmenovaný svazek, ne bind" ;;
  esac
fi

krok 5 "Formulář"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je připravený" \
  "chybí formulář — spusťte ./start.sh, doplní ho"
# Jméno svazku si skládá Compose z jména projektu — je tedy per žák
# a přečte se jedině z běžícího prostředí.
# Filtruje se i podle jména svazku — kdo zkusí Rozšíření a přidá další,
# dostal by jinak náhodně vybraný a FAIL na správně vyplněném formuláři.
SVAZEK="$(docker volume ls --filter "label=com.docker.compose.project=$PROJEKT" \
  --filter "label=com.docker.compose.volume=stav" \
  --format '{{.Name}}' 2>/dev/null | head -1)"
ODP_SV="$(_zaznam "$FORMULAR" svazek | tr -d ' ')"
if [ -z "$SVAZEK" ]; then
  chyba "žádný svazek projektu $PROJEKT neexistuje"
  poznamka "pojmenovaný svazek se deklaruje v sekci volumes: na konci souboru"
elif [ "$ODP_SV" = "$SVAZEK" ]; then
  uspech "jméno svazku ve formuláři sedí"
else
  chyba "jméno svazku ve formuláři nesedí (máte '${ODP_SV:-nic}')"
  poznamka "docker volume ls — Compose si před jméno přidá jméno projektu"
fi
ODP_ID="$(_zaznam "$FORMULAR" id-web | tr -d ' ' | tr 'A-Z' 'a-z')"
if [ -z "$ID_WEB" ]; then
  chyba "služba web neběží, takže se ID nedá porovnat"
elif [ -z "$ODP_ID" ]; then
  chyba "ve formuláři chybí ID kontejneru se službou web"
else
  PLNE="$(docker inspect -f '{{.Id}}' "$ID_WEB" 2>/dev/null)"
  case "$PLNE" in
    "$ODP_ID"*) uspech "ID kontejneru web ve formuláři sedí" ;;
    *)          chyba "ID kontejneru web ve formuláři nesedí (máte '$ODP_ID')" ;;
  esac
fi

vypis_souhrn
