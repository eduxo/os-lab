#!/bin/bash
# 3/02 — návrat do výchozího stavu
set -uo pipefail
DIAG="$HOME/netlab/diagnostika"
echo
echo "  Tím ukončíte naslouchač a smažete $DIAG i s vyplněným formulářem."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    # Ukončení má na starosti stop.sh — dělá to slušně (TERM, pak teprve
    # KILL), což je přesně to, co cvičení o procesech učí.
    "$(dirname "$0")/stop.sh" >/dev/null 2>&1
    rm -rf "${DIAG:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
