#!/bin/bash
# 2/10 — návrat do výchozího stavu (rozbalí archiv znovu)
set -uo pipefail
AUDIT="$HOME/netlab/audit"
echo
echo "  Tím smažete celý adresář $AUDIT včetně vašeho výsledku."
echo "  U ověřovacího cvičení to vyučující uvidí — reset použijte,"
echo "  jen když jste si prostředí opravdu rozbili."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${AUDIT:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
