#!/bin/bash
# 4/02 — úklid. Odpojí pole, ale nerozebere ho.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
PRIPOJ="$HOME/netlab/raid/data"
echo
if mountpoint -q "$PRIPOJ" 2>/dev/null; then
  sudo umount "$PRIPOJ" && echo "  Odpojeno: $PRIPOJ"
else
  echo "  Nic připojeného, není co odpojovat."
fi
echo "  Pole zůstává složené — příští hodinu z něj vytáhneme disk."
echo
