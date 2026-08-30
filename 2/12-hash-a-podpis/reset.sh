#!/bin/bash
# 2/12 — návrat do výchozího stavu (stáhne instalačky a zprávy znovu)
set -uo pipefail
POD="$HOME/netlab/podpisy"
echo
echo "  Tím smažete celý adresář $POD včetně vašeho podpisu."
echo "  Váš klíč GPG ani klíčenka se to nedotkne."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${POD:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
