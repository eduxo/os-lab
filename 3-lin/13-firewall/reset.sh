#!/bin/bash
# 3/13 — návrat do výchozího stavu
#
# Firewall se dá vrátit do výchozího stavu bez bourání serveru, proto je
# měkký reset první — server provoz-XX sdílejí cvičení 11, 12 a 13.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="provoz-$ZAK2"

znovu_start() { exec "$(dirname "$0")/start.sh"; }

echo
echo "  Server $KONT je společný pro cvičení 11, 12 a 13."
echo
echo "    [z] Vymazat pravidla firewallu — jen ufw, nic jiného."
echo "        Práce z 11 a 12 zůstane."
echo "    [c] Celý server od nuly — smaže i archiv a úklid ze cvičení 12."
echo "    [n] Nic nedělat."
echo
read -r -p "  Co uděláme? [z/c/N] " o

case "$o" in
  [zZ])
    if ! lxc list "^${KONT}$" -c s --format csv 2>/dev/null | grep -q RUNNING; then
      echo "  Server neběží — spusťte nejdřív ./start.sh"; echo; exit 1
    fi
    # `ufw --force reset` zahodí pravidla a firewall vypne. Jde přes
    # lxc exec, takže funguje i tehdy, když se žák odřízl od SSH.
    lxc exec "$KONT" -- bash -c "ufw --force reset" >/dev/null 2>&1
    echo "  Pravidla firewallu vymazána, ufw je vypnutý."
    znovu_start ;;
  [cC])
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      echo "  Smazáno."; znovu_start
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
