#!/bin/bash
# 2/16 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PRAVA="$HOME/netlab/prava"
TABULKA="$PRAVA/tabulka.txt"

ADRESARE=(vedeni sklad ucetni verejne)
SKUPINY=(vedeni sklad ucetni "$(id -gn)")
# Skupina musí na svůj adresář vždycky aspoň dosáhnout — 700 by znamenalo,
# že oddělení nevidí do vlastní složky, což je zadání bez smyslu.
# Jen 770 a 750. S 775 by do složky oddělení viděl celý svět — a přesně
# proti tomu je tiket, kvůli kterému se cvičení dělá.
MOZNE=(770 750)
prava_pro() {
  case "$1" in
    3) echo 755 ;;
    *) echo "${MOZNE[$(( $(lab_vyber 2 1 $((170 + $1))) - 1 ))]}" ;;
  esac
}

krok 1 "Prostředí"
require_soubor_neprazdny "$TABULKA" \
  "zadání a formulář jsou na místě" \
  "chybí ~/netlab/prava/tabulka.txt — spusťte ./start.sh"
for S in vedeni sklad ucetni; do require_group "$S"; done

krok 2 "Vlastnictví"
for i in 0 1 2 3; do
  require_owner "$PRAVA/${ADRESARE[$i]}" "$(id -un):${SKUPINY[$i]}"
done

krok 3 "Práva"
for i in 0 1 2 3; do
  require_mode "$PRAVA/${ADRESARE[$i]}" "$(prava_pro $i)"
done

# Negativní kontrola: 777 není řešení, i když „funguje".
for i in 0 1 2 3; do
  negative_no_777 "$PRAVA/${ADRESARE[$i]}"
done

krok 4 "Doložení vlastního běhu"
require_zaznam_tvar "$TABULKA" umask '^0?[0-7]{3}$' \
  "ve formuláři je vaše výchozí maska"
# Symbolický zápis se čte přímo z adresáře — musí sedět na skutečný stav.
SYMB="$(ls -ld "$PRAVA/verejne" 2>/dev/null | cut -c1-10)"
require_zaznam "$TABULKA" symbolicky "$SYMB" \
  "ve formuláři je symbolický zápis práv adresáře verejne"

vypis_souhrn
