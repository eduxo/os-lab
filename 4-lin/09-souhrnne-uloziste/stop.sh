#!/bin/bash
# 4/09 — úklid. Nic se nemaže: výsledek souhrnné práce je podklad k obhajobě.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
PRIPOJ="$HOME/netlab/ucto"
MAPPER="sejf-$ZAK2"
echo
mountpoint -q "$PRIPOJ" 2>/dev/null \
  && echo "  Svazek zakázky je připojený v $PRIPOJ — nechávám ho být." \
  || echo "  Svazek zakázky připojený není."
echo "  Sejf zavřete, až skončíte:  sudo cryptsetup close $MAPPER"
echo "  (nejdřív odpojit: sudo umount $PRIPOJ)"
echo
