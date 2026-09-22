#!/bin/bash
# 4/07 — úklid. Nic se neodpojuje: projektový disk má zůstat připojený
# a hlavně má po restartu naskočit sám.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
echo
if projekt_pripojen; then
  echo "  Projekt je připojený v $PROJEKT_PRIPOJ."
else
  echo "  Pozor: projekt připojený NENÍ — fstab ještě není v pořádku."
fi
# Špatný TYP souborového systému je pro findmnt jen varování [W], a bez
# roota ho nepozná vůbec (nedostane se k blokovému zařízení). Ptáme se
# proto zvlášť: sedí třetí pole s tím, co na disku doopravdy je?
ZAR="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
TYP="$(lsblk -no FSTYPE "${ZAR:-/nic}" 2>/dev/null | tr -d ' ' | head -1)"
RADEK="$(grep -vE '^[[:space:]]*(#|$)' /etc/fstab 2>/dev/null \
  | awk -v c="$PROJEKT_PRIPOJ" '$2==c {print; exit}')"
TYP_F="$(printf '%s' "$RADEK" | awk '{print $3}')"
TYP_SEDI=1
[ -n "$TYP" ] && [ -n "$TYP_F" ] && [ "$TYP_F" != "$TYP" ] && TYP_SEDI=0
if sudo -n findmnt --verify 2>&1 | grep -qF '[E]' \
   || findmnt --verify 2>&1 | grep -qF '[E]' || [ "$TYP_SEDI" = "0" ]; then
  echo "  A ve /etc/fstab je pořád závada. Když jste dnešní opravu ještě"
  echo "  nedělali, je to v pořádku — restart je součást zadání. Pokud už"
  echo "  ale opravovat máte za sebou, nerestartujte a podívejte se znovu."
else
  echo "  findmnt --verify je čistý, stanice může bezpečně restartovat."
  # Záchranná kopie v /etc je po skončení labu spíš matoucí než užitečná.
  [ -f /etc/fstab.zaloha ] && sudo rm -f /etc/fstab.zaloha \
    && echo "  Uklidil jsem záchrannou kopii /etc/fstab.zaloha."
fi
echo
