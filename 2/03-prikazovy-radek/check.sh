#!/bin/bash
# 2/03 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

BAZE="$HOME/nakoleni"
KOD="NAK-$(( (ZAK * 7919) % 9000 + 1000 ))"

krok 1 "Orientace v adresářích"
require_path "$BAZE" "pracovní adresář ~/nakoleni existuje"
if [ -f "$HOME/.bash_history" ] && grep -qE '(^|;| )(pwd|ls)( |$)' "$HOME/.bash_history"; then
  uspech "vyzkoušeli jste pwd nebo ls"
else
  poznamka "tip: až se rozhlédnete příkazy pwd a ls, ukáže se to tady"
fi

krok 2 "Nalezení předávacího protokolu"
if [ -f "$BAZE/odpoved.txt" ] && grep -qF "$KOD" "$BAZE/odpoved.txt"; then
  uspech "našli jste přístupový kód a zapsali ho do odpoved.txt"
else
  chyba "v ~/nakoleni/odpoved.txt zatím není správný kód"
  poznamka "kód je v jednom ze souborů uvnitř ~/nakoleni — projděte adresáře"
fi

krok 3 "Vlastní složka"
require_path "$BAZE/prevzato" "vytvořili jste adresář ~/nakoleni/prevzato"
if [ -f "$BAZE/prevzato/poznamky.txt" ] && [ -s "$BAZE/prevzato/poznamky.txt" ]; then
  uspech "poznámky.txt existuje a není prázdný"
else
  chyba "chybí ~/nakoleni/prevzato/poznamky.txt s vaším textem"
fi

vypis_souhrn
