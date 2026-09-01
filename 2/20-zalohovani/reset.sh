#!/bin/bash
# 2/20 — návrat do výchozího stavu
set -uo pipefail
ZAL="$HOME/netlab/zalohy"
echo
echo "  Tím smažete celý adresář $ZAL včetně obnovených souborů."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${ZAL:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
