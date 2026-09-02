#!/bin/bash
# 2/17 — návrat do výchozího stavu
set -uo pipefail
SDILENE="$HOME/netlab/sdilene"
echo
echo "  Tím smažete celý adresář $SDILENE i s nastavenými právy."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    sudo rm -rf "${SDILENE:?}" 2>/dev/null || rm -rf "${SDILENE:?}"
    echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
