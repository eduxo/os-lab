#!/bin/bash
# 2/19 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

ARCH="$HOME/netlab/archiv"
DATA="$ARCH/data"
TAR="$ARCH/zaloha.tar"
TGZ="$ARCH/zaloha.tar.gz"
OBNOVENO="$ARCH/obnoveno"
FORMULAR="$ARCH/prehled.txt"

krok 1 "Prostředí"
require_path "$DATA" \
  "data k zálohování jsou na místě" \
  "chybí ~/netlab/archiv/data — spusťte ./start.sh"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na místě" \
  "chybí ~/netlab/archiv/prehled.txt — spusťte ./start.sh"

# Kolik souborů má archiv obsahovat — počítá se ze skutečných dat.
POCET_DAT=$(find "$DATA" -type f 2>/dev/null | grep -c '')

krok 2 "Archiv"
require_soubor_neprazdny "$TAR" \
  "archiv zaloha.tar existuje" \
  "chybí ~/netlab/archiv/zaloha.tar"
if [ -f "$TAR" ]; then
  V_ARCHIVU=$(tar -tf "$TAR" 2>/dev/null | grep -c '[^/]$')
  if [ "$V_ARCHIVU" -eq "$POCET_DAT" ]; then
    uspech "archiv obsahuje všech $POCET_DAT souborů"
  else
    chyba "archiv obsahuje $V_ARCHIVU souborů, dat je $POCET_DAT"
    poznamka "zabalit se má celý adresář data, ne jen jeho část"
  fi
  # Archiv nesmí obsahovat absolutní cesty — rozbalil by se pak jinam,
  # než žák čeká, a na cizím stroji by přepsal systémové soubory.
  if tar -tf "$TAR" 2>/dev/null | grep -q '^/'; then
    chyba "v archivu jsou absolutní cesty"
    poznamka "balte z adresáře ~/netlab/archiv příkazem na adresář data, ne na /home/..."
  else
    uspech "archiv má relativní cesty"
  fi
fi

require_soubor_neprazdny "$TGZ" \
  "komprimovaný archiv zaloha.tar.gz existuje" \
  "chybí ~/netlab/archiv/zaloha.tar.gz"
if [ -f "$TAR" ] && [ -f "$TGZ" ]; then
  VT=$(wc -c < "$TAR" | tr -d ' ')
  VG=$(wc -c < "$TGZ" | tr -d ' ')
  if [ "$VG" -lt "$VT" ]; then
    uspech "komprimovaný archiv je menší než nekomprimovaný"
  else
    chyba "komprimovaný archiv není menší — zkontrolujte, čím jste ho vyrobili"
  fi
fi

krok 3 "Obnovení a přehled"
require_path "$OBNOVENO/data" \
  "archiv je rozbalený v adresáři obnoveno" \
  "chybí ~/netlab/archiv/obnoveno/data — rozbalte archiv do zvoleného adresáře"
if [ -d "$OBNOVENO/data" ]; then
  POCET_OBN=$(find "$OBNOVENO/data" -type f 2>/dev/null | grep -c '')
  if [ "$POCET_OBN" -eq "$POCET_DAT" ]; then
    uspech "rozbalená data mají všech $POCET_DAT souborů"
  else
    chyba "rozbalená data mají $POCET_OBN souborů, má jich být $POCET_DAT"
  fi
fi

# Hodnoty z vlastního běhu — u každého žáka jiné.
if [ -f "$TAR" ]; then
  require_zaznam "$FORMULAR" souboru "$POCET_DAT" \
    "ve formuláři je počet souborů v archivu"
  require_zaznam "$FORMULAR" velikost-tar "$(wc -c < "$TAR" | tr -d ' ')" \
    "ve formuláři je velikost nekomprimovaného archivu"
fi
if [ -f "$TGZ" ]; then
  require_zaznam "$FORMULAR" velikost-tgz "$(wc -c < "$TGZ" | tr -d ' ')" \
    "ve formuláři je velikost komprimovaného archivu"
fi
require_zaznam "$FORMULAR" mensi "tgz" \
  "ve formuláři je, který archiv je menší"

vypis_souhrn
