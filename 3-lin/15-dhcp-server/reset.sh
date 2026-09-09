#!/bin/bash
# 3/15 — návrat do výchozího stavu
#
# Dvě úrovně. Server netlab-XX sdílejí cvičení 14 a 15, takže bourat ho
# kvůli novému pokusu s DHCP by znamenalo přijít i o zónu ze čtrnáctky.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="netlab-$ZAK2"
KLIENT="klient-$ZAK2"

znovu_start() { exec "$(dirname "$0")/start.sh"; }

echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Server $KONT je společný pro cvičení 14 a 15."
echo
echo "    [z] Zahodit jen nastavení DHCP a databázi zápůjček."
echo "        Zóna DNS ze cvičení 14 zůstane."
echo "    [c] Celý server od nuly — smaže i zónu."
echo "    [n] Nic nedělat."
echo
read -r -p "  Co uděláme? [z/c/N] " o

case "$o" in
  [zZ])
    if [ "$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)" != "RUNNING" ]; then
      echo "  Server neběží — spusťte nejdřív ./start.sh"; echo; exit 1
    fi
    lxc exec "$KONT" -- bash -c "
      systemctl disable --now dnsmasq >/dev/null 2>&1
      rm -f /etc/dnsmasq.d/*.conf /var/lib/misc/dnsmasq.leases
    " >/dev/null 2>&1
    # Klient se smaže celý — jinak by si držel starou zápůjčku a vypadalo by
    # to, že DHCP funguje, i když se ho nikdo neptal.
    lxc delete -f "$KLIENT" >/dev/null 2>&1
    echo "  Nastavení DHCP smazáno. Stavím klienta znovu."
    znovu_start ;;
  [cC])
    lxc delete -f "$KLIENT" >/dev/null 2>&1
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      echo "  Smazáno."; znovu_start
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
