#!/bin/bash
# 3/04 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="server-$ZAK2"
IP_STARA="$(lxc list "^${KONT}$" -c4 --format csv 2>/dev/null | cut -d' ' -f1)"
echo
echo "  Tím smažete server $KONT včetně všeho, co jste na něm udělali."
echo "  Váš pár klíčů, přenesené soubory ani formulář na stanici to nesmaže."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      [ -n "$IP_STARA" ] && ssh-keygen -R "$IP_STARA" >/dev/null 2>&1
      echo "  Smazáno."; exec "$(dirname "$0")/start.sh"
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
