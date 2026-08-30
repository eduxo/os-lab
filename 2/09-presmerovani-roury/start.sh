#!/bin/bash
# 2/09 — Přesměrování a roury. Prostředí: žákova stanice.
# Vyrobí přístupový log, ze kterého se dá rourou vytáhnout přehled.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

LOGY="$HOME/netlab/logy"
PREHLED="$LOGY/prehled.txt"
LOG="$LOGY/pristup.log"

if [ -d "$LOGY" ]; then
  echo
  echo "  Prostředí už existuje v $LOGY — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Stahuji přístupový log z webového serveru…"
mkdir -p "$LOGY"

# Adresy klientů. Pořadí podle aktivity se odvozuje z čísla žáka, ale rozestupy
# mezi počty jsou pevné a dost velké — kdyby se dvě adresy shodly, nebylo by
# „třetí nejaktivnější" jednoznačné a žák by dostal FAIL za správnou rouru.
ADRESY=(10.10.10.11 10.10.10.24 10.10.10.37 10.10.10.42 10.10.10.58)
PORADI=($(lab_vyber 5 5 91))
ZAKLADY=(24 16 11 7 4)
POCET_CHYB=$(( 3 + $(lab_vyber 6 1 92) ))

# Přirážka je pro každou adresu jiná a odvozuje se z otisku, ne ze zbytku po
# dělení. Dřív to bylo `ZAK % 3`, tedy tři možné logy na čtyřicet žáků — osm
# dvojic mělo shodný celý formulář a dvě i shodný report.txt.
# Strop přirážky je 3, rozestupy základů jsou 8/5/4/3. První tři místa proto
# zůstávají vždy ostře oddělená (nejmenší rozdíl 4−3 = 1) a právě na nich
# stojí odpovědi i report. Čtvrté a páté se vyrovnat mohou — nikde na nich
# ale nic nezávisí.
PRIRAZKY=()
for r in 0 1 2 3 4; do PRIRAZKY+=( $(( $(lab_vyber 4 1 $((95 + r))) - 1 )) ); done

{
  for r in 0 1 2 3 4; do
    A="${ADRESY[$(( ${PORADI[$r]} - 1 ))]}"
    CELKEM=$(( ${ZAKLADY[$r]} + ${PRIRAZKY[$r]} ))
    for i in $(seq 1 "$CELKEM"); do
      # Chyby serveru patří prostřední adrese, aby se počty ostatních
      # nepohnuly. Nenalezené stránky mají první požadavek liché adresy.
      if [ "$r" -eq 2 ] && [ "$i" -le "$POCET_CHYB" ]; then
        printf '2026-09-%02d %02d:%02d %s POST /ulozit 500\n' \
          $(( i % 28 + 1 )) $(( 9 + i % 8 )) $(( i % 60 )) "$A"
      elif [ "$i" -eq 1 ] && [ $(( r % 2 )) -eq 1 ]; then
        printf '2026-09-%02d %02d:%02d %s GET /stara-stranka 404\n' \
          $(( i % 28 + 1 )) $(( 10 + i % 6 )) $(( i % 60 )) "$A"
      else
        printf '2026-09-%02d %02d:%02d %s GET /index.html 200\n' \
          $(( i % 28 + 1 )) $(( 7 + i % 12 )) $(( i % 60 )) "$A"
      fi
    done
  done
} > "$LOG"

printf 'Servisní zásah 1. 9. — restart služby.\n' > "$LOGY/servis.txt"

# Malý soubor s pevným obsahem. Slouží k nácviku rour ve vedené části —
# na skutečném logu by ukázkový výstup prozradil odpovědi.
# Dvě podmínky naráz: žádné dvě položky nemají stejný počet (při shodě se
# pořadí liší podle implementace sortu), a abecední pořadí je jiné než pořadí
# podle četnosti — jinak by ukázka `sort -rn` vypsala totéž co bez něj a žák
# by nikde neviděl, k čemu druhé řazení vlastně je.
printf 'vedeni\nsklad\nvedeni\nucetni\nvedeni\nsklad\n' > "$LOGY/ukazka.txt"

cat > "$PREHLED" <<'FORMULAR'
# Přehled provozu — vyplňte hodnoty za dvojtečku.
radku:
chyb:
top-adresa:
top-pocet:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Přístupový log:  $LOG
    Formulář:        $PREHLED

  Přepněte se do adresáře:

    cd ~/netlab/logy

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/09-presmerovani-roury && ./check.sh --krok 1

EOF
