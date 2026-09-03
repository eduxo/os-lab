#!/bin/bash
# 3/00 — návrat do výchozího stavu
set -uo pipefail
ROZ="$HOME/netlab/rozcvicka"
echo
echo "  Tím smažete celý adresář $ROZ i s vyplněnými odpověďmi."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${ROZ:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
