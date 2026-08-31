#!/bin/bash
# 2/19 — návrat do výchozího stavu
set -uo pipefail
ARCH="$HOME/netlab/archiv"
echo
echo "  Tím smažete celý adresář $ARCH včetně archivů, které jste vyrobili."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${ARCH:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
