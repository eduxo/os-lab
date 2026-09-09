#!/bin/bash
# 3/12 — návrat do výchozího stavu
#
# Dvě úrovně, stejně jako u 3/10. Server provoz-XX je společný pro cvičení
# 11, 12 a 13, takže bourat ho kvůli novému úklidu by znamenalo přijít
# i o práci z ostatních dvou.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="provoz-$ZAK2"
ZAVEDENO_KLIC="user.lab312-zavedeno"

znovu_start() { exec "$(dirname "$0")/start.sh"; }

echo
echo "  Server $KONT je společný pro cvičení 11, 12 a 13."
echo
echo "    [z] Zaneřádit server znovu — smaže jen to, co patří tomuhle"
echo "        cvičení. Práce z 11 a 13 zůstane."
echo "    [c] Celý server od nuly — smaže i archiv a nastavení firewallu."
echo "    [n] Nic nedělat."
echo
read -r -p "  Co uděláme? [z/c/N] " o

case "$o" in
  [zZ])
    if ! lxc list "^${KONT}$" -c s --format csv 2>/dev/null | grep -q RUNNING; then
      echo "  Server neběží — spusťte nejdřív ./start.sh"; echo; exit 1
    fi
    ZAVEDENO="$(lxc config get "$KONT" "$ZAVEDENO_KLIC" 2>/dev/null)"
    # V klíči jsou tři losovaná jména: služba, fronta, evidence.
    read -r SLUZBA FRONTA EVID _ <<< "$ZAVEDENO"   # čtvrté pole je otisk logu, tady nepotřebný
    if [ -n "${SLUZBA:-}" ] && [ -n "${FRONTA:-}" ] && [ -n "${EVID:-}" ]; then
      lxc exec "$KONT" -- bash -c "
        systemctl disable --now $SLUZBA $EVID >/dev/null 2>&1
        rm -f /etc/systemd/system/$SLUZBA.service /etc/systemd/system/$EVID.service
        rm -f /usr/local/bin/$SLUZBA.sh /usr/local/bin/$EVID.sh
        rm -rf /var/lib/$SLUZBA /srv/$FRONTA /var/log/$EVID
        systemctl daemon-reload
      " >/dev/null 2>&1
    fi
    if ! lxc config unset "$KONT" "$ZAVEDENO_KLIC" 2>/dev/null; then
      echo "  Stav se nepodařilo vymazat — zavolejte vyučujícího."; echo; exit 1
    fi
    echo "  Uklizeno. Zaneřáduji server znovu."
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
