#!/bin/bash
# 4/01 — úklid. Odpojí, co žák připojil. Disk NEMAŽE.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
PRIPOJ="$HOME/netlab/disky/data"
echo
if mountpoint -q "$PRIPOJ" 2>/dev/null; then
  sudo umount "$PRIPOJ" && echo "  Odpojeno: $PRIPOJ"
else
  echo "  Nic připojeného, není co odpojovat."
fi
echo "  Data na disku zůstávají — příští hodinu na ně navážeme."
echo
