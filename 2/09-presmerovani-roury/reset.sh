#!/bin/bash
# 2/09 — návrat do výchozího stavu (stáhne log znovu)
set -uo pipefail
LOGY="$HOME/netlab/logy"
echo
echo "  Tím smažete celý adresář $LOGY včetně vašeho reportu."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${LOGY:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
