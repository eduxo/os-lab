#!/bin/bash
# 3/22 — návrat do výchozího stavu (smaže server i celou souhrnnou práci)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="intraweb-$ZAK2"
PRACE="$HOME/netlab/intraweb"
PROTOKOL="$PRACE/protokol.txt"
echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Tím smažete server $KONT a s ním CELOU souhrnnou práci —"
echo "  web, certifikát, zónu, timer i nastavení firewallu."
echo "  U dvoublokové práce to znamená začít od nuly."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      # Kód zakázky i otisk certifikátu vzniknou nové, takže vyplněný
      # protokol by přestal platit.
      rm -f "$PROTOKOL"
      echo "  Smazáno — i protokol na stanici, protože hodnoty v něm už neplatí."
      exec "$(dirname "$0")/start.sh"
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; echo; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo ;;
esac
