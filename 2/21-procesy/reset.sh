#!/bin/bash
# 2/21 — návrat do výchozího stavu
set -uo pipefail
PROC="$HOME/netlab/procesy"
VZOR='bash .*(hlidac-[a-z]+|tvrdohlavy)\.sh'
echo
echo "  Tím ukončíte běžící skripty a smažete celý adresář $PROC včetně logů."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    for p in $(pgrep -f "$VZOR" 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
    rm -rf "${PROC:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
