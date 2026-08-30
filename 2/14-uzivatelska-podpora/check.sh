#!/bin/bash
# 2/14 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PODPORA="$HOME/netlab/podpora"
ODPOVEDI="$PODPORA/tikety.txt"
KONTEJNER="glpi"

# Matice priorit. Je to standardní tabulka dopad × naléhavost — hodnotí se,
# jestli si žák sám se sebou neodporuje, ne jestli trefil názor autora na to,
# jak je která situace naléhavá. To je věc rozpravy s vyučujícím.
priorita_z_matice() {  # dopad nalehavost
  case "$1:$2" in
    vysoky:vysoka)   echo kriticka ;;
    vysoky:stredni)  echo vysoka ;;
    vysoky:nizka)    echo stredni ;;
    stredni:vysoka)  echo vysoka ;;
    stredni:stredni) echo stredni ;;
    stredni:nizka)   echo nizka ;;
    nizky:vysoka)    echo stredni ;;
    nizky:stredni)   echo nizka ;;
    nizky:nizka)     echo velmi-nizka ;;
    *) echo "" ;;
  esac
}

krok 1 "Prostředí"
require_soubor_neprazdny "$ODPOVEDI" \
  "formulář tikety.txt je na místě" \
  "chybí ~/netlab/podpora/tikety.txt — spusťte ./start.sh"
if command -v lxc >/dev/null 2>&1 && \
   [ "$(lxc list "^$KONTEJNER\$" -c s --format csv 2>/dev/null | head -1)" = "RUNNING" ]; then
  uspech "kontejner s GLPI běží"
else
  chyba "kontejner s GLPI neběží — spusťte ./start.sh"
fi

krok 2 "Posouzení situací"
PLATNE=0
PRIORITY=""
for I in 1 2 3 4; do
  D="$(_zaznam "$ODPOVEDI" "situace-$I-dopad")"
  N="$(_zaznam "$ODPOVEDI" "situace-$I-nalehavost")"
  P="$(_zaznam "$ODPOVEDI" "situace-$I-priorita")"
  OCEK="$(priorita_z_matice "$D" "$N")"
  if [ -z "$D" ] || [ -z "$N" ] || [ -z "$P" ]; then
    chyba "situace $I není posouzená celá"
  elif [ -z "$OCEK" ]; then
    chyba "u situace $I je neplatná hodnota dopadu nebo naléhavosti"
    poznamka "dopad: vysoky/stredni/nizky · naléhavost: vysoka/stredni/nizka"
  elif [ "$P" = "$OCEK" ]; then
    uspech "situace $I: priorita odpovídá dopadu a naléhavosti, které jste určili"
    PLATNE=$((PLATNE + 1)); PRIORITY="$PRIORITY $P"
  else
    chyba "u situace $I priorita neodpovídá tabulce"
    poznamka "dopad $D a naléhavost $N dávají podle tabulky jinou prioritu"
  fi
done

# Měkká připomínka, ne hodnocení: čtyři různé situace se stejnou prioritou
# bývají známka toho, že se tabulka vyplňovala bez čtení.
if [ "$PLATNE" -eq 4 ] && [ "$(printf '%s' "$PRIORITY" | tr ' ' '\n' | sort -u | grep -c .)" -eq 1 ]; then
  poznamka "${_M}pozn.:${_0} všechny čtyři situace máte na stejné prioritě — vyučující se zeptá proč"
fi

krok 3 "Tiket v GLPI"
require_zaznam_tvar "$ODPOVEDI" tiket '^[0-9]+$' \
  "ve formuláři je číslo tiketu, který jste v GLPI založili"
poznamka "obsah tiketu a jeho uzavření si prohlédne vyučující přímo v GLPI —"
poznamka "skript do něj nevidí"

vypis_souhrn
