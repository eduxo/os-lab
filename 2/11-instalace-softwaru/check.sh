#!/bin/bash
# 2/11 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

SOFT="$HOME/netlab/software"
PREHLED="$SOFT/prehled.txt"
ZDROJE="/etc/apt/sources.list.d/ubuntu.sources"

BALICKY=(tree ncdu figlet sl jq htop)
MUJ="${BALICKY[$(( $(lab_vyber 6 1 111) - 1 ))]}"

krok 1 "Prostředí"
require_soubor_neprazdny "$PREHLED" \
  "formulář prehled.txt je na místě" \
  "chybí ~/netlab/software/prehled.txt — spusťte ./start.sh"
require_zaznam "$PREHLED" balicek "$MUJ" \
  "ve formuláři je balíček přidělený vašemu číslu"

krok 2 "Instalace"
require_pkg "$MUJ"

# Verze i počet souborů se čtou z nainstalovaného balíčku na téhle stanici.
if dpkg -s "$MUJ" >/dev/null 2>&1; then
  VERZE="$(dpkg-query -W -f='${Version}' "$MUJ" 2>/dev/null)"
  SOUBORU="$(dpkg -L "$MUJ" 2>/dev/null | grep -c '')"
  require_zaznam "$PREHLED" verze "$VERZE" \
    "ve formuláři je verze, kterou máte nainstalovanou"
  require_zaznam "$PREHLED" souboru "$SOUBORU" \
    "ve formuláři je počet souborů, které balíček přinesl"
else
  chyba "verzi ani počet souborů nelze ověřit, dokud balíček není nainstalovaný"
fi

krok 3 "Zdroje balíčků"
if [ -f "$ZDROJE" ]; then
  uspech "soubor se zdroji $ZDROJE existuje"
  # Uznáváme kteroukoli adresu, která je v souboru opravdu uvedená — zrcadel
  # je víc a liší se podle toho, jak byl systém nainstalovaný.
  # Odpověď musí mít tvar adresy a musí se rovnat některé z adres na řádcích
  # URIs. Pouhé `grep -qF` v celém souboru uznalo i jediné písmeno.
  ODPOVED="$(_zaznam "$PREHLED" zdroj)"; ODPOVED="${ODPOVED%/}"
  URIS="$(grep -i '^[[:space:]]*URIs:' "$ZDROJE" | sed 's/^[^:]*:[[:space:]]*//' \
          | tr ' ' '\n' | sed 's#/$##' | grep -v '^$')"
  if printf '%s' "$ODPOVED" | grep -qE '^https?://[^ ]+$' && \
     printf '%s\n' "$URIS" | grep -qxF "$ODPOVED"; then
    uspech "adresa ve formuláři opravdu je mezi zdroji této stanice"
  else
    chyba "zatím nesedí — adresa zdroje (máte '${ODPOVED:-nic}')"
    poznamka "opište celou adresu z řádku URIs v $ZDROJE, včetně http://"
  fi
else
  chyba "na této stanici chybí $ZDROJE — řekněte o tom vyučujícímu"
  poznamka "Ubuntu 24.04 má zdroje v tomhle souboru, starší formát tu být nemusí"
fi

vypis_souhrn
