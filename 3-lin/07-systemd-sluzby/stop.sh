#!/bin/bash
# 3/07 — konec hodiny: server se zastaví, ale nemaže
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="sluzby-$ZAK2"
if lxc info "$KONT" >/dev/null 2>&1; then
  lxc stop "$KONT" >/dev/null 2>&1
  echo; echo "  Server $KONT zastaven. Vaše práce zůstává — příště na ni navážete."; echo
else
  echo; echo "  Server $KONT neexistuje, není co zastavovat."; echo
fi
