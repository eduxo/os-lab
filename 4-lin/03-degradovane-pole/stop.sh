#!/bin/bash
# 4/03 — úklid. Odpojí pole, ale nerozebere ho: příští cvičení na něm nestojí,
# zato by ho žák zbytečně stavěl znovu.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
PRIPOJ="$HOME/netlab/raid/data"
echo
if mountpoint -q "$PRIPOJ" 2>/dev/null; then
  sudo umount "$PRIPOJ" && echo "  Odpojeno: $PRIPOJ"
else
  echo "  Nic připojeného, není co odpojovat."
fi
echo "  Pole zůstává složené."
echo
