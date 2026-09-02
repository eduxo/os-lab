#!/bin/bash
# 2/01 — návrat do výchozího stavu (smaže vyplněný formulář)
set -uo pipefail
PREHLED="$HOME/dokumentace/stanice.txt"
echo
echo "  Tím smažete vyplněný formulář $PREHLED."
echo "  Zbytek adresáře ~/dokumentace zůstane beze změny."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) rm -f "${PREHLED:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
