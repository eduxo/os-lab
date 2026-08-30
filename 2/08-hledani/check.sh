#!/bin/bash
# 2/08 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

HLEDANI="$HOME/netlab/hledani"
NALEZY="$HLEDANI/nalezy.txt"

krok 1 "Prostředí"
require_path "$HLEDANI" \
  "adresář ~/netlab/hledani existuje" \
  "chybí ~/netlab/hledani — spusťte ./start.sh"
require_soubor_neprazdny "$NALEZY" \
  "formulář nalezy.txt je na místě" \
  "chybí ~/netlab/hledani/nalezy.txt — spusťte ./start.sh"

# Všechny správné hodnoty se čtou ze skutečné kupky, ne z tabulky v tomhle
# skriptu — takže se přizpůsobí i tomu, co si žák do adresáře přidá.
POCET_CONF=$(find "$HLEDANI" -name '*.conf' -type f 2>/dev/null | grep -c '')
VELKY=$(find "$HLEDANI" -type f -size +100k 2>/dev/null | head -1)
VELKY="${VELKY#"$HLEDANI"/}"
POCET_CHYB=$(grep -c 'ERROR' "$HLEDANI/logy/system.log" 2>/dev/null); POCET_CHYB="${POCET_CHYB:-0}"
# Formulář se z hledání vylučuje — žák si do něj cestu opisuje z výpisu grepu
# a bez toho by grep našel sám sebe.
NALEZ=$(grep -rn --exclude='nalezy.txt' 'Servisní klíč' "$HLEDANI" 2>/dev/null | head -1)
KLIC_SOUBOR="${NALEZ%%:*}"; KLIC_SOUBOR="${KLIC_SOUBOR#"$HLEDANI"/}"
ZBYTEK="${NALEZ#*:}"; KLIC_RADEK="${ZBYTEK%%:*}"
KLIC="$(printf '%s' "$NALEZ" | grep -oE 'KLIC-[0-9]+')"

krok 2 "Hledání souborů podle vlastností"
require_zaznam "$NALEZY" konfiguraci "$POCET_CONF" \
  "v nálezech je správný počet konfiguračních souborů"
require_zaznam_cesta "$NALEZY" velky-soubor "$VELKY" "$HLEDANI" \
  "v nálezech je cesta k souboru většímu než 100 kB"

krok 3 "Hledání v obsahu"
require_zaznam "$NALEZY" klic "$KLIC" \
  "v nálezech je servisní klíč"
require_zaznam_cesta "$NALEZY" klic-soubor "$KLIC_SOUBOR" "$HLEDANI" \
  "v nálezech je soubor, ve kterém klíč leží"
require_zaznam "$NALEZY" klic-radek "$KLIC_RADEK" \
  "v nálezech je číslo řádku, na kterém klíč je"
require_zaznam "$NALEZY" chyby "$POCET_CHYB" \
  "v nálezech je počet chybových řádků v system.log"

vypis_souhrn
