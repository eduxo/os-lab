#!/bin/bash
# 3/10 — návrat do výchozího stavu
#
# Dvě úrovně. Server sluzby-XX je společný pro cvičení 7 až 10, takže bourat
# ho kvůli znovunasazení jedné služby by znamenalo přijít i o práci
# z ostatních tří. Proto je „měkký" reset první.
#
# Ani jedna úroveň nedá jiné závady — losují se z čísla žáka pevnými solemi.
# Reset je na to, když se prostředí rozbije, ne na nový pokus s jinou úlohou.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="sluzby-$ZAK2"
ZAVEDENO_KLIC="user.lab310-zavedeno"

znovu_start() { exec "$(dirname "$0")/start.sh"; }

echo
echo "  Server $KONT je společný pro cvičení 7, 8, 9 a 10."
echo
echo "    [z] Nasadit službu tisk znovu — smaže jen ji."
echo "        Práce ze cvičení 7, 8 a 9 zůstane. Závady budou TYTÉŽ:"
echo "        losují se z vašeho čísla, takže se restartem nezmění."
echo "    [c] Celý server od nuly — smaže i hlídače, zálohovací timer"
echo "        a skript s podmínkou."
echo "    [n] Nic nedělat."
echo
read -r -p "  Co uděláme? [z/c/N] " o

case "$o" in
  [zZ])
    if ! lxc list "^${KONT}$" -c s --format csv 2>/dev/null | grep -q RUNNING; then
      echo "  Server neběží — spusťte nejdřív ./start.sh"; echo; exit 1
    fi
    lxc exec "$KONT" -- bash -c "
      systemctl disable --now tisk >/dev/null 2>&1
      rm -f /etc/systemd/system/tisk.service /usr/local/bin/tisk.sh
      rm -rf /var/log/tisk /srv/tisk /srv/tisk-fronta
      systemctl daemon-reload
    " >/dev/null 2>&1
    # Smazání klíče je to, co start.sh pozná jako „stav ještě nestojí".
    if ! lxc config unset "$KONT" "$ZAVEDENO_KLIC" 2>/dev/null; then
      echo "  Stav se nepodařilo vymazat — zavolejte vyučujícího."; echo; exit 1
    fi
    echo "  Služba tisk smazána. Stavím ji znovu se stejnými závadami."
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
