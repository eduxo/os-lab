#!/bin/bash
# 2/14 — návrat do výchozího stavu
set -uo pipefail
PODPORA="$HOME/netlab/podpora"
echo
echo "  Tím smažete celý adresář $PODPORA včetně tiketu, který jste sepsali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${PODPORA:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
