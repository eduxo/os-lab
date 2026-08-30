#!/bin/bash
# 2/02 — návrat do výchozího stavu (smaže celý adresář cvičení)
set -uo pipefail
HYG="$HOME/dokumentace/hygiena"
echo
echo "  Tím smažete celý adresář $HYG."
echo "  Zmizí i databáze hesel, kterou jste si v něm založili."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) rm -rf "${HYG:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
