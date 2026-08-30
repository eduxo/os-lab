#!/bin/bash
# 2/05 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

CESTY="$HOME/netlab/cesty"
MAPA="$CESTY/mapa.txt"
NALEZ="$CESTY/nalez.txt"
VYCHOZI="$CESTY/sklad/2025/faktury"

krok 1 "Prostředí"
require_path "$CESTY" \
  "adresář ~/netlab/cesty existuje" \
  "chybí ~/netlab/cesty — spusťte ./start.sh"
require_soubor_neprazdny "$MAPA" \
  "formulář mapa.txt je na místě" \
  "chybí ~/netlab/cesty/mapa.txt — spusťte ./start.sh"

krok 2 "Mapa souborového systému"
# Vzory jsou shovívavé k lomítku na konci — /etc i /etc/ znamenají totéž.
require_zaznam_tvar "$MAPA" konfigurace '^/etc/?$'      "konfigurace systému: /etc"
require_zaznam_tvar "$MAPA" logy         '^/var/log/?$'  "systémové záznamy: /var/log"
require_zaznam_tvar "$MAPA" domovske     '^/home/?$'     "domovské adresáře: /home"
require_zaznam_tvar "$MAPA" docasne      '^/tmp/?$'      "dočasné soubory: /tmp"
require_zaznam_tvar "$MAPA" programy     '^/usr/bin/?$'  "spustitelné programy: /usr/bin"
require_zaznam_tvar "$MAPA" zarizeni     '^/dev/?$'      "soubory zařízení: /dev"

# Dvě hodnoty přečtené z této konkrétní stanice. Kdo je nespustil, nezjistí je.
require_zaznam "$MAPA" bin-odkaz "$(readlink /bin)" \
  "kam ukazuje /bin na této stanici"
require_zaznam "$MAPA" ls-cesta "$(command -v ls)" \
  "kde na této stanici leží program ls"

krok 3 "Cesty k nalezenému souboru"
require_soubor_neprazdny "$NALEZ" \
  "formulář nalez.txt je na místě" \
  "chybí ~/netlab/cesty/nalez.txt — spusťte ./start.sh"

# Skutečné umístění hledaného souboru — čte se ze stromu, ne z tabulky.
POCET_CILU=$(cd "$CESTY" 2>/dev/null && ls -1d provoz/*/*/inventura.txt 2>/dev/null | grep -c '')
CIL=$(cd "$CESTY" 2>/dev/null && ls -1d provoz/*/*/inventura.txt 2>/dev/null | head -1)

# Negativní kontrola: druhá inventura ve stromu by udělala z jednoznačné
# odpovědi hádanku. Bývá to pokus zkrátit si hledání, ne nehoda.
if [ "${POCET_CILU:-0}" -gt 1 ]; then
  chyba "ve struktuře jsou $POCET_CILU soubory inventura.txt — má být jeden"
  poznamka "ty, které jste přidali, smažte; původní obnoví ./reset.sh"
fi

if [ -n "$CIL" ]; then
  require_zaznam "$NALEZ" absolutni "$CESTY/$CIL" \
    "absolutní cesta k inventuře souhlasí"

  # Relativní cestu porovnáváme po odříznutí úvodního ./ — obojí je správně.
  REL_OCEK="../../../$CIL"
  REL_ZAK=$(_zaznam "$NALEZ" relativni | sed -E 's#^\./##')
  if [ "$REL_ZAK" = "$REL_OCEK" ]; then
    uspech "relativní cesta ze sklad/2025/faktury souhlasí"
  else
    chyba "relativní cesta ze sklad/2025/faktury nesouhlasí (máte '${REL_ZAK:-nic}')"
    poznamka "vede z $VYCHOZI, takže začíná tečkami"
  fi

  # Kód je uvnitř souboru — bez otevření cesty se k němu nedostanete.
  require_zaznam "$NALEZ" kod "$(lab_kod INV 5)" \
    "kód inventury z nalezeného souboru souhlasí"
else
  chyba "v ~/netlab/cesty nenacházím inventuru — spusťte ./reset.sh"
fi

vypis_souhrn
