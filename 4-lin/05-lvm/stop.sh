#!/bin/bash
# 4/05 — úklid. Odpojí svazek, deaktivuje skupinu a zavře sejf.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
PRIPOJ="$HOME/netlab/lvm/data"
SKUPINA="data-$ZAK2"
MAPPER="sejf-$ZAK2"
echo
if mountpoint -q "$PRIPOJ" 2>/dev/null; then
  sudo umount "$PRIPOJ" && echo "  Odpojeno: $PRIPOJ"
else
  echo "  Nic připojeného, není co odpojovat."
fi
# Odpojit se musí VŠECHNY svazky skupiny, ne jen ten z Postupu: kdo si
# v Rozšíření udělal druhý svazek a nechal ho připojený, nedostane skupinu
# do klidu — a pak nejde zavřít ani sejf.
while read -r LV; do
  [ -n "$LV" ] || continue
  if mountpoint -q "$(findmnt -no TARGET "$LV" 2>/dev/null)" 2>/dev/null; then
    CIL="$(findmnt -no TARGET "$LV" 2>/dev/null)"
    sudo umount "$LV" && echo "  Odpojeno: $CIL"
  fi
done < <(sudo lvs --noheadings -o lv_path "$SKUPINA" 2>/dev/null | tr -d ' ')

# Skupina musí být deaktivovaná dřív, než se zavře sejf — leží uvnitř něj.
if sudo vgchange -an "$SKUPINA" >/dev/null 2>&1; then
  echo "  Skupina $SKUPINA deaktivována."
else
  echo "  Skupinu $SKUPINA se nepodařilo deaktivovat — něco z ní se ještě používá."
  echo "  Co je připojené, ukáže: findmnt | grep $SKUPINA"
  exit 1
fi
if [ -b "/dev/mapper/$MAPPER" ]; then
  if sudo cryptsetup close "$MAPPER"; then
    echo "  Sejf zavřen: $MAPPER"
  else
    echo "  Sejf se NEPODAŘILO zavřít — něco ho ještě drží otevřený."
    echo "  Zkuste: sudo umount $PRIPOJ  a pak ./stop.sh znovu."
    exit 1
  fi
fi
echo "  Data zůstávají na disku — bez vašeho hesla je z nich šum."
echo
