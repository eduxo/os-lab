#!/bin/bash
# 2/15 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

UCTY="$HOME/netlab/ucty"
ZADANI="$UCTY/zadani.txt"

JMENA=(jnovak jhrabal pkusek smala tsimakova apolaskova pmezek dhlavata)
ODDELENI=(sklad ucetni vedeni)
VYBER=($(lab_vyber 8 3 151))

krok 1 "Prostředí"
require_soubor_neprazdny "$ZADANI" \
  "zadání a formulář jsou na místě" \
  "chybí ~/netlab/ucty/zadani.txt — spusťte ./start.sh"

krok 2 "Skupiny a účty"
# Všechna tři oddělení, ne jen ta, do kterých někdo patří. Cvičení o
# oprávněních na ně navazuje a potřebuje je všechna — kdyby si žák založil
# jen ta svá, zasekl by se hned v příštím cvičení.
for S in "${ODDELENI[@]}"; do
  require_group "$S"
done

I=1
for N in "${VYBER[@]}"; do
  U="${JMENA[$((N-1))]}"
  S="${ODDELENI[$(( $(lab_vyber 3 1 $((160 + I))) - 1 ))]}"
  require_user "$U"
  if id "$U" >/dev/null 2>&1; then
    require_member "$U" "$S"
    # Celé jméno se ukládá do pátého pole /etc/passwd (pole GECOS).
    GECOS="$(getent passwd "$U" | cut -d: -f5 | cut -d, -f1)"
    if [ -n "$GECOS" ]; then
      uspech "$U má vyplněné celé jméno ($GECOS)"
    else
      chyba "$U nemá vyplněné celé jméno"
      poznamka "zakládá se přepínačem -c, doplnit jde příkazem usermod"
    fi
  fi
  I=$((I+1))
done

# `chage -l` cizího účtu smí číst jen root. Zkusíme to nejdřív bez dotazu
# (sudo si heslo chvíli pamatuje) a teprve pak se zeptáme.
# LC_ALL=C vynutí anglický výpis. Bez toho se hledaly české fráze a stačilo,
# aby se `Účet vyprší` lišil od vzoru `účtu vyprší`, a kontrola platnosti účtu
# neprošla nikomu.
chage_vypis() {
  sudo -n env LC_ALL=C chage -l "$1" 2>/dev/null || sudo env LC_ALL=C chage -l "$1" 2>/dev/null
}

krok 3 "Platnost účtu a hesla"
for N in "${VYBER[@]}"; do
  U="${JMENA[$((N-1))]}"
  id "$U" >/dev/null 2>&1 || continue
  UDAJE="$(chage_vypis "$U")"
  if [ -z "$UDAJE" ]; then
    chyba "u $U se nepodařilo přečíst nastavení platnosti"
    continue
  fi
  # Hodnoty se čtou z chage, ne z /etc/shadow — výpis je stejný česky i anglicky
  # jen v číslech, takže se hledají čísla, ne slova.
  MAX="$(printf '%s' "$UDAJE"  | grep -i 'Maximum number of days' | grep -oE '[0-9]+' | head -1)"
  MIN="$(printf '%s' "$UDAJE"  | grep -i 'Minimum number of days' | grep -oE '[0-9]+' | head -1)"
  WARN="$(printf '%s' "$UDAJE" | grep -i 'warning'               | grep -oE '[0-9]+' | head -1)"
  EXP="$(printf '%s' "$UDAJE"  | grep -i 'Account expires'       | grep -oE '2027'   | head -1)"
  [ "$MAX" = "90" ] && uspech "$U: heslo platí nejvýš 90 dnů" || chyba "$U: heslo nemá platnost 90 dnů"
  [ "$MIN" = "5" ]  && uspech "$U: heslo lze změnit nejdřív po 5 dnech" || chyba "$U: chybí minimální doba 5 dnů"
  [ "$WARN" = "14" ] && uspech "$U: upozornění 14 dní předem" || chyba "$U: chybí upozornění 14 dní předem"
  [ -n "$EXP" ] && uspech "$U: platnost účtu končí v roce 2027" || chyba "$U: účet nemá nastavenou platnost do konce roku 2027"
done

krok 4 "Doložení vlastního běhu"
PRVNI="${JMENA[$(( ${VYBER[0]} - 1 ))]}"
if id "$PRVNI" >/dev/null 2>&1; then
  require_zaznam "$ZADANI" uid-prvni "$(id -u "$PRVNI")" \
    "ve formuláři je UID prvního účtu ze seznamu"
else
  chyba "UID nelze ověřit, dokud účet $PRVNI neexistuje"
fi
require_zaznam "$ZADANI" skupin "$(id -nG "$(id -un)" | wc -w | tr -d ' ')" \
  "ve formuláři je počet skupin vašeho vlastního účtu"

# Negativní kontrola: účty nemají mít prázdné heslo ani neomezená práva.
OBCHVAT=0
for N in "${VYBER[@]}"; do
  U="${JMENA[$((N-1))]}"
  id "$U" >/dev/null 2>&1 || continue
  id -nG "$U" 2>/dev/null | tr ' ' '\n' | grep -qx sudo && OBCHVAT=1
done
if [ "$OBCHVAT" -eq 0 ]; then
  uspech "žádný z účtů nedostal práva správce"
else
  chyba "některý z účtů je ve skupině sudo — zadání to nechtělo"
  poznamka "běžný uživatel oddělení práva správce nepotřebuje"
fi

vypis_souhrn
