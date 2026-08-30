#!/bin/bash
# 2/11 — návrat do výchozího stavu (smaže formulář, balíček nechá být)
set -uo pipefail
SOFT="$HOME/netlab/software"
echo
echo "  Tím smažete vyplněný formulář v $SOFT."
echo "  Nainstalovaný balíček se to nedotkne — ten si odinstalujte sami,"
echo "  je to jeden z úkolů cvičení."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${SOFT:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
