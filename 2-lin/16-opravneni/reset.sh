#!/bin/bash
# 2/16 — návrat do výchozího stavu (adresáře znovu, bez nastavených práv)
set -uo pipefail
PRAVA="$HOME/netlab/prava"
echo
echo "  Tím smažete celý adresář $PRAVA i s nastavenými právy."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    sudo rm -rf "${PRAVA:?}" 2>/dev/null || rm -rf "${PRAVA:?}"
    echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
