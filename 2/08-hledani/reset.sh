#!/bin/bash
# 2/08 — návrat do výchozího stavu (rozbalí zálohu znovu)
set -uo pipefail
HLEDANI="$HOME/netlab/hledani"
echo
echo "  Tím smažete celý adresář $HLEDANI včetně vyplněných nálezů."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${HLEDANI:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
