#!/bin/bash
# 2/22 — návrat do výchozího stavu
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PREV="$HOME/netlab/prevzeti"
VZOR='bash .*sber-[a-z]+\.sh'
# Účet se dopočítá stejným vzorcem jako v start.sh — maže se jen ten, který
# cvičení zadává. Mazat všechny kandidáty by znamenalo smazat i skutečný
# účet stanice, kdyby se náhodou jmenoval stejně.
JMENA=(mvesela rkolar jsedlak bnovotny lkrizova pmoravec)
UZIVATEL="${JMENA[$(( $(lab_vyber 6 1 221) - 1 ))]}"

echo
echo "  Tím smažete celý adresář $PREV včetně všeho, co jste udělali,"
echo "  a nabídnu vám i zrušení účtu $UZIVATEL a skupiny expedice."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo; exit 0 ;;
esac

# Nejdřív slušně, teprve pak natvrdo — stejné pořadí, jaké učí samo cvičení.
for p in $(pgrep -f "$VZOR" 2>/dev/null); do kill "$p" 2>/dev/null; done
sleep 1
for p in $(pgrep -f "$VZOR" 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
# Adresář je celý žákův, root na něj není potřeba.
rm -rf "${PREV:?}"
echo "  Adresář smazán."

# Účet a skupina se ruší jen na výslovné přání — mazání účtu je nevratné.
read -r -p "  Zrušit i účet $UZIVATEL a skupinu expedice? [a/N] " u
case "$u" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS])
    if id "$UZIVATEL" >/dev/null 2>&1; then
      # Pojistka: ruší se jen účet, který je opravdu z tohoto cvičení.
      if id -nG "$UZIVATEL" 2>/dev/null | tr ' ' '\n' | grep -qx expedice; then
        sudo userdel -r "$UZIVATEL" 2>/dev/null && echo "  Účet $UZIVATEL zrušen."
      else
        echo "  Účet $UZIVATEL není ve skupině expedice — nechávám ho být."
      fi
    fi
    getent group expedice >/dev/null && sudo groupdel expedice 2>/dev/null \
      && echo "  Skupina expedice zrušena."
    ;;
  *) echo "  Účet a skupina zůstávají." ;;
esac
exec "$(dirname "$0")/start.sh"
