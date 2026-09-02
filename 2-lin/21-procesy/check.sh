#!/bin/bash
# 2/21 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PROC="$HOME/netlab/procesy"
FORMULAR="$PROC/procesy.txt"
LOG="$PROC/hlidac.log"
LOG2="$PROC/tvrdohlavy.log"

# Musí souhlasit se start.sh — stejné pole, stejná sůl.
USEKY=(sklad vratnice kotelna serverovna recepce dilna)
IDX=$(lab_vyber 6 1 211)
USEK="${USEKY[IDX-1]}"
JMENO="hlidac-$USEK.sh"
SKRIPT="$PROC/$JMENO"
INTERVAL=$(( 2 + ZAK % 4 ))

# Hledáme jen běžící skript, ne jeho jméno v příkazové řádce editoru.
bezi() {  # bezi jmeno_skriptu → vypíše PIDy
  pgrep -f "bash .*$1" 2>/dev/null
}

krok 1 "Prostředí"
# Hlášky neuvádějí jméno hlídače — to je jedna z odpovědí do formuláře.
require_soubor_neprazdny "$SKRIPT" \
  "váš hlídač je na místě" \
  "chybí váš hlídací skript v ~/netlab/procesy — spusťte ./start.sh"
require_soubor_neprazdny "$PROC/tvrdohlavy.sh" \
  "druhý skript je na místě" \
  "chybí ~/netlab/procesy/tvrdohlavy.sh — spusťte ./start.sh"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na místě" \
  "chybí ~/netlab/procesy/procesy.txt — spusťte ./start.sh, doplní ho"

krok 2 "Hlídač"
require_min_radku "$LOG" 5 \
  "hlídač běžel dost dlouho na to, aby stihl aspoň pět zápisů" \
  "hlídač zatím nestihl pět zápisů do ~/netlab/procesy/hlidac.log"

# Zápisy musí být od sebe vzdálené o interval hlídače. Ručně dopsané řádky
# to nesplní — a bez téhle kontroly by cvičení uzavřelo i pár echo příkazů.
if [ -f "$LOG" ]; then
  DOBRE=$(awk '{ split($1, t, ":"); s = t[1]*3600 + t[2]*60 + t[3];
                 if (NR > 1) { d = s - p; if (d < 0) d += 86400; print d }
                 p = s }' "$LOG" \
          | awk -v iv="$INTERVAL" '$1 >= iv && $1 <= iv + 1' | grep -c '')
  if [ "${DOBRE:-0}" -ge 3 ]; then
    uspech "rozestupy zápisů odpovídají intervalu hlídače"
  else
    chyba "rozestupy zápisů v logu neodpovídají intervalu hlídače"
    poznamka "log vzniká během hlídače — nechte ho běžet, nedopisujte do něj"
  fi
fi

# PID z formuláře musí být v logu — tedy z běhu, který se opravdu stal.
PID="$(_zaznam "$FORMULAR" pid)"
if printf '%s' "$PID" | grep -qE '^[0-9]+$'; then
  if [ -f "$LOG" ] && grep -q "PID=$PID " "$LOG"; then
    uspech "PID ve formuláři patří k vašemu běhu hlídače"
  else
    chyba "PID $PID v logu hlídače není"
    poznamka "PID zjistěte za běhu (pgrep -f hlidac-) — po každém spuštění je jiný"
  fi
else
  chyba "ve formuláři chybí PID hlídače, nebo to není číslo"
fi

# „Už neběží" má smysl hlásit jen u procesu, který prokazatelně běžel.
# Jinak by [PASS] dostal i ten, kdo hlídač nikdy nespustil.
ZBYLE="$(bezi "$JMENO" | tr '\n' ' ')"
if [ -n "${ZBYLE// /}" ]; then
  chyba "hlídač pořád běží (PID: ${ZBYLE% })"
  poznamka "ukončete ho a spusťte kontrolu znovu"
elif [ -f "$LOG" ]; then
  uspech "hlídač už neběží"
fi

krok 3 "Tvrdohlavý proces a formulář"
require_min_radku "$LOG2" 3 \
  "tvrdohlavý skript běžel a stihl zapisovat" \
  "tvrdohlavý skript zatím nestihl tři zápisy do ~/netlab/procesy/tvrdohlavy.log"

ZBYLE2="$(bezi tvrdohlavy.sh | tr '\n' ' ')"
if [ -n "${ZBYLE2// /}" ]; then
  chyba "tvrdohlavý proces pořád běží (PID: ${ZBYLE2% })"
  poznamka "obyčejný kill si zakázal — použijte signál, který se zakázat nedá"
elif [ -f "$LOG2" ]; then
  uspech "tvrdohlavý proces už neběží"
fi

require_zaznam "$FORMULAR" skript "$JMENO" \
  "ve formuláři je jméno vašeho hlídače"
require_zaznam "$FORMULAR" interval "$INTERVAL" \
  "ve formuláři je interval hlídače"
# Rozsah, ne jen „číslo": RSS shellu ve smyčce jsou stovky až tisíce kB.
# Kdo napíše 4 (megabajty) nebo 0, hodnotu neměřil.
require_zaznam_tvar "$FORMULAR" pamet '^[1-9][0-9]{2,5}$' \
  "ve formuláři je paměť hlídače v kB" \
  "ve formuláři chybí paměť hlídače, nebo není v kB (čekám stovky až tisíce)"
require_zaznam "$FORMULAR" signal "9" \
  "ve formuláři je číslo signálu, který tvrdohlavý proces ukončil"

vypis_souhrn
