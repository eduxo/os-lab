#!/bin/bash
# 3/15 — DHCP server. Prostředí: server netlab-XX + testovací klient klient-XX.
#
# Server je týž jako ve 14 a DNS na něm poslouchá dál — i žákovi, který
# čtrnáctku nedělal, ho tenhle skript nainstaluje a nastartuje. Je to
# záměr, ne vedlejší efekt: obsazený port 53 je jádro učiva patnáctky.
# dnsmasq totiž umí DNS i DHCP a je potřeba mu tu první půlku vypnout.
#
# ./start.sh --klient  přinutí testovacího klienta požádat o adresu znovu
#                      a vypíše, co dostal. Žák tím má zpětnou vazbu, aniž
#                      by sám sahal na `lxc`.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="netlab-$ZAK2"
source "$(dirname "$0")/../../lib/netlab-lib.sh"

vypis_klienta() {
  local a; a="$(klient_adresa)"
  echo
  if [ -z "$a" ]; then
    echo "  Klient $NETLAB_KLIENT žádnou adresu nedostal."
    echo "  Buď DHCP server neběží, nebo nerozdává na správném rozhraní."
    echo "  Na serveru pomůže:  systemctl status dnsmasq"
  else
    echo "  Klient $NETLAB_KLIENT dostal adresu: $a"
    lxc exec "$NETLAB_KLIENT" -- bash -c \
      "ip route show default 2>/dev/null | head -1" 2>/dev/null \
      | sed 's/^/    výchozí brána:  /'
  fi
  echo
}

if [ "${1:-}" = "--klient" ]; then
  if ! command -v lxc >/dev/null 2>&1; then
    echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
  fi
  if [ "$(lxc list "^${NETLAB_KLIENT}$" -c s --format csv 2>/dev/null)" != "RUNNING" ]; then
    echo; echo "  Testovací klient neběží. Spusťte nejdřív ./start.sh"; echo; exit 1
  fi
  echo; echo "  Žádám o novou adresu…"
  klient_znovu || true
  vypis_klienta
  exit 0
fi

zaridi_sit || exit 1
SERVER_SIT2="$NETLAB_SIT"
SERVER_IP2="$NETLAB_SERVER/$NETLAB_PREFIX"   # prefix se bere ze sítě, ne natvrdo
source "$(dirname "$0")/../../lib/server-lib.sh"

DHCP="$HOME/netlab/dhcp"
FORMULAR="$DHCP/formular.txt"

vyrob_formular() {
  mkdir -p "$DHCP"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# Obojí najdete v databázi zápůjček na serveru. Kde leží, zjistíte
# z dokumentace dnsmasq — hledejte „lease file".
#
# adresa-klienta = adresa, kterou klient dostal
# mac-klienta    = jeho hardwarová adresa (šest dvojic oddělených dvojtečkou)
adresa-klienta:
mac-klienta:
FORM_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

# bind9 tu není kvůli DNS, ale kvůli tomu, aby byl port 53 obsazený
# i žákovi, který čtrnáctku nedělal. Bez toho by polovina třídy nepochopila,
# proč se dnsmasq musí DNS zakázat — u nich by naběhl i bez toho.
doinstaluj bind9:named dnsmasq:dnsmasq || exit 1
lxc exec "$SERVER_KONT" -- systemctl enable --now named >/dev/null 2>&1

# dnsmasq se po instalaci sám spustí s výchozí konfigurací a obsadil by
# port 53 dřív, než ho žák stihne vypnout. Necháme ho zastavený — nastartuje
# si ho sám, až bude mít konfiguraci hotovou. Je to i poctivější zadání:
# „služba neběží, rozběhněte ji" místo „služba běží špatně".
#
# PODMÍNĚNĚ: jakmile žák konfiguraci napsal, je služba jeho práce a druhé
# spuštění start.sh ji nesmí vypnout. Bez téhle podmínky by stačilo pustit
# ./stop.sh a ./start.sh a hotové cvičení by hlásilo tři FAILy.
if ! lxc exec "$SERVER_KONT" -- test -e /etc/dnsmasq.d/netlab.conf; then
  lxc exec "$SERVER_KONT" -- systemctl disable --now dnsmasq >/dev/null 2>&1
fi

postav_klienta || exit 1

[ -s "$FORMULAR" ] || vyrob_formular

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP        (správa, přes lxdbr0)
    Přihlášení: $PRIHLASENI

    Síť netlab:      $NETLAB_PODSIT.0/24
    Brána:           $NETLAB_BRANA
    Adresa serveru:  $NETLAB_SERVER   (rozhraní eth1)
    Testovací klient: $NETLAB_KLIENT   (je jen na netlab, adresu nemá)

    Formulář:   $FORMULAR   (na stanici)

  Rozdávat se má z rozsahu $NETLAB_PODSIT.100 až $NETLAB_PODSIT.150,
  s bránou $NETLAB_BRANA, DNS serverem $NETLAB_SERVER
  a doménou netlab.test.

  Až budete chtít zkusit, jestli to funguje, spusťte NA STANICI:

    cd ~/os-lab/3-lin/15-dhcp-server && ./start.sh --klient

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/15-dhcp-server && ./check.sh --krok 1

EOF
