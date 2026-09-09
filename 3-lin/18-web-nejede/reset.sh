#!/bin/bash
# 3/18 — návrat do výchozího stavu
#
# Dvě úrovně. Server web-XX sdílejí cvičení 16, 17 a 18, takže bourat ho
# kvůli novému pokusu s poruchou by znamenalo přijít i o certifikáty
# a vlastní certifikační autoritu ze sedmnáctky.
#
# Ani jedna úroveň nedá JINOU vrstvu — losuje se z čísla žáka pevnou solí.
# Reset je na to, když se prostředí rozbije, ne na druhý pokus s jinou úlohou.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="web-$ZAK2"
SERVER_KONT="$KONT"
# Jen kvůli jménu klíče — ať není natvrdo na třech místech.
source "$(dirname "$0")/../../lib/web-lib.sh"
ZAVEDENO_KLIC="$WEB_VRSTVA_KLIC"
SITE=objednavky
ROOT=/var/www/objednavky

znovu_start() { exec "$(dirname "$0")/start.sh"; }

echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Server $KONT je společný pro cvičení 16, 17 a 18."
echo
echo "    [z] Postavit web objednavky znovu — smaže jen jeho."
echo "        Váš web i certifikáty ze 16 a 17 zůstanou. Vrstva bude"
echo "        TATÁŽ: losuje se z vašeho čísla, restartem se nezmění."
echo "    [c] Celý server od nuly — smaže i certifikační autoritu."
echo "    [n] Nic nedělat."
echo
read -r -p "  Co uděláme? [z/c/N] " o

case "$o" in
  [zZ])
    if [ "$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)" != "RUNNING" ]; then
      echo "  Server neběží — spusťte nejdřív ./start.sh"; echo; exit 1
    fi
    lxc exec "$KONT" -- bash -c "
      a2dissite $SITE >/dev/null 2>&1
      rm -f /etc/apache2/sites-available/$SITE.conf
      rm -rf $ROOT
      systemctl unmask apache2 >/dev/null 2>&1
      systemctl enable --now apache2 >/dev/null 2>&1
      systemctl reload apache2 >/dev/null 2>&1
    " >/dev/null 2>&1
    if ! lxc config unset "$KONT" "$ZAVEDENO_KLIC" 2>/dev/null; then
      echo "  Stav se nepodařilo vymazat — zavolejte vyučujícího."; echo; exit 1
    fi
    echo "  Web objednavky smazán. Stavím ho znovu se stejnou vrstvou."
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
