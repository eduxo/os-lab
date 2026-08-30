#!/bin/bash
# 2/09 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

LOGY="$HOME/netlab/logy"
LOG="$LOGY/pristup.log"
PREHLED="$LOGY/prehled.txt"
REPORT="$LOGY/report.txt"

krok 1 "Prostředí"
require_path "$LOGY" \
  "adresář ~/netlab/logy existuje" \
  "chybí ~/netlab/logy — spusťte ./start.sh"
require_soubor_neprazdny "$LOG" \
  "přístupový log je na místě" \
  "chybí ~/netlab/logy/pristup.log — spusťte ./start.sh"
# Negativní kontrola: všechny odpovědi se počítají z logu, takže bez tohohle
# by stačilo log zkrátit na dva řádky a všechno by „souhlasilo".
# Nejmenší možný log má 62 řádků (nejnižší kombinace přirážek).
require_min_radku "$LOG" 62 \
  "log je celý — nic se z něj neztratilo"

# Správné hodnoty se počítají z logu, který má žák u sebe.
# `|| echo 0` by u souboru bez shody přidalo druhou nulu a hodnota by měla
# dva řádky — pak by neprošla žádná odpověď.
RADKU=$(grep -c '' "$LOG" 2>/dev/null); RADKU="${RADKU:-0}"
CHYB=$(grep -c ' 500$' "$LOG" 2>/dev/null); CHYB="${CHYB:-0}"
POradi=$(grep -oE '10\.10\.10\.[0-9]+' "$LOG" 2>/dev/null | sort | uniq -c | sort -rn)
TOP_RADEK=$(printf '%s\n' "$POradi" | head -1)
TOP_ADRESA=$(printf '%s' "$TOP_RADEK" | grep -oE '10\.10\.10\.[0-9]+')
TOP_POCET=$(printf '%s' "$TOP_RADEK" | grep -oE '[0-9]+' | head -1)

krok 2 "Počty z logu"
require_zaznam "$PREHLED" radku "$RADKU" \
  "v přehledu je počet řádků logu"
require_zaznam "$PREHLED" chyb "$CHYB" \
  "v přehledu je počet chybových požadavků"

krok 3 "Nejaktivnější klient a report"
require_zaznam "$PREHLED" top-adresa "$TOP_ADRESA" \
  "v přehledu je nejaktivnější adresa"
require_zaznam "$PREHLED" top-pocet "$TOP_POCET" \
  "v přehledu je počet jejích požadavků"

# Report musí obsahovat právě tři nejaktivnější adresy ve správném pořadí.
if [ -f "$REPORT" ]; then
  OCEKAVANE=$(printf '%s\n' "$POradi" | head -3 | grep -oE '10\.10\.10\.[0-9]+' | tr '\n' ' ')
  MAJI=$(grep -oE '10\.10\.10\.[0-9]+' "$REPORT" | head -3 | tr '\n' ' ')
  if [ "$MAJI" = "$OCEKAVANE" ]; then
    uspech "report.txt obsahuje tři nejaktivnější adresy ve správném pořadí"
  else
    chyba "report.txt neobsahuje tři nejaktivnější adresy ve správném pořadí"
    poznamka "pořadí dělá druhé řazení — bez něj vyjde abecední, ne podle počtu"
  fi
else
  chyba "chybí ~/netlab/logy/report.txt"
fi

vypis_souhrn
