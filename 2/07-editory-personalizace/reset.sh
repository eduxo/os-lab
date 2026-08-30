#!/bin/bash
# 2/07 — návrat do výchozího stavu (rozházený postup znovu)
set -uo pipefail
EDITOR_DIR="$HOME/netlab/editor"
echo
echo "  Tím smažete adresář $EDITOR_DIR a postup se rozsype znovu."
echo "  Nastavení /etc/motd ani ~/.bashrc se to nedotkne — ta si spravujete sami."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${EDITOR_DIR:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
