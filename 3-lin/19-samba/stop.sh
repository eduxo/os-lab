#!/bin/bash
# 3/19 — zastavení serveru (práce na něm zůstává)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="data-$ZAK2"
echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
if [ -z "$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)" ]; then
  echo "  Server $KONT neexistuje, není co zastavovat."
else
  lxc stop "$KONT" >/dev/null 2>&1
  echo "  Server $KONT zastaven. Vaše práce na něm zůstala."
  echo "  Příště ho nastartuje ./start.sh"
fi
echo
