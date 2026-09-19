#!/bin/bash
# 4/04 — úklid. Sejf se na konci hodiny ZAVÍRÁ: otevřený svazek je stejně
# přístupný jako nešifrovaný disk a to je půlka pointy dnešního cvičení.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
PRIPOJ="$HOME/netlab/sejf/data"
MAPPER="sejf-$ZAK2"
echo
if mountpoint -q "$PRIPOJ" 2>/dev/null; then
  sudo umount "$PRIPOJ" && echo "  Odpojeno: $PRIPOJ"
else
  echo "  Nic připojeného, není co odpojovat."
fi
if [ -b "/dev/mapper/$MAPPER" ]; then
  if sudo cryptsetup close "$MAPPER"; then
    echo "  Sejf zavřen: $MAPPER"
  else
    echo "  Sejf se NEPODAŘILO zavřít — něco ho ještě drží otevřený."
    echo "  Zkuste: sudo umount $PRIPOJ  a pak ./stop.sh znovu."
    exit 1
  fi
else
  echo "  Sejf už zavřený je."
fi
echo "  Data zůstávají na disku — bez vašeho hesla je z nich šum."
echo
