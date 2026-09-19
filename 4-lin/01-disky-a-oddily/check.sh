#!/bin/bash
# 4/01 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/disky"
FORMULAR="$LAB/rozvrzeni.txt"
PRIPOJ="$LAB/data"
NAZEV="DATA-$ZAK2"
VELIKOST=$(( 400 + 50 * $(lab_vyber 9 1 410) ))   # MiB, stejně jako start.sh
PREVZETI="$PRIPOJ/prevzeti.txt"

zkontroluj_disky 1 || exit 1
DISK="$(labovy_disk 1)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }
CAST1="$(lsblk -rno NAME "/dev/$DISK" 2>/dev/null | tail -n +2 | head -1)"

krok 1 "Co na stanici je"
# Nejdřív pojistka: cvičení se dělá na labovém disku a projektový disk musí
# zůstat nedotčený. Kdyby si ho žák spletl, je lepší to říct hned — a nahlas.
if [ -n "$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)" ]; then
  uspech "disk ročníkového projektu je v pořádku"
else
  chyba "disk ročníkového projektu nenajdu — nepracovali jste omylem na něm?"
  poznamka "zastavte se a řekněte to vyučujícímu, než budete pokračovat"
fi
require_soubor_neprazdny "$FORMULAR" \
  "formulář rozvrzeni.txt je na místě" \
  "chybí ~/netlab/disky/rozvrzeni.txt — spusťte ./start.sh"
require_zaznam "$FORMULAR" disk "$DISK" \
  "ve formuláři je jméno labového disku"

krok 2 "Tabulka oddílů"
TABULKA="$(lsblk -dno PTTYPE "/dev/$DISK" 2>/dev/null | tr -d ' ' | tr 'A-Z' 'a-z')"
case "$TABULKA" in
  gpt) uspech "disk /dev/$DISK má tabulku GPT" ;;
  dos) chyba "disk má starou tabulku MBR (dos), zadání chce GPT" ;;
  '')  chyba "disk /dev/$DISK zatím nemá tabulku oddílů" ;;
  *)   chyba "disk má tabulku $TABULKA, zadání chce GPT" ;;
esac
POCET="$(lsblk -rno NAME "/dev/$DISK" 2>/dev/null | tail -n +2 | grep -c '')"
[ "$POCET" = "2" ] \
  && uspech "na disku jsou dva oddíly" \
  || chyba "na disku je oddílů: $POCET, mají být dva"
# Měří se v MiB — v týchž jednotkách, ve kterých se oddíl zadává v parted.
# Tolerance je na zarovnání, ne na převod jednotek.
if [ -n "$CAST1" ]; then
  BAJTU="$(lsblk -brno SIZE "/dev/$CAST1" 2>/dev/null | head -1)"
  MIB=$(( ${BAJTU:-0} / 1048576 ))
  ROZDIL=$(( MIB - VELIKOST )); [ "$ROZDIL" -lt 0 ] && ROZDIL=$(( -ROZDIL ))
  if [ "$ROZDIL" -le 5 ]; then
    uspech "první oddíl má zadanou velikost (${MIB} MiB)"
  else
    chyba "první oddíl má ${MIB} MiB, zadání chce $VELIKOST MiB"
  fi
else
  chyba "první oddíl na disku zatím není"
fi
require_zaznam_tvar "$FORMULAR" tabulka '^(gpt|GPT)$' \
  "ve formuláři je typ tabulky oddílů" \
  "ve formuláři chybí typ tabulky oddílů"
require_zaznam "$FORMULAR" oddilu "2" \
  "ve formuláři je počet oddílů"

krok 3 "Souborový systém"
if [ -n "$CAST1" ]; then
  # head -1: u zařízení s potomky vrací lsblk víc řádků.
  FS="$(lsblk -no FSTYPE "/dev/$CAST1" 2>/dev/null | tr -d ' ' | head -1)"
  LBL="$(lsblk -no LABEL "/dev/$CAST1" 2>/dev/null | sed 's/ *$//' | head -1)"
  [ "$FS" = "ext4" ] \
    && uspech "na prvním oddílu je souborový systém ext4" \
    || chyba "na prvním oddílu je '${FS:-nic}', zadání chce ext4"
  [ "$LBL" = "$NAZEV" ] \
    && uspech "souborový systém má návěští $NAZEV" \
    || chyba "návěští je '${LBL:-žádné}', má být $NAZEV"
else
  chyba "první oddíl na disku zatím není"
fi
require_zaznam "$FORMULAR" navesti "$NAZEV" \
  "ve formuláři je návěští souborového systému"

krok 4 "Připojení"
CIL="$(findmnt -no TARGET "/dev/${CAST1:-nic}" 2>/dev/null | head -1)"
if [ "$CIL" = "$PRIPOJ" ]; then
  uspech "první oddíl je připojený v $PRIPOJ"
elif [ -n "$CIL" ]; then
  chyba "první oddíl je připojený v $CIL, zadání chce $PRIPOJ"
else
  chyba "první oddíl není nikam připojený"
fi
# Doklad o vlastním běhu: UUID se nedá vymyslet ani opsat od souseda,
# protože vzniklo při formátování právě na téhle stanici.
UUID="$(lsblk -no UUID "/dev/${CAST1:-nic}" 2>/dev/null | tr -d ' ' | head -1)"
# Doklad se hledá NA disku — bez tohohle by prošel i soubor ležící
# v prázdném přípojném adresáři na systémovém disku.
if [ "$(findmnt -no SOURCE "$PRIPOJ" 2>/dev/null | head -1)" != "/dev/${CAST1:-nic}" ]; then
  chyba "v $PRIPOJ není připojený váš oddíl — doklad nemá kde ležet"
elif [ -z "$UUID" ]; then
  chyba "souborový systém zatím nemá UUID — není ještě vytvořený"
elif [ ! -s "$PREVZETI" ]; then
  chyba "na připojeném disku chybí prevzeti.txt"
  poznamka "soubor patří NA disk, ne vedle něj"
elif ! grep -vF "$UUID" "$PREVZETI" 2>/dev/null | grep -qE '.{20,}'; then
  chyba "v prevzeti.txt je jen UUID — chybí vaše věta"
elif grep -qF "$UUID" "$PREVZETI" 2>/dev/null; then
  uspech "v prevzeti.txt je UUID tohohle souborového systému"
else
  chyba "v prevzeti.txt není UUID tohohle souborového systému"
fi
# Uznává se absolutní cesta i zápis s vlnovkou — obojí je táž cesta a hádat
# se o to s žákem nemá smysl.
require_zaznam_tvar "$FORMULAR" pripojeno "^($HOME|~)/netlab/disky/data/?\$" \
  "ve formuláři je cesta, kam je oddíl připojený" \
  "ve formuláři chybí cesta, kam je oddíl připojený"

vypis_souhrn
