#!/bin/bash
# 3/03 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="server-$ZAK2"
# Adresu je nutné zjistit JEŠTĚ PŘED smazáním — potom už ji nikdo nezjistí
# a záznam v known_hosts by zůstal viset.
IP_STARA="$(lxc list "^${KONT}$" -c4 --format csv 2>/dev/null | cut -d' ' -f1)"

echo
echo "  Tím smažete server $KONT včetně všeho, co jste na něm udělali."
echo "  Formulář na stanici i uložené heslo zůstanou."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      # Nový server bude mít jiný klíč. Starý záznam v known_hosts by pak
      # připojení zablokoval hláškou o možném útoku — proto ho odstraníme.
      [ -n "$IP_STARA" ] && ssh-keygen -R "$IP_STARA" >/dev/null 2>&1
      echo "  Smazáno."; exec "$(dirname "$0")/start.sh"
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
