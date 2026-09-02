#!/bin/bash
# 2/06 — návrat do výchozího stavu (vysype dokumenty znovu neroztříděné)
set -uo pipefail
UKLID="$HOME/netlab/uklid"
echo
echo "  Tím smažete celý adresář $UKLID včetně roztřídění, které jste udělali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${UKLID:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
