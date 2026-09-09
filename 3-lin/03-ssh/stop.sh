#!/bin/bash
# 3/03 — konec hodiny: server se zastaví, ale nemaže
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="server-$ZAK2"
if ! command -v lxc >/dev/null 2>&1; then
  echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
if lxc info "$KONT" >/dev/null 2>&1; then
  lxc stop "$KONT" >/dev/null 2>&1
  echo; echo "  Server $KONT zastaven. Vaše práce zůstává — příště na ni navážete."; echo
else
  echo; echo "  Server $KONT neexistuje, není co zastavovat."; echo
fi
