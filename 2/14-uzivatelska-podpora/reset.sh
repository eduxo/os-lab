#!/bin/bash
# 2/14 — návrat do výchozího stavu. Situace zůstávají tytéž, jsou odvozené
# z čísla žáka; vyprázdní se jen vyplněné odpovědi.
set -uo pipefail
PODPORA="$HOME/netlab/podpora"
echo
echo "  Tím smažete vyplněný formulář v $PODPORA a začnete s prázdným."
echo "  Tikety, které jste v GLPI založili, zůstanou — ty se z něj mažou v GLPI."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    rm -rf "${PODPORA:?}"; echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
